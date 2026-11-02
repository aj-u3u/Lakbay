"""Pure, conservative cost projection from current catalog choices and assumptions."""

from collections import Counter
from decimal import Decimal, ROUND_HALF_UP

from app.features.destinations.models import Destination
from app.features.planning.schemas import (
    PlanningAccommodationOption,
    PlanningActivityOption,
    PlanningBudget,
    PlanningCostLine,
    PlanningFuelEstimate,
    PlanningMissingCost,
    PlanningSelectionProblem,
    PlanningState,
    PlanningTransportOption,
)


ZERO = Decimal("0.00")
CATEGORIES = ("transportation", "food", "other", "destination", "activity", "accommodation")


def build_budget(
    state: PlanningState,
    destinations: list[Destination],
    transport_options: list[PlanningTransportOption],
    activity_options: list[PlanningActivityOption],
    accommodation_options: list[PlanningAccommodationOption],
    selection_problems: list[PlanningSelectionProblem],
    whole_trip_budget: Decimal | None,
    fuel: PlanningFuelEstimate | None = None,
) -> tuple[PlanningBudget, list[PlanningSelectionProblem]]:
    projection = _Projection(state, selection_problems)
    destinations_by_id = {item.destination_id: item for item in destinations}
    transports = {item.option_id: item for item in transport_options}
    activities = {item.option_id: item for item in activity_options}
    accommodations = {item.accommodation_id: item for item in accommodation_options}

    for field in ("traveler_count", "day_count", "night_count", "return_to_origin"):
        if getattr(state, field) is None:
            projection.missing("trip_details_missing", field, f"Provide {field} before completing the estimate.")
    if not destinations_by_id:
        projection.missing("destination_selection_missing", "destination_ids", "Choose an active catalog destination.")
    for field, selected, available in (
        ("destination_ids", state.destination_ids, destinations_by_id),
        ("selected_transport_option_ids", state.selected_transport_option_ids, transports),
        ("selected_activity_option_ids", state.selected_activity_option_ids, activities),
        ("selected_accommodation_ids", state.selected_accommodation_ids, accommodations),
    ):
        if any(item not in available for item in selected):
            projection.missing("selection_invalid", field, "Review choices that are no longer available for these destinations.")

    allowances = _allowances(projection, destinations_by_id, activities)
    covered_activities = {
        option_id: "food" if category == "food" else f"destination:{destination_id}"
        for (category, destination_id, _), allowance in allowances.items()
        if category in {"destination", "food"}
        for option_id in allowance.includes_activity_option_ids
    }
    age_rules = _age_rules(
        projection, destinations_by_id, transports, activities, allowances, covered_activities,
    )
    for destination in destinations:
        reference = f"destination:{destination.destination_id}"
        allowance = allowances.get(("destination", destination.destination_id, None))
        rule = age_rules.get(("destination", reference))
        if rule is not None:
            _age_priced_cost(projection, rule, "destination", reference, destination.name,
                             rule.adult_unit_amount, charge_count=1,
                             adult_source="traveler_age_pricing_rule")
        elif allowance is None:
            projection.missing(
                "destination_allowance_missing", reference,
                "Provide a labeled entrance/destination allowance; the catalog estimate has an unknown basis and inclusions.",
            )
        else:
            projection.allowance(allowance, reference, f"{destination.name}: entrance/destination allowance")
    for option_id in state.selected_activity_option_ids:
        option = activities.get(option_id)
        if option is None:
            continue
        allowance = allowances.get(("activity", None, option_id))
        rule = age_rules.get(("activity", option_id))
        if option_id in covered_activities:
            if allowance is not None:
                projection.problem(
                    "cost_allowances", option_id, "cost_allowance_invalid",
                    "This activity is already included in a destination or food allowance; remove the separate activity allowance.",
                )
                projection.missing("allowance_conflict", option_id, "Resolve the duplicate activity inclusion before completing the estimate.")
            projection.line(
                "activity", option_id, option.label, ZERO, "included_in_allowance",
                included_in=covered_activities[option_id],
            )
        elif rule is not None:
            _age_priced_cost(projection, rule, "activity", option_id, option.label,
                             rule.adult_unit_amount, charge_count=1,
                             adult_source="traveler_age_pricing_rule")
        elif allowance is None:
            projection.missing("activity_allowance_missing", option_id, f"Provide a labeled allowance for {option.label}; its fee is unknown.")
        else:
            projection.allowance(allowance, option_id, f"{option.label}: activity allowance")

    _transport_costs(projection, transports, allowances, fuel, age_rules)
    _accommodation_costs(projection, accommodations, allowances)
    for category in ("food", "other"):
        allowance = allowances.get((category, None, None))
        if allowance is not None:
            projection.allowance(allowance, category, f"Whole-trip {category} allowance")
        elif category == "food":
            projection.missing("food_allowance_missing", "food", "Provide a whole-trip food allowance, including an explicit zero if appropriate.")
    if projection.problems:
        projection.missing("selection_invalid", "selection_problems", "Resolve invalid selections, allowances, or pricing assumptions.")
    return projection.result(whole_trip_budget), projection.problems[len(selection_problems):]


class _Projection:
    def __init__(self, state: PlanningState, problems: list[PlanningSelectionProblem]):
        self.state = state
        self.problems = list(problems)
        self.lines: list[PlanningCostLine] = []
        self.missing_costs: list[PlanningMissingCost] = []
        self.assumptions: list[str] = []

    def missing(self, code: str, reference: str, message: str) -> None:
        if not any(item.code == code and item.reference_id == reference for item in self.missing_costs):
            self.missing_costs.append(PlanningMissingCost(code=code, reference_id=reference, message=message))

    def problem(self, field: str, option_id: str, code: str, message: str) -> None:
        if not any(item.field == field and item.option_id == option_id and item.code == code for item in self.problems):
            self.problems.append(PlanningSelectionProblem(field=field, option_id=option_id, code=code, message=message))

    def line(self, category, reference, label, amount, source, **details) -> None:
        self.lines.append(PlanningCostLine(
            category=category, reference_id=reference, label=label,
            amount=amount.quantize(Decimal("0.01")), source=source, **details,
        ))

    def allowance(self, allowance, reference, label) -> None:
        self.line(
            allowance.category, reference, label, allowance.amount, "traveler_allowance",
            unit_amount=allowance.amount, quantity=1, price_basis="whole_trip_allowance",
        )
        self.assumptions.append(f"{label} is a traveler estimate, including any explicitly allowed zero; it is not a verified catalog fee.")

    def result(self, budget: Decimal | None) -> PlanningBudget:
        totals = {category: ZERO for category in CATEGORIES}
        for line in self.lines:
            totals[line.category] += line.amount
        subtotal = sum(totals.values(), ZERO)
        reserve = self.state.reserve_amount.quantize(Decimal("0.01"))
        minimum_overage = max(subtotal + reserve - budget, ZERO) if budget is not None else ZERO
        complete = not self.missing_costs
        suggested = subtotal + reserve if complete else None
        fit = (
            "over_budget" if budget is not None and minimum_overage > ZERO
            else "fits_estimate" if complete and budget is not None
            else "undetermined"
        )
        return PlanningBudget(
            completeness="complete" if complete else "partial", fit=fit,
            priced_subtotal=subtotal, total_estimate=subtotal if complete else None,
            reserve_amount=reserve, suggested_trip_funds=suggested,
            remaining_budget=max(budget - suggested, ZERO) if complete and budget is not None else None,
            over_budget_amount=minimum_overage if complete and budget is not None else None,
            minimum_over_budget_amount=minimum_overage, category_totals=totals,
            lines=self.lines, missing_costs=self.missing_costs, assumptions=self.assumptions,
        )


def _allowances(projection, destinations, activities):
    state = projection.state
    valid = {}
    for allowance in state.cost_allowances:
        reference = allowance.option_id or (
            f"destination:{allowance.destination_id}" if allowance.destination_id is not None
            else f"allowance:{allowance.category}"
        )
        invalid = None
        if allowance.category == "destination":
            if allowance.destination_id not in destinations or allowance.destination_id not in state.destination_ids:
                invalid = "This destination allowance no longer refers to a selected active destination."
            elif any(
                option_id not in state.selected_activity_option_ids
                or option_id not in activities
                or activities[option_id].destination_id != allowance.destination_id
                for option_id in allowance.includes_activity_option_ids
            ):
                invalid = "Included activities must be available, selected, and belong to this destination."
        elif allowance.category == "activity":
            if allowance.option_id not in state.selected_activity_option_ids or allowance.option_id not in activities:
                invalid = "This activity allowance no longer refers to a selected available activity."
        elif allowance.category == "food" and any(
            option_id not in state.selected_activity_option_ids or option_id not in activities
            for option_id in allowance.includes_activity_option_ids
        ):
            invalid = "Food inclusions must reference selected available activities."
        elif allowance.category == "accommodation" and state.night_count == 0 and allowance.amount > ZERO:
            invalid = "A trip with zero nights cannot include an overnight accommodation allowance."
        if invalid:
            projection.problem("cost_allowances", reference, "cost_allowance_invalid", invalid)
            continue
        valid[(allowance.category, allowance.destination_id, allowance.option_id)] = allowance
    food = valid.get(("food", None, None))
    destination_inclusions = {
        option_id
        for (category, _, _), allowance in valid.items()
        if category == "destination"
        for option_id in allowance.includes_activity_option_ids
    }
    if food is not None and destination_inclusions.intersection(food.includes_activity_option_ids):
        valid.pop(("food", None, None))
        projection.problem(
            "cost_allowances", "food", "cost_allowance_invalid",
            "Food and destination allowances both include the same activity; remove the duplicate food inclusion.",
        )
    return valid


def _age_rules(projection, destinations, transports, activities, allowances, covered_activities):
    state = projection.state
    valid = {}
    for rule in state.age_pricing_rules:
        reference = rule.reference_id
        conflict = False
        if rule.category == "destination":
            destination_id = next(
                (item for item in state.destination_ids if reference == f"destination:{item}"), None
            )
            conflict = destination_id is not None and (
                "destination", destination_id, None
            ) in allowances
            available = destination_id in destinations
        elif rule.category == "activity":
            available = reference in activities and reference in state.selected_activity_option_ids
            conflict = (
                ("activity", None, reference) in allowances or reference in covered_activities
            )
        else:
            option = transports.get(reference)
            fare = next(
                (item for item in state.transport_pricing if item.option_id == reference), None
            )
            available = (
                reference in state.selected_transport_option_ids
                and option is not None and option.kind == "catalog_transport"
                and fare is not None and fare.price_basis == "per_person"
            )
            conflict = ("transportation", None, None) in allowances
        if not available or conflict:
            projection.problem(
                "age_pricing_rules", reference, "pricing_assumption_invalid",
                "Age pricing must reference a selected available item and cannot overlap a whole-trip allowance.",
            )
            continue
        valid[(rule.category, reference)] = rule
    return valid


def _age_priced_cost(
    projection, rule, category, reference, label, adult_unit_amount,
    *, charge_count, adult_source,
):
    state = projection.state
    adult_count = state.adult_count or 0
    if adult_count:
        quantity = adult_count * charge_count
        projection.line(
            category, reference, f"{label}: adults", adult_unit_amount * quantity,
            adult_source, unit_amount=adult_unit_amount, quantity=quantity,
            price_basis="per_person",
        )
    if rule is None:
        projection.missing(
            "child_price_rule_missing", reference,
            "Provide explicit child age-band pricing or a whole-trip allowance; children are not assumed free or full price.",
        )
        return
    for age, count in sorted(Counter(state.child_ages).items()):
        band = next(
            (item for item in rule.child_bands if item.min_age <= age <= item.max_age), None
        )
        if band is None:
            projection.missing(
                "child_price_band_missing", f"{reference}:age:{age}",
                f"Provide an explicit price rule for children age {age} at {label}.",
            )
            continue
        factor = {"free": Decimal("0"), "half": Decimal("0.5"), "full": Decimal("1")}[band.rate]
        unit = (adult_unit_amount * factor).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)
        quantity = count * charge_count
        projection.line(
            category, f"{reference}:child_age:{age}",
            f"{label}: children age {age} ({band.rate})", unit * quantity,
            "traveler_age_pricing_rule", unit_amount=unit, quantity=quantity,
            price_basis="per_person",
        )
    projection.assumptions.append(
        f"{reference}: child age-band prices are traveler-supplied rules, not verified catalog child fees."
    )


def _transport_costs(projection, options, allowances, fuel, age_rules):
    state = projection.state
    selected = [options[item] for item in state.selected_transport_option_ids if item in options]
    assumptions = {}
    for assumption in state.transport_pricing:
        option = options.get(assumption.option_id)
        if (
            assumption.option_id not in state.selected_transport_option_ids
            or option is None or option.kind != "catalog_transport" or option.listed_price is None
        ):
            projection.problem(
                "transport_pricing", assumption.option_id, "pricing_assumption_invalid",
                "Fare assumptions must reference a selected available catalog transportation option.",
            )
            continue
        if option.price_basis is not None and assumption.price_basis != option.price_basis:
            projection.problem(
                "transport_pricing", assumption.option_id, "pricing_assumption_invalid",
                "The fare basis must match the verified catalog charging unit.",
            )
            continue
        if (
            state.return_to_origin is False
            and option.route_match == "destination_to_origin"
            and assumption.journey_scope == "listed_leg"
        ):
            projection.problem(
                "transport_pricing", assumption.option_id, "pricing_assumption_invalid",
                "A listed return-only fare does not cover this outbound-only trip; choose an outbound segment or explicitly declare estimated package coverage.",
            )
            continue
        assumptions[assumption.option_id] = assumption
    if len(state.destination_ids) == 1:
        exact_legs = [
            option for option in selected
            if option.option_id in assumptions
            and option.destination_id == state.destination_ids[0]
            and option.route_match in {"origin_to_destination", "destination_to_origin"}
        ]
        if len(exact_legs) > 1 and any(
            assumptions[option.option_id].journey_scope == "round_trip"
            for option in exact_legs
        ):
            for option in exact_legs:
                projection.problem(
                    "transport_pricing", option.option_id, "pricing_assumption_invalid",
                    "Declared round-trip coverage overlaps another selected fare for the same journey; remove conflicting pricing assumptions instead of charging the journey twice.",
                )
                assumptions.pop(option.option_id)
        else:
            for direction in ("origin_to_destination", "destination_to_origin"):
                overlapping = [option for option in exact_legs if option.route_match == direction]
                if len(overlapping) < 2:
                    continue
                for option in overlapping:
                    projection.problem(
                        "transport_pricing", option.option_id, "pricing_assumption_invalid",
                        "Multiple selected fares cover the same full-group journey direction; choose one fare and use its charge or vehicle count instead of charging alternative services together.",
                    )
                    assumptions.pop(option.option_id)
    if not selected:
        projection.missing("transport_selection_missing", "transportation", "Choose a valid transportation option or personal vehicle mode.")
    override = allowances.get(("transportation", None, None))
    if override is not None:
        projection.allowance(override, "allowance:transportation", "Whole-trip transportation allowance")
        projection.assumptions.append("The transportation allowance replaces individual fares and covers all selected travel, transfers, return legs, and vehicle expenses.")
        return
    if (
        state.route_preferences is not None
        and len(selected) == 1 and selected[0].kind == "personal_vehicle"
    ):
        _vehicle_costs(projection, fuel)
        return
    for option in selected:
        assumption = assumptions.get(option.option_id)
        if assumption is None:
            projection.missing(
                "transport_price_basis_missing", option.option_id,
                "Provide an explicit fare basis/count, or a whole-trip transportation allowance for vehicle and unpriced travel expenses.",
            )
            continue
        if assumption.price_basis == "per_person" and state.child_ages:
            _age_priced_cost(
                projection, age_rules.get(("transportation", option.option_id)),
                "transportation", option.option_id, option.label, option.listed_price,
                charge_count=assumption.charge_count,
                adult_source=(
                    "catalog_price_with_verified_basis" if option.price_basis
                    else "catalog_price_with_assumed_basis"
                ),
            )
            projection.assumptions.append(
                f"{option.option_id}: catalog adult fare with {assumption.charge_count} "
                f"traveler-assumed charge(s) and {assumption.journey_scope} coverage."
            )
            continue
        quantity = assumption.charge_count
        if assumption.price_basis == "per_person":
            if state.traveler_count is None:
                continue
            quantity *= state.traveler_count
        elif assumption.price_basis == "per_vehicle":
            quantity *= assumption.vehicle_count
        projection.line(
            "transportation", option.option_id, option.label,
            option.listed_price * quantity,
            "catalog_price_with_verified_basis" if option.price_basis else "catalog_price_with_assumed_basis",
            unit_amount=option.listed_price, quantity=quantity, price_basis=assumption.price_basis,
        )
        projection.assumptions.append(
            f"{option.option_id}: catalog rate and "
            f"{'verified charging unit' if option.price_basis else 'assumed charging unit'}; "
            f"{assumption.charge_count} charge(s), {assumption.journey_scope} coverage, "
            "and any vehicle count are traveler assumptions."
        )
    if any(option.route_match == "unconfirmed" for option in selected):
        projection.missing("transport_connections_missing", "transportation", "Unconfirmed transport legs may leave transfers or connections unpriced; use a whole-trip allowance or applicable catalog segments.")
    round_trip = any(
        assumption.journey_scope == "round_trip" for assumption in assumptions.values()
    )
    priced_directions = {
        option.route_match for option in selected if option.option_id in assumptions
    }
    if not round_trip and "origin_to_destination" not in priced_directions:
        projection.missing(
            "transport_outbound_missing", "transportation",
            "Provide an applicable outbound fare, declare estimated package coverage, or use a whole-trip transportation allowance.",
        )
    if len(state.destination_ids) > 1:
        projection.missing(
            "transport_connections_missing", "transportation",
            "Multiple-destination connections have not been composed yet; use a whole-trip transportation allowance until journey legs can be priced together.",
        )
    if state.return_to_origin and not round_trip:
        if not {"origin_to_destination", "destination_to_origin"}.issubset(priced_directions):
            projection.missing("transport_return_missing", "transportation", "Price outbound and return legs explicitly, or declare estimated round-trip coverage or a whole-trip allowance.")
    if round_trip:
        projection.assumptions.append("Declared round-trip coverage is an explicit traveler estimate; identical return fares or real journey feasibility have not been verified.")


def _vehicle_costs(projection: _Projection, fuel: PlanningFuelEstimate | None) -> None:
    inputs = projection.state.fuel_assumptions
    if fuel is not None and fuel.status == "calculated" and fuel.amount is not None:
        projection.line(
            "transportation", "vehicle:fuel", "Estimated fuel for the selected journey",
            fuel.amount, "route_with_traveler_assumptions", price_basis="whole_trip_fuel_estimate",
        )
        projection.assumptions.extend(fuel.assumptions)
    else:
        projection.missing(
            "fuel_estimate_missing", "vehicle:fuel",
            "Fuel needs a supported road route and explicit efficiency, fuel-price, and vehicle assumptions; a straight-line estimate is insufficient.",
        )
    for field, label in (
        ("parking_amount", "Parking"), ("toll_amount", "Tolls"),
        ("vehicle_ferry_amount", "Vehicle ferry charges"),
        ("other_vehicle_amount", "Other vehicle expenses"),
    ):
        amount = getattr(inputs, field) if inputs is not None else None
        reference = f"vehicle:{field}"
        if amount is None:
            projection.missing(
                "vehicle_expense_allowance_missing", reference,
                f"Provide a whole-trip {label.lower()} allocation, including an explicit zero if appropriate.",
            )
        else:
            projection.line(
                "transportation", reference, f"{label}: whole-trip vehicle allowance",
                amount, "traveler_allowance", unit_amount=amount, quantity=1,
                price_basis="whole_trip_allowance",
            )
            projection.assumptions.append(
                f"{label} allocation covers all selected vehicles for the whole trip; an explicit zero is a traveler assumption, not a verified free charge."
            )


def _accommodation_costs(projection, options, allowances):
    state = projection.state
    selected = [options[item] for item in state.selected_accommodation_ids if item in options]
    assumptions = {}
    for assumption in state.accommodation_pricing:
        reference = f"accommodation:{assumption.accommodation_id}"
        option = options.get(assumption.accommodation_id)
        message = None
        if assumption.accommodation_id not in state.selected_accommodation_ids or option is None:
            message = "Room assumptions must reference a selected available accommodation."
        elif state.night_count == 0 or (state.night_count is not None and assumption.night_count > state.night_count):
            message = "Assumed stay nights must fit the explicit trip nights."
        elif state.traveler_count is not None and assumption.room_count * option.capacity < state.traveler_count:
            message = "The assumed room quantity cannot accommodate the full traveler group."
        elif option.price_basis is not None and assumption.price_basis != option.price_basis:
            message = "The room price basis must match the verified catalog charging unit."
        if message:
            projection.problem("accommodation_pricing", reference, "pricing_assumption_invalid", message)
            continue
        assumptions[assumption.accommodation_id] = assumption
    if state.night_count == 0:
        for option in selected:
            projection.problem(
                "selected_accommodation_ids", f"accommodation:{option.accommodation_id}",
                "accommodation_option_unavailable", "A zero-night trip cannot select an overnight stay.",
            )
        return
    override = allowances.get(("accommodation", None, None))
    if override is not None:
        projection.allowance(override, "allowance:accommodation", "Whole-trip accommodation allowance")
        projection.assumptions.append("The accommodation allowance replaces selected room prices and covers the full stay; it does not verify vacancy.")
        return
    if state.night_count is None:
        return
    if not selected:
        projection.missing("accommodation_selection_missing", "accommodation", "Choose an overnight stay with explicit room/night pricing assumptions or provide a whole-trip accommodation allowance.")
        return
    for option in selected:
        if option.accommodation_id not in assumptions:
            projection.missing("accommodation_price_basis_missing", f"accommodation:{option.accommodation_id}", "Provide a compatible room price basis, room count, and stay nights.")
    stay_nights = sum(item.night_count for item in assumptions.values())
    if stay_nights != state.night_count:
        projection.missing("accommodation_nights_mismatch", "accommodation", "For sequential full-group stays, the selected stay nights must add up to the explicit trip nights.")
    if stay_nights > state.night_count:
        for assumption in assumptions.values():
            projection.problem(
                "accommodation_pricing", f"accommodation:{assumption.accommodation_id}",
                "pricing_assumption_invalid", "Sequential full-group stay nights exceed the trip nights; correct the allocation.",
            )
        return
    for option in selected:
        assumption = assumptions.get(option.accommodation_id)
        if assumption is None:
            continue
        quantity = assumption.room_count
        if assumption.price_basis == "per_room_per_night":
            quantity *= assumption.night_count
        projection.line(
            "accommodation", f"accommodation:{option.accommodation_id}", option.name,
            option.listed_price * quantity,
            "catalog_price_with_verified_basis" if option.price_basis else "catalog_price_with_assumed_basis",
            unit_amount=option.listed_price, quantity=quantity, price_basis=assumption.price_basis,
        )
        projection.assumptions.append(
            f"accommodation:{option.accommodation_id}: {assumption.room_count} room(s), "
            f"{assumption.night_count} night(s); "
            f"{'catalog charging unit' if option.price_basis else 'assumed charging unit'} "
            "and traveler room/night allocation do not verify availability."
        )
