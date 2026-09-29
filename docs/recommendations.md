# Recommendation Guide

This document explains the Phase 3 recommendation API in plain terms.

## Purpose

Phase 3 turns traveler preferences into ranked destination suggestions without
using AI. The scoring is deterministic and explainable, so Flutter can show why
each destination was recommended.

## What Phase 3 Includes

Phase 3 adds:

- saved user preference signals.
- destination recommendation scoring.
- destination interactions.
- destination popularity counters.

Phase 3 does not create trips, itineraries, AI-generated plans, route
optimization, or budget breakdowns.

## Protected Endpoints

These endpoints require a user access token.

```text
POST /api/v1/recommendations
```

Saves the user's preferences and returns ranked destination recommendations.

Example request:

```json
{
  "preferred_categories": ["beach"],
  "preferred_vibes": ["relaxed"],
  "preferred_activities": ["swimming"],
  "preferred_districts": ["Davao Oriental"],
  "budget_class": "mid_range",
  "difficulty_level": "easy",
  "stay_duration_type": "full_day",
  "family_friendly": true,
  "limit": 5
}
```

Example response shape:

```json
{
  "preference_signal_id": 1,
  "total_candidates": 3,
  "recommendations": [
    {
      "destination_id": 1,
      "name": "Dahican Beach",
      "district": "Davao Oriental",
      "category": "beach",
      "estimated_cost": "2500.00",
      "score": 80,
      "matched_fields": ["category", "vibes", "activities"],
      "reasons": ["Matches preferred destination category."]
    }
  ]
}
```

```text
GET /api/v1/recommendations/preferences/latest
```

Returns the latest saved preference signal for the logged-in user.

```text
POST /api/v1/destinations/{destination_id}/interactions
```

Records one user interaction with a destination.

Allowed `interaction_type` values:

- `view`
- `save`
- `rate`
- `add_to_itinerary`

For `rate`, include a `rating` from `1` to `5`. For other interaction types,
do not include `rating`.

Interaction stability rules:

- `view` can be recorded repeatedly.
- `save` is counted once per user per destination.
- `add_to_itinerary` is counted once per user per destination.
- `rate` is counted once per user per destination. Sending another rating
  updates that user's previous rating instead of creating a second rating count.

## Public Endpoint

```text
GET /api/v1/destinations/{destination_id}/popularity
```

Returns aggregate popularity counters for an active destination.

## Scoring Notes

The first scoring version uses these signals:

- category match: `+25`.
- vibe match: `+15`.
- activity match: `+15`.
- district match: `+10`.
- budget class match: `+15`.
- difficulty match: `+10`.
- stay duration match: `+5`.
- family, couple, and group friendliness: `+5` each.
- popularity boost from interactions: up to `+10`.

These are intentionally simple rules. They are easy to test, easy to explain,
and safe to improve later.

The default request limit is `5`, so the API is already prepared to show the top
5 recommended destinations. Flutter can request fewer or more within the schema
limit, but capstone examples should show top 5 recommendations.

Popularity score is recalculated from destination interactions:

```text
popularity_score =
  view_count
+ save_count * 3
+ add_to_itinerary_count * 5
+ average_rating * 2
```

## Planned Geo-Analytics Grouping

Phase 15 should not replace this recommendation formula. It should group and
re-rank destination sets using route practicality.

Planned combined group score:

```text
final_group_score =
  preference_score * 0.35
+ geo_score * 0.25
+ budget_fit_score * 0.20
+ popularity_score * 0.10
+ accessibility_score * 0.05
+ child_friendliness_score * 0.05
```

This lets the system recommend practical groups such as nearby destinations in
the same district or destinations that are efficient to visit together in one
route.

## Hard Filters

A destination is excluded when:

- it is inactive.
- it is over `max_estimated_cost`, when that preference is provided.
- it does not satisfy required accessibility flags.
- it has no ranking-score match when the user provided ranking preferences such
  as category, vibe, activity, district, budget class, difficulty, duration, or
  traveler-friendly flags.

## Migration

The Phase 3 migrations are:

```text
0003_recommendation_signals
0004_recommendation_stability
```

It creates:

- `user_preference_signals`
- `destination_interactions`
- `destination_popularity`

The stabilization migration adds the interaction uniqueness rule used by the
popularity counters.

Apply it after reviewing the migration:

```bash
alembic upgrade head
```

## Testing

Run the Phase 3 tests:

```bash
python -m pytest tests/test_phase3_recommendations.py -q
```

Run the full suite:

```bash
python -m pytest -q
```
