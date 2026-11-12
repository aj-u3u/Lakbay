from decimal import Decimal
from typing import Annotated

from pydantic import BaseModel, Field, PositiveInt, model_validator

Money = Annotated[
    Decimal,
    Field(ge=0, max_digits=10, decimal_places=2),
]
TotalBudget = Annotated[
    Decimal,
    Field(gt=0, max_digits=10, decimal_places=2),
]


class BudgetEstimateRequest(BaseModel):
    total_budget: TotalBudget
    traveler_count: int = Field(ge=1, le=100)
    day_count: int = Field(ge=1, le=365)
    destination_ids: list[PositiveInt] = Field(min_length=1, max_length=20)
    accommodation_ids: list[PositiveInt] = Field(default_factory=list, max_length=50)
    transportation_ids: list[PositiveInt] = Field(default_factory=list, max_length=50)
    meal_cost_per_day: Money = Decimal("0.00")
    miscellaneous_cost: Money = Decimal("0.00")

    @model_validator(mode="after")
    def validate_unique_ids(self) -> "BudgetEstimateRequest":
        _require_unique_ids("destination_ids", self.destination_ids)
        _require_unique_ids("accommodation_ids", self.accommodation_ids)
        _require_unique_ids("transportation_ids", self.transportation_ids)

        return self


class BudgetBreakdown(BaseModel):
    destinations: Decimal
    accommodations: Decimal
    transportation: Decimal
    meals: Decimal
    miscellaneous: Decimal


class BudgetEstimateResponse(BaseModel):
    total_budget: Decimal
    total_estimated_cost: Decimal
    remaining_budget: Decimal
    over_budget_amount: Decimal
    is_over_budget: bool
    percent_used: Decimal
    traveler_count: int
    day_count: int
    breakdown: BudgetBreakdown


def _require_unique_ids(field_name: str, values: list[int]) -> None:
    if len(values) != len(set(values)):
        raise ValueError(f"{field_name} must not contain duplicate IDs")
