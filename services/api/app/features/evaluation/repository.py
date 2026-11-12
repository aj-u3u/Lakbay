from datetime import datetime

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.ai.models import AIGenerationRun
from app.features.destinations.models import Destination
from app.features.recommendations.models import (
    DestinationInteraction,
    UserPreferenceSignal,
)


class EvaluationRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def ai_totals(self, start: datetime, end: datetime):
        result = await self.session.execute(
            select(
                func.count().label("attempts"),
                func.count().filter(AIGenerationRun.status == "succeeded").label("succeeded"),
                func.count().filter(AIGenerationRun.status == "failed").label("failed"),
                func.count().filter(AIGenerationRun.validation_status == "valid").label("valid"),
                func.count().filter(AIGenerationRun.validation_status == "invalid").label("invalid"),
                func.count().filter(AIGenerationRun.fallback_used.is_(True)).label("fallback_used"),
                func.avg(AIGenerationRun.response_time_ms).label("average_response_time_ms"),
            ).where(AIGenerationRun.created_at >= start, AIGenerationRun.created_at <= end)
        )
        return result.one()

    async def ai_by_model(self, start: datetime, end: datetime):
        result = await self.session.execute(
            select(
                AIGenerationRun.model_role,
                AIGenerationRun.model_id,
                func.count().label("attempts"),
                func.count().filter(AIGenerationRun.status == "succeeded").label("succeeded"),
                func.count().filter(AIGenerationRun.status == "failed").label("failed"),
                func.avg(AIGenerationRun.response_time_ms).label("average_response_time_ms"),
            )
            .where(AIGenerationRun.created_at >= start, AIGenerationRun.created_at <= end)
            .group_by(AIGenerationRun.model_role, AIGenerationRun.model_id)
            .order_by(AIGenerationRun.model_role, AIGenerationRun.model_id)
        )
        return result.all()

    async def preference_submissions(self, start: datetime, end: datetime) -> int:
        result = await self.session.execute(
            select(func.count()).select_from(UserPreferenceSignal).where(
                UserPreferenceSignal.created_at >= start,
                UserPreferenceSignal.created_at <= end,
            )
        )
        return int(result.scalar_one())

    async def catalog_interactions(self, start: datetime, end: datetime):
        result = await self.session.execute(
            select(
                DestinationInteraction.interaction_type,
                func.count().label("count"),
                func.avg(DestinationInteraction.rating).label("average_rating"),
            )
            .where(
                DestinationInteraction.created_at >= start,
                DestinationInteraction.created_at <= end,
            )
            .group_by(DestinationInteraction.interaction_type)
        )
        return result.all()

    async def catalog_snapshot(self):
        result = await self.session.execute(
            select(
                func.count().label("active"),
                func.count().filter(Destination.route_ready.is_(True)).label("route_ready"),
                func.count().filter(Destination.estimated_cost.is_(None)).label("unknown_cost"),
            ).where(Destination.is_active.is_(True))
        )
        return result.one()
