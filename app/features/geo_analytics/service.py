from dataclasses import dataclass
from decimal import Decimal
from itertools import combinations
from math import asin, cos, radians, sin, sqrt

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.features.destinations.models import Destination
from app.features.geo_analytics.repository import GeoAnalyticsRepository
from app.features.geo_analytics.schemas import (
    DestinationGroup,
    DestinationGroupsRequest,
    DestinationGroupsResponse,
    GroupScoreBreakdown,
)
from app.features.recommendations.repository import RecommendationRepository
from app.features.recommendations.service import RecommendationService
from app.features.routes.schemas import RouteOptimizeRequest
from app.features.routes.service import RouteService
from app.features.users.models import User

EARTH_RADIUS_KM = 6371.0


@dataclass(frozen=True)
class Candidate:
    destinations: tuple[Destination, ...]
    preference: float
    proximity: float
    district: float
    popularity: float
    accessibility: float
    child_friendliness: float
    cost: Decimal
    shortlist_score: float

    @property
    def ids(self) -> tuple[int, ...]:
        return tuple(destination.destination_id for destination in self.destinations)


class GeoAnalyticsService:
    def __init__(self, session: AsyncSession, routes: RouteService) -> None:
        self.destinations = GeoAnalyticsRepository(session)
        self.recommendations = RecommendationRepository(session)
        self.scorer = RecommendationService(session)
        self.routes = routes

    async def group(
        self, *, data: DestinationGroupsRequest, user: User
    ) -> DestinationGroupsResponse:
        if data.group_size > get_settings().route_max_destinations:
            raise LakbayAPIError(
                "Group size exceeds the configured route destination limit.",
                code="route_destination_limit_exceeded",
                details={"max_destinations": get_settings().route_max_destinations},
            )

        rows = await self.destinations.list_active_by_ids(data.destination_ids)
        by_id = {destination.destination_id: destination for destination in rows}
        missing_ids = [item for item in data.destination_ids if item not in by_id]
        if missing_ids:
            raise LakbayAPIError(
                "One or more destinations were not found or are inactive.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
                details={"destination_ids": missing_ids},
            )

        preference = await self.recommendations.get_latest_preference(
            user_id=user.user_id
        )
        popularity = await self.recommendations.list_popularity()
        warnings: list[str] = []
        if preference is None:
            warnings.append("No saved preferences; preference score is neutral.")
        eligible: list[Destination] = []
        preference_scores: dict[int, float] = {}
        popularity_scores: dict[int, float] = {}
        for destination_id in data.destination_ids:
            destination = by_id[destination_id]
            record = popularity.get(destination_id)
            popularity_scores[destination_id] = min(
                100.0, float(record.popularity_score or 0) if record else 0.0
            )
            if preference is None:
                preference_scores[destination_id] = 50.0
            else:
                scored = self.scorer.score_destination(
                    destination=destination, preference=preference, popularity=record
                )
                if scored is None:
                    continue
                popularity_boost = min(popularity_scores[destination_id] / 10, 10)
                preference_scores[destination_id] = _clamp(
                    (scored.score - popularity_boost) / 110 * 100
                )
            eligible.append(destination)

        if len(eligible) < len(rows):
            warnings.append("Some destinations did not match the saved preferences.")

        unknown_cost_ids = [
            item.destination_id for item in eligible if item.estimated_cost is None
        ]
        if unknown_cost_ids:
            warnings.append("Destinations with unknown costs were excluded from cost-scored groups.")
        candidates: list[Candidate] = []
        ordered = sorted(
            (item for item in eligible if item.estimated_cost is not None),
            key=lambda item: item.destination_id,
        )
        for group in combinations(ordered, data.group_size):
            max_distance = max(
                _haversine_km(start, end) for start, end in combinations(group, 2)
            )
            if max_distance > data.max_separation_km:
                continue
            proximity = _clamp(100 * (1 - max_distance / data.max_separation_km))
            districts = {
                item.district.strip().casefold()
                for item in group
                if item.district and item.district.strip()
            }
            district_score = (
                100.0
                if len(districts) == 1
                and all(item.district and item.district.strip() for item in group)
                else 50.0
                if districts and len(districts) < len(group)
                else 0.0
            )
            cost = sum((item.estimated_cost for item in group), Decimal("0.00"))
            if data.max_destination_cost is not None and cost > data.max_destination_cost:
                continue
            preference_score = _mean(preference_scores[item.destination_id] for item in group)
            candidates.append(
                Candidate(
                    destinations=group,
                    preference=preference_score,
                    proximity=proximity,
                    district=district_score,
                    popularity=_mean(
                        popularity_scores[item.destination_id] for item in group
                    ),
                    accessibility=_mean(
                        100.0 if item.is_wheelchair_accessible else 0.0
                        for item in group
                    ),
                    child_friendliness=_mean(
                        100.0 if item.is_kid_friendly else 0.0 for item in group
                    ),
                    cost=cost,
                    shortlist_score=round(
                        0.45 * preference_score
                        + 0.40 * proximity
                        + 0.15 * district_score,
                        2,
                    ),
                )
            )

        candidates.sort(key=lambda item: (-item.shortlist_score, item.ids))
        shortlist = candidates[: min(10, max(5, data.max_groups * 2))]
        scored = [await self._route_and_score(candidate, data) for candidate in shortlist]
        groups = [
            group
            for group in scored
            if group.route_duration_minutes <= data.max_route_minutes
        ]
        groups.sort(key=lambda item: (-item.score, item.destination_ids))
        if not groups:
            warnings.append(
                "No destination groups met the separation, preference, cost, and route limits."
            )
        return DestinationGroupsResponse(
            groups=groups[: data.max_groups],
            candidates_considered=len(candidates),
            warnings=warnings,
        )

    async def _route_and_score(
        self, candidate: Candidate, data: DestinationGroupsRequest
    ) -> DestinationGroup:
        route = await self.routes.optimize_route(
            RouteOptimizeRequest(
                destination_ids=list(candidate.ids),
                travel_mode=data.travel_mode,
                preserve_first_destination=False,
            )
        )
        route_efficiency = _clamp(
            100 * (1 - route.total_duration_minutes / data.max_route_minutes)
        )
        mode_fit = (
            30.0
            if data.travel_mode == "public_transport"
            else 50.0 if route.is_estimated else 100.0
        )
        geo = round(
            0.40 * candidate.proximity
            + 0.35 * route_efficiency
            + 0.15 * candidate.district
            + 0.10 * mode_fit,
            2,
        )
        budget_fit = (
            50.0 if data.max_destination_cost is None
            else 100.0 if candidate.cost == 0
            else _clamp(float((1 - candidate.cost / data.max_destination_cost) * 100))
        )
        score = round(
            0.35 * candidate.preference
            + 0.25 * geo
            + 0.20 * budget_fit
            + 0.10 * candidate.popularity
            + 0.05 * candidate.accessibility
            + 0.05 * candidate.child_friendliness,
            2,
        )
        reasons = []
        if candidate.district == 100:
            reasons.append("Destinations share a district.")
        if candidate.proximity >= 50:
            reasons.append("Destinations are close together.")
        if candidate.preference >= 60:
            reasons.append("Destinations match saved travel preferences.")
        if not reasons:
            reasons.append("Destinations meet the requested separation limit.")
        warnings = list(route.warnings)
        if route.is_estimated and not warnings:
            warnings.append("Route distance and duration are estimates.")
        warnings.append("Destination cost excludes transport, lodging, meals, and other expenses.")
        return DestinationGroup(
            destination_ids=list(candidate.ids),
            route_order=[
                stop.destination_id
                for stop in route.stops
                if stop.destination_id is not None
            ],
            score=score,
            scores=GroupScoreBreakdown(
                preference=round(candidate.preference, 2),
                proximity=round(candidate.proximity, 2),
                route_efficiency=round(route_efficiency, 2),
                district=round(candidate.district, 2),
                travel_mode_fit=mode_fit,
                geo=geo,
                budget_fit=round(budget_fit, 2),
                popularity=round(candidate.popularity, 2),
                accessibility=round(candidate.accessibility, 2),
                child_friendliness=round(candidate.child_friendliness, 2),
            ),
            estimated_destination_cost=candidate.cost,
            route_distance_km=route.total_distance_km,
            route_duration_minutes=route.total_duration_minutes,
            route_provider=route.route_provider,
            is_route_estimated=route.is_estimated,
            reasons=reasons,
            warnings=warnings,
        )


def _mean(values) -> float:
    numbers = list(values)
    return sum(numbers) / len(numbers)


def _clamp(value: float) -> float:
    return max(0.0, min(100.0, value))


def _haversine_km(start: Destination, end: Destination) -> float:
    latitude_1 = radians(start.lat)
    latitude_2 = radians(end.lat)
    latitude_delta = radians(end.lat - start.lat)
    longitude_delta = radians(end.lng - start.lng)
    value = (
        sin(latitude_delta / 2) ** 2
        + cos(latitude_1) * cos(latitude_2) * sin(longitude_delta / 2) ** 2
    )
    return 2 * EARTH_RADIUS_KM * asin(min(1.0, sqrt(value)))
