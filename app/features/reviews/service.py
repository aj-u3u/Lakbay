from decimal import Decimal, ROUND_HALF_UP

from fastapi import status
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.exceptions import LakbayAPIError
from app.features.reviews.models import TripReview
from app.features.reviews.repository import ReviewRepository
from app.features.reviews.schemas import (
    TripReviewCreate,
    TripReviewResponse,
    TripReviewSummaryResponse,
    TripReviewUpdate,
)
from app.features.trips.models import Trip, TripMember
from app.features.users.models import User


class ReviewService:
    def __init__(self, session: AsyncSession) -> None:
        self.session = session
        self.reviews = ReviewRepository(session)

    async def create_review(
        self,
        *,
        user: User,
        trip_id: int,
        data: TripReviewCreate,
    ) -> TripReviewResponse:
        trip, current_member = await self._require_active_member(user=user, trip_id=trip_id)
        self._require_trip_reviewable(trip)
        self._require_destination_belongs_to_trip(trip=trip, destination_id=data.destination_id)
        await self._require_no_duplicate_review(
            trip_id=trip_id,
            user_id=user.user_id,
            destination_id=data.destination_id,
        )
        review = TripReview(
            trip_id=trip_id,
            user_id=user.user_id,
            trip_member_id=current_member.trip_member_id,
            destination_id=data.destination_id,
            post_trip_rating=data.post_trip_rating,
            accuracy_rating=data.accuracy_rating,
            route_efficiency_rating=data.route_efficiency_rating,
            budget_adherence_rating=data.budget_adherence_rating,
            overall_experience_rating=data.overall_experience_rating,
            comments=data.comments,
            status="active",
        )

        try:
            await self.reviews.add_review(review)
            await self.session.commit()
        except IntegrityError as exc:
            await self.session.rollback()
            raise LakbayAPIError(
                "You have already submitted this review.",
                code="trip_review_already_exists",
                status_code=status.HTTP_400_BAD_REQUEST,
            ) from exc

        created_review = await self._require_review(
            trip_id=trip_id,
            review_id=review.trip_review_id,
        )

        return _review_response(created_review)

    async def list_reviews(
        self,
        *,
        user: User,
        trip_id: int,
        destination_id: int | None,
        limit: int,
        offset: int,
    ) -> list[TripReviewResponse]:
        trip, _ = await self._require_active_member(user=user, trip_id=trip_id)
        self._require_destination_belongs_to_trip(trip=trip, destination_id=destination_id)
        reviews = await self.reviews.list_reviews(
            trip_id=trip_id,
            destination_id=destination_id,
            limit=limit,
            offset=offset,
        )

        return [_review_response(review) for review in reviews]

    async def get_review(
        self,
        *,
        user: User,
        trip_id: int,
        review_id: int,
    ) -> TripReviewResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        review = await self._require_review(trip_id=trip_id, review_id=review_id)

        return _review_response(review)

    async def update_review(
        self,
        *,
        user: User,
        trip_id: int,
        review_id: int,
        data: TripReviewUpdate,
    ) -> TripReviewResponse:
        trip, _ = await self._require_active_member(user=user, trip_id=trip_id)
        self._require_trip_reviewable(trip)
        review = await self._require_review(trip_id=trip_id, review_id=review_id)
        self._require_review_owner(user=user, review=review)
        values = data.model_dump(exclude_unset=True)

        if not values:
            raise LakbayAPIError(
                "At least one review field must be provided.",
                code="empty_review_update",
                status_code=status.HTTP_400_BAD_REQUEST,
            )

        for field, value in values.items():
            setattr(review, field, value)

        await self.session.commit()
        updated_review = await self._require_review(trip_id=trip_id, review_id=review_id)

        return _review_response(updated_review)

    async def delete_review(
        self,
        *,
        user: User,
        trip_id: int,
        review_id: int,
    ) -> TripReviewResponse:
        trip, _ = await self._require_active_member(user=user, trip_id=trip_id)
        self._require_trip_reviewable(trip)
        review = await self._require_review(trip_id=trip_id, review_id=review_id)
        self._require_review_owner(user=user, review=review)
        review.status = "deleted"
        await self.session.commit()

        deleted_review = await self._require_review(
            trip_id=trip_id,
            review_id=review_id,
            include_deleted=True,
        )

        return _review_response(deleted_review)

    async def get_summary(
        self,
        *,
        user: User,
        trip_id: int,
    ) -> TripReviewSummaryResponse:
        await self._require_active_member(user=user, trip_id=trip_id)
        reviews = await self.reviews.list_active_reviews_for_summary(trip_id=trip_id)

        return TripReviewSummaryResponse(
            trip_id=trip_id,
            review_count=len(reviews),
            average_post_trip_rating=_average(
                [review.post_trip_rating for review in reviews],
            ),
            average_accuracy_rating=_average(
                [review.accuracy_rating for review in reviews],
            ),
            average_route_efficiency_rating=_average(
                [review.route_efficiency_rating for review in reviews],
            ),
            average_budget_adherence_rating=_average(
                [review.budget_adherence_rating for review in reviews],
            ),
            average_overall_experience_rating=_average(
                [review.overall_experience_rating for review in reviews],
            ),
        )

    async def _require_active_member(
        self,
        *,
        user: User,
        trip_id: int,
    ) -> tuple[Trip, TripMember]:
        trip = await self.reviews.get_trip_with_members(trip_id=trip_id)

        if trip is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        member = _active_member_for_user(trip, user.user_id)

        if member is None:
            raise LakbayAPIError(
                "Trip was not found.",
                code="trip_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return trip, member

    async def _require_review(
        self,
        *,
        trip_id: int,
        review_id: int,
        include_deleted: bool = False,
    ) -> TripReview:
        review = await self.reviews.get_review(
            trip_id=trip_id,
            review_id=review_id,
            include_deleted=include_deleted,
        )

        if review is None:
            raise LakbayAPIError(
                "Trip review was not found.",
                code="trip_review_not_found",
                status_code=status.HTTP_404_NOT_FOUND,
            )

        return review

    async def _require_no_duplicate_review(
        self,
        *,
        trip_id: int,
        user_id: int,
        destination_id: int | None,
    ) -> None:
        existing_review = await self.reviews.get_existing_active_review(
            trip_id=trip_id,
            user_id=user_id,
            destination_id=destination_id,
        )

        if existing_review is None:
            return

        raise LakbayAPIError(
            "You have already submitted this review.",
            code="trip_review_already_exists",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    def _require_trip_reviewable(self, trip: Trip) -> None:
        if trip.status == "completed":
            return

        raise LakbayAPIError(
            "Reviews can only be submitted for completed trips.",
            code="trip_not_completed",
            status_code=status.HTTP_400_BAD_REQUEST,
        )

    def _require_review_owner(self, *, user: User, review: TripReview) -> None:
        if review.user_id == user.user_id:
            return

        raise LakbayAPIError(
            "You do not have permission to edit this review.",
            code="trip_review_permission_denied",
            status_code=status.HTTP_403_FORBIDDEN,
        )

    def _require_destination_belongs_to_trip(
        self,
        *,
        trip: Trip,
        destination_id: int | None,
    ) -> None:
        if destination_id is None:
            return

        trip_destination_ids = {
            trip_destination.destination_id
            for trip_destination in trip.destinations
        }

        if destination_id in trip_destination_ids:
            return

        raise LakbayAPIError(
            "Review destination must belong to this trip.",
            code="trip_review_destination_mismatch",
            status_code=status.HTTP_400_BAD_REQUEST,
            details={"destination_id": destination_id},
        )


def _review_response(review: TripReview) -> TripReviewResponse:
    return TripReviewResponse(
        trip_review_id=review.trip_review_id,
        trip_id=review.trip_id,
        user_id=review.user_id,
        trip_member_id=review.trip_member_id,
        full_name=review.member.user.full_name,
        email=review.member.user.email,
        destination_id=review.destination_id,
        destination_name=(review.destination.name if review.destination is not None else None),
        post_trip_rating=review.post_trip_rating,
        accuracy_rating=review.accuracy_rating,
        route_efficiency_rating=review.route_efficiency_rating,
        budget_adherence_rating=review.budget_adherence_rating,
        overall_experience_rating=review.overall_experience_rating,
        comments=review.comments,
        status=review.status,
        created_at=review.created_at,
        updated_at=review.updated_at,
    )


def _active_member_for_user(trip: Trip, user_id: int) -> TripMember | None:
    return next(
        (
            member
            for member in trip.members
            if member.user_id == user_id and member.status == "active"
        ),
        None,
    )


def _average(values: list[int]) -> Decimal:
    if not values:
        return Decimal("0.00")

    return (
        Decimal(sum(values)) / Decimal(len(values))
    ).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
