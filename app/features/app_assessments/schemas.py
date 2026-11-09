from datetime import datetime
from typing import Annotated

from pydantic import BaseModel, Field, field_validator, model_validator


Rating = Annotated[int, Field(ge=1, le=5)]


class AppAssessmentCreate(BaseModel):
    functional_suitability_rating: Rating | None
    information_accuracy_rating: Rating | None
    performance_rating: Rating | None
    interaction_rating: Rating | None
    reliability_rating: Rating | None
    sharing_clarity_rating: Rating | None
    comment: str | None = Field(default=None, max_length=2000)
    app_version: str | None = Field(default=None, max_length=32)

    @field_validator("comment", "app_version")
    @classmethod
    def strip_optional_text(cls, value: str | None) -> str | None:
        if value is None:
            return None
        return value.strip() or None

    @model_validator(mode="after")
    def require_one_rating(self) -> "AppAssessmentCreate":
        if all(getattr(self, field) is None for field in RATING_NAMES):
            raise ValueError("At least one assessment rating is required.")
        return self


RATING_NAMES = (
    "functional_suitability_rating",
    "information_accuracy_rating",
    "performance_rating",
    "interaction_rating",
    "reliability_rating",
    "sharing_clarity_rating",
)


class AppAssessmentResponse(AppAssessmentCreate):
    app_assessment_id: int
    trip_id: int
    question_version: int
    submitted_at: datetime


class MyAppAssessmentResponse(BaseModel):
    assessment: AppAssessmentResponse | None


class AdminAppAssessmentResponse(BaseModel):
    app_assessment_id: int
    question_version: int
    functional_suitability_rating: int | None
    information_accuracy_rating: int | None
    performance_rating: int | None
    interaction_rating: int | None
    reliability_rating: int | None
    sharing_clarity_rating: int | None
    comment: str | None
    app_version: str | None
    submitted_at: datetime


class AdminAppAssessmentListResponse(BaseModel):
    total: int
    items: list[AdminAppAssessmentResponse]


class QuestionMetrics(BaseModel):
    answered: int
    not_applicable: int
    average: float | None
    ratings: dict[int, int]


class AdminAppAssessmentSummaryResponse(BaseModel):
    window_start: datetime
    generated_at: datetime
    response_count: int
    participant_count: int
    questions: dict[str, QuestionMetrics]
