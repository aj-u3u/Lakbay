from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.dependencies import get_current_user
from app.db.session import get_db_session
from app.features.notifications.schemas import (
    NotificationEventType,
    NotificationReadAllResponse,
    NotificationResponse,
    NotificationUnreadCountResponse,
)
from app.features.notifications.service import NotificationService
from app.features.users.models import User


router = APIRouter(prefix="/notifications", tags=["notifications"])


@router.get(
    "",
    response_model=list[NotificationResponse],
    summary="List notifications",
    description=(
        "Protected endpoint that lists the current user's active notifications. "
        "Use unread_only, event_type, trip_id, limit, and offset for Flutter views."
    ),
)
async def list_notifications(
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
    unread_only: bool = False,
    event_type: NotificationEventType | None = None,
    trip_id: int | None = Query(default=None, ge=1),
    limit: int = Query(default=20, ge=1, le=100),
    offset: int = Query(default=0, ge=0),
) -> list[NotificationResponse]:
    return await NotificationService(session).list_notifications(
        user=current_user,
        unread_only=unread_only,
        event_type=event_type,
        trip_id=trip_id,
        limit=limit,
        offset=offset,
    )


@router.get(
    "/unread-count",
    response_model=NotificationUnreadCountResponse,
    summary="Get unread notification count",
    description="Protected endpoint that returns the current user's unread count.",
)
async def get_unread_count(
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> NotificationUnreadCountResponse:
    return await NotificationService(session).unread_count(user=current_user)


@router.patch(
    "/{notification_id}/read",
    response_model=NotificationResponse,
    summary="Mark notification as read",
    description=(
        "Protected endpoint that marks one active notification as read. "
        "Only the notification recipient can do this."
    ),
)
async def mark_notification_read(
    notification_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> NotificationResponse:
    return await NotificationService(session).mark_read(
        user=current_user,
        notification_id=notification_id,
    )


@router.patch(
    "/read-all",
    response_model=NotificationReadAllResponse,
    summary="Mark all notifications as read",
    description="Protected endpoint that marks all active unread notifications as read.",
)
async def mark_all_notifications_read(
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> NotificationReadAllResponse:
    return await NotificationService(session).mark_all_read(user=current_user)


@router.delete(
    "/{notification_id}",
    response_model=NotificationResponse,
    summary="Delete notification",
    description=(
        "Protected endpoint that soft-deletes one notification. "
        "Deleted notifications are hidden from normal lists."
    ),
)
async def delete_notification(
    notification_id: int,
    current_user: Annotated[User, Depends(get_current_user)],
    session: Annotated[AsyncSession, Depends(get_db_session)],
) -> NotificationResponse:
    return await NotificationService(session).delete_notification(
        user=current_user,
        notification_id=notification_id,
    )
