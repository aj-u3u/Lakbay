from datetime import datetime, timedelta, timezone

from sqlalchemy.ext.asyncio import AsyncSession

from app.features.evaluation.repository import EvaluationRepository
from app.features.evaluation.schemas import (
    AIMetrics,
    AIModelMetrics,
    CatalogMetrics,
    EvaluationSummaryResponse,
    RecommendationMetrics,
)


def _average(value: object | None) -> float | None:
    return None if value is None else round(float(value), 1)


class EvaluationService:
    def __init__(self, session: AsyncSession) -> None:
        self.repository = EvaluationRepository(session)

    async def summary(self, *, window_days: int) -> EvaluationSummaryResponse:
        generated_at = datetime.now(timezone.utc)
        window_start = generated_at - timedelta(days=window_days)
        ai = await self.repository.ai_totals(window_start, generated_at)
        by_model = await self.repository.ai_by_model(window_start, generated_at)
        preferences = await self.repository.preference_submissions(window_start, generated_at)
        interactions = await self.repository.catalog_interactions(window_start, generated_at)
        catalog = await self.repository.catalog_snapshot()
        interaction_counts = {kind: int(count) for kind, count, _ in interactions}
        rating = next(
            (average for kind, _, average in interactions if kind == "rate"),
            None,
        )

        return EvaluationSummaryResponse(
            window_start=window_start,
            generated_at=generated_at,
            ai=AIMetrics(
                attempts=int(ai.attempts),
                succeeded=int(ai.succeeded),
                failed=int(ai.failed),
                valid=int(ai.valid),
                invalid=int(ai.invalid),
                fallback_used=int(ai.fallback_used),
                average_response_time_ms=_average(ai.average_response_time_ms),
                by_model=[
                    AIModelMetrics(
                        model_role=row.model_role,
                        model_id=row.model_id,
                        attempts=int(row.attempts),
                        succeeded=int(row.succeeded),
                        failed=int(row.failed),
                        average_response_time_ms=_average(row.average_response_time_ms),
                    )
                    for row in by_model
                ],
            ),
            recommendations=RecommendationMetrics(
                preference_submissions=preferences,
                catalog_views=interaction_counts.get("view", 0),
                catalog_saves=interaction_counts.get("save", 0),
                catalog_ratings=interaction_counts.get("rate", 0),
                catalog_itinerary_adds=interaction_counts.get("add_to_itinerary", 0),
                average_catalog_rating=_average(rating),
                attribution_note=(
                    "Catalog interactions are not linked to a recommendation result. "
                    "These counts do not measure recommendation accuracy."
                ),
            ),
            catalog=CatalogMetrics(
                active_destinations=int(catalog.active),
                route_ready_destinations=int(catalog.route_ready),
                unknown_cost_destinations=int(catalog.unknown_cost),
            ),
        )
