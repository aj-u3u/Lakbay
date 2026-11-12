"""Read-only Phase 15B and Phase 3 inputs for selected itinerary destinations."""

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.exceptions import LakbayAPIError
from app.features.destinations.models import Destination
from app.features.geo_analytics.dependencies import get_geo_group_limiter
from app.features.geo_analytics.schemas import DestinationGroupsRequest, DestinationGroupsResponse
from app.features.geo_analytics.service import GeoAnalyticsService
from app.features.planning.schemas import PlanningPreviewResponse
from app.features.recommendations.repository import RecommendationRepository
from app.features.recommendations.schemas import RecommendationItem, RecommendationRequest
from app.features.recommendations.service import RecommendationService
from app.features.routes.service import RouteService
from app.features.users.models import User


async def selected_geo_inputs(
    *,
    session: AsyncSession,
    user: User,
    preview: PlanningPreviewResponse,
    destinations: list[Destination],
    routes: RouteService | None,
    interests: list[str],
) -> tuple[list[RecommendationItem], DestinationGroupsResponse | None]:
    """Rank only allowed IDs and score groups when a planning route was requested."""
    interests = interests or preview.state.interests
    recommendations: list[RecommendationItem] = []
    if interests:
        scorer = RecommendationService(session)
        popularity = await RecommendationRepository(session).list_popularity()
        preference = RecommendationRequest(
            preferred_categories=interests,
            preferred_vibes=interests,
            preferred_activities=interests,
            group_friendly=True if (preview.state.traveler_count or 0) > 1 else None,
        )
        for destination in destinations:
            scored = scorer.score_destination(
                destination=destination,
                preference=preference,
                popularity=popularity.get(destination.destination_id),
            )
            if scored is not None and {"category", "vibes", "activities"}.intersection(scored.matched_fields):
                recommendations.append(scored)
        recommendations.sort(key=lambda item: (-item.score, item.destination_id))
        recommendations = recommendations[:5]

    route = preview.route
    if (
        routes is None or route.summary is None or route.travel_mode is None
        or len(preview.state.destination_ids) < 2
    ):
        return recommendations, None

    group_size = min(3, len(preview.state.destination_ids), get_settings().route_max_destinations)
    if group_size < 2:
        return recommendations, None
    get_geo_group_limiter().check(user.user_id)
    try:
        groups = await GeoAnalyticsService(session, routes).group(
            data=DestinationGroupsRequest(
                destination_ids=preview.state.destination_ids,
                travel_mode=route.travel_mode,
                group_size=group_size,
                max_groups=3,
                max_destination_cost=preview.whole_trip_budget,
                max_route_minutes=min(1440, 240 * (preview.state.day_count or 1)),
            ),
            user=user,
        )
    except LakbayAPIError as exc:
        if exc.status_code == status.HTTP_429_TOO_MANY_REQUESTS:
            raise
        # A group is supplementary context; the authoritative preview remains valid.
        groups = DestinationGroupsResponse(
            groups=[], candidates_considered=0,
            warnings=[f"Phase 15B grouping unavailable: {exc.message}"],
        )
    return recommendations, groups
