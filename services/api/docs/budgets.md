# Budget Engine Guide

This document explains the Phase 4 budget estimate API in plain terms.

## Purpose

Phase 4 checks whether selected destinations and rate options fit a user's
planned budget. It is deterministic and does not save trips, expenses, or group
shares yet.

## Protected Endpoint

This endpoint requires a user access token.

```text
POST /api/v1/budgets/estimate
```

The endpoint calculates:

- destination or activity cost from `destinations.estimated_cost`.
- accommodation cost from selected available accommodations.
- transportation cost from selected available transportation options.
- meal estimate from `meal_cost_per_day * traveler_count * day_count`.
- miscellaneous cost from the request.

Example request:

```json
{
  "total_budget": "10000.00",
  "traveler_count": 2,
  "day_count": 3,
  "destination_ids": [1, 2],
  "accommodation_ids": [1],
  "transportation_ids": [1],
  "meal_cost_per_day": "500.00",
  "miscellaneous_cost": "300.00"
}
```

Example response shape:

```json
{
  "total_budget": "10000.00",
  "total_estimated_cost": "7100.00",
  "remaining_budget": "2900.00",
  "over_budget_amount": "0.00",
  "is_over_budget": false,
  "percent_used": "71.00",
  "traveler_count": 2,
  "day_count": 3,
  "breakdown": {
    "destinations": "1500.00",
    "accommodations": "1800.00",
    "transportation": "500.00",
    "meals": "3000.00",
    "miscellaneous": "300.00"
  }
}
```

## Validation Notes

- `total_budget` must be greater than `0` and use two decimal places.
- `meal_cost_per_day` and `miscellaneous_cost` must be non-negative money values
  with two decimal places.
- `traveler_count` must be from `1` to `100`.
- `day_count` must be from `1` to `365`.
- `destination_ids` must contain at least one active destination.
- selected accommodations must be available.
- selected transportation options must be available.
- selected accommodations and transportation options must belong to one of the
  selected destinations.
- duplicate IDs are rejected to avoid accidental double counting.

Over-budget estimates still return `200 OK`. Flutter should use
`is_over_budget` and `over_budget_amount` to decide how to display the result.

## Planned Activity-Based Projection

Phase 15 should improve budget explanations by projecting costs from planned
activities, not only destination-level estimates.

First version:

- use `destinations.estimated_cost` as the activity or destination estimate.
- use itinerary activity `estimated_cost` when the user is evaluating a drafted
  itinerary.
- keep accommodation, transportation, meals, and miscellaneous costs separate.

Possible later version:

- add a `destination_activities` catalog after the stateless projection is
  reviewed.
- store activity duration, adult price, child price policy, indoor/outdoor
  category, and activity notes.

Recommended projection formula:

```text
total_projected_cost =
  activity_costs
+ accommodation_costs
+ transportation_costs
+ meal_costs
+ miscellaneous_cost
```

## Planned Child-Aware Costing

Some trips include children whose fees may be free, half price, or full price
depending on age and activity rules. This is planned as a Phase 15 enhancement
because it affects budgets, AI itinerary planning, expenses, reports, and
fairness.

Recommended default rules:

```text
adult = full cost
child age 0-2 = free by default
child age 3-7 = half cost by default
child age 8+ = full cost by default
```

Destination or activity rules should be able to override the default. For
example, a boat fare may charge full price for a child while a park entrance fee
may be free for children below a specific age.

Fairness rule:

```text
The backend should calculate child costs from explicit age and pricing rules.
It should not assume which adult or member should shoulder the payment unless
the trip expense module later adds an approved payer rule.
```

## Migration

Phase 4 is currently stateless. It adds no database table and does not require a
new Alembic migration.

## Testing

Run the Phase 4 tests:

```bash
python -m pytest tests/test_phase4_budget_engine.py -q
```

Run the full suite:

```bash
python -m pytest -q
```
