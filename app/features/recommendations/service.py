from decimal import Decimal

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.destinations.models import Destination
from app.features.planning.routing import _has_non_road_access_hint
from app.features.recommendations.models import (
    DestinationInteraction,
    DestinationPopularity,
)
from app.features.recommendations.repository import RecommendationRepository
from app.features.recommendations.schemas import (
    DestinationInteractionCreate,
    DestinationInteractionResponse,
    DestinationPopularityResponse,
    PreferenceSignalResponse,
    PlanningRecommendationItem,
    RecommendationItem,
    RecommendationRequest,
    RecommendationResponse,
)
from app.features.routes.schemas import RouteCoordinate, RoutePreviewRequest, RouteSummaryResponse
from app.features.routes.service import RouteService
from app.features.users.models import User

NON_REPEATABLE_INTERACTIONS = {"save", "rate", "add_to_itinerary"}


class RecommendationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.recommendations = RecommendationRepository(session)

    async def rank_planning_candidates(
        self,
        *,
        interests: list[str],
        traveler_count: int | None,
        origin: RouteCoordinate | None,
        travel_mode: str | None,
        route_service: RouteService | None,
        limit: int = 5,
    ) -> tuple[list[PlanningRecommendationItem], int, str | None]:
        """Return only preference matches with verified arrivals and provider routes."""
        if not interests:
            return [], 0, "No travel interests were supplied, so there is no preference match to rank."
        preference = RecommendationRequest(
            preferred_categories=interests,
            preferred_vibes=interests,
            preferred_activities=interests,
            group_friendly=True if traveler_count and traveler_count > 1 else None,
            limit=limit,
        )
        destinations = await self.recommendations.list_active_destinations()
        popularity = await self.recommendations.list_popularity()
        matches = [
            item
            for destination in destinations
            if (
                item := self.score_destination(
                    destination=destination,
                    preference=preference,
                    popularity=popularity.get(destination.destination_id),
                )
            ) is not None
            and bool({"category", "vibes", "activities"} & set(item.matched_fields))
        ]
        matches.sort(key=lambda item: (-item.score, item.destination_id))
        if not matches:
            return [], 0, "No active catalog destination matches the supplied travel interests."

        destinations_by_id = {item.destination_id: item for item in destinations}
        verified = [
            item for item in matches
            if _has_verified_arrival(destinations_by_id[item.destination_id])
        ]
        unverified_count = len(matches) - len(verified)
        road_candidates = [
            item for item in verified
            if not _has_non_road_access_hint(destinations_by_id[item.destination_id])
        ]
        non_road_count = len(verified) - len(road_candidates)
        if not road_candidates:
            return [], 0, (
                f"No verified road candidates qualify from {len(matches)} preference matches: "
                f"{unverified_count} lack a verified arrival point and "
                f"{non_road_count} need a separate non-road connection."
            )
        if origin is None:
            return [], 0, (
                f"{len(matches)} preference matches found; {unverified_count} lack a verified "
                f"arrival point and {non_road_count} need a non-road connection. Reachability "
                "of the remaining candidates cannot be confirmed without a map-selected origin coordinate."
            )
        if travel_mode not in {"driving", "walking"}:
            return [], 0, (
                f"{len(matches)} preference matches found; {unverified_count} lack a verified "
                f"arrival point and {non_road_count} need a non-road connection. A single "
                "driving or walking mode is needed to confirm routes to the remaining candidates."
            )
        if route_service is None:
            return [], 0, "Routing is unavailable, so no candidate can be confirmed reachable."

        qualified: list[PlanningRecommendationItem] = []
        route_failed_count = 0
        for item in road_candidates:
            try:
                route = await route_service.preview_route(RoutePreviewRequest(
                    destination_ids=[item.destination_id],
                    origin=origin,
                    travel_mode=travel_mode,
                ))
            except LakbayAPIError:
                route_failed_count += 1
                continue
            if not _confirms_candidate_route(
                route, destinations_by_id[item.destination_id], origin, travel_mode,
            ):
                route_failed_count += 1
                continue
            qualified.append(PlanningRecommendationItem(
                **{
                    **item.model_dump(),
                    "reasons": [*item.reasons, "Provider route reaches the verified visitor arrival point."],
                },
                route_provider=route.route_provider,
                travel_mode=travel_mode,
                route_distance_km=route.total_distance_km,
                route_duration_minutes=route.total_duration_minutes,
            ))

        # Preserve preference rank; a shorter confirmed trip breaks equal scores.
        qualified.sort(key=lambda item: (
            -item.score, item.route_duration_minutes,
            item.route_distance_km, item.destination_id,
        ))
        total = len(qualified)
        reason = None
        if total < limit:
            reason = (
                f"Only {total} verified, reachable candidates qualify from {len(matches)} "
                f"preference matches: {unverified_count} lack a verified arrival point, "
                f"{non_road_count} need a separate non-road connection, and "
                f"{route_failed_count} have no confirmed {travel_mode} route."
            )
        return qualified[:limit], total, reason

    async def recommend_destinations(
        self,
        *,
        user: User,
        data: RecommendationRequest,
    ) -> RecommendationResponse:
        preference = await self.recommendations.create_preference_signal(
            user_id=user.user_id,
            data=data,
        )
        destinations = await self.recommendations.list_active_destinations()
        popularity_by_destination = await self.recommendations.list_popularity()

        scored = [
            item
            for destination in destinations
            if (
                item := self.score_destination(
                    destination=destination,
                    preference=preference,
                    popularity=popularity_by_destination.get(
                        destination.destination_id,
                    ),
                )
            )
            is not None
        ]
        scored.sort(key=lambda item: item.score, reverse=True)

        await self.session.commit()

        return RecommendationResponse(
            preference_signal_id=preference.preference_signal_id,
            total_candidates=len(scored),
            recommendations=scored[: data.limit],
        )

    async def get_latest_preference(self, *, user: User) -> PreferenceSignalResponse:
        preference = await self.recommendations.get_latest_preference(
            user_id=user.user_id,
        )

        if preference is None:
            raise LakbayAPIError(
                "No preference signal was found for this user.",
                code="preference_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return PreferenceSignalResponse.model_validate(preference)

    async def create_interaction(
        self,
        *,
        user: User,
        destination_id: int,
        data: DestinationInteractionCreate,
    ) -> DestinationInteractionResponse:
        await self._require_active_destination(destination_id)
        interaction = await self._record_interaction(
            user_id=user.user_id,
            destination_id=destination_id,
            data=data,
        )
        popularity = await self.recommendations.get_or_create_popularity(
            destination_id=destination_id,
        )
        interactions = await self.recommendations.list_destination_interactions(
            destination_id=destination_id,
        )

        self._recalculate_popularity(
            popularity=popularity,
            interactions=interactions,
        )
        await self.session.commit()
        await self.session.refresh(interaction)

        return DestinationInteractionResponse.model_validate(interaction)

    async def get_popularity(
        self,
        *,
        destination_id: int,
    ) -> DestinationPopularityResponse:
        await self._require_active_destination(destination_id)
        popularity = await self.recommendations.get_popularity(
            destination_id=destination_id,
        )

        if popularity is None:
            return DestinationPopularityResponse(
                destination_id=destination_id,
                view_count=0,
                save_count=0,
                rating_count=0,
                rating_sum=0,
                average_rating=Decimal("0.00"),
                add_to_itinerary_count=0,
                popularity_score=Decimal("0.00"),
                created_at=None,
                updated_at=None,
            )

        return DestinationPopularityResponse.model_validate(popularity)

    async def _require_active_destination(self, destination_id: int) -> Destination:
        destination = await self.recommendations.get_active_destination(
            destination_id=destination_id,
        )

        if destination is None:
            raise LakbayAPIError(
                "Destination was not found.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return destination

    def score_destination(
        self,
        *,
        destination: Destination,
        preference,
        popularity: DestinationPopularity | None,
    ) -> RecommendationItem | None:
        if not self._passes_hard_filters(destination=destination, preference=preference):
            return None

        score = 0.0
        matched_fields: list[str] = []
        reasons: list[str] = []

        score += _match_list(
            values=preference.preferred_categories,
            text=destination.category,
            weight=25,
            field="category",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Matches preferred destination category.",
        )
        score += _match_list(
            values=preference.preferred_vibes,
            text=destination.vibes,
            weight=15,
            field="vibes",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Matches preferred travel vibe.",
        )
        score += _match_list(
            values=preference.preferred_activities,
            text=destination.activities,
            weight=15,
            field="activities",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Offers one or more preferred activities.",
        )
        score += _match_list(
            values=preference.preferred_districts,
            text=destination.district,
            weight=10,
            field="district",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Matches preferred district.",
        )
        score += _match_value(
            preferred=preference.budget_class,
            actual=destination.budget_class,
            weight=15,
            field="budget_class",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Fits the preferred budget class.",
        )
        score += _match_value(
            preferred=preference.difficulty_level,
            actual=destination.difficulty_level,
            weight=10,
            field="difficulty_level",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Matches preferred difficulty level.",
        )
        score += _match_value(
            preferred=preference.stay_duration_type,
            actual=destination.stay_duration_type,
            weight=5,
            field="stay_duration_type",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Matches preferred trip duration.",
        )
        score += _match_bool(
            preferred=preference.family_friendly,
            actual=destination.family_friendly,
            field="family_friendly",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Works for family travel.",
        )
        score += _match_bool(
            preferred=preference.couple_friendly,
            actual=destination.couple_friendly,
            field="couple_friendly",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Works for couple travel.",
        )
        score += _match_bool(
            preferred=preference.group_friendly,
            actual=destination.group_friendly,
            field="group_friendly",
            matched_fields=matched_fields,
            reasons=reasons,
            reason="Works for group travel.",
        )

        has_ranking_preferences = _has_ranking_preferences(preference)

        if has_ranking_preferences and score <= 0:
            return None

        score += self._popularity_boost(popularity, matched_fields, reasons)

        return RecommendationItem(
            destination_id=destination.destination_id,
            name=destination.name,
            district=destination.district,
            category=destination.category,
            estimated_cost=destination.estimated_cost,
            score=round(score, 2),
            matched_fields=matched_fields,
            reasons=reasons,
        )

    def _passes_hard_filters(self, *, destination: Destination, preference) -> bool:
        if (
            preference.max_estimated_cost is not None
            and (
                destination.estimated_cost is None
                or destination.estimated_cost > preference.max_estimated_cost
            )
        ):
            return False

        required_flags = [
            (preference.requires_kid_friendly, destination.is_kid_friendly),
            (
                preference.requires_wheelchair_accessible,
                destination.is_wheelchair_accessible,
            ),
            (preference.requires_pet_friendly, destination.is_pet_friendly),
            (preference.requires_elderly_friendly, destination.is_elderly_friendly),
        ]

        return all(not required or actual for required, actual in required_flags)

    def _popularity_boost(
        self,
        popularity: DestinationPopularity | None,
        matched_fields: list[str],
        reasons: list[str],
    ) -> float:
        if popularity is None or popularity.popularity_score <= 0:
            return 0

        boost = min(float(popularity.popularity_score) / 10, 10)

        if boost > 0:
            matched_fields.append("popularity")
            reasons.append("Has positive traveler interaction history.")

        return boost

    async def _record_interaction(
        self,
        *,
        user_id: int,
        destination_id: int,
        data: DestinationInteractionCreate,
    ) -> DestinationInteraction:
        if data.interaction_type in NON_REPEATABLE_INTERACTIONS:
            existing = await self.recommendations.get_user_interaction(
                user_id=user_id,
                destination_id=destination_id,
                interaction_type=data.interaction_type,
            )

            if existing is not None:
                if data.interaction_type == "rate":
                    return await self.recommendations.update_interaction(
                        existing,
                        data,
                    )

                return existing

        return await self.recommendations.create_interaction(
            user_id=user_id,
            destination_id=destination_id,
            data=data,
        )

    def _recalculate_popularity(
        self,
        *,
        popularity: DestinationPopularity,
        interactions: list[DestinationInteraction],
    ) -> None:
        ratings = [
            interaction.rating
            for interaction in interactions
            if interaction.interaction_type == "rate" and interaction.rating is not None
        ]

        popularity.view_count = _count_interactions(interactions, "view")
        popularity.save_count = _count_interactions(interactions, "save")
        popularity.add_to_itinerary_count = _count_interactions(
            interactions,
            "add_to_itinerary",
        )
        popularity.rating_count = len(ratings)
        popularity.rating_sum = sum(ratings)
        popularity.average_rating = (
            (
                Decimal(popularity.rating_sum) / Decimal(popularity.rating_count)
            ).quantize(Decimal("0.01"))
            if popularity.rating_count
            else Decimal("0.00")
        )

        popularity.popularity_score = (
            Decimal(_int(popularity.view_count))
            + Decimal(_int(popularity.save_count) * 3)
            + Decimal(_int(popularity.add_to_itinerary_count) * 5)
            + (Decimal(popularity.average_rating or 0) * Decimal("2"))
        )


def _has_verified_arrival(destination: Destination) -> bool:
    return bool(
        destination.route_ready
        and destination.arrival_lat is not None
        and destination.arrival_lng is not None
        and destination.arrival_source_url
        and destination.arrival_verified_at
    )


def _confirms_candidate_route(
    route: RouteSummaryResponse,
    destination: Destination,
    origin: RouteCoordinate,
    travel_mode: str,
) -> bool:
    if len(route.stops) != 2 or len(route.legs) != 1:
        return False
    start, end = route.stops
    leg = route.legs[0]
    return bool(
        route.route_provider in {"osrm", "google_routes"}
        and route.travel_mode == travel_mode
        and not route.is_estimated
        and route.arrival_points_verified
        and start.is_origin and start.destination_id is None
        and start.coordinate_basis == "origin"
        and abs(start.lat - origin.lat) <= 0.000001
        and abs(start.lng - origin.lng) <= 0.000001
        and not end.is_origin
        and end.destination_id == destination.destination_id
        and end.coordinate_basis == "verified_arrival"
        and abs(end.lat - destination.arrival_lat) <= 0.000001
        and abs(end.lng - destination.arrival_lng) <= 0.000001
        and leg.from_destination_id is None
        and leg.to_destination_id == destination.destination_id
        and not leg.is_estimated
        and abs(route.total_distance_km - leg.distance_km) <= Decimal("0.01")
        and abs(route.total_duration_minutes - leg.duration_minutes) <= 1
    )


def _match_list(
    *,
    values: list[str],
    text: str | None,
    weight: int,
    field: str,
    matched_fields: list[str],
    reasons: list[str],
    reason: str,
) -> float:
    if not values or not text:
        return 0

    searchable = text.lower()

    if any(value in searchable for value in values):
        matched_fields.append(field)
        reasons.append(reason)

        return weight

    return 0


def _match_value(
    *,
    preferred: str | None,
    actual: str | None,
    weight: int,
    field: str,
    matched_fields: list[str],
    reasons: list[str],
    reason: str,
) -> float:
    if preferred and actual and preferred.strip().lower() == actual.strip().lower():
        matched_fields.append(field)
        reasons.append(reason)

        return weight

    return 0


def _match_bool(
    *,
    preferred: bool | None,
    actual: bool,
    field: str,
    matched_fields: list[str],
    reasons: list[str],
    reason: str,
) -> float:
    if preferred is True and actual:
        matched_fields.append(field)
        reasons.append(reason)

        return 5

    return 0


def _has_ranking_preferences(preference) -> bool:
    return any(
        (
            preference.preferred_categories,
            preference.preferred_vibes,
            preference.preferred_activities,
            preference.preferred_districts,
            preference.budget_class,
            preference.difficulty_level,
            preference.stay_duration_type,
            preference.family_friendly is not None,
            preference.couple_friendly is not None,
            preference.group_friendly is not None,
        )
    )


def _count_interactions(
    interactions: list[DestinationInteraction],
    interaction_type: str,
) -> int:
    return sum(
        1
        for interaction in interactions
        if interaction.interaction_type == interaction_type
    )


def _int(value: int | None) -> int:
    return value or 0
