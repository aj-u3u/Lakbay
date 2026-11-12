from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field


NotificationEventType = Literal[
    "trip_member_added",
    "task_assigned",
    "task_updated",
    "expense_created",
    "expense_updated",
    "expense_voided",
    "trip_updated",
    "trip_route_updated",
]
NotificationEntityType = Literal[
    "trip",
    "trip_member",
    "trip_task",
    "trip_expense",
    "trip_route",
]
NotificationStatus = Literal["active", "deleted"]


class NotificationCreate(BaseModel):
    recipient_user_id: int = Field(ge=1)
    actor_user_id: int | None = Field(default=None, ge=1)
    trip_id: int | None = Field(default=None, ge=1)
    event_type: NotificationEventType
    title: str = Field(min_length=1, max_length=255)
    message: str = Field(min_length=1, max_length=1000)
    entity_type: NotificationEntityType | None = None
    entity_id: int | None = Field(default=None, ge=1)
    metadata: dict[str, Any] = Field(default_factory=dict)


class NotificationResponse(BaseModel):
    notification_id: int
    recipient_user_id: int
    actor_user_id: int | None
    actor_full_name: str | None
    trip_id: int | None
    trip_title: str | None
    event_type: NotificationEventType
    title: str
    message: str
    entity_type: NotificationEntityType | None
    entity_id: int | None
    metadata: dict[str, Any]
    is_read: bool
    read_at: datetime | None
    status: NotificationStatus
    created_at: datetime
    updated_at: datetime


class NotificationUnreadCountResponse(BaseModel):
    user_id: int
    unread_count: int


class NotificationReadAllResponse(BaseModel):
    updated_count: int
    unread_count: int
