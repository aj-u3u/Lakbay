from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.features.accommodations.models import Accommodation
from app.features.ai.models import AIGenerationRun
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation


class AIItineraryRepository:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session

    async def list_active_destinations_by_ids(
        self,
        destination_ids: list[int],
    ) -> list[Destination]:
        result = await self.session.execute(
            select(Destination).where(
                Destination.destination_id.in_(destination_ids),
                Destination.is_active.is_(True),
            )
        )

        return list(result.scalars().all())

    async def list_available_accommodations_by_ids(
        self,
        accommodation_ids: list[int],
    ) -> list[Accommodation]:
        if not accommodation_ids:
            return []

        result = await self.session.execute(
            select(Accommodation).where(
                Accommodation.accommodation_id.in_(accommodation_ids),
                Accommodation.is_available.is_(True),
            )
        )

        return list(result.scalars().all())

    async def list_available_transportations_by_ids(
        self,
        transportation_ids: list[int],
    ) -> list[Transportation]:
        if not transportation_ids:
            return []

        result = await self.session.execute(
            select(Transportation).where(
                Transportation.transportation_id.in_(transportation_ids),
                Transportation.is_available.is_(True),
            )
        )

        return list(result.scalars().all())

    async def create_generation_run(
        self,
        *,
        user_id: int,
        request_purpose: str,
        model_role: str,
        model_id: str,
        prompt_version: str,
        input_summary: dict,
        fallback_used: bool = False,
    ) -> AIGenerationRun:
        run = AIGenerationRun(
            user_id=user_id,
            request_purpose=request_purpose,
            model_role=model_role,
            model_id=model_id,
            prompt_version=prompt_version,
            status="running",
            validation_status="pending",
            input_summary=input_summary,
            fallback_used=fallback_used,
        )
        self.session.add(run)
        await self.session.flush()

        return run

    async def update_generation_run(
        self,
        run: AIGenerationRun,
        *,
        status: str,
        validation_status: str,
        response_time_ms: int | None = None,
        prompt_tokens: int | None = None,
        completion_tokens: int | None = None,
        total_tokens: int | None = None,
        error_message: str | None = None,
        output_summary: dict | None = None,
    ) -> AIGenerationRun:
        run.status = status
        run.validation_status = validation_status
        run.response_time_ms = response_time_ms
        run.prompt_tokens = prompt_tokens
        run.completion_tokens = completion_tokens
        run.total_tokens = total_tokens
        run.error_message = error_message
        run.output_summary = output_summary
        await self.session.flush()

        return run
