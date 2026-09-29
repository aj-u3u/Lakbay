from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, EmailStr, Field, field_validator


ReviewStatus = Literal["active", "deleted"]
Rating = Annotated[int, Field(ge=1, le=5)]


class TripReviewCreate(BaseModel):
    destination_id: int | None = Field(default=None, ge=1)
    post_trip_rating: Rating
    accuracy_rating: Rating
    route_efficiency_rating: Rating
    budget_adherence_rating: Rating
    overall_experience_rating: Rating
    comments: str | None = Field(default=None, max_length=2000)

    @field_validator("comments")
    @classmethod
    def normalize_comments(cls, value: str | None) -> str | None:
        if value is None:
            return None

        normalized = value.strip()
        return normalized or None


class TripReviewUpdate(BaseModel):
    post_trip_rating: Rating | None = None
    accuracy_rating: Rating | None = None
    route_efficiency_rating: Rating | None = None
    budget_adherence_rating: Rating | None = None
    overall_experience_rating: Rating | None = None
    comments: str | None = Field(default=None, max_length=2000)

    @field_validator(
        "post_trip_rating",
        "accuracy_rating",
        "route_efficiency_rating",
        "budget_adherence_rating",
        "overall_experience_rating",
        mode="before",
    )
    @classmethod
    def ratings_cannot_be_null(cls, value):
        if value is None:
            raise ValueError("Rating fields cannot be null when provided.")

        return value

    @field_validator("comments")
    @classmethod
    def normalize_comments(cls, value: str | None) -> str | None:
        if value is None:
            return None

        normalized = value.strip()
        return normalized or None


class TripReviewResponse(BaseModel):
    trip_review_id: int
    trip_id: int
    user_id: int
    trip_member_id: int
    full_name: str
    email: EmailStr
    destination_id: int | None
    destination_name: str | None
    post_trip_rating: int
    accuracy_rating: int
    route_efficiency_rating: int
    budget_adherence_rating: int
    overall_experience_rating: int
    comments: str | None
    status: ReviewStatus
    created_at: datetime
    updated_at: datetime


class TripReviewSummaryResponse(BaseModel):
    trip_id: int
    review_count: int
    average_post_trip_rating: Decimal
    average_accuracy_rating: Decimal
    average_route_efficiency_rating: Decimal
    average_budget_adherence_rating: Decimal
    average_overall_experience_rating: Decimal
