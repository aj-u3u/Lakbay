from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator


InteractionType = Literal["view", "save", "rate", "add_to_itinerary"]
PreferenceText = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=100),
]


class RecommendationRequest(BaseModel):
    preferred_categories: list[PreferenceText] = Field(
        default_factory=list,
        max_length=10,
    )
    preferred_vibes: list[PreferenceText] = Field(default_factory=list, max_length=10)
    preferred_activities: list[PreferenceText] = Field(
        default_factory=list,
        max_length=15,
    )
    preferred_districts: list[PreferenceText] = Field(
        default_factory=list,
        max_length=10,
    )
    budget_class: str | None = Field(default=None, max_length=50)
    difficulty_level: str | None = Field(default=None, max_length=50)
    stay_duration_type: str | None = Field(default=None, max_length=50)
    max_estimated_cost: Decimal | None = Field(
        default=None,
        ge=0,
        max_digits=10,
        decimal_places=2,
    )
    requires_kid_friendly: bool = False
    requires_wheelchair_accessible: bool = False
    requires_pet_friendly: bool = False
    requires_elderly_friendly: bool = False
    family_friendly: bool | None = None
    couple_friendly: bool | None = None
    group_friendly: bool | None = None
    limit: int = Field(default=5, ge=1, le=20)


class PreferenceSignalResponse(BaseModel):
    preference_signal_id: int
    user_id: int
    preferred_categories: list[str]
    preferred_vibes: list[str]
    preferred_activities: list[str]
    preferred_districts: list[str]
    budget_class: str | None
    difficulty_level: str | None
    stay_duration_type: str | None
    max_estimated_cost: Decimal | None
    requires_kid_friendly: bool
    requires_wheelchair_accessible: bool
    requires_pet_friendly: bool
    requires_elderly_friendly: bool
    family_friendly: bool | None
    couple_friendly: bool | None
    group_friendly: bool | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class RecommendationItem(BaseModel):
    destination_id: int
    name: str
    district: str | None
    category: str | None
    estimated_cost: Decimal
    score: float
    matched_fields: list[str]
    reasons: list[str]


class RecommendationResponse(BaseModel):
    preference_signal_id: int
    total_candidates: int
    recommendations: list[RecommendationItem]


class DestinationInteractionCreate(BaseModel):
    interaction_type: InteractionType
    rating: int | None = Field(default=None, ge=1, le=5)
    notes: str | None = Field(default=None, max_length=1000)

    @model_validator(mode="after")
    def validate_rating_for_type(self) -> "DestinationInteractionCreate":
        if self.interaction_type == "rate" and self.rating is None:
            raise ValueError("rating is required for rate interactions")

        if self.interaction_type != "rate" and self.rating is not None:
            raise ValueError("rating is only allowed for rate interactions")

        return self


class DestinationInteractionResponse(BaseModel):
    interaction_id: int
    user_id: int
    destination_id: int
    interaction_type: str
    rating: int | None
    notes: str | None
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)


class DestinationPopularityResponse(BaseModel):
    destination_id: int
    view_count: int
    save_count: int
    rating_count: int
    rating_sum: int
    average_rating: Decimal
    add_to_itinerary_count: int
    popularity_score: Decimal
    created_at: datetime | None
    updated_at: datetime | None

    model_config = ConfigDict(from_attributes=True)
