from datetime import UTC, datetime
from decimal import Decimal

from fastapi import status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.expenses.models import TripExpense
from app.features.notifications.models import Notification
from app.features.notifications.repository import NotificationRepository
from app.features.notifications.schemas import (
    NotificationCreate,
    NotificationEventType,
    NotificationReadAllResponse,
    NotificationResponse,
    NotificationUnreadCountResponse,
)
from app.features.trips.models import Trip, TripMember, TripTask
from app.features.users.models import User


class NotificationService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.notifications = NotificationRepository(session)

    async def list_notifications(
        self,
        *,
        user: User,
        unread_only: bool,
        event_type: NotificationEventType | None,
        trip_id: int | None,
        limit: int,
        offset: int,
    ) -> list[NotificationResponse]:
        notifications = await self.notifications.list_notifications(
            recipient_user_id=user.user_id,
            unread_only=unread_only,
            event_type=event_type,
            trip_id=trip_id,
            limit=limit,
            offset=offset,
        )

        return [_notification_response(notification) for notification in notifications]

    async def unread_count(self, *, user: User) -> NotificationUnreadCountResponse:
        unread_count = await self.notifications.unread_count(
            recipient_user_id=user.user_id,
        )

        return NotificationUnreadCountResponse(
            user_id=user.user_id,
            unread_count=unread_count,
        )

    async def mark_read(
        self,
        *,
        user: User,
        notification_id: int,
    ) -> NotificationResponse:
        notification = await self._require_notification(
            user=user,
            notification_id=notification_id,
        )

        if notification.read_at is None:
            now = datetime.now(UTC)
            notification.read_at = now
            notification.updated_at = now
            await self.session.commit()
            notification = await self._require_notification(
                user=user,
                notification_id=notification_id,
            )

        return _notification_response(notification)

    async def mark_all_read(self, *, user: User) -> NotificationReadAllResponse:
        updated_count = await self.notifications.mark_all_read(
            recipient_user_id=user.user_id,
        )
        await self.session.commit()
        unread_count = await self.notifications.unread_count(
            recipient_user_id=user.user_id,
        )

        return NotificationReadAllResponse(
            updated_count=updated_count,
            unread_count=unread_count,
        )

    async def delete_notification(
        self,
        *,
        user: User,
        notification_id: int,
    ) -> NotificationResponse:
        notification = await self._require_notification(
            user=user,
            notification_id=notification_id,
        )
        notification.status = "deleted"
        notification.updated_at = datetime.now(UTC)
        await self.session.commit()

        return _notification_response(notification)

    async def create_many(
        self,
        payloads: list[NotificationCreate],
    ) -> list[Notification]:
        notifications = [
            Notification(
                recipient_user_id=payload.recipient_user_id,
                actor_user_id=payload.actor_user_id,
                trip_id=payload.trip_id,
                event_type=payload.event_type,
                title=payload.title,
                message=payload.message,
                entity_type=payload.entity_type,
                entity_id=payload.entity_id,
                metadata_=payload.metadata,
                status="active",
            )
            for payload in _dedupe_payloads(payloads)
        ]

        return await self.notifications.add_notifications(notifications)

    async def notify_trip_member_added(
        self,
        *,
        actor: User,
        trip: Trip,
        member: TripMember,
    ) -> None:
        if member.user_id == actor.user_id:
            return

        await self.create_many(
            [
                NotificationCreate(
                    recipient_user_id=member.user_id,
                    actor_user_id=actor.user_id,
                    trip_id=trip.trip_id,
                    event_type="trip_member_added",
                    title="Added to trip",
                    message=f"{actor.full_name} added you to {trip.title}.",
                    entity_type="trip_member",
                    entity_id=member.trip_member_id,
                    metadata=_notification_metadata(
                        actor=actor,
                        trip=trip,
                        values={
                            "trip_member_id": member.trip_member_id,
                            "role": member.role,
                        },
                    ),
                )
            ]
        )

    async def notify_trip_updated(
        self,
        *,
        actor: User,
        trip: Trip,
        changed_fields: list[str],
    ) -> None:
        await self._notify_active_trip_members(
            actor=actor,
            trip=trip,
            event_type="trip_updated",
            title="Trip updated",
            message=f"{actor.full_name} updated {trip.title}.",
            entity_type="trip",
            entity_id=trip.trip_id,
            metadata={"changed_fields": sorted(changed_fields)},
        )

    async def notify_trip_route_updated(
        self,
        *,
        actor: User,
        trip: Trip,
    ) -> None:
        route = trip.route
        await self._notify_active_trip_members(
            actor=actor,
            trip=trip,
            event_type="trip_route_updated",
            title="Trip route updated",
            message=f"{actor.full_name} updated the route for {trip.title}.",
            entity_type="trip_route",
            entity_id=(route.trip_route_id if route is not None else None),
            metadata=(
                {
                    "travel_mode": route.travel_mode,
                    "route_provider": route.route_provider,
                    "total_distance_km": _decimal_to_string(route.total_distance_km),
                    "total_duration_minutes": route.total_duration_minutes,
                }
                if route is not None
                else {}
            ),
        )

    async def notify_task_assigned(
        self,
        *,
        actor: User,
        trip: Trip,
        task: TripTask,
        assigned_member: TripMember | None,
    ) -> None:
        if assigned_member is None or assigned_member.user_id == actor.user_id:
            return

        await self.create_many(
            [
                NotificationCreate(
                    recipient_user_id=assigned_member.user_id,
                    actor_user_id=actor.user_id,
                    trip_id=trip.trip_id,
                    event_type="task_assigned",
                    title="New task assigned",
                    message=f"{actor.full_name} assigned you a task: {task.title}.",
                    entity_type="trip_task",
                    entity_id=task.trip_task_id,
                    metadata=_notification_metadata(
                        actor=actor,
                        trip=trip,
                        values={
                            "trip_task_id": task.trip_task_id,
                            "task_title": task.title,
                            "status": task.status,
                        },
                    ),
                )
            ]
        )

    async def notify_task_updated(
        self,
        *,
        actor: User,
        trip: Trip,
        task: TripTask,
        assigned_member: TripMember | None,
        changed_fields: list[str],
    ) -> None:
        if assigned_member is None or assigned_member.user_id == actor.user_id:
            return

        await self.create_many(
            [
                NotificationCreate(
                    recipient_user_id=assigned_member.user_id,
                    actor_user_id=actor.user_id,
                    trip_id=trip.trip_id,
                    event_type="task_updated",
                    title="Task updated",
                    message=f"{actor.full_name} updated a task: {task.title}.",
                    entity_type="trip_task",
                    entity_id=task.trip_task_id,
                    metadata=_notification_metadata(
                        actor=actor,
                        trip=trip,
                        values={
                            "trip_task_id": task.trip_task_id,
                            "task_title": task.title,
                            "status": task.status,
                            "changed_fields": sorted(changed_fields),
                        },
                    ),
                )
            ]
        )

    async def notify_expense_created(
        self,
        *,
        actor: User,
        trip: Trip,
        expense: TripExpense,
    ) -> None:
        await self._notify_expense_event(
            actor=actor,
            trip=trip,
            expense=expense,
            event_type="expense_created",
            title="New expense added",
            message=f"{actor.full_name} added an expense: {expense.title}.",
        )

    async def notify_expense_updated(
        self,
        *,
        actor: User,
        trip: Trip,
        expense: TripExpense,
        changed_fields: list[str],
    ) -> None:
        await self._notify_expense_event(
            actor=actor,
            trip=trip,
            expense=expense,
            event_type="expense_updated",
            title="Expense updated",
            message=f"{actor.full_name} updated an expense: {expense.title}.",
            extra_metadata={"changed_fields": sorted(changed_fields)},
        )

    async def notify_expense_voided(
        self,
        *,
        actor: User,
        trip: Trip,
        expense: TripExpense,
    ) -> None:
        await self._notify_expense_event(
            actor=actor,
            trip=trip,
            expense=expense,
            event_type="expense_voided",
            title="Expense voided",
            message=f"{actor.full_name} voided an expense: {expense.title}.",
        )

    async def _notify_expense_event(
        self,
        *,
        actor: User,
        trip: Trip,
        expense: TripExpense,
        event_type: NotificationEventType,
        title: str,
        message: str,
        extra_metadata: dict | None = None,
    ) -> None:
        metadata = {
            "trip_expense_id": expense.trip_expense_id,
            "expense_title": expense.title,
            "category": expense.category,
            "amount": _decimal_to_string(expense.amount),
            "status": expense.status,
        }
        metadata.update(extra_metadata or {})
        await self._notify_active_trip_members(
            actor=actor,
            trip=trip,
            event_type=event_type,
            title=title,
            message=message,
            entity_type="trip_expense",
            entity_id=expense.trip_expense_id,
            metadata=metadata,
        )

    async def _notify_active_trip_members(
        self,
        *,
        actor: User,
        trip: Trip,
        event_type: NotificationEventType,
        title: str,
        message: str,
        entity_type: str,
        entity_id: int | None,
        metadata: dict,
    ) -> None:
        if entity_id is None:
            return

        await self.create_many(
            [
                NotificationCreate(
                    recipient_user_id=member.user_id,
                    actor_user_id=actor.user_id,
                    trip_id=trip.trip_id,
                    event_type=event_type,
                    title=title,
                    message=message,
                    entity_type=entity_type,
                    entity_id=entity_id,
                    metadata=_notification_metadata(
                        actor=actor,
                        trip=trip,
                        values=metadata,
                    ),
                )
                for member in _active_members(trip)
                if member.user_id != actor.user_id
            ]
        )

    async def _require_notification(
        self,
        *,
        user: User,
        notification_id: int,
    ) -> Notification:
        notification = await self.notifications.get_notification_for_user(
            recipient_user_id=user.user_id,
            notification_id=notification_id,
        )

        if notification is None:
            raise LakbayAPIError(
                "Notification was not found.",
                code="notification_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return notification


def _notification_response(notification: Notification) -> NotificationResponse:
    metadata = notification.metadata_ or {}

    return NotificationResponse(
        notification_id=notification.notification_id,
        recipient_user_id=notification.recipient_user_id,
        actor_user_id=notification.actor_user_id,
        actor_full_name=(
            metadata.get("actor_full_name")
            or (notification.actor.full_name if notification.actor is not None else None)
        ),
        trip_id=notification.trip_id,
        trip_title=(
            metadata.get("trip_title")
            or (notification.trip.title if notification.trip is not None else None)
        ),
        event_type=notification.event_type,
        title=notification.title,
        message=notification.message,
        entity_type=notification.entity_type,
        entity_id=notification.entity_id,
        metadata=metadata,
        is_read=notification.read_at is not None,
        read_at=notification.read_at,
        status=notification.status,
        created_at=notification.created_at,
        updated_at=notification.updated_at,
    )


def _active_members(trip: Trip) -> list[TripMember]:
    return [member for member in trip.members if member.status == "active"]


def _dedupe_payloads(payloads: list[NotificationCreate]) -> list[NotificationCreate]:
    seen_recipients: set[int] = set()
    deduped: list[NotificationCreate] = []

    for payload in payloads:
        if payload.recipient_user_id in seen_recipients:
            continue

        seen_recipients.add(payload.recipient_user_id)
        deduped.append(payload)

    return deduped


def _notification_metadata(
    *,
    actor: User,
    trip: Trip,
    values: dict,
) -> dict:
    return {
        **values,
        "actor_full_name": actor.full_name,
        "trip_title": trip.title,
    }


def _decimal_to_string(value: Decimal) -> str:
    return str(value)
