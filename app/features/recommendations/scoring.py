"""Weighted scoring model (Simple Additive Weighting) for the personalized Top 5.

Every factor is normalized to 0-1, multiplied by its weight, and added. The
functions here are pure so the formula can be tested and checked by hand.
"""

from decimal import Decimal

# Interest, travel and budget match the Phase 15B group weights
# (`geo_analytics/service.py`). Group fit combines child and group needs.
WEIGHTS: dict[str, float] = {
    "interest": 0.35,
    "travel": 0.25,
    "budget": 0.20,
    "group_fit": 0.10,
    "popularity": 0.10,
}
# Used when the traveler gave no value to compare against, so the factor
# neither helps nor hurts any place.
NEUTRAL = 0.5
DAY_TRIP_MAX_TRAVEL_MINUTES = 180
MULTI_DAY_MAX_TRAVEL_MINUTES = 300
LARGE_GROUP_SIZE = 5
# Interest fields searched for each traveler interest, in reporting order.
INTEREST_FIELDS = ("category", "vibes", "activities")


def max_travel_minutes(day_count: int | None) -> int:
    """One-way travel limit: tighter for a day trip than for a longer stay."""
    return MULTI_DAY_MAX_TRAVEL_MINUTES if day_count and day_count >= 2 else DAY_TRIP_MAX_TRAVEL_MINUTES


def interest_matches(
    interests: list[str], fields: dict[str, str | None]
) -> tuple[list[str], list[str]]:
    """Return the interests found in the place's text and the fields that matched."""
    matched: list[str] = []
    matched_fields: list[str] = []
    for interest in interests:
        wanted = interest.strip().lower()
        if not wanted:
            continue
        hits = [name for name in INTEREST_FIELDS if wanted in (fields.get(name) or "").lower()]
        if hits:
            matched.append(interest)
            matched_fields.extend(name for name in hits if name not in matched_fields)
    return matched, matched_fields


def interest_score(selected_count: int, matched_count: int) -> float:
    """Benefit: share of the traveler's interests the place matches."""
    if selected_count <= 0:
        return NEUTRAL
    return min(1.0, matched_count / selected_count)


def travel_score(minutes: float | None, max_minutes: int) -> float:
    """Cost: shorter travel scores higher, reaching 0 at the trip's limit."""
    if minutes is None:
        return NEUTRAL
    return max(0.0, min(1.0, 1 - minutes / max_minutes))


def budget_score(cost_per_person: Decimal | None, budget_per_person: Decimal | None) -> float:
    """Cost: full marks up to half the budget, then down to 0 at the full budget.

    The flat first half keeps the cheapest place from always winning when every
    option fits comfortably.
    """
    if cost_per_person is None or budget_per_person is None or budget_per_person <= 0:
        return NEUTRAL
    ratio = float(cost_per_person / budget_per_person)
    if ratio <= 0.5:
        return 1.0
    return max(0.0, (1 - ratio) / 0.5)


def group_fit_score(
    *,
    has_children: bool,
    traveler_count: int,
    is_kid_friendly: bool,
    group_friendly: bool,
) -> float:
    """Benefit: needs met divided by needs. A party with no needs scores 1."""
    needs: list[bool] = []
    if has_children:
        needs.append(bool(is_kid_friendly))
    if traveler_count >= LARGE_GROUP_SIZE:
        needs.append(bool(group_friendly))
    if not needs:
        return 1.0
    return sum(needs) / len(needs)


def popularity_score(score: Decimal | float | None) -> float:
    """Benefit: the stored popularity score on the same 0-100 scale as Phase 15B."""
    if score is None or score <= 0:
        return 0.0
    return min(100.0, float(score)) / 100


def weighted_points(values: dict[str, float]) -> dict[str, float]:
    """Each factor's contribution to the 0-100 score, rounded to two decimals."""
    return {name: round(100 * WEIGHTS[name] * values[name], 2) for name in WEIGHTS}


def total_score(points: dict[str, float]) -> float:
    """The 0-100 score: the sum of the rounded points, so the breakdown always adds up."""
    return round(sum(points.values()), 2)
