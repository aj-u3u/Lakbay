from decimal import Decimal
from time import perf_counter

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import LakbayAPIError
from app.features.accommodations.models import Accommodation
from app.features.ai.models import AIGenerationRun
from app.features.ai.repository import AIItineraryRepository
from app.features.ai.rag import VectorRAGRetriever
from app.features.ai.schemas import (
    AIChatRequest,
    AIChatResponse,
    AIItineraryGenerateRequest,
    AIItineraryGenerateResponse,
    AIModelRunResult,
)
from app.features.ai.validators import (
    AIItineraryCatalog,
    AIOutputValidationError,
    parse_and_validate_itinerary_output,
)
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation
from app.features.users.models import User
from app.integrations.groq.client import GroqClient
from app.integrations.groq.errors import GroqClientError
from app.integrations.groq.model_selector import (
    ModelSelection,
    select_comparison_models,
    select_fallback_model,
    select_primary_model,
)
from app.integrations.groq.prompts import (
    CHAT_PROMPT_VERSION,
    PROMPT_VERSION,
    build_chat_messages,
    build_itinerary_messages,
)

REQUEST_PURPOSE = "itinerary_generation"
CHAT_REQUEST_PURPOSE = "travel_chat"


class AIItineraryService:
    def __init__(self, session: AsyncSession, groq_client: GroqClient) -> None:
        self.session = session
        self.ai = AIItineraryRepository(session)
        self.groq_client = groq_client

    async def generate_itinerary(
        self,
        *,
        user: User,
        data: AIItineraryGenerateRequest,
    ) -> AIItineraryGenerateResponse:
        settings = get_settings()
        destinations = await self.ai.list_active_destinations_by_ids(
            list(data.destination_ids),
        )
        self._require_all_destinations(data.destination_ids, destinations)

        accommodations = await self.ai.list_available_accommodations_by_ids(
            list(data.accommodation_ids),
        )
        self._require_all_accommodations(data.accommodation_ids, accommodations)

        transportations = await self.ai.list_available_transportations_by_ids(
            list(data.transportation_ids),
        )
        self._require_all_transportations(data.transportation_ids, transportations)
        self._require_rates_belong_to_destinations(
            accommodations=accommodations,
            transportations=transportations,
            destination_ids=set(data.destination_ids),
        )

        selections = self._select_models(settings=settings, data=data)
        catalog_payload = _build_catalog_payload(
            destinations=destinations,
            accommodations=accommodations,
            transportations=transportations,
        )
        validator_catalog = AIItineraryCatalog(
            destination_ids={destination.destination_id for destination in destinations},
            accommodation_ids={
                accommodation.accommodation_id for accommodation in accommodations
            },
            transportation_ids={
                transportation.transportation_id for transportation in transportations
            },
            total_budget=Decimal(data.total_budget),
            day_count=data.day_count,
            minimum_option_count=settings.ai_itinerary_option_count,
        )
        messages = build_itinerary_messages(
            request=data,
            catalog=catalog_payload,
            option_count=settings.ai_itinerary_option_count,
        )

        model_runs: list[AIModelRunResult] = []
        primary_options = []

        for selection in selections:
            run_result = await self._run_model_generation(
                user=user,
                data=data,
                selection=selection,
                messages=messages,
                catalog=validator_catalog,
                option_count=settings.ai_itinerary_option_count,
            )
            model_runs.append(run_result)

            if run_result.status == "succeeded" and not primary_options:
                primary_options = run_result.options

            if run_result.status == "succeeded" and not data.compare_models:
                break

        if not primary_options:
            raise LakbayAPIError(
                "AI itinerary generation failed.",
                code="ai_generation_failed",
                status_code=status.HTTP_502_BAD_GATEWAY,
                details={
                    "model_runs": [
                        run.model_dump(exclude={"options"}) for run in model_runs
                    ],
                },
            )

        return AIItineraryGenerateResponse(
            options=primary_options,
            model_runs=model_runs,
        )

    async def chat(
        self,
        *,
        user: User,
        data: AIChatRequest,
    ) -> AIChatResponse:
        settings = get_settings()
        selections = self._select_chat_models(
            settings=settings,
            model_role=data.model_role,
            allow_fallback=data.allow_fallback,
        )
        rag_matches = []
        if data.use_rag and data.rag_limit > 0:
            rag_matches = await VectorRAGRetriever(self.session).retrieve(
                _build_rag_query(data),
                limit=data.rag_limit,
            )

        retrieved_context = [match.to_prompt_dict() for match in rag_matches]
        messages = build_chat_messages(
            request=data,
            retrieved_context=retrieved_context,
        )
        failed_runs: list[dict] = []

        for selection in selections:
            run = await self.ai.create_generation_run(
                user_id=user.user_id,
                request_purpose=CHAT_REQUEST_PURPOSE,
                model_role=selection.model_role,
                model_id=selection.model_id,
                prompt_version=CHAT_PROMPT_VERSION,
                input_summary=_build_chat_input_summary(data),
                fallback_used=selection.fallback_used,
            )
            await self.session.commit()
            await self.session.refresh(run)

            started_at = perf_counter()

            try:
                completion = await self.groq_client.create_chat_completion(
                    model=selection.model_id,
                    messages=messages,
                )
                response_time_ms = _elapsed_ms(started_at)
                chat_response = completion.content.strip() or (
                    "I could not generate a helpful answer just now. "
                    "Please try asking in another way."
                )
                updated_run = await self.ai.update_generation_run(
                    run,
                    status="succeeded",
                    validation_status="not_run",
                    response_time_ms=response_time_ms,
                    prompt_tokens=completion.prompt_tokens,
                    completion_tokens=completion.completion_tokens,
                    total_tokens=completion.total_tokens,
                    output_summary={
                        "response_length": len(chat_response),
                        "retrieved_context_count": len(retrieved_context),
                    },
                )
                await self.session.commit()
                await self.session.refresh(updated_run)

                return AIChatResponse(
                    chat_response=chat_response,
                    mode="rag_chat" if retrieved_context else "chat",
                    model_role=updated_run.model_role,
                    model_id=updated_run.model_id,
                    ai_generation_run_id=updated_run.ai_generation_run_id,
                    retrieved_context=[
                        match.to_response_dict() for match in rag_matches
                    ],
                    response_time_ms=updated_run.response_time_ms,
                    prompt_tokens=updated_run.prompt_tokens,
                    completion_tokens=updated_run.completion_tokens,
                    total_tokens=updated_run.total_tokens,
                )
            except GroqClientError as exc:
                updated_run = await self.ai.update_generation_run(
                    run,
                    status="failed",
                    validation_status="not_run",
                    response_time_ms=_elapsed_ms(started_at),
                    error_message=exc.message,
                )
                await self.session.commit()
                await self.session.refresh(updated_run)
                failed_runs.append(
                    {
                        "ai_generation_run_id": updated_run.ai_generation_run_id,
                        "model_role": updated_run.model_role,
                        "model_id": updated_run.model_id,
                        "error_message": updated_run.error_message,
                    }
                )

        raise LakbayAPIError(
            "AI chat failed.",
            code="ai_chat_failed",
            status_code=status.HTTP_502_BAD_GATEWAY,
            details={"model_runs": failed_runs},
        )

    def _select_models(
        self,
        *,
        settings: Settings,
        data: AIItineraryGenerateRequest,
    ) -> list[ModelSelection]:
        if data.compare_models:
            if not settings.ai_model_comparison_enabled:
                raise LakbayAPIError(
                    "AI model comparison is disabled.",
                    code="ai_model_comparison_disabled",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )

            comparison_models = select_comparison_models(settings=settings)

            if len(comparison_models) < 2:
                raise LakbayAPIError(
                    "At least two comparison models must be configured.",
                    code="ai_comparison_models_not_configured",
                    status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

            return comparison_models

        primary = select_primary_model(settings=settings, model_role=data.model_role)

        if primary is None:
            raise LakbayAPIError(
                "A Groq model is not configured for itinerary generation.",
                code="ai_model_not_configured",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        selections = [primary]

        if data.allow_fallback:
            fallback = select_fallback_model(
                settings=settings,
                primary_model_id=primary.model_id,
            )

            if fallback is not None:
                selections.append(fallback)

        return selections

    def _select_chat_models(
        self,
        *,
        settings: Settings,
        model_role: str,
        allow_fallback: bool,
    ) -> list[ModelSelection]:
        primary = select_primary_model(settings=settings, model_role=model_role)

        if primary is None:
            raise LakbayAPIError(
                "A Groq model is not configured for AI chat.",
                code="ai_model_not_configured",
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        selections = [primary]

        if allow_fallback:
            fallback = select_fallback_model(
                settings=settings,
                primary_model_id=primary.model_id,
            )

            if fallback is not None:
                selections.append(fallback)

        return selections

    async def _run_model_generation(
        self,
        *,
        user: User,
        data: AIItineraryGenerateRequest,
        selection: ModelSelection,
        messages: list[dict[str, str]],
        catalog: AIItineraryCatalog,
        option_count: int,
    ) -> AIModelRunResult:
        run = await self.ai.create_generation_run(
            user_id=user.user_id,
            request_purpose=REQUEST_PURPOSE,
            model_role=selection.model_role,
            model_id=selection.model_id,
            prompt_version=PROMPT_VERSION,
            input_summary=_build_input_summary(data),
            fallback_used=selection.fallback_used,
        )
        await self.session.commit()
        await self.session.refresh(run)

        started_at = perf_counter()

        try:
            completion = await self.groq_client.create_chat_completion(
                model=selection.model_id,
                messages=messages,
            )
            response_time_ms = _elapsed_ms(started_at)
            options = parse_and_validate_itinerary_output(
                content=completion.content,
                catalog=catalog,
            )
            updated_run = await self.ai.update_generation_run(
                run,
                status="succeeded",
                validation_status="valid",
                response_time_ms=response_time_ms,
                prompt_tokens=completion.prompt_tokens,
                completion_tokens=completion.completion_tokens,
                total_tokens=completion.total_tokens,
                output_summary={
                    "option_count": len(options),
                    "minimum_option_count": option_count,
                },
            )
            await self.session.commit()
            await self.session.refresh(updated_run)

            return _build_run_result(run=updated_run, options=options)
        except AIOutputValidationError as exc:
            updated_run = await self.ai.update_generation_run(
                run,
                status="failed",
                validation_status="invalid",
                response_time_ms=_elapsed_ms(started_at),
                error_message=exc.message,
                output_summary={"validation_errors": exc.details},
            )
            await self.session.commit()
            await self.session.refresh(updated_run)

            return _build_run_result(run=updated_run, options=[])
        except GroqClientError as exc:
            updated_run = await self.ai.update_generation_run(
                run,
                status="failed",
                validation_status="not_run",
                response_time_ms=_elapsed_ms(started_at),
                error_message=exc.message,
            )
            await self.session.commit()
            await self.session.refresh(updated_run)

            return _build_run_result(run=updated_run, options=[])

    def _require_all_destinations(
        self,
        requested_ids: list[int],
        destinations: list[Destination],
    ) -> None:
        found_ids = {destination.destination_id for destination in destinations}
        missing_ids = _missing_ids(requested_ids, found_ids)

        if missing_ids:
            raise LakbayAPIError(
                "One or more destinations were not found or are inactive.",
                code="destination_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
                details={"destination_ids": missing_ids},
            )

    def _require_all_accommodations(
        self,
        requested_ids: list[int],
        accommodations: list[Accommodation],
    ) -> None:
        found_ids = {
            accommodation.accommodation_id for accommodation in accommodations
        }
        missing_ids = _missing_ids(requested_ids, found_ids)

        if missing_ids:
            raise LakbayAPIError(
                "One or more accommodations were not found or are unavailable.",
                code="accommodation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
                details={"accommodation_ids": missing_ids},
            )

    def _require_all_transportations(
        self,
        requested_ids: list[int],
        transportations: list[Transportation],
    ) -> None:
        found_ids = {
            transportation.transportation_id for transportation in transportations
        }
        missing_ids = _missing_ids(requested_ids, found_ids)

        if missing_ids:
            raise LakbayAPIError(
                "One or more transportation options were not found or are unavailable.",
                code="transportation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
                details={"transportation_ids": missing_ids},
            )

    def _require_rates_belong_to_destinations(
        self,
        *,
        accommodations: list[Accommodation],
        transportations: list[Transportation],
        destination_ids: set[int],
    ) -> None:
        mismatched_accommodation_ids = [
            accommodation.accommodation_id
            for accommodation in accommodations
            if accommodation.destination_id not in destination_ids
        ]

        if mismatched_accommodation_ids:
            raise LakbayAPIError(
                "Accommodation options must belong to the selected destinations.",
                code="accommodation_destination_mismatch",
                details={"accommodation_ids": mismatched_accommodation_ids},
            )

        mismatched_transportation_ids = [
            transportation.transportation_id
            for transportation in transportations
            if transportation.destination_id not in destination_ids
        ]

        if mismatched_transportation_ids:
            raise LakbayAPIError(
                "Transportation options must belong to the selected destinations.",
                code="transportation_destination_mismatch",
                details={"transportation_ids": mismatched_transportation_ids},
            )


def _build_catalog_payload(
    *,
    destinations: list[Destination],
    accommodations: list[Accommodation],
    transportations: list[Transportation],
) -> dict:
    return {
        "destinations": [
            {
                "destination_id": destination.destination_id,
                "name": destination.name,
                "district": destination.district,
                "location": destination.location,
                "category": destination.category,
                "vibes": destination.vibes,
                "activities": destination.activities,
                "estimated_cost": str(destination.estimated_cost),
                "entrance_fee": destination.entrance_fee,
                "overnight_fee": destination.overnight_fee,
                "operating_hours": destination.operating_hours,
                "best_time_to_visit": destination.best_time_to_visit,
                "difficulty_level": destination.difficulty_level,
                "stay_duration_type": destination.stay_duration_type,
            }
            for destination in destinations
        ],
        "accommodations": [
            {
                "accommodation_id": accommodation.accommodation_id,
                "destination_id": accommodation.destination_id,
                "name": accommodation.name,
                "room_type": accommodation.room_type,
                "price": str(accommodation.price),
                "capacity": accommodation.capacity,
                "description": accommodation.description,
            }
            for accommodation in accommodations
        ],
        "transportations": [
            {
                "transportation_id": transportation.transportation_id,
                "destination_id": transportation.destination_id,
                "vehicle_type": transportation.vehicle_type,
                "transport_mode": transportation.transport_mode,
                "route_from": transportation.route_from,
                "route_to": transportation.route_to,
                "price": str(transportation.price),
                "duration_minutes": transportation.duration_minutes,
                "duration_text": transportation.duration_text,
                "notes": transportation.notes,
            }
            for transportation in transportations
        ],
    }


def _build_input_summary(data: AIItineraryGenerateRequest) -> dict:
    return {
        "total_budget": str(data.total_budget),
        "traveler_count": data.traveler_count,
        "day_count": data.day_count,
        "destination_ids": list(data.destination_ids),
        "accommodation_ids": list(data.accommodation_ids),
        "transportation_ids": list(data.transportation_ids),
        "interests": list(data.interests),
        "travel_style": data.travel_style,
        "compare_models": data.compare_models,
    }


def _build_chat_input_summary(data: AIChatRequest) -> dict:
    return {
        "message_preview": data.message[:500],
        "message_length": len(data.message),
        "history_count": len(data.history),
        "context_keys": sorted((data.context or {}).keys()),
        "model_role": data.model_role,
        "use_rag": data.use_rag,
        "rag_limit": data.rag_limit,
    }


def _build_rag_query(data: AIChatRequest) -> str:
    parts = [data.message]
    parts.extend(
        message.content
        for message in data.history[-4:]
        if message.role == "user"
    )
    parts.extend(_flatten_context_values(data.context or {}))

    return " ".join(parts)


def _flatten_context_values(value) -> list[str]:
    if value is None:
        return []

    if isinstance(value, str):
        return [value]

    if isinstance(value, (int, float, bool)):
        return [str(value)]

    if isinstance(value, dict):
        items: list[str] = []
        for child in value.values():
            items.extend(_flatten_context_values(child))
        return items

    if isinstance(value, list):
        items: list[str] = []
        for child in value:
            items.extend(_flatten_context_values(child))
        return items

    return [str(value)]


def _build_run_result(
    *,
    run: AIGenerationRun,
    options: list,
) -> AIModelRunResult:
    return AIModelRunResult(
        ai_generation_run_id=run.ai_generation_run_id,
        model_role=run.model_role,
        model_id=run.model_id,
        status=run.status,
        validation_status=run.validation_status,
        response_time_ms=run.response_time_ms,
        prompt_tokens=run.prompt_tokens,
        completion_tokens=run.completion_tokens,
        total_tokens=run.total_tokens,
        error_message=run.error_message,
        options=options,
    )


def _missing_ids(requested_ids: list[int], found_ids: set[int]) -> list[int]:
    return [
        requested_id
        for requested_id in requested_ids
        if requested_id not in found_ids
    ]


def _elapsed_ms(started_at: float) -> int:
    return int((perf_counter() - started_at) * 1000)
