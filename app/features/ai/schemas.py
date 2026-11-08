from datetime import datetime
from decimal import Decimal
from typing import Annotated, Any, Literal

from pydantic import BaseModel, ConfigDict, Field, PositiveInt, StringConstraints
from pydantic import model_validator

from app.features.planning.schemas import (
    PlanningPreviewResponse,
    PlanningState,
)
from app.features.recommendations.schemas import PlanningRecommendationItem

Money = Annotated[
    Decimal,
    Field(ge=0, max_digits=10, decimal_places=2),
]
TotalBudget = Annotated[
    Decimal,
    Field(gt=0, max_digits=10, decimal_places=2),
]
PreferenceText = Annotated[
    str,
    StringConstraints(strip_whitespace=True, min_length=1, max_length=100),
]
ModelRole = Literal["default", "fast", "quality"]
ChatRole = Literal["user", "assistant"]


class AIItineraryGenerateRequest(BaseModel):
    total_budget: TotalBudget
    traveler_count: int = Field(ge=1, le=100)
    day_count: int = Field(ge=1, le=30)
    destination_ids: list[PositiveInt] = Field(min_length=1, max_length=10)
    accommodation_ids: list[PositiveInt] = Field(default_factory=list, max_length=50)
    transportation_ids: list[PositiveInt] = Field(default_factory=list, max_length=50)
    meal_cost_per_day: Money = Decimal("0.00")
    miscellaneous_cost: Money = Decimal("0.00")
    interests: list[PreferenceText] = Field(default_factory=list, max_length=15)
    travel_style: str | None = Field(default=None, max_length=100)
    special_requirements: str | None = Field(default=None, max_length=1000)
    model_role: ModelRole = "quality"
    compare_models: bool = False
    allow_fallback: bool = True
    planning_state: PlanningState | None = None
    input_revision: int = Field(default=0, ge=0)

    @model_validator(mode="after")
    def validate_unique_ids(self) -> "AIItineraryGenerateRequest":
        _require_unique_ids("destination_ids", self.destination_ids)
        _require_unique_ids("accommodation_ids", self.accommodation_ids)
        _require_unique_ids("transportation_ids", self.transportation_ids)

        return self


class AIItineraryActivity(BaseModel):
    time: str = Field(min_length=1, max_length=20)
    title: str = Field(min_length=1, max_length=255)
    description: str = Field(min_length=1, max_length=1000)
    destination_id: int | None = None
    accommodation_id: int | None = None
    transportation_id: int | None = None
    estimated_cost: Money = Decimal("0.00")
    cost_source: Literal["ai_draft_estimate"] = "ai_draft_estimate"
    notes: str | None = Field(default=None, max_length=1000)


class AIItineraryDay(BaseModel):
    day: PositiveInt
    title: str = Field(min_length=1, max_length=255)
    summary: str = Field(min_length=1, max_length=1000)
    activities: list[AIItineraryActivity] = Field(min_length=1, max_length=20)


class AIItineraryOption(BaseModel):
    option_number: PositiveInt
    title: str = Field(min_length=1, max_length=255)
    summary: str = Field(min_length=1, max_length=1000)
    estimated_total_cost: Money
    cost_source: Literal["ai_draft_estimate"] = "ai_draft_estimate"
    is_over_budget: bool
    days: list[AIItineraryDay] = Field(min_length=1, max_length=30)
    quality_warnings: list[str] = Field(default_factory=list)


class AIModelRunResult(BaseModel):
    ai_generation_run_id: int
    model_role: str
    model_id: str
    status: str
    validation_status: str
    response_time_ms: int | None
    prompt_tokens: int | None
    completion_tokens: int | None
    total_tokens: int | None
    error_message: str | None
    options: list[AIItineraryOption] = Field(default_factory=list)


class AIItineraryGenerateResponse(BaseModel):
    options: list[AIItineraryOption]
    model_runs: list[AIModelRunResult]
    selected_generation_run_id: int | None = None
    planning_preview: PlanningPreviewResponse | None = None
    geo_analytics_context: dict[str, Any] | None = None


class AIChatMessage(BaseModel):
    role: ChatRole
    content: str = Field(min_length=1, max_length=2000)


class AIChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    history: list[AIChatMessage] = Field(default_factory=list, max_length=12)
    context: dict | None = None
    planning_state: PlanningState | None = None
    input_revision: int = Field(default=0, ge=0)
    model_role: ModelRole = "default"
    allow_fallback: bool = True
    use_rag: bool = True
    rag_limit: int = Field(default=6, ge=0, le=12)


class AIPlanningOriginUpdate(BaseModel):
    model_config = ConfigDict(extra="forbid")

    label: PreferenceText


class AIPlanningStateUpdates(BaseModel):
    """Allowlisted conversational changes; UI selections stay caller-owned."""

    model_config = ConfigDict(extra="forbid")

    origin: AIPlanningOriginUpdate | None = None
    destination_ids: list[PositiveInt] | None = Field(default=None, max_length=10)
    total_budget: TotalBudget | None = None
    budget_scope: Literal["whole_trip", "per_person"] | None = None
    traveler_count: int | None = Field(default=None, ge=1, le=100)
    day_count: int | None = Field(default=None, ge=1, le=30)
    night_count: int | None = Field(default=None, ge=0, le=30)
    return_to_origin: bool | None = None
    interests: list[PreferenceText] | None = Field(default=None, max_length=15)

    @model_validator(mode="after")
    def reject_null_non_clearable_fields(self) -> "AIPlanningStateUpdates":
        for field_name in ("destination_ids", "budget_scope", "interests"):
            if field_name in self.model_fields_set and getattr(self, field_name) is None:
                raise ValueError(f"{field_name} cannot be null; use an empty list to clear it.")
        if self.destination_ids is not None:
            _require_unique_ids("destination_ids", self.destination_ids)
        return self


class AIPlanningChatOutput(BaseModel):
    model_config = ConfigDict(extra="forbid")

    chat_response: str = Field(min_length=1, max_length=2000)
    state_updates: AIPlanningStateUpdates = Field(default_factory=AIPlanningStateUpdates)


class AIPlanningChatResult(BaseModel):
    input_revision: int
    state_updates: dict[str, Any] = Field(default_factory=dict)
    update_status: Literal[
        "applied", "no_changes", "needs_clarification", "invalid_output",
    ]
    preview: PlanningPreviewResponse
    recommendations: list[PlanningRecommendationItem] = Field(default_factory=list)
    recommendation_total_candidates: int = 0
    recommendation_shortfall_reason: str | None = None


class AIChatResponse(BaseModel):
    message: str = "ok"
    chat_response: str = Field(min_length=1)
    mode: str = "chat"
    parsed_preferences: dict = Field(default_factory=dict)
    results: list[dict] = Field(default_factory=list)
    retrieved_context: list[dict] = Field(default_factory=list)
    planning: AIPlanningChatResult | None = None
    model_role: str
    model_id: str
    ai_generation_run_id: int
    response_time_ms: int | None = None
    prompt_tokens: int | None = None
    completion_tokens: int | None = None
    total_tokens: int | None = None


class AIGenerationRunResponse(BaseModel):
    ai_generation_run_id: int
    user_id: int
    request_purpose: str
    model_role: str
    model_id: str
    prompt_version: str
    status: str
    validation_status: str
    response_time_ms: int | None
    prompt_tokens: int | None
    completion_tokens: int | None
    total_tokens: int | None
    error_message: str | None
    input_summary: dict | None
    output_summary: dict | None
    fallback_used: bool
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)


def _require_unique_ids(field_name: str, values: list[int]) -> None:
    if len(values) != len(set(values)):
        raise ValueError(f"{field_name} must not contain duplicate IDs")
