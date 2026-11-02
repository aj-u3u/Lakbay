from typing import Annotated

from fastapi import APIRouter, Depends, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.ai.schemas import (
    AIChatRequest,
    AIChatResponse,
    AIItineraryGenerateRequest,
    AIItineraryGenerateResponse,
)
from app.features.ai.service import AIItineraryService
from app.features.planning.dependencies import get_planning_route_limiter
from app.features.routes.service import RouteService
from app.features.users.models import User
from app.integrations.groq.client import GroqClient, get_groq_client
from app.integrations.osrm.client import get_osrm_client

router = APIRouter(prefix="/ai", tags=["ai"])


def get_ai_chat_route_service(
    data: AIChatRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RouteService | None:
    state = data.planning_state
    if state is None:
        return None
    needs_candidate_routes = bool(
        state.origin is not None
        and state.origin.lat is not None
        and state.origin.lng is not None
        and state.selected_transport_option_ids in (
            ["mode:personal_vehicle"], ["mode:walking"],
        )
    )
    if state.route_preferences is None and not needs_candidate_routes:
        return None
    get_planning_route_limiter().check(current_user.user_id)
    return RouteService(session, get_osrm_client())


def get_ai_itinerary_route_service(
    data: AIItineraryGenerateRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> RouteService | None:
    state = data.planning_state
    if state is None or state.route_preferences is None:
        return None
    get_planning_route_limiter().check(current_user.user_id)
    return RouteService(session, get_osrm_client())


@router.post(
    "/itineraries/generate",
    response_model=AIItineraryGenerateResponse,
    status_code=status.HTTP_200_OK,
    summary="Generate AI itinerary drafts",
    description=(
        "Protected endpoint that uses selected catalog destinations and optional "
        "rate rows to ask a configured Groq model for structured itinerary draft "
        "options. The response is validated before it is returned and no permanent "
        "trip is created in this phase."
    ),
)
async def generate_itinerary(
    data: AIItineraryGenerateRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    groq_client: Annotated[GroqClient, Depends(get_groq_client)],
    route_service: Annotated[RouteService | None, Depends(get_ai_itinerary_route_service)],
) -> AIItineraryGenerateResponse:
    return await AIItineraryService(session, groq_client, route_service).generate_itinerary(
        user=current_user,
        data=data,
    )


@router.post(
    "/chat",
    response_model=AIChatResponse,
    status_code=status.HTTP_200_OK,
    summary="Chat with Lakbay AI",
    description=(
        "Protected free-text assistant endpoint. It sends the user's message, "
        "optional conversation history, and optional context to the configured "
        "Groq model and returns a natural-language assistant response. When "
        "planning_state is supplied, it also returns validated state updates and "
        "a recalculated stateless planning preview."
    ),
)
async def chat(
    data: AIChatRequest,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    groq_client: Annotated[GroqClient, Depends(get_groq_client)],
    route_service: Annotated[RouteService | None, Depends(get_ai_chat_route_service)],
) -> AIChatResponse:
    return await AIItineraryService(session, groq_client, route_service).chat(
        user=current_user,
        data=data,
    )
