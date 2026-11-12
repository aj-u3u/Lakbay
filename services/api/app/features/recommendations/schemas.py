from datetime import datetime
from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.features.routes.schemas import RouteCoordinate, TravelMode


InteractionType = Literal["view", "save", "rate", "add_to_itinerary"]
PreferenceText = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=100),
]


class RecommendationRequest(BaseModel):
    preferred_categories: list[PreferenceText] = Field(
        default_factory=list,
        max_length=15,
    )
    preferred_vibes: list[PreferenceText] = Field(default_factory=list, max_length=15)
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
    estimated_cost: Decimal | None
    score: float
    matched_fields: list[str]
    reasons: list[str]


class RecommendationResponse(BaseModel):
    preference_signal_id: int
    total_candidates: int
    recommendations: list[RecommendationItem]


TopPlaceTravelBasis = Literal[
    "road_route",            # verified entrance, provider road route
    "approximate_location",  # provider road route to the attraction pin
    "straight_line_estimate",  # routing unavailable; Haversine at a fallback speed
    "commute_estimate",      # public transport; Haversine until commute legs exist
    "unknown",               # no start point
]
TopPlaceCostBasis = Literal["catalog_estimate", "not_listed"]


class TopPlacesRequest(BaseModel):
    interests: list[PreferenceText] = Field(default_factory=list, max_length=15)
    preferred_districts: list[PreferenceText] = Field(default_factory=list, max_length=10)
    origin: RouteCoordinate | None = None
    travel_mode: TravelMode = "driving"
    total_budget: Decimal | None = Field(default=None, gt=0, max_digits=10, decimal_places=2)
    budget_scope: Literal["whole_trip", "per_person"] = "whole_trip"
    traveler_count: int | None = Field(default=None, ge=1, le=100)
    adult_count: int | None = Field(default=None, ge=0, le=100)
    child_ages: list[int] = Field(default_factory=list, max_length=100)
    day_count: int | None = Field(default=None, ge=1, le=30)
    requires_kid_friendly: bool = False
    requires_wheelchair_accessible: bool = False
    requires_pet_friendly: bool = False
    requires_elderly_friendly: bool = False
    limit: int = Field(default=5, ge=1, le=10)

    @model_validator(mode="after")
    def validate_child_ages(self) -> "TopPlacesRequest":
        if any(age < 0 or age > 17 for age in self.child_ages):
            raise ValueError("child_ages must be between 0 and 17 years.")
        return self

    @property
    def party_size(self) -> int:
        return max(
            self.traveler_count or 0,
            (self.adult_count or 0) + len(self.child_ages),
            1,
        )


class TopPlaceFactor(BaseModel):
    value: float = Field(description="Normalized factor score from 0 to 1.")
    weight: float
    points: float = Field(description="Contribution to the 0-100 score: 100 x weight x value.")


class TopPlaceBreakdown(BaseModel):
    interest: TopPlaceFactor
    travel: TopPlaceFactor
    budget: TopPlaceFactor
    group_fit: TopPlaceFactor
    popularity: TopPlaceFactor


class TopPlaceItem(BaseModel):
    rank: int
    destination_id: int
    name: str
    district: str | None
    category: str | None
    image_url: str | None
    estimated_cost: Decimal | None
    cost_basis: TopPlaceCostBasis
    score: float
    breakdown: TopPlaceBreakdown
    matched_interests: list[str]
    matched_fields: list[str]
    reasons: list[str]
    route_verified: bool
    travel_mode: TravelMode
    travel_basis: TopPlaceTravelBasis
    route_provider: str | None
    travel_minutes: int | None
    travel_distance_km: Decimal | None


class TopPlacesSkipped(BaseModel):
    no_interest_match: int = 0
    outside_preferred_districts: int = 0
    missing_required_accessibility: int = 0
    over_budget: int = 0
    needs_boat_or_ferry: int = 0
    no_route: int = 0
    too_far: int = 0


class TopPlacesResponse(BaseModel):
    method: Literal["simple_additive_weighting"] = "simple_additive_weighting"
    weights: dict[str, float]
    max_travel_minutes: int
    preference_signal_id: int | None
    total_candidates: int
    verified_count: int
    items: list[TopPlaceItem]
    skipped: TopPlacesSkipped
    shortfall_reason: str | None
    warnings: list[str]


class PlanningRecommendationItem(RecommendationItem):
    """A Top 5 place in the planning chat; `score` is the 0-100 weighted score."""

    route_provider: str | None = None
    travel_mode: TravelMode
    route_distance_km: Decimal | None = None
    route_duration_minutes: int | None = None
    route_verified: bool = False
    travel_basis: TopPlaceTravelBasis = "unknown"
    breakdown: TopPlaceBreakdown | None = None


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
