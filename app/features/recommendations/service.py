from dataclasses import dataclass
from decimal import Decimal

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.destinations.candidate_repository import distance_meters
from app.features.destinations.models import Destination
from app.features.planning.routing import _has_non_road_access_hint
from app.features.recommendations import scoring
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
    TopPlaceBreakdown,
    TopPlaceFactor,
    TopPlaceItem,
    TopPlacesRequest,
    TopPlacesResponse,
    TopPlacesSkipped,
    TopPlaceTravelBasis,
)
from app.features.routes.schemas import RouteCoordinate
from app.features.routes.service import FALLBACK_SPEED_KMH
from app.features.users.models import User
from app.integrations.osrm.client import MAX_PREVIEW_WAYPOINT_SNAP_METERS, OSRMClient
from app.integrations.osrm.errors import OSRMClientError

NON_REPEATABLE_INTERACTIONS = {"save", "rate", "add_to_itinerary"}
# One OSRM table request covers at most this many places (public OSRM allows 100).
MAX_ROUTED_CANDIDATES = 50


@dataclass
class _TopPlaceCandidate:
    destination: Destination
    matched: list[str]
    matched_fields: list[str]
    # Normalized 0-1 factor values, except travel, which needs a route first.
    values: dict[str, float]


@dataclass(frozen=True)
class _Trip:
    minutes: int | None
    distance_km: Decimal | None
    basis: TopPlaceTravelBasis
    provider: str | None
    verified: bool
    reachable: bool = True


class RecommendationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.recommendations = RecommendationRepository(session)

    async def rank_top_places(
        self,
        *,
        data: TopPlacesRequest,
        osrm_client: OSRMClient | None,
        user: User | None = None,
        save_preference: bool = False,
    ) -> TopPlacesResponse:
        """Rank places with the weighted scoring model in `scoring.py`.

        Places with a verified entrance and a confirmed road route fill the list
        first; places whose location is approximate fill any remaining slots.
        """
        preference_signal_id = None
        if save_preference and user is not None:
            preference = await self.recommendations.create_preference_signal(
                user_id=user.user_id,
                data=RecommendationRequest(
                    preferred_categories=data.interests,
                    preferred_vibes=data.interests,
                    preferred_activities=data.interests,
                    preferred_districts=data.preferred_districts,
                    requires_kid_friendly=data.requires_kid_friendly,
                    requires_wheelchair_accessible=data.requires_wheelchair_accessible,
                    requires_pet_friendly=data.requires_pet_friendly,
                    requires_elderly_friendly=data.requires_elderly_friendly,
                    group_friendly=True if data.party_size > 1 else None,
                    limit=data.limit,
                ),
            )
            preference_signal_id = preference.preference_signal_id

        destinations = await self.recommendations.list_active_destinations()
        popularity = await self.recommendations.list_popularity()
        party = data.party_size
        budget_per_person = (
            None if data.total_budget is None
            else data.total_budget if data.budget_scope == "per_person"
            else data.total_budget / party
        )
        max_minutes = scoring.max_travel_minutes(data.day_count)
        districts = {item.strip().lower() for item in data.preferred_districts}
        required_flags = (
            (data.requires_kid_friendly, "is_kid_friendly"),
            (data.requires_wheelchair_accessible, "is_wheelchair_accessible"),
            (data.requires_pet_friendly, "is_pet_friendly"),
            (data.requires_elderly_friendly, "is_elderly_friendly"),
        )
        road_mode = data.travel_mode in {"driving", "walking"}
        skipped = TopPlacesSkipped()
        interest_match_count = 0
        candidates: list[_TopPlaceCandidate] = []
        for destination in destinations:
            matched, matched_fields = scoring.interest_matches(data.interests, {
                "category": destination.category,
                "vibes": destination.vibes,
                "activities": destination.activities,
            })
            if matched:
                interest_match_count += 1
            if districts and (destination.district or "").strip().lower() not in districts:
                skipped.outside_preferred_districts += 1
                continue
            if any(required and not getattr(destination, flag) for required, flag in required_flags):
                skipped.missing_required_accessibility += 1
                continue
            if data.interests and not matched:
                skipped.no_interest_match += 1
                continue
            cost = destination.estimated_cost
            if cost is not None and budget_per_person is not None and cost > budget_per_person:
                skipped.over_budget += 1
                continue
            if road_mode and _has_non_road_access_hint(destination):
                skipped.needs_boat_or_ferry += 1
                continue
            record = popularity.get(destination.destination_id)
            candidates.append(_TopPlaceCandidate(
                destination=destination,
                matched=matched,
                matched_fields=matched_fields,
                values={
                    "interest": scoring.interest_score(len(data.interests), len(matched)),
                    "budget": scoring.budget_score(cost, budget_per_person),
                    "group_fit": scoring.group_fit_score(
                        has_children=bool(data.child_ages),
                        traveler_count=party,
                        is_kid_friendly=destination.is_kid_friendly,
                        group_friendly=destination.group_friendly,
                    ),
                    "popularity": scoring.popularity_score(
                        record.popularity_score if record else None
                    ),
                },
            ))

        # Route only the strongest candidates, so one table request stays small.
        # A straight-line estimate stands in for travel while shortlisting, so
        # distant places cannot crowd out nearby ones before the road check.
        candidates.sort(key=lambda item: (
            -_shortlist_score(data, item, max_minutes),
            item.destination.destination_id,
        ))
        candidates = candidates[:MAX_ROUTED_CANDIDATES]
        travel, warnings = await _travel_times(data, candidates, osrm_client)

        qualified: list[TopPlaceItem] = []
        for candidate in candidates:
            destination = candidate.destination
            trip = travel[destination.destination_id]
            if not trip.reachable:
                skipped.no_route += 1
                continue
            if trip.minutes is not None and trip.minutes > max_minutes:
                skipped.too_far += 1
                continue
            values = {**candidate.values, "travel": scoring.travel_score(trip.minutes, max_minutes)}
            points = scoring.weighted_points(values)
            qualified.append(TopPlaceItem(
                rank=0,
                destination_id=destination.destination_id,
                name=destination.name,
                district=destination.district,
                category=destination.category,
                image_url=destination.image_url,
                estimated_cost=destination.estimated_cost,
                cost_basis="not_listed" if destination.estimated_cost is None else "catalog_estimate",
                score=scoring.total_score(points),
                breakdown=TopPlaceBreakdown(**{
                    name: TopPlaceFactor(
                        value=round(values[name], 4),
                        weight=scoring.WEIGHTS[name],
                        points=points[name],
                    )
                    for name in scoring.WEIGHTS
                }),
                matched_interests=candidate.matched,
                matched_fields=candidate.matched_fields,
                reasons=_top_place_reasons(
                    data=data,
                    candidate=candidate,
                    trip=trip,
                    budget_per_person=budget_per_person,
                ),
                route_verified=trip.verified,
                travel_mode=data.travel_mode,
                travel_basis=trip.basis,
                route_provider=trip.provider,
                travel_minutes=trip.minutes,
                travel_distance_km=trip.distance_km,
            ))

        # Verified road routes first, then approximate places; best score first in each.
        qualified.sort(key=lambda item: (
            not item.route_verified,
            -item.score,
            item.travel_minutes if item.travel_minutes is not None else float("inf"),
            item.destination_id,
        ))
        items = [
            item.model_copy(update={"rank": index})
            for index, item in enumerate(qualified[: data.limit], start=1)
        ]
        approximate = sum(1 for item in items if not item.route_verified)
        if data.origin is None:
            warnings.append("Set a start point on the map to rank places by travel time.")
        elif approximate:
            warnings.append(
                f"{approximate} of these places {'has' if approximate == 1 else 'have'} "
                "no verified road route to a visitor entrance yet, so travel times are approximate."
            )
        if data.total_budget is not None:
            warnings.append(
                "Costs are catalog estimates per person; transport, lodging and meals are not included."
            )

        if save_preference:
            await self.session.commit()
        return TopPlacesResponse(
            weights=scoring.WEIGHTS,
            max_travel_minutes=max_minutes,
            preference_signal_id=preference_signal_id,
            total_candidates=len(qualified),
            verified_count=sum(1 for item in qualified if item.route_verified),
            items=items,
            skipped=skipped,
            shortfall_reason=_top_place_shortfall(
                data=data,
                qualified=len(qualified),
                interest_match_count=interest_match_count,
                skipped=skipped,
            ),
            warnings=warnings,
        )

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


def planning_recommendation_from_top_place(item: TopPlaceItem) -> PlanningRecommendationItem:
    """Shape a Top 5 place for the planning chat response."""
    return PlanningRecommendationItem(
        destination_id=item.destination_id,
        name=item.name,
        district=item.district,
        category=item.category,
        estimated_cost=item.estimated_cost,
        score=item.score,
        matched_fields=item.matched_fields,
        reasons=item.reasons,
        route_provider=item.route_provider,
        travel_mode=item.travel_mode,
        route_distance_km=item.travel_distance_km,
        route_duration_minutes=item.travel_minutes,
        route_verified=item.route_verified,
        travel_basis=item.travel_basis,
        breakdown=item.breakdown,
    )


def _route_point(destination: Destination) -> RouteCoordinate:
    """The verified visitor entrance when there is one, otherwise the attraction pin."""
    if _has_verified_arrival(destination):
        return RouteCoordinate(lat=destination.arrival_lat, lng=destination.arrival_lng)
    return RouteCoordinate(lat=destination.lat, lng=destination.lng)


async def _travel_times(
    data: TopPlacesRequest,
    candidates: list[_TopPlaceCandidate],
    osrm_client: OSRMClient | None,
) -> tuple[dict[int, _Trip], list[str]]:
    """Travel from the start point to each candidate, with how it was measured."""
    if data.origin is None:
        return {
            item.destination.destination_id: _Trip(None, None, "unknown", None, False)
            for item in candidates
        }, []
    if data.travel_mode == "public_transport":
        return {
            item.destination.destination_id: _straight_line_trip(
                data.origin, item.destination, "public_transport", "commute_estimate",
            )
            for item in candidates
        }, []

    table = None
    if osrm_client is not None and candidates:
        try:
            table = await osrm_client.table(
                travel_mode=data.travel_mode,
                origin=data.origin,
                destinations=[_route_point(item.destination) for item in candidates],
            )
        except OSRMClientError:
            table = None
    if table is None:
        return {
            item.destination.destination_id: _straight_line_trip(
                data.origin, item.destination, data.travel_mode, "straight_line_estimate",
            )
            for item in candidates
        }, (
            ["Road routing was unavailable, so travel times are straight-line estimates."]
            if candidates else []
        )

    source_on_road = (
        table.source_snap_meters is not None
        and table.source_snap_meters <= MAX_PREVIEW_WAYPOINT_SNAP_METERS
    )
    trips: dict[int, _Trip] = {}
    for item, entry in zip(candidates, table.entries):
        destination_id = item.destination.destination_id
        if entry.duration_seconds is None:
            trips[destination_id] = _Trip(
                None, None, "approximate_location", "osrm", False, reachable=False,
            )
            continue
        # A road route counts as verified only to a sourced visitor entrance that
        # OSRM reached without moving either end more than 250 m.
        verified = bool(
            _has_verified_arrival(item.destination)
            and source_on_road
            and entry.snap_meters is not None
            and entry.snap_meters <= MAX_PREVIEW_WAYPOINT_SNAP_METERS
        )
        trips[destination_id] = _Trip(
            minutes=_whole_minutes(entry.duration_seconds),
            distance_km=(
                None if entry.distance_meters is None
                else (Decimal(str(entry.distance_meters)) / 1000).quantize(Decimal("0.01"))
            ),
            basis="road_route" if verified else "approximate_location",
            provider="osrm",
            verified=verified,
        )
    return trips, []


def _shortlist_score(
    data: TopPlacesRequest,
    candidate: _TopPlaceCandidate,
    max_minutes: int,
) -> float:
    """The weighted score with straight-line travel, used only to pick places to route."""
    travel = scoring.NEUTRAL
    if data.origin is not None:
        estimate = _straight_line_trip(
            data.origin, candidate.destination, data.travel_mode, "straight_line_estimate",
        )
        travel = scoring.travel_score(estimate.minutes, max_minutes)
    return scoring.total_score(scoring.weighted_points({**candidate.values, "travel": travel}))


def _straight_line_trip(
    origin: RouteCoordinate,
    destination: Destination,
    travel_mode: str,
    basis: TopPlaceTravelBasis,
) -> _Trip:
    point = _route_point(destination)
    km = distance_meters(origin.lat, origin.lng, point.lat, point.lng) / 1000
    return _Trip(
        minutes=_whole_minutes(km / float(FALLBACK_SPEED_KMH[travel_mode]) * 3600),
        distance_km=Decimal(str(round(km, 2))).quantize(Decimal("0.01")),
        basis=basis,
        provider="haversine",
        verified=False,
    )


def _whole_minutes(seconds: float) -> int:
    return max(1, round(seconds / 60)) if seconds > 0 else 0


_MODE_WORDS = {"driving": "by car", "walking": "on foot", "public_transport": "by commute"}


def _top_place_reasons(
    *,
    data: TopPlacesRequest,
    candidate: _TopPlaceCandidate,
    trip: _Trip,
    budget_per_person: Decimal | None,
) -> list[str]:
    destination = candidate.destination
    reasons: list[str] = []
    if candidate.matched:
        reasons.append(f"Matches {', '.join(candidate.matched)}.")
    elif not data.interests:
        reasons.append("Add a vibe or interest to rank places by what you like.")

    way = _MODE_WORDS[data.travel_mode]
    if trip.basis == "road_route":
        reasons.append(f"About {trip.minutes} min {way} from your start by road.")
    elif trip.basis == "approximate_location":
        reasons.append(
            f"About {trip.minutes} min {way}; approximate, because the visitor entrance "
            "is not verified yet."
        )
    elif trip.basis == "straight_line_estimate":
        reasons.append(f"About {trip.minutes} min {way} (straight-line estimate).")
    elif trip.basis == "commute_estimate":
        reasons.append(f"About {trip.minutes} min by commute (estimate).")
    else:
        reasons.append("Set a start point to rank by travel time.")

    cost = destination.estimated_cost
    if cost is None:
        reasons.append("Cost not listed.")
    elif budget_per_person is not None:
        reasons.append(
            f"About ₱{cost:,.0f} per person, within your ₱{budget_per_person:,.0f} per person."
        )
    else:
        reasons.append(f"About ₱{cost:,.0f} per person (catalog estimate).")

    if data.child_ages:
        reasons.append("Kid-friendly." if destination.is_kid_friendly else "Not marked kid-friendly.")
    if data.party_size >= scoring.LARGE_GROUP_SIZE and destination.group_friendly:
        reasons.append("Good for groups.")
    if candidate.values["popularity"] > 0:
        reasons.append("Popular with Lakbay travelers.")
    return reasons


_SKIP_PHRASES = {
    "no_interest_match": ("does not match your interests", "do not match your interests"),
    "outside_preferred_districts": ("is outside your chosen districts", "are outside your chosen districts"),
    "missing_required_accessibility": (
        "lacks a required accessibility feature", "lack a required accessibility feature",
    ),
    "over_budget": ("is over your budget", "are over your budget"),
    "needs_boat_or_ferry": ("needs a boat or ferry", "need a boat or ferry"),
    "no_route": ("has no road route from your start", "have no road route from your start"),
    "too_far": ("is too far for your trip length", "are too far for your trip length"),
}


def _top_place_shortfall(
    *,
    data: TopPlacesRequest,
    qualified: int,
    interest_match_count: int,
    skipped: TopPlacesSkipped,
) -> str | None:
    if data.interests and interest_match_count == 0:
        return "No active catalog destination matches the supplied travel interests."
    if qualified >= data.limit:
        return None
    parts = [
        f"{count} {single if count == 1 else plural}"
        for name, (single, plural) in _SKIP_PHRASES.items()
        if (count := getattr(skipped, name)) > 0
    ]
    found = f"Only {qualified} {'place qualifies' if qualified == 1 else 'places qualify'} for your Top {data.limit}"
    if not parts:
        return f"{found}."
    listed = parts[0] if len(parts) == 1 else f"{', '.join(parts[:-1])} and {parts[-1]}"
    return f"{found}: {listed}."
