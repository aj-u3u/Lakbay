from datetime import UTC, date, datetime

from fastapi import status
from pydantic import ValidationError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.accommodations.models import Accommodation
from app.features.ai.schemas import AIItineraryOption
from app.features.destinations.models import Destination
from app.features.notifications.service import NotificationService
from app.features.planning.schemas import PlanningPreviewResponse
from app.features.routes.schemas import RouteSummaryResponse
from app.features.transportations.models import Transportation
from app.features.trips.models import (
    Trip,
    TripDestination,
    TripItineraryActivity,
    TripItineraryDay,
    TripMember,
    TripRoute,
    TripTask,
)
from app.features.trips.repository import TripRepository
from app.features.trips.schemas import (
    TripCreate,
    TripFromAIOptionCreate,
    TripItineraryActivityCreate,
    TripItineraryDayCreate,
    TripDestinationResponse,
    TripItineraryActivityResponse,
    TripItineraryDayResponse,
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
from app.features.users.models import User


class TripService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.trips = TripRepository(session)
        self.notifications = NotificationService(session)

    async def create_trip(
        self, *, user: User, data: TripCreate,
        planning_snapshot: dict | None = None,
        route_summary: RouteSummaryResponse | None = None,
    ) -> TripResponse:
        destinations = await self.trips.list_active_destinations_by_ids(
            list(data.destination_ids),
        )
        self._require_all_destinations(data.destination_ids, destinations)

        selected_destination_ids = set(data.destination_ids)
        accommodation_ids = _collect_activity_ids(data, "accommodation_id")
        transportation_ids = _collect_activity_ids(data, "transportation_id")
        self._require_activity_destinations_belong_to_trip(
            data=data,
            destination_ids=selected_destination_ids,
        )

        accommodations = await self.trips.list_available_accommodations_by_ids(
            accommodation_ids,
        )
        self._require_all_accommodations(accommodation_ids, accommodations)

        transportations = await self.trips.list_available_transportations_by_ids(
            transportation_ids,
        )
        self._require_all_transportations(transportation_ids, transportations)
        self._require_rates_belong_to_destinations(
            accommodations=accommodations,
            transportations=transportations,
            destination_ids=selected_destination_ids,
        )

        destination_by_id = {
            destination.destination_id: destination for destination in destinations
        }
        trip = Trip(
            owner_user_id=user.user_id,
            title=data.title,
            description=data.description,
            start_date=data.start_date,
            end_date=data.end_date,
            traveler_count=data.traveler_count,
            total_budget=data.total_budget,
            estimated_total_cost=data.estimated_total_cost,
            notes=data.notes,
            planning_snapshot=planning_snapshot,
        )
        trip.members = [
            TripMember(
                user_id=user.user_id,
                role="owner",
                status="active",
            )
        ]
        trip.destinations = [
            TripDestination(
                destination_id=destination_id,
                stop_order=index,
            )
            for index, destination_id in enumerate(data.destination_ids, start=1)
        ]
        trip.itinerary_days = [
            TripItineraryDay(
                day_number=day.day_number,
                title=day.title,
                summary=day.summary,
                activities=[
                    TripItineraryActivity(
                        activity_order=activity.activity_order,
                        time=activity.time,
                        title=activity.title,
                        description=activity.description,
                        destination_id=activity.destination_id,
                        accommodation_id=activity.accommodation_id,
                        transportation_id=activity.transportation_id,
                        estimated_cost=activity.estimated_cost,
                        notes=activity.notes,
                    )
                    for activity in day.activities
                ],
            )
            for day in data.itinerary_days
        ]
        if route_summary is not None:
            route_destinations = {
                stop.destination_id for stop in route_summary.stops
                if stop.destination_id is not None
            }
            if route_destinations != selected_destination_ids:
                raise LakbayAPIError(
                    "The saved route must contain exactly the trip's destinations.",
                    code="trip_route_destination_mismatch",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
            route_data = TripRouteCreate.model_validate(route_summary.model_dump())
            trip.route = TripRoute(**route_data.model_dump(mode="json"))

        await self.trips.create_trip(trip)
        await self.session.commit()

        created_trip = await self.trips.get_accessible_trip(
            user_id=user.user_id,
            trip_id=trip.trip_id,
        )

        if created_trip is None:
            raise LakbayAPIError(
                "Trip was created but could not be loaded.",
                code="trip_reload_failed",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return _trip_response(created_trip, destination_by_id=destination_by_id)

    async def create_from_ai_option(
        self, *, user: User, data: TripFromAIOptionCreate,
    ) -> TripResponse:
        run = await self.trips.get_owned_generation_run(
            user_id=user.user_id, generation_run_id=data.generation_run_id,
        )
        if (
            run is None or run.request_purpose != "itinerary_generation"
            or run.status != "succeeded" or run.validation_status != "valid"
            or not run.output_summary or "planning_preview" not in run.output_summary
        ):
            raise LakbayAPIError(
                "A saved planning generation run was not found.",
                code="planning_generation_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )
        try:
            preview = PlanningPreviewResponse.model_validate(run.output_summary["planning_preview"])
            options = [
                AIItineraryOption.model_validate(item)
                for item in run.output_summary["options"]
            ]
        except (KeyError, TypeError, ValidationError) as exc:
            raise LakbayAPIError(
                "The stored planning run is invalid.",
                code="planning_generation_invalid",
                status_code=status.HTTP_409_CONFLICT,
            ) from exc
        option = next((item for item in options if item.option_number == data.option_number), None)
        if option is None:
            raise LakbayAPIError(
                "This itinerary option was not part of the generation run.",
                code="planning_option_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )
        if preview.selection_problems or preview.budget.total_estimate is None:
            raise LakbayAPIError(
                "Resolve selected options and missing costs before saving this trip.",
                code="planning_preview_incomplete",
                status_code=status.HTTP_409_CONFLICT,
            )
        if preview.route.status != "not_requested" and preview.route.summary is None:
            raise LakbayAPIError(
                "The requested route must have a summary before saving this trip.",
                code="planning_route_incomplete",
                status_code=status.HTTP_409_CONFLICT,
            )
        if preview.whole_trip_budget is None or preview.state.traveler_count is None:
            raise LakbayAPIError(
                "Budget and traveler count are required to save this trip.",
                code="planning_preview_incomplete",
                status_code=status.HTTP_409_CONFLICT,
            )
        trip_data = TripCreate(
            title=option.title,
            description=option.summary,
            start_date=data.start_date,
            end_date=data.end_date,
            traveler_count=preview.state.traveler_count,
            total_budget=preview.whole_trip_budget,
            estimated_total_cost=preview.budget.total_estimate,
            destination_ids=preview.state.destination_ids,
            notes=data.notes,
            itinerary_days=[
                TripItineraryDayCreate(
                    day_number=day.day,
                    title=day.title,
                    summary=day.summary,
                    activities=[
                        TripItineraryActivityCreate(
                            activity_order=index,
                            time=activity.time,
                            title=activity.title,
                            description=activity.description,
                            destination_id=activity.destination_id,
                            accommodation_id=activity.accommodation_id,
                            transportation_id=activity.transportation_id,
                            estimated_cost=activity.estimated_cost,
                            notes=activity.notes,
                        )
                        for index, activity in enumerate(day.activities, start=1)
                    ],
                )
                for day in option.days
            ],
        )
        snapshot = {
            "generation_run_id": run.ai_generation_run_id,
            "option_number": option.option_number,
            "preview": preview.model_dump(mode="json"),
            "ai_costs_are_draft_estimates": True,
        }
        return await self.create_trip(
            user=user, data=trip_data, planning_snapshot=snapshot,
            route_summary=preview.route.summary,
        )

    async def list_trips(
        self,
        *,
        user: User,
        include_archived: bool,
        limit: int,
        offset: int,
    ) -> list[TripListItemResponse]:
        trips = await self.trips.list_accessible_trips(
            user_id=user.user_id,
            include_archived=include_archived,
            limit=limit,
            offset=offset,
        )

        return [TripListItemResponse.model_validate(trip) for trip in trips]

    async def get_trip(self, *, user: User, trip_id: int) -> TripResponse:
        trip = await self._require_trip_access(user=user, trip_id=trip_id)

        return _trip_response(trip)

    async def update_trip(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripUpdate,
    ) -> TripResponse:
        trip = await self._require_trip_manager(user=user, trip_id=trip_id)
        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one trip field must be provided.",
                code="empty_trip_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if values.get("status") == "archived" and trip.owner_user_id != user.user_id:
            raise LakbayAPIError(
                "Only the trip owner can perform this action.",
                code="trip_owner_required",
                status_code=status.HTTP_403_FORBIDDEN,
            )

        start_date = values.get("start_date", trip.start_date)
        end_date = values.get("end_date", trip.end_date)
        _validate_date_range(start_date, end_date)

        for field, value in values.items():
            setattr(trip, field, value)

        await self.notifications.notify_trip_updated(
            actor=user,
            trip=trip,
            changed_fields=list(values.keys()),
        )
        await self.session.commit()

        updated_trip = await self._require_trip_access(user=user, trip_id=trip_id)

        return _trip_response(updated_trip)

    async def archive_trip(self, *, user: User, trip_id: int) -> TripResponse:
        trip = await self._require_trip_owner(user=user, trip_id=trip_id)
        trip.status = "archived"
        await self.notifications.notify_trip_updated(
            actor=user,
            trip=trip,
            changed_fields=["status"],
        )
        await self.session.commit()

        archived_trip = await self._require_trip_access(user=user, trip_id=trip_id)

        return _trip_response(archived_trip)

    async def save_route(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripRouteCreate,
    ) -> TripRouteResponse:
        trip = await self._require_trip_manager(user=user, trip_id=trip_id)
        selected_destination_ids = {
            trip_destination.destination_id for trip_destination in trip.destinations
        }
        invalid_destination_ids = [
            stop.destination_id
            for stop in data.stops
            if stop.destination_id is not None
            and stop.destination_id not in selected_destination_ids
        ]
        invalid_destination_ids.extend(
            destination_id
            for leg in data.legs
            for destination_id in (leg.from_destination_id, leg.to_destination_id)
            if destination_id is not None and destination_id not in selected_destination_ids
        )

        if invalid_destination_ids:
            raise LakbayAPIError(
                "Route stops and legs must belong to this trip's destinations.",
                code="trip_route_destination_mismatch",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={"destination_ids": sorted(set(invalid_destination_ids))},
            )

        destination_by_id = {
            item.destination_id: item.destination for item in trip.destinations
        }
        verified_stops = [
            stop for stop in data.stops if not stop.is_origin
        ]
        for stop in verified_stops:
            if stop.coordinate_basis != "verified_arrival":
                continue
            destination = destination_by_id.get(stop.destination_id)
            if (
                destination is None
                or not destination.route_ready
                or destination.arrival_lat is None
                or destination.arrival_lng is None
                or not destination.arrival_source_url
                or destination.arrival_verified_at is None
                or abs(stop.lat - destination.arrival_lat) > 0.000001
                or abs(stop.lng - destination.arrival_lng) > 0.000001
            ):
                raise LakbayAPIError(
                    "A saved route's verified arrival point must match the reviewed destination.",
                    code="trip_route_arrival_unverified",
                    status_code=status.HTTP_400_BAD_REQUEST,
                )
        all_arrivals_verified = bool(verified_stops) and all(
            stop.coordinate_basis == "verified_arrival" for stop in verified_stops
        )
        if data.arrival_points_verified != all_arrivals_verified or (
            not all_arrivals_verified and any(leg.steps for leg in data.legs)
        ):
            raise LakbayAPIError(
                "Verified directions require reviewed arrival points at every destination.",
                code="trip_route_arrival_unverified",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        route = await self.trips.save_route(trip=trip, data=data)
        await self.notifications.notify_trip_route_updated(actor=user, trip=trip)
        await self.session.commit()

        reloaded_trip = await self._require_trip_access(user=user, trip_id=trip_id)

        if reloaded_trip.route is None:
            raise LakbayAPIError(
                "Trip route was saved but could not be loaded.",
                code="trip_route_reload_failed",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return TripRouteResponse.model_validate(reloaded_trip.route)

    async def get_route(self, *, user: User, trip_id: int) -> TripRouteResponse:
        trip = await self._require_trip_access(user=user, trip_id=trip_id)

        if trip.route is None:
            raise LakbayAPIError(
                "No route summary was saved for this trip.",
                code="trip_route_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return TripRouteResponse.model_validate(trip.route)

    async def list_members(
        self,
        *,
        user: User,
        trip_id: int,
    ) -> list[TripMemberResponse]:
        trip = await self._require_trip_access(user=user, trip_id=trip_id)

        return [_member_response(member) for member in _active_members(trip)]

    async def add_member(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripMemberCreate,
    ) -> TripMemberResponse:
        trip = await self._require_trip_manager(user=user, trip_id=trip_id)
        target_user = await self.trips.get_user_by_email(_normalize_email(str(data.email)))

        if target_user is None:
            raise LakbayAPIError(
                "User was not found.",
                code="user_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        existing_member = await self.trips.get_trip_member_by_user_id(
            trip_id=trip_id,
            user_id=target_user.user_id,
        )

        if existing_member is not None and existing_member.status == "active":
            raise LakbayAPIError(
                "User is already an active trip member.",
                code="trip_member_already_exists",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        if existing_member is None:
            member = TripMember(
                trip_id=trip_id,
                user_id=target_user.user_id,
                role=data.role,
                status="active",
            )
            await self.trips.add_trip_member(member)
        else:
            existing_member.role = data.role
            existing_member.status = "active"
            existing_member.joined_at = datetime.now(UTC)
            member = existing_member

        await self.notifications.notify_trip_member_added(
            actor=user,
            trip=trip,
            member=member,
        )
        await self.session.commit()

        reloaded_member = await self.trips.get_trip_member_by_user_id(
            trip_id=trip_id,
            user_id=target_user.user_id,
        )

        if reloaded_member is None:
            raise LakbayAPIError(
                "Trip member was saved but could not be loaded.",
                code="trip_member_reload_failed",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return _member_response(reloaded_member)

    async def update_member(
        self,
        *,
        user: User,
        trip_id: int,
        member_id: int,
        data: TripMemberUpdate,
    ) -> TripMemberResponse:
        await self._require_trip_manager(user=user, trip_id=trip_id)
        member = await self._require_active_member_by_id(
            trip_id=trip_id,
            member_id=member_id,
        )

        if member.role == "owner":
            raise LakbayAPIError(
                "The trip owner's membership role cannot be changed.",
                code="owner_member_locked",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        member.role = data.role
        await self.session.commit()

        reloaded_member = await self._require_active_member_by_id(
            trip_id=trip_id,
            member_id=member_id,
        )

        return _member_response(reloaded_member)

    async def remove_member(
        self,
        *,
        user: User,
        trip_id: int,
        member_id: int,
    ) -> TripMemberResponse:
        await self._require_trip_manager(user=user, trip_id=trip_id)
        member = await self._require_active_member_by_id(
            trip_id=trip_id,
            member_id=member_id,
        )

        if member.role == "owner":
            raise LakbayAPIError(
                "The trip owner cannot be removed from the trip.",
                code="owner_member_locked",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        member.status = "removed"
        await self.session.commit()

        reloaded_member = await self.trips.get_trip_member(
            trip_id=trip_id,
            trip_member_id=member_id,
        )

        if reloaded_member is None:
            raise LakbayAPIError(
                "Trip member was removed but could not be loaded.",
                code="trip_member_reload_failed",
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            )

        return _member_response(reloaded_member)

    async def list_tasks(
        self,
        *,
        user: User,
        trip_id: int,
        task_status: TripTaskStatus | None,
        assigned_to_me: bool,
        limit: int,
        offset: int,
    ) -> list[TripTaskResponse]:
        member = await self._require_active_member(user=user, trip_id=trip_id)
        assigned_trip_member_id = member.trip_member_id if assigned_to_me else None
        tasks = await self.trips.list_trip_tasks(
            trip_id=trip_id,
            task_status=task_status,
            assigned_trip_member_id=assigned_trip_member_id,
            limit=limit,
            offset=offset,
        )

        return [_task_response(task) for task in tasks]

    async def create_task(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripTaskCreate,
    ) -> TripTaskResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        trip = await self._require_trip_access(user=user, trip_id=trip_id)
        assigned_member = await self._validate_task_assignee(
            trip_id=trip_id,
            assigned_trip_member_id=data.assigned_trip_member_id,
        )
        task = TripTask(
            trip_id=trip_id,
            created_by_user_id=user.user_id,
            assigned_trip_member_id=(
                assigned_member.trip_member_id if assigned_member is not None else None
            ),
            title=data.title,
            description=data.description,
            status=data.status,
            due_date=data.due_date,
            completed_at=(
                datetime.now(UTC) if data.status == "completed" else None
            ),
        )

        await self.trips.add_trip_task(task)
        await self.notifications.notify_task_assigned(
            actor=user,
            trip=trip,
            task=task,
            assigned_member=assigned_member,
        )
        await self.session.commit()
        await self.session.refresh(task)

        return _task_response(task)

    async def get_task(
        self,
        *,
        user: User,
        trip_id: int,
        task_id: int,
    ) -> TripTaskResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        task = await self._require_task(trip_id=trip_id, task_id=task_id)

        return _task_response(task)

    async def update_task(
        self,
        *,
        user: User,
        trip_id: int,
        task_id: int,
        data: TripTaskUpdate,
    ) -> TripTaskResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        trip = await self._require_trip_access(user=user, trip_id=trip_id)
        task = await self._require_task(trip_id=trip_id, task_id=task_id)
        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one task field must be provided.",
                code="empty_task_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        assigned_member_for_notification: TripMember | None = None
        previous_assigned_trip_member_id = task.assigned_trip_member_id

        if "assigned_trip_member_id" in values:
            assigned_member = await self._validate_task_assignee(
                trip_id=trip_id,
                assigned_trip_member_id=values["assigned_trip_member_id"],
            )
            values["assigned_trip_member_id"] = (
                assigned_member.trip_member_id if assigned_member is not None else None
            )
            assigned_member_for_notification = assigned_member
        elif task.assigned_trip_member_id is not None:
            assigned_member_for_notification = await self._get_active_member_by_id_or_none(
                trip_id=trip_id,
                member_id=task.assigned_trip_member_id,
            )

        if "status" in values:
            if values["status"] == "completed" and task.status != "completed":
                task.completed_at = datetime.now(UTC)
            elif values["status"] != "completed":
                task.completed_at = None

        for field, value in values.items():
            setattr(task, field, value)

        if (
            "assigned_trip_member_id" in values
            and assigned_member_for_notification is not None
            and previous_assigned_trip_member_id
            != assigned_member_for_notification.trip_member_id
        ):
            await self.notifications.notify_task_assigned(
                actor=user,
                trip=trip,
                task=task,
                assigned_member=assigned_member_for_notification,
            )
        else:
            await self.notifications.notify_task_updated(
                actor=user,
                trip=trip,
                task=task,
                assigned_member=assigned_member_for_notification,
                changed_fields=list(values.keys()),
            )

        await self.session.commit()
        await self.session.refresh(task)

        return _task_response(task)

    async def delete_task(
        self,
        *,
        user: User,
        trip_id: int,
        task_id: int,
    ) -> None:
        await self._require_active_member(user=user, trip_id=trip_id)
        task = await self._require_task(trip_id=trip_id, task_id=task_id)
        await self.trips.delete_trip_task(task)
        await self.session.commit()

    async def _require_trip_access(self, *, user: User, trip_id: int) -> Trip:
        trip = await self.trips.get_accessible_trip(
            user_id=user.user_id,
            trip_id=trip_id,
        )

        if trip is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return trip

    async def _require_trip_manager(self, *, user: User, trip_id: int) -> Trip:
        trip = await self._require_trip_access(user=user, trip_id=trip_id)

        if trip.owner_user_id == user.user_id:
            return trip

        member = _active_member_for_user(trip, user.user_id)

        if member is not None and member.role == "organizer":
            return trip

        raise LakbayAPIError(
            "You do not have permission to manage this trip.",
            code="trip_permission_denied",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    async def _require_trip_owner(self, *, user: User, trip_id: int) -> Trip:
        trip = await self._require_trip_access(user=user, trip_id=trip_id)

        if trip.owner_user_id == user.user_id:
            return trip

        raise LakbayAPIError(
            "Only the trip owner can perform this action.",
            code="trip_owner_required",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    async def _require_active_member(self, *, user: User, trip_id: int) -> TripMember:
        trip = await self._require_trip_access(user=user, trip_id=trip_id)
        member = _active_member_for_user(trip, user.user_id)

        if member is not None:
            return member

        member = TripMember(
            trip_id=trip.trip_id,
            user_id=user.user_id,
            role="owner",
            status="active",
        )
        await self.trips.add_trip_member(member)
        await self.session.commit()

        return member

    async def _require_active_member_by_id(
        self,
        *,
        trip_id: int,
        member_id: int,
    ) -> TripMember:
        member = await self.trips.get_trip_member(
            trip_id=trip_id,
            trip_member_id=member_id,
        )

        if member is None or member.status != "active":
            raise LakbayAPIError(
                "Trip member was not found.",
                code="trip_member_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return member

    async def _get_active_member_by_id_or_none(
        self,
        *,
        trip_id: int,
        member_id: int,
    ) -> TripMember | None:
        member = await self.trips.get_trip_member(
            trip_id=trip_id,
            trip_member_id=member_id,
        )

        if member is None or member.status != "active":
            return None

        return member

    async def _validate_task_assignee(
        self,
        *,
        trip_id: int,
        assigned_trip_member_id: int | None,
    ) -> TripMember | None:
        if assigned_trip_member_id is None:
            return None

        return await self._require_active_member_by_id(
            trip_id=trip_id,
            member_id=assigned_trip_member_id,
        )

    async def _require_task(self, *, trip_id: int, task_id: int) -> TripTask:
        task = await self.trips.get_trip_task(trip_id=trip_id, trip_task_id=task_id)

        if task is None:
            raise LakbayAPIError(
                "Trip task was not found.",
                code="trip_task_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return task

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

    def _require_activity_destinations_belong_to_trip(
        self,
        *,
        data: TripCreate,
        destination_ids: set[int],
    ) -> None:
        invalid_destination_ids = sorted(
            {
                activity.destination_id
                for day in data.itinerary_days
                for activity in day.activities
                if activity.destination_id is not None
                and activity.destination_id not in destination_ids
            }
        )

        if invalid_destination_ids:
            raise LakbayAPIError(
                "Itinerary activities must use destinations selected for the trip.",
                code="trip_activity_destination_mismatch",
                status_code=status.HTTP_400_BAD_REQUEST,
                details={"destination_ids": invalid_destination_ids},
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


def _trip_response(
    trip: Trip,
    *,
    destination_by_id: dict[int, Destination] | None = None,
) -> TripResponse:
    destination_lookup = destination_by_id or {
        item.destination_id: item.destination for item in trip.destinations
    }

    return TripResponse(
        trip_id=trip.trip_id,
        owner_user_id=trip.owner_user_id,
        title=trip.title,
        description=trip.description,
        start_date=trip.start_date,
        end_date=trip.end_date,
        traveler_count=trip.traveler_count,
        total_budget=trip.total_budget,
        estimated_total_cost=trip.estimated_total_cost,
        status=trip.status,
        notes=trip.notes,
        created_at=trip.created_at,
        updated_at=trip.updated_at,
        destinations=[
            TripDestinationResponse(
                trip_destination_id=item.trip_destination_id,
                destination_id=item.destination_id,
                name=destination_lookup[item.destination_id].name,
                stop_order=item.stop_order,
            )
            for item in sorted(trip.destinations, key=lambda item: item.stop_order)
        ],
        itinerary_days=[
            _day_response(day)
            for day in sorted(trip.itinerary_days, key=lambda day: day.day_number)
        ],
        route=(
            TripRouteResponse.model_validate(trip.route)
            if trip.route is not None
            else None
        ),
        planning_snapshot=trip.planning_snapshot,
        members=[
            _member_response(member)
            for member in sorted(
                _active_members(trip),
                key=lambda member: member.trip_member_id,
            )
        ],
        tasks=[
            _task_response(task)
            for task in sorted(
                trip.tasks,
                key=lambda task: task.trip_task_id,
            )
        ],
    )


def _day_response(day: TripItineraryDay) -> TripItineraryDayResponse:
    return TripItineraryDayResponse(
        trip_itinerary_day_id=day.trip_itinerary_day_id,
        day_number=day.day_number,
        title=day.title,
        summary=day.summary,
        activities=[
            TripItineraryActivityResponse(
                trip_itinerary_activity_id=activity.trip_itinerary_activity_id,
                destination_id=activity.destination_id,
                accommodation_id=activity.accommodation_id,
                transportation_id=activity.transportation_id,
                activity_order=activity.activity_order,
                time=activity.time,
                title=activity.title,
                description=activity.description,
                estimated_cost=activity.estimated_cost,
                notes=activity.notes,
            )
            for activity in sorted(
                day.activities,
                key=lambda activity: activity.activity_order,
            )
        ],
    )


def _member_response(member: TripMember) -> TripMemberResponse:
    return TripMemberResponse(
        trip_member_id=member.trip_member_id,
        trip_id=member.trip_id,
        user_id=member.user_id,
        full_name=member.user.full_name,
        email=member.user.email,
        role=member.role,
        status=member.status,
        joined_at=member.joined_at,
        created_at=member.created_at,
        updated_at=member.updated_at,
    )


def _task_response(task: TripTask) -> TripTaskResponse:
    return TripTaskResponse(
        trip_task_id=task.trip_task_id,
        trip_id=task.trip_id,
        created_by_user_id=task.created_by_user_id,
        assigned_trip_member_id=task.assigned_trip_member_id,
        title=task.title,
        description=task.description,
        status=task.status,
        due_date=task.due_date,
        completed_at=task.completed_at,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )


def _active_members(trip: Trip) -> list[TripMember]:
    return [member for member in trip.members if member.status == "active"]


def _active_member_for_user(trip: Trip, user_id: int) -> TripMember | None:
    return next(
        (
            member
            for member in _active_members(trip)
            if member.user_id == user_id
        ),
        None,
    )


def _collect_activity_ids(data: TripCreate, field_name: str) -> list[int]:
    values = {
        value
        for day in data.itinerary_days
        for activity in day.activities
        if (value := getattr(activity, field_name)) is not None
    }

    return sorted(values)


def _missing_ids(requested_ids: list[int], found_ids: set[int]) -> list[int]:
    return [
        requested_id
        for requested_id in requested_ids
        if requested_id not in found_ids
    ]


def _validate_date_range(start_date: date | None, end_date: date | None) -> None:
    if start_date is not None and end_date is not None and end_date < start_date:
        raise LakbayAPIError(
            "Trip end date must be on or after the start date.",
            code="invalid_trip_date_range",
            status_code=status.HTTP_400_BAD_REQUEST,
        )


def _normalize_email(email: str) -> str:
    return email.strip().lower()
