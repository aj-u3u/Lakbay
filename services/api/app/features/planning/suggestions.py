"""Suggested whole-trip allowances derived from the traveler's stated budget.

These are labelled system estimates, not catalog prices. The whole-trip budget is a
ceiling: shares deliberately add up to less than 100% so reserve and unallocated money
stay visible. Destination fees and activities are left to the catalog and the traveler.
"""

from decimal import ROUND_HALF_UP, Decimal

from app.features.planning.schemas import PlanningSuggestedAllowance

# Share of the whole-trip budget, by category.
_OVERNIGHT_SHARES = (
    ("transportation", Decimal("0.20")),
    ("food", Decimal("0.25")),
    ("accommodation", Decimal("0.30")),
    ("other", Decimal("0.05")),
)
_DAY_TRIP_SHARES = (
    ("transportation", Decimal("0.25")),
    ("food", Decimal("0.30")),
    ("other", Decimal("0.05")),
)
_ROUNDING_STEP = Decimal("50")


def suggest_allowances(
    whole_trip_budget: Decimal | None,
    night_count: int | None,
) -> list[PlanningSuggestedAllowance]:
    """Return editable suggestions, or nothing when there is no usable budget."""
    if whole_trip_budget is None or whole_trip_budget <= 0:
        return []
    shares = _OVERNIGHT_SHARES if night_count else _DAY_TRIP_SHARES
    suggestions = []
    for category, share in shares:
        raw = whole_trip_budget * share
        amount = (raw / _ROUNDING_STEP).quantize(Decimal("1"), rounding=ROUND_HALF_UP)
        amount = (amount * _ROUNDING_STEP).quantize(Decimal("0.01"))
        suggestions.append(
            PlanningSuggestedAllowance(
                category=category,
                amount=amount,
                share_percent=int(share * 100),
            )
        )
    return suggestions
