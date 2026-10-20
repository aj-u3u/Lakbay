from typing import Annotated

from fastapi import APIRouter, Depends, Query, Response, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.trips.schemas import (
    TripCreate,
    TripFromAIOptionCreate,
    TripListItemResponse,
    TripMemberCreate,
    TripMemberResponse,
    TripMemberUpdate,
    TripResponse,
    TripRouteCreate,
    TripRouteResponse,
    TripTaskCreate,
    TripTaskResponse,
    TripTaskStatus,
    TripTaskUpdate,
    TripUpdate,
)
from app.features.trips.service import TripService
from app.features.users.models import User

router = APIRouter(prefix="/trips", tags=["trips"])


@router.post(
    "",
    response_model=TripResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create trip",
    description=(
        "Protected endpoint that saves a user's selected destinations and "
        "optional itinerary days as a real trip. The creator is added as the "
        "owner member for Phase 8 collaboration."
    ),
)
async def create_trip(
    data: TripCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripResponse:
    return await TripService(session).create_trip(user=current_user, data=data)


@router.post(
    "/from-ai-option",
    response_model=TripResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Save a selected planning itinerary",
    description="Save one validated option from the current user's planning generation run, with its cost and route snapshot.",
)
async def create_trip_from_ai_option(
    data: TripFromAIOptionCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripResponse:
    return await TripService(session).create_from_ai_option(user=current_user, data=data)


@router.get(
    "",
    response_model=list[TripListItemResponse],
    summary="List my trips",
    description=(
        "Protected endpoint that lists trips owned by the current user. "
        "Archived trips are hidden by default."
    ),
)
async def list_trips(
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    include_archived: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[TripListItemResponse]:
    return await TripService(session).list_trips(
        user=current_user,
        include_archived=include_archived,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/{trip_id}",
    response_model=TripResponse,
    summary="Get my trip",
    description=(
        "Protected endpoint that returns one trip with destinations, itinerary "
        "days, activities, and an optional saved route summary."
    ),
)
async def get_trip(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripResponse:
    return await TripService(session).get_trip(user=current_user, trip_id=trip_id)


@router.patch(
    "/{trip_id}",
    response_model=TripResponse,
    summary="Update my trip",
    description=(
        "Protected endpoint for editing trip metadata such as title, dates, "
        "budget, notes, traveler count, or status."
    ),
)
async def update_trip(
    trip_id: int,
    data: TripUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripResponse:
    return await TripService(session).update_trip(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.delete(
    "/{trip_id}",
    response_model=TripResponse,
    summary="Archive my trip",
    description=(
        "Protected soft delete. The trip remains in the database and is marked "
        "as archived instead of being permanently removed."
    ),
)
async def delete_trip(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripResponse:
    return await TripService(session).archive_trip(user=current_user, trip_id=trip_id)


@router.post(
    "/{trip_id}/archive",
    response_model=TripResponse,
    summary="Archive my trip",
    description="Protected endpoint that marks a trip as archived.",
)
async def archive_trip(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripResponse:
    return await TripService(session).archive_trip(user=current_user, trip_id=trip_id)


@router.post(
    "/{trip_id}/route",
    response_model=TripRouteResponse,
    summary="Save trip route summary",
    description=(
        "Protected endpoint that saves or replaces the route summary for a trip. "
        "Use the response from Phase 6 route preview or optimization as the body."
    ),
)
async def save_trip_route(
    trip_id: int,
    data: TripRouteCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripRouteResponse:
    return await TripService(session).save_route(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.get(
    "/{trip_id}/route",
    response_model=TripRouteResponse,
    summary="Get saved trip route",
    description="Protected endpoint that returns the saved route summary for a trip.",
)
async def get_trip_route(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripRouteResponse:
    return await TripService(session).get_route(user=current_user, trip_id=trip_id)


@router.get(
    "/{trip_id}/members",
    response_model=list[TripMemberResponse],
    summary="List trip members",
    description="Protected endpoint that lists active members for a shared trip.",
)
async def list_trip_members(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> list[TripMemberResponse]:
    return await TripService(session).list_members(user=current_user, trip_id=trip_id)


@router.post(
    "/{trip_id}/members",
    response_model=TripMemberResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Add trip member",
    description=(
        "Protected endpoint that adds an existing user to a trip by email. "
        "The trip owner or an organizer can add members."
    ),
)
async def add_trip_member(
    trip_id: int,
    data: TripMemberCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemberResponse:
    return await TripService(session).add_member(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.patch(
    "/{trip_id}/members/{member_id}",
    response_model=TripMemberResponse,
    summary="Update trip member",
    description="Protected endpoint that changes a trip member role.",
)
async def update_trip_member(
    trip_id: int,
    member_id: int,
    data: TripMemberUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemberResponse:
    return await TripService(session).update_member(
        user=current_user,
        trip_id=trip_id,
        member_id=member_id,
        data=data,
    )


@router.delete(
    "/{trip_id}/members/{member_id}",
    response_model=TripMemberResponse,
    summary="Remove trip member",
    description="Protected endpoint that removes a member from shared trip access.",
)
async def remove_trip_member(
    trip_id: int,
    member_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripMemberResponse:
    return await TripService(session).remove_member(
        user=current_user,
        trip_id=trip_id,
        member_id=member_id,
    )


@router.get(
    "/{trip_id}/tasks",
    response_model=list[TripTaskResponse],
    summary="List trip tasks",
    description=(
        "Protected endpoint that lists collaboration tasks for a shared trip. "
        "Use status and assigned_to_me filters for simple Flutter task views."
    ),
)
async def list_trip_tasks(
    trip_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
    task_status: TripTaskStatus | None = Query(default=None, alias="status"),
    assigned_to_me: bool = False,
    limit: int = Query(default=50, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[TripTaskResponse]:
    return await TripService(session).list_tasks(
        user=current_user,
        trip_id=trip_id,
        task_status=task_status,
        assigned_to_me=assigned_to_me,
        limit=limit,
        offset=offset,
    )


@router.post(
    "/{trip_id}/tasks",
    response_model=TripTaskResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create trip task",
    description="Protected endpoint that creates a task for a shared trip.",
)
async def create_trip_task(
    trip_id: int,
    data: TripTaskCreate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripTaskResponse:
    return await TripService(session).create_task(
        user=current_user,
        trip_id=trip_id,
        data=data,
    )


@router.get(
    "/{trip_id}/tasks/{task_id}",
    response_model=TripTaskResponse,
    summary="Get trip task",
    description="Protected endpoint that returns one task from a shared trip.",
)
async def get_trip_task(
    trip_id: int,
    task_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripTaskResponse:
    return await TripService(session).get_task(
        user=current_user,
        trip_id=trip_id,
        task_id=task_id,
    )


@router.patch(
    "/{trip_id}/tasks/{task_id}",
    response_model=TripTaskResponse,
    summary="Update trip task",
    description="Protected endpoint that updates task fields or marks a task complete.",
)
async def update_trip_task(
    trip_id: int,
    task_id: int,
    data: TripTaskUpdate,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> TripTaskResponse:
    return await TripService(session).update_task(
        user=current_user,
        trip_id=trip_id,
        task_id=task_id,
        data=data,
    )


@router.delete(
    "/{trip_id}/tasks/{task_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    summary="Delete trip task",
    description="Protected endpoint that deletes a task from a shared trip.",
)
async def delete_trip_task(
    trip_id: int,
    task_id: int,
    session: Annotated[AsyncSession, Depends(get_db_session)],
    current_user: Annotated[User, Depends(get_current_user)],
) -> Response:
    await TripService(session).delete_task(
        user=current_user,
        trip_id=trip_id,
        task_id=task_id,
    )

    return Response(status_code=status.HTTP_204_NO_CONTENT)
