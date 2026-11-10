import json
import re
from decimal import Decimal
from time import perf_counter

from fastapi import status
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.core.exceptions import LakbayAPIError
from app.core.provider_usage import ProviderLimiter
from app.features.accommodations.models import Accommodation
from app.features.ai.models import AIGenerationRun
from app.features.ai.geo_context import selected_geo_inputs
from app.features.ai.repository import AIItineraryRepository
from app.features.ai.rag import VectorRAGRetriever
from app.features.ai.schemas import (
    AIChatRequest,
    AIChatResponse,
    AIPlanningChatOutput,
    AIPlanningChatResult,
    AIPlanningStateUpdates,
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
from app.features.planning.schemas import PlanningOrigin, PlanningPreviewRequest, PlanningPreviewResponse, PlanningState
from app.features.planning.service import PlanningService
from app.features.recommendations.schemas import TopPlacesRequest
from app.features.recommendations.service import (
    RecommendationService,
    planning_recommendation_from_top_place,
)
from app.features.routes.schemas import RouteCoordinate
from app.features.routes.service import RouteService
from app.features.transportations.models import Transportation
from app.features.users.models import User
from app.integrations.groq.client import GroqClient
from app.integrations.groq.errors import GroqClientError, GroqRateLimitError
from app.integrations.groq.itinerary_schema import ITINERARY_RESPONSE_FORMAT
from app.integrations.groq.model_selector import (
    ModelSelection,
    select_comparison_models,
    select_fallback_model,
    select_primary_model,
)
from app.integrations.groq.prompts import (
    CHAT_PROMPT_VERSION,
    PLANNING_PROMPT_VERSION,
    PROMPT_VERSION,
    build_chat_messages,
    build_geo_analytics_context,
    build_itinerary_messages,
)

REQUEST_PURPOSE = "itinerary_generation"
CHAT_REQUEST_PURPOSE = "travel_chat"
_ai_user_limiter = ProviderLimiter()


def _reserve_user_ai_call(user_id: int, settings: Settings) -> None:
    _ai_user_limiter.reserve(
        f"groq:user:{user_id}",
        limit=settings.groq_user_requests_per_minute,
        code="ai_user_rate_limit_exceeded",
        message="Too many AI requests. Please try again shortly.",
    )


def _groq_rate_limit_response(exc: GroqRateLimitError) -> LakbayAPIError:
    return LakbayAPIError(
        exc.message,
        code="groq_rate_limit_exceeded",
        status_code=429,
        details={"retry_after_seconds": exc.retry_after_seconds},
        headers={"Retry-After": str(exc.retry_after_seconds)},
    )


class AIItineraryService:
    def __init__(
        self,
        session: AsyncSession,
        groq_client: GroqClient,
        route_service: RouteService | None = None,
    ) -> None:
        self.session = session
        self.ai = AIItineraryRepository(session)
        self.groq_client = groq_client
        self.route_service = route_service

    async def generate_itinerary(
        self,
        *,
        user: User,
        data: AIItineraryGenerateRequest,
    ) -> AIItineraryGenerateResponse:
        settings = get_settings()
        planning_preview: PlanningPreviewResponse | None = None
        if data.planning_state is not None:
            planning_preview = await PlanningService(self.session, self.route_service).preview(
                PlanningPreviewRequest(input_revision=data.input_revision, state=data.planning_state)
            )
            _validate_generation_planning_state(data, planning_preview)
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

        geo_analytics_context = None
        route_destination_order = None
        if planning_preview is not None:
            route = planning_preview.route
            if route.status == "calculated" and route.summary is not None:
                route_destination_order = tuple(
                    stop.destination_id
                    for stop in route.summary.stops
                    if not stop.is_origin and stop.destination_id is not None
                )
            recommendations, scored_groups = await selected_geo_inputs(
                session=self.session,
                user=user,
                preview=planning_preview,
                destinations=destinations,
                routes=self.route_service,
                interests=data.interests,
            )
            geo_analytics_context = build_geo_analytics_context(
                planning_preview,
                recommendations=recommendations,
                scored_groups=scored_groups,
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
            required_destination_ids=set(data.destination_ids),
            route_destination_order=route_destination_order,
            required_accommodation_ids=set(data.accommodation_ids) if planning_preview else None,
            required_transportation_ids=set(data.transportation_ids) if planning_preview else None,
            accommodation_destination_ids={
                item.accommodation_id: item.destination_id for item in accommodations
            } if planning_preview else None,
            transportation_destination_ids={
                item.transportation_id: item.destination_id for item in transportations
            } if planning_preview else None,
        )
        messages = build_itinerary_messages(
            request=data,
            catalog=catalog_payload,
            option_count=settings.ai_itinerary_option_count,
            planning_preview=planning_preview,
            geo_analytics_context=geo_analytics_context,
            route_destination_order=route_destination_order,
        )
        quality_warnings = _itinerary_quality_warnings(
            destinations=destinations,
            transportations=transportations,
            traveler_count=data.traveler_count,
            planning_preview=planning_preview,
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
                planning_preview=planning_preview,
                geo_analytics_context=geo_analytics_context,
                quality_warnings=quality_warnings,
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
            selected_generation_run_id=next(
                run.ai_generation_run_id for run in model_runs if run.status == "succeeded"
            ) if planning_preview else None,
            planning_preview=planning_preview,
            geo_analytics_context=geo_analytics_context,
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
        retrieval_coverage = {"status": "disabled", "destinations": [], "truncated": False}
        if data.use_rag and data.rag_limit > 0:
            retriever = VectorRAGRetriever(self.session)
            rag_matches = await retriever.retrieve(
                data.message,
                limit=data.rag_limit,
                history=[item.content for item in data.history if item.role == "user"],
                context=data.context,
            )
            retrieval_coverage = retriever.coverage

        retrieved_context = [match.to_prompt_dict() for match in rag_matches]
        messages = build_chat_messages(
            request=data,
            retrieved_context=retrieved_context,
            retrieval_coverage=retrieval_coverage,
        )
        failed_runs: list[dict] = []

        for selection in selections:
            _reserve_user_ai_call(user.user_id, settings)
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
                planning_result = None
                validation_status = "not_run"
                if data.planning_state is None:
                    chat_response = completion.content.strip() or (
                        "I could not generate a helpful answer just now. "
                        "Please try asking in another way."
                    )
                else:
                    (
                        chat_response,
                        planning_result,
                        validation_status,
                    ) = await _build_planning_chat_result(
                        content=completion.content,
                        data=data,
                        session=self.session,
                        route_service=self.route_service,
                        retrieved_destination_ids={
                            match.source_id
                            for match in rag_matches
                            if match.source == "destination"
                        },
                    )
                updated_run = await self.ai.update_generation_run(
                    run,
                    status="succeeded",
                    validation_status=validation_status,
                    response_time_ms=response_time_ms,
                    prompt_tokens=completion.prompt_tokens,
                    completion_tokens=completion.completion_tokens,
                    total_tokens=completion.total_tokens,
                    output_summary={
                        "response_length": len(chat_response),
                        "retrieved_context_count": len(retrieved_context),
                        "planning_update_status": (
                            planning_result.update_status if planning_result else None
                        ),
                        "planning_input_revision": (
                            planning_result.input_revision if planning_result else None
                        ),
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
                    planning=planning_result,
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
                if isinstance(exc, GroqRateLimitError):
                    raise _groq_rate_limit_response(exc) from exc
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
        planning_preview: PlanningPreviewResponse | None = None,
        geo_analytics_context: dict | None = None,
        quality_warnings: list[str] | None = None,
    ) -> AIModelRunResult:
        _reserve_user_ai_call(user.user_id, get_settings())
        run = await self.ai.create_generation_run(
            user_id=user.user_id,
            request_purpose=REQUEST_PURPOSE,
            model_role=selection.model_role,
            model_id=selection.model_id,
            prompt_version=(
                PLANNING_PROMPT_VERSION if planning_preview is not None else PROMPT_VERSION
            ),
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
                response_format=ITINERARY_RESPONSE_FORMAT,
            )
            response_time_ms = _elapsed_ms(started_at)
            options = parse_and_validate_itinerary_output(
                content=completion.content,
                catalog=catalog,
            )
            options = [
                option.model_copy(update={"quality_warnings": list(quality_warnings or [])})
                for option in options
            ]
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
                    **({
                        "options": [option.model_dump(mode="json") for option in options],
                        "planning_preview": planning_preview.model_dump(mode="json"),
                        "geo_analytics_context": geo_analytics_context,
                    } if planning_preview is not None else {}),
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

            if isinstance(exc, GroqRateLimitError):
                raise _groq_rate_limit_response(exc) from exc

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


def _itinerary_quality_warnings(
    *,
    destinations: list[Destination],
    transportations: list[Transportation],
    traveler_count: int,
    planning_preview: PlanningPreviewResponse | None,
) -> list[str]:
    warnings: list[str] = []
    for destination in destinations:
        warnings.append(
            f"Current opening hours for {destination.name} are not verified by Lakbay; "
            "confirm before traveling."
        )
        access_text = " ".join(
            part for part in (destination.description, destination.how_to_get_there) if part
        )
        if re.search(r"\b(ferry|boat)\b", access_text, flags=re.IGNORECASE):
            has_priced_ferry = any(
                transportation.destination_id == destination.destination_id
                and transportation.charging_unit is not None
                and re.search(
                    r"\b(ferry|boat)\b",
                    " ".join((transportation.vehicle_type, transportation.transport_mode)),
                    flags=re.IGNORECASE,
                )
                for transportation in transportations
            )
            if not has_priced_ferry:
                warnings.append(
                    f"The ferry or boat fare for {destination.name} has no selected "
                    "catalog rate with a known charging unit; confirm and add this cost."
                )

    if traveler_count > 1:
        warnings.append(
            f"AI costs are draft estimates; confirm the full cost for {traveler_count} travelers."
        )
    if planning_preview is None:
        warnings.append(
            "Travel times and visitor arrival access have not been checked against a route."
        )
    return warnings


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
                "description": destination.description,
                "district": destination.district,
                "location": destination.location,
                "category": destination.category,
                "vibes": destination.vibes,
                "activities": destination.activities,
                "lat": destination.lat,
                "lng": destination.lng,
                "arrival_lat": destination.arrival_lat,
                "arrival_lng": destination.arrival_lng,
                "route_ready": destination.route_ready,
                "estimated_cost": (
                    str(destination.estimated_cost)
                    if destination.estimated_cost is not None else None
                ),
                "entrance_fee": destination.entrance_fee,
                "overnight_fee": destination.overnight_fee,
                "operating_hours": destination.operating_hours,
                "best_time_to_visit": destination.best_time_to_visit,
                "how_to_get_there": destination.how_to_get_there,
                "estimated_travel_time": destination.estimated_travel_time,
                "travel_notes": destination.travel_notes,
                "what_to_bring": destination.what_to_bring,
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
                "currency": accommodation.currency,
                "charging_unit": accommodation.charging_unit,
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
                "currency": transportation.currency,
                "charging_unit": transportation.charging_unit,
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
        "planning_enabled": data.planning_state is not None,
        "input_revision": data.input_revision if data.planning_state is not None else None,
    }


def _validate_generation_planning_state(
    data: AIItineraryGenerateRequest,
    preview: PlanningPreviewResponse,
) -> None:
    state = preview.state
    selected_transport_ids = {
        option.transportation_id for option in preview.transport_options
        if option.selected and option.transportation_id is not None
    }
    if preview.selection_problems:
        raise LakbayAPIError(
            "Review planning selections before generating an itinerary.",
            code="planning_selection_invalid",
            status_code=status.HTTP_400_BAD_REQUEST,
            details={"selection_problems": [item.model_dump() for item in preview.selection_problems]},
        )
    if preview.budget.minimum_over_budget_amount > 0:
        raise LakbayAPIError(
            "The selected plan already exceeds the budget estimate.",
            code="planning_over_budget",
            status_code=status.HTTP_409_CONFLICT,
        )
    if (
        data.destination_ids != state.destination_ids
        or set(data.accommodation_ids) != set(state.selected_accommodation_ids)
        or set(data.transportation_ids) != selected_transport_ids
        or data.traveler_count != state.traveler_count
        or data.day_count != state.day_count
        or data.total_budget != preview.whole_trip_budget
    ):
        raise LakbayAPIError(
            "AI generation inputs must match the selected planning preview.",
            code="planning_input_mismatch",
            status_code=status.HTTP_400_BAD_REQUEST,
        )


def _build_chat_input_summary(data: AIChatRequest) -> dict:
    return {
        "message_preview": data.message[:500],
        "message_length": len(data.message),
        "history_count": len(data.history),
        "context_keys": sorted((data.context or {}).keys()),
        "model_role": data.model_role,
        "use_rag": data.use_rag,
        "rag_limit": data.rag_limit,
        "planning_enabled": data.planning_state is not None,
        "input_revision": data.input_revision if data.planning_state is not None else None,
    }


async def _build_planning_chat_result(
    *,
    content: str,
    data: AIChatRequest,
    session: AsyncSession,
    route_service: RouteService | None,
    retrieved_destination_ids: set[int],
) -> tuple[str, AIPlanningChatResult, str]:
    assert data.planning_state is not None
    current_state = data.planning_state
    fallback_response = (
        "I couldn't safely update your plan from that response. Your current "
        "preview is shown below; try restating the change or use the preview controls."
    )
    output, rejected_fields = _parse_planning_chat_output(content)
    if output is not None:
        output, unconfirmed_fields = _reject_unconfirmed_trip_details(output, data)
        rejected_fields.extend(unconfirmed_fields)

    update_status = "invalid_output"
    validation_status = "invalid"
    chat_response = fallback_response
    changes_json: dict = {}
    next_state = current_state
    if output is not None:
        # The recovered output is validated before use; the run table's
        # validation-status constraint does not define a separate partial value.
        validation_status = "valid"
        chat_response = (
            _partial_planning_reply(rejected_fields)
            if rejected_fields else output.chat_response.strip()
        )
        changes = output.state_updates.model_dump(exclude_unset=True, mode="python")
        changes_json = output.state_updates.model_dump(exclude_unset=True, mode="json")
        update_status = "no_changes"

        proposed_origin = changes.get("origin")
        if isinstance(proposed_origin, dict):
            label = proposed_origin["label"]
            current_origin = current_state.origin
            if (
                current_origin is not None
                and current_origin.label is not None
                and current_origin.label.casefold() == label.casefold()
            ):
                changes.pop("origin")
                changes_json.pop("origin", None)
            else:
                # An AI-proposed label cannot supply coordinates. Clear stale
                # coordinates when the traveler changes their origin label.
                changes["origin"] = PlanningOrigin(label=label)

        requested_destinations = changes.get("destination_ids")
        if requested_destinations is not None:
            allowed_destinations = retrieved_destination_ids | set(current_state.destination_ids)
            if not set(requested_destinations).issubset(allowed_destinations):
                changes.pop("destination_ids")
                changes_json.pop("destination_ids", None)
                update_status = "needs_clarification"
                chat_response = (
                    f"{chat_response}\n\nI couldn't match that destination to an active "
                    "Lakbay catalog entry, so I kept your current destination selection. "
                    "Choose a destination from the preview or clarify the place."
                )

        current_values = current_state.model_dump(mode="json")
        for field_name, value in list(changes_json.items()):
            if field_name in changes and current_values.get(field_name) == value:
                changes.pop(field_name)
                changes_json.pop(field_name)

        try:
            if changes:
                state_values = current_state.model_dump()
                if (
                    current_state.route_preferences is not None
                    and current_state.route_preferences.road_access_confirmed
                    and changes.keys() & {"origin", "destination_ids", "return_to_origin"}
                ):
                    state_values["route_preferences"] = None
                    changes_json["route_preferences"] = None
                if (
                    "destination_ids" in changes
                    and changes["destination_ids"] != current_state.destination_ids
                ):
                    # Choices and allowances belong to the old destinations.
                    state_values.update(
                        selected_transport_option_ids=[],
                        selected_activity_option_ids=[],
                        selected_accommodation_ids=[],
                        cost_allowances=[],
                        transport_pricing=[],
                        accommodation_pricing=[],
                        age_pricing_rules=[],
                    )
                next_state = PlanningState.model_validate(
                    {**state_values, **changes},
                )
                if update_status != "needs_clarification":
                    update_status = "applied"
            elif update_status != "needs_clarification":
                update_status = "no_changes"
        except ValidationError:
            next_state = current_state
            changes_json = {}
            update_status = "invalid_output"
            validation_status = "invalid"
            chat_response = fallback_response

    preview = await PlanningService(session, route_service).preview(
        PlanningPreviewRequest(
            input_revision=data.input_revision,
            state=next_state,
        ),
    )
    recommendations = []
    recommendation_total_candidates = 0
    recommendation_shortfall_reason = None
    if not next_state.destination_ids and not next_state.interests:
        recommendation_shortfall_reason = (
            "No travel interests were supplied, so there is no preference match to rank."
        )
    elif not next_state.destination_ids:
        selected_modes = tuple(next_state.selected_transport_option_ids)
        top_places = await RecommendationService(session).rank_top_places(
            data=TopPlacesRequest(
                interests=next_state.interests,
                origin=(
                    RouteCoordinate(
                        label=next_state.origin.label,
                        lat=next_state.origin.lat,
                        lng=next_state.origin.lng,
                    )
                    if next_state.origin is not None
                    and next_state.origin.lat is not None
                    and next_state.origin.lng is not None
                    else None
                ),
                # Catalog fare choices mean the traveler is commuting; no choice
                # yet is ranked by car.
                travel_mode={
                    ("mode:personal_vehicle",): "driving",
                    ("mode:walking",): "walking",
                }.get(selected_modes, "public_transport" if selected_modes else "driving"),
                total_budget=next_state.total_budget,
                budget_scope=next_state.budget_scope,
                traveler_count=next_state.traveler_count,
                adult_count=next_state.adult_count,
                child_ages=next_state.child_ages,
                day_count=next_state.day_count,
            ),
            osrm_client=route_service.osrm_client if route_service is not None else None,
        )
        recommendations = [
            planning_recommendation_from_top_place(item) for item in top_places.items
        ]
        recommendation_total_candidates = top_places.total_candidates
        recommendation_shortfall_reason = top_places.shortfall_reason
        if recommendation_shortfall_reason is not None:
            # Catalog and route checks are authoritative over model prose.
            chat_response = recommendation_shortfall_reason
    return (
        chat_response,
        AIPlanningChatResult(
            input_revision=data.input_revision,
            state_updates=changes_json,
            update_status=update_status,
            preview=preview,
            recommendations=recommendations,
            recommendation_total_candidates=recommendation_total_candidates,
            recommendation_shortfall_reason=recommendation_shortfall_reason,
        ),
        validation_status,
    )


def _strip_json_fence(content: str) -> str:
    value = content.strip()
    if value.startswith("```") and value.endswith("```"):
        value = value.split("\n", 1)[-1].rsplit("```", 1)[0].strip()
    return value


def _parse_planning_chat_output(
    content: str,
) -> tuple[AIPlanningChatOutput | None, list[str]]:
    """Retain valid allowlisted fields when a sibling field has bad shape."""
    cleaned = _strip_json_fence(content)
    try:
        return AIPlanningChatOutput.model_validate_json(cleaned), []
    except ValidationError:
        pass

    try:
        raw = json.loads(cleaned)
    except (TypeError, ValueError):
        return None, []
    if not isinstance(raw, dict) or set(raw) != {"chat_response", "state_updates"}:
        return None, []
    updates = raw["state_updates"]
    if not isinstance(updates, dict):
        return None, []
    allowed_fields = set(AIPlanningStateUpdates.model_fields)
    if set(updates) - allowed_fields:
        # Unsupported selections are never silently accepted or ignored.
        return None, []

    valid_updates: dict = {}
    rejected_fields: list[str] = []
    for field_name, value in updates.items():
        try:
            validated = AIPlanningStateUpdates.model_validate({field_name: value})
        except ValidationError:
            rejected_fields.append(field_name)
            continue
        valid_updates[field_name] = validated.model_dump(
            exclude_unset=True, mode="python",
        )[field_name]
    if not rejected_fields:
        return None, []
    try:
        output = AIPlanningChatOutput.model_validate({
            "chat_response": raw["chat_response"],
            "state_updates": valid_updates,
        })
    except ValidationError:
        return None, []
    return output, rejected_fields


_NIGHT_WORDS = {
    "zero": 0,
    "one": 1,
    "two": 2,
    "three": 3,
    "four": 4,
    "five": 5,
    "six": 6,
    "seven": 7,
    "eight": 8,
    "nine": 9,
    "ten": 10,
}
_NIGHT_NUMBER = r"\d+|zero|one|two|three|four|five|six|seven|eight|nine|ten"


def _number_from_text(value: str) -> int:
    return _NIGHT_WORDS.get(value.casefold(), int(value) if value.isdigit() else -1)


def _confirmed_night_count(data: AIChatRequest) -> int | None:
    message = data.message.casefold().strip()
    if re.search(
        r"\b(?:same[ -]?day|no overnight|without overnight|no nights?|"
        r"not staying overnight|won't stay overnight|will not stay overnight)\b",
        message,
    ):
        return 0
    if re.search(r"\bday[ -]?trip\b", message) and not re.search(
        r"\b(?:[2-9]|[1-9]\d+|two|three|four|five|six|seven|eight|nine|ten)[ -]?day[ -]?trip\b",
        message,
    ):
        return 0
    matches = re.findall(
        rf"\b({_NIGHT_NUMBER})\s*(?:nights?|overnights?(?:\s+stays?)?)\b",
        message,
    )
    if matches:
        counts = {_number_from_text(value) for value in matches}
        return counts.pop() if len(counts) == 1 else None
    if data.history and data.history[-1].role == "assistant":
        question = data.history[-1].content.casefold()
        if re.search(r"\b(?:nights?|overnights?)\b", question):
            bare_number = re.fullmatch(rf"\s*({_NIGHT_NUMBER})\s*", message)
            if bare_number:
                return _number_from_text(bare_number.group(1))
    return None


def _confirmed_return_to_origin(data: AIChatRequest) -> bool | None:
    message = data.message.casefold().strip()
    no_return_pattern = (
        r"\b(?:one[ -]?way|no return|no round[ -]?trip|not return(?:ing)?|"
        r"don't return|won't return|will not return|not going back|"
        r"don't go back|without (?:a )?return)\b"
    )
    says_no_return = re.search(no_return_pattern, message)
    says_return = re.search(
        r"\b(?:round[ -]?trip|return(?:ing)? (?:to|back|fare|bus|trip)|"
        r"go(?:ing)? back|back to|will return|include (?:the )?return fare)\b",
        re.sub(no_return_pattern, "", message),
    )
    if says_no_return and says_return:
        return None
    if says_no_return:
        return False
    if says_return:
        return True
    if data.history and data.history[-1].role == "assistant":
        question = data.history[-1].content.casefold()
        if re.search(r"\b(?:return|round[ -]?trip|back to)\b", question):
            if re.fullmatch(r"(?:yes|yes please|yep|sure)", message):
                return True
            if re.fullmatch(r"(?:no|no thanks|no thank you|nope)", message):
                return False
    return None


def _reject_unconfirmed_trip_details(
    output: AIPlanningChatOutput,
    data: AIChatRequest,
) -> tuple[AIPlanningChatOutput, list[str]]:
    updates = output.state_updates.model_dump(exclude_unset=True, mode="python")
    rejected: list[str] = []
    confirmed_values = {
        "night_count": _confirmed_night_count(data),
        "return_to_origin": _confirmed_return_to_origin(data),
    }
    for field_name, confirmed_value in confirmed_values.items():
        if field_name not in updates:
            continue
        if confirmed_value is not None and updates[field_name] == confirmed_value:
            continue
        if confirmed_value is None and data.planning_state is not None and updates[field_name] == getattr(
            data.planning_state, field_name,
        ):
            continue
        updates.pop(field_name)
        rejected.append(field_name)
    if not rejected:
        return output, []
    return AIPlanningChatOutput(
        chat_response=output.chat_response,
        state_updates=AIPlanningStateUpdates.model_validate(updates),
    ), rejected


def _partial_planning_reply(rejected_fields: list[str]) -> str:
    labels = {
        "origin": "starting place",
        "destination_ids": "destination",
        "total_budget": "budget",
        "budget_scope": "budget scope",
        "traveler_count": "traveler count",
        "day_count": "day count",
        "night_count": "overnight stay",
        "return_to_origin": "return trip",
        "interests": "travel interests",
    }
    names = ", ".join(labels[field] for field in rejected_fields)
    return (
        f"I could not use the {names}; please confirm that detail in the plan review. "
        "Any other valid changes are shown in your plan below."
    )


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
