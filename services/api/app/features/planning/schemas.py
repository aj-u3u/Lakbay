from decimal import Decimal
from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, PositiveInt, StringConstraints
from pydantic import field_validator, model_validator

from app.features.routes.schemas import RouteSummaryResponse, TravelMode


Text = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]
OptionId = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=120)]
Money = Annotated[Decimal, Field(ge=0, max_digits=10, decimal_places=2)]
Budget = Annotated[Decimal, Field(gt=0, max_digits=10, decimal_places=2)]


class PlanningInput(BaseModel):
    model_config = ConfigDict(extra="forbid")


class PlanningOrigin(PlanningInput):
    label: Text | None = None
    lat: float | None = Field(default=None, ge=-90, le=90)
    lng: float | None = Field(default=None, ge=-180, le=180)

    @model_validator(mode="after")
    def require_coordinate_pair(self):
        if (self.lat is None) != (self.lng is None):
            raise ValueError("Origin latitude and longitude must be supplied together.")
        return self


class PlanningCostAllowance(PlanningInput):
    category: Literal["transportation", "food", "other", "destination", "activity", "accommodation"]
    amount: Money
    destination_id: PositiveInt | None = None
    option_id: OptionId | None = None
    includes_activity_option_ids: list[OptionId] = Field(default_factory=list, max_length=50)

    @model_validator(mode="after")
    def validate_scope(self):
        if self.category == "destination":
            if self.destination_id is None or self.option_id is not None:
                raise ValueError("Destination allowances require a destination ID only.")
        elif self.category == "activity":
            if self.option_id is None or self.destination_id is not None:
                raise ValueError("Activity allowances require an activity option ID only.")
        elif self.destination_id is not None or self.option_id is not None:
            raise ValueError("This allowance covers its category for the whole trip.")
        if self.includes_activity_option_ids and self.category not in {"destination", "food"}:
            raise ValueError("Only destination or food allowances can include selected activities.")
        if len(self.includes_activity_option_ids) != len(set(self.includes_activity_option_ids)):
            raise ValueError("Included activity identifiers must be unique.")
        return self


class PlanningTransportPricing(PlanningInput):
    option_id: OptionId
    price_basis: Literal["per_person", "per_vehicle", "per_group"]
    charge_count: int = Field(default=1, ge=1, le=20)
    vehicle_count: int = Field(default=1, ge=1, le=100)
    journey_scope: Literal["listed_leg", "round_trip"] = "listed_leg"

    @model_validator(mode="after")
    def validate_vehicles(self):
        if self.price_basis != "per_vehicle" and self.vehicle_count != 1:
            raise ValueError("Vehicle count applies only to a per-vehicle price basis.")
        return self


class PlanningAccommodationPricing(PlanningInput):
    accommodation_id: PositiveInt
    price_basis: Literal["per_room_per_night", "per_room_per_stay"]
    room_count: int = Field(ge=1, le=100)
    night_count: int = Field(ge=1, le=30)


class PlanningChildPriceBand(PlanningInput):
    min_age: int = Field(ge=0, le=17)
    max_age: int = Field(ge=0, le=17)
    rate: Literal["free", "half", "full"]

    @model_validator(mode="after")
    def validate_range(self):
        if self.min_age > self.max_age:
            raise ValueError("min_age cannot exceed max_age.")
        return self


class PlanningAgePricingRule(PlanningInput):
    category: Literal["destination", "activity", "transportation"]
    reference_id: OptionId
    adult_unit_amount: Money | None = None
    child_bands: list[PlanningChildPriceBand] = Field(min_length=1, max_length=18)

    @model_validator(mode="after")
    def validate_rule(self):
        prefix = f"{self.category}:"
        if not self.reference_id.startswith(prefix):
            raise ValueError("reference_id does not match the pricing category.")
        if self.category == "transportation" and self.adult_unit_amount is not None:
            raise ValueError("Transportation adult fare comes from the selected catalog rate.")
        if self.category != "transportation" and self.adult_unit_amount is None:
            raise ValueError("Destination and activity rules require an adult unit amount.")
        covered = set()
        for band in self.child_bands:
            ages = set(range(band.min_age, band.max_age + 1))
            if covered.intersection(ages):
                raise ValueError("Child age bands cannot overlap.")
            covered.update(ages)
        return self


class PlanningRoutePreferences(PlanningInput):
    optimize_order: bool = False
    road_access_confirmed: bool = False


class PlanningFuelAssumptions(PlanningInput):
    kilometers_per_liter: Annotated[Decimal, Field(gt=0, le=100, max_digits=5, decimal_places=2)]
    price_per_liter: Budget
    vehicle_count: int = Field(default=1, ge=1, le=100)
    # Whole-trip allocations for all selected vehicles, never automatic zero fees.
    parking_amount: Money | None = None
    toll_amount: Money | None = None
    vehicle_ferry_amount: Money | None = None
    other_vehicle_amount: Money | None = None


class PlanningState(PlanningInput):
    origin: PlanningOrigin | None = None
    destination_ids: list[PositiveInt] = Field(default_factory=list, max_length=10)
    total_budget: Budget | None = None
    budget_scope: Literal["whole_trip", "per_person"] = "whole_trip"
    traveler_count: int | None = Field(default=None, ge=1, le=100)
    adult_count: int | None = Field(default=None, ge=0, le=100)
    child_ages: list[int] = Field(default_factory=list, max_length=100)
    day_count: int | None = Field(default=None, ge=1, le=30)
    night_count: int | None = Field(default=None, ge=0, le=30)
    return_to_origin: bool | None = None
    interests: list[Text] = Field(default_factory=list, max_length=15)
    reserve_amount: Money = Decimal("0.00")
    selected_transport_option_ids: list[OptionId] = Field(default_factory=list, max_length=50)
    selected_activity_option_ids: list[OptionId] = Field(default_factory=list, max_length=50)
    selected_accommodation_ids: list[PositiveInt] = Field(default_factory=list, max_length=10)
    cost_allowances: list[PlanningCostAllowance] = Field(default_factory=list, max_length=100)
    transport_pricing: list[PlanningTransportPricing] = Field(default_factory=list, max_length=50)
    accommodation_pricing: list[PlanningAccommodationPricing] = Field(default_factory=list, max_length=10)
    age_pricing_rules: list[PlanningAgePricingRule] = Field(default_factory=list, max_length=100)
    route_preferences: PlanningRoutePreferences | None = None
    fuel_assumptions: PlanningFuelAssumptions | None = None

    @field_validator(
        "destination_ids", "selected_transport_option_ids", "selected_activity_option_ids",
        "selected_accommodation_ids",
    )
    @classmethod
    def require_unique_ids(cls, values):
        if len(values) != len(set(values)):
            raise ValueError("Option and destination identifiers must be unique.")
        return values

    @field_validator("interests")
    @classmethod
    def normalize_interests(cls, values):
        seen = set()
        result = []
        for value in values:
            if value.casefold() not in seen:
                seen.add(value.casefold())
                result.append(value)
        return result

    @model_validator(mode="after")
    def validate_nights(self):
        if any(age < 0 or age > 17 for age in self.child_ages):
            raise ValueError("child_ages must be between 0 and 17 years.")
        if self.child_ages and self.adult_count is None:
            raise ValueError("adult_count is required when child_ages are supplied.")
        if self.adult_count is not None and self.traveler_count is not None and (
            self.adult_count + len(self.child_ages) != self.traveler_count
        ):
            raise ValueError("adult_count plus child_ages must equal traveler_count.")
        if self.age_pricing_rules and not self.child_ages:
            raise ValueError("age_pricing_rules require at least one child age.")
        if (
            self.day_count is not None
            and self.night_count is not None
            and self.night_count > self.day_count
        ):
            raise ValueError("Night count cannot exceed day count.")
        allowance_keys = [
            (item.category, item.destination_id, item.option_id) for item in self.cost_allowances
        ]
        for values in (
            allowance_keys,
            [item.option_id for item in self.transport_pricing],
            [item.accommodation_id for item in self.accommodation_pricing],
            [(item.category, item.reference_id) for item in self.age_pricing_rules],
        ):
            if len(values) != len(set(values)):
                raise ValueError("Allowance scopes and pricing assumption identifiers must be unique.")
        return self


class PlanningPreviewRequest(PlanningInput):
    input_revision: int = Field(default=0, ge=0)
    state: PlanningState = Field(default_factory=PlanningState)


class PlanningFeedbackRequest(PlanningPreviewRequest):
    traveling_with_children: bool | None = None


class PlanningDestination(BaseModel):
    destination_id: int
    name: str
    district: str | None
    location: str | None
    activities_description: str | None
    catalog_estimated_cost: Decimal | None
    entrance_fee_description: str | None


class PlanningTransportOption(BaseModel):
    option_id: str
    kind: Literal["personal_vehicle", "catalog_transport", "walking"]
    label: str
    destination_id: int | None = None
    transportation_id: int | None = None
    vehicle_type: str
    transport_mode: str
    route_from: str | None = None
    route_to: str | None = None
    listed_price: Decimal | None = None
    price_basis: Literal["per_person", "per_vehicle", "per_group"] | None = None
    duration_minutes: int | None = None
    route_match: Literal[
        "origin_to_destination", "destination_to_origin", "unconfirmed",
    ] = "unconfirmed"
    journey_complete: Literal[False] = False
    missing_information: list[str]
    selected: bool = False


class PlanningActivityOption(BaseModel):
    option_id: str
    destination_id: int
    label: str
    charge_type: Literal["unknown"] = "unknown"
    price: None = None
    price_basis: Literal["per_room_per_night", "per_room_per_stay"] | None = None
    duration_minutes: None = None
    source: Literal["destination.activities"] = "destination.activities"
    missing_information: list[str] = Field(default_factory=lambda: ["activity_fee", "duration"])
    selected: bool = False


class PlanningAccommodationOption(BaseModel):
    accommodation_id: int
    destination_id: int
    name: str
    room_type: str
    capacity: int
    listed_price: Decimal
    price_basis: None = None
    selected: bool = False


class PlanningSelectionProblem(BaseModel):
    field: str
    option_id: str
    code: Literal[
        "destination_unavailable", "transport_option_unavailable", "activity_option_unavailable",
        "accommodation_option_unavailable", "cost_allowance_invalid", "pricing_assumption_invalid",
    ]
    message: str


class PlanningNextAction(BaseModel):
    code: Literal[
        "complete_details", "choose_transport", "choose_activities", "review_selections",
        "complete_costs", "reduce_costs",
        "choose_accommodation",
        "review_route", "complete_fuel_details",
    ]
    fields: list[str] = Field(default_factory=list)
    label: str


class PlanningCostLine(BaseModel):
    category: Literal["transportation", "food", "other", "destination", "activity", "accommodation"]
    reference_id: str
    label: str
    amount: Decimal
    source: Literal[
        "traveler_allowance", "catalog_price_with_assumed_basis", "included_in_allowance",
        "route_with_traveler_assumptions", "catalog_price_with_verified_basis",
        "traveler_age_pricing_rule",
    ]
    unit_amount: Decimal | None = None
    quantity: int | None = None
    price_basis: str | None = None
    included_in: str | None = None


class PlanningMissingCost(BaseModel):
    code: str
    reference_id: str
    message: str


class PlanningBudget(BaseModel):
    completeness: Literal["complete", "partial"]
    fit: Literal["fits_estimate", "over_budget", "undetermined"]
    priced_subtotal: Decimal
    total_estimate: Decimal | None
    reserve_amount: Decimal
    suggested_trip_funds: Decimal | None
    remaining_budget: Decimal | None
    over_budget_amount: Decimal | None
    minimum_over_budget_amount: Decimal
    category_totals: dict[str, Decimal]
    lines: list[PlanningCostLine]
    missing_costs: list[PlanningMissingCost]
    assumptions: list[str]


class PlanningRoutePreview(BaseModel):
    status: Literal["not_requested", "needs_details", "needs_review", "calculated"]
    travel_mode: TravelMode | None = None
    order_strategy: Literal["preserve_order", "optimize"] = "preserve_order"
    summary: RouteSummaryResponse | None = None
    missing_information: list[str] = Field(default_factory=list)
    warnings: list[str] = Field(default_factory=list)


class PlanningFuelEstimate(BaseModel):
    status: Literal["not_requested", "needs_details", "unavailable", "calculated"]
    distance_km: Decimal | None = None
    liters: Decimal | None = None
    amount: Decimal | None = None
    vehicle_count: int | None = None
    included_in: str | None = None
    assumptions: list[str] = Field(default_factory=list)
    missing_information: list[str] = Field(default_factory=list)


class PlanningPreviewResponse(BaseModel):
    input_revision: int
    status: Literal["needs_details", "needs_selection_review", "choices_available"]
    state: PlanningState
    whole_trip_budget: Decimal | None
    destinations: list[PlanningDestination]
    transport_options: list[PlanningTransportOption]
    activity_options: list[PlanningActivityOption]
    accommodation_options: list[PlanningAccommodationOption]
    budget: PlanningBudget
    route: PlanningRoutePreview
    fuel: PlanningFuelEstimate
    missing_inputs: list[str]
    selection_problems: list[PlanningSelectionProblem]
    next_actions: list[PlanningNextAction]


class PlanningFeedbackFinding(BaseModel):
    code: Literal[
        "selection_invalid", "trip_details_missing", "catalog_cost_unknown",
        "budget_incomplete", "over_budget", "arrival_unverified",
        "route_not_requested", "route_needs_review", "route_estimated",
        "route_order_not_compared", "travel_time_high", "walking_distance_high",
        "activity_load_high", "child_suitability_review",
    ]
    category: Literal["data", "budget", "route", "pacing", "activities", "suitability"]
    severity: Literal["required", "review", "info"]
    message: str
    fields: list[str] = Field(default_factory=list)
    destination_ids: list[int] = Field(default_factory=list)


class PlanningFeedbackResponse(BaseModel):
    input_revision: int
    traveling_with_children: bool | None
    status: Literal["needs_details", "needs_review", "no_flagged_issues"]
    findings: list[PlanningFeedbackFinding]
    preview: PlanningPreviewResponse
