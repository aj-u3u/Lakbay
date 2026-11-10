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

## Personalized Top 5 (Phase 15I)

```text
POST /api/v1/recommendations/top-places
```

Ranks active destinations with a **weighted scoring model** (Simple Additive
Weighting): every factor is normalized to 0–1, multiplied by its weight, and
added. The formula lives in `app/features/recommendations/scoring.py`; the scope
and approved decisions are in
[top5_weighted_scoring_scope_2026-11-10.md](top5_weighted_scoring_scope_2026-11-10.md).
The endpoint requires sign-in, shares the per-user route rate limit
(`ROUTE_REQUESTS_PER_MINUTE`), and saves a preference signal like
`POST /api/v1/recommendations`, so Phase 15B grouping uses the latest
preferences. Planning chat uses the same ranking (without saving a preference)
whenever the traveler has interests and no selected destinations.

```text
score = 100 × (0.35 × Interest + 0.25 × Travel + 0.20 × Budget
               + 0.10 × GroupFit + 0.10 × Popularity)
```

| Factor | Type | Normalization | When the input is missing |
| --- | --- | --- | --- |
| Interest | Benefit | Interests matched ÷ interests selected, searched in category, vibes and activities | No interests: 0.5 |
| Travel | Cost | `1 − minutes ÷ max_minutes`; 180 minutes one way for a day trip, 300 for two or more days | No start point: 0.5 |
| Budget | Cost | `r = estimated_cost ÷ per-person budget`; 1 if `r ≤ 0.5`, else `(1 − r) ÷ 0.5` | Cost not listed or no budget: 0.5 |
| Group fit | Benefit | Needs met ÷ needs: children need kid-friendly, five or more travelers need group-friendly | No needs: 1 |
| Popularity | Benefit | `min(100, popularity_score) ÷ 100`, as in Phase 15B | No interactions: 0 |

The per-person budget is `total_budget ÷ travelers` for a whole-trip budget.
`estimated_cost` is treated as a per-person catalog estimate because its unit is
not recorded; transport, lodging and meals are not included.

**Hard filters.** A place is removed and counted in `skipped` when it is outside
`preferred_districts`, lacks a required accessibility flag, matches none of the
interests, has a listed cost above the per-person budget, needs a boat or ferry
while the mode is driving or walking, has no road route from the start point, or
is farther than `max_minutes`. When no place matches the interests at all,
`shortfall_reason` is "No active catalog destination matches the supplied travel
interests." Unknown-cost places are kept.

**Travel time.** Driving and walking use one OSRM Table request from the start
point to every candidate (at most 50). When more places qualify, the 50 are
chosen by their score with a straight-line travel estimate, so distant places
cannot crowd out nearby ones before the road check.

| `travel_basis` | Meaning |
| --- | --- |
| `road_route` | OSRM route to a sourced, dated, route-ready visitor entrance; both ends snapped within 250 m |
| `approximate_location` | OSRM route to the attraction pin, or a far snap; the entrance is not verified |
| `straight_line_estimate` | OSRM was unavailable; Haversine at 40 km/h driving or 5 km/h walking |
| `commute_estimate` | Public transport; Haversine at 30 km/h until commute legs exist |
| `unknown` | No start point |

**Order.** Places with `route_verified=true` fill the list first, then
approximate places, each group by score, then shorter travel, then ID. Only
`route_verified` places are described as route-feasible; every other place is
labeled. As visitor entrances are verified, the list becomes fully verified
without code changes. A place must still not be marked route-ready from its
rough attraction coordinate.

**Response.** Each item has `rank`, `score` (0–100, equal to the sum of its
`breakdown` points), the `breakdown` per factor (`value`, `weight`, `points`),
`matched_interests`, `reasons`, `route_verified`, `travel_basis`,
`travel_minutes`, `travel_distance_km`, and `cost_basis` (`catalog_estimate` or
`not_listed`). The response also returns `method`, `weights`,
`max_travel_minutes`, `total_candidates`, `verified_count`, `skipped`,
`shortfall_reason` (when fewer than `limit` qualify) and `warnings`.

### Worked example

Start in Bajada, Davao City, by car, with ₱3,000 for 2 adults and 1 child
(₱1,000 per person), interests nature and family, all places kid-friendly:

| Place | Interest | Travel | Budget | Group fit | Popularity | Score |
| --- | --- | --- | --- | --- | --- | --- |
| A: matches both, 55 min, ₱385 | 1.00 | 0.69 | 1.00 | 1.00 | 0.90 | 91 |
| B: matches one, 25 min, ₱200 | 0.50 | 0.86 | 1.00 | 1.00 | 0.60 | 75 |
| C: matches both, 150 min, ₱800 | 1.00 | 0.17 | 0.40 | 1.00 | 1.00 | 67 |

Place A: `100 × (0.35 × 1.00 + 0.25 × 0.69 + 0.20 × 1.00 + 0.10 × 1.00 + 0.10 × 0.90) = 91`.
Moving the start point 40 minutes from C raises its travel value to 0.78 and its
score to 82, so it passes B. `tests/test_top_places_scoring.py` checks the A, B
and C scores.

### Planning chat

Planning chat maps `mode:personal_vehicle` to driving, `mode:walking` to walking,
any other transport choice to public transport, and no choice to driving. Its
`recommendations` items keep their earlier fields; `score` is now the 0–100
weighted score, the route fields may be null, and each item adds
`route_verified`, `travel_basis` and `breakdown`. With no interests, chat returns
no recommendations and explains that no interests were supplied.

The regular `POST /api/v1/recommendations` endpoint is unchanged: a
preference-only ranking that must not be described as route-feasible.

As of 4 November 2026 the configured catalog had 30 active destinations and no
verified visitor entrances, so every Top 5 place is currently labeled
approximate. See the [arrival review](davao_region_access_arrival_review_2026-10-29_README.md).

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

## Hard Filters for POST /recommendations

The personalized Top 5 has its own filters, described above. For
`POST /api/v1/recommendations`, a destination is excluded when:

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

Run the personalized Top 5 tests:

```bash
python -m pytest tests/test_top_places_scoring.py tests/test_planning_chat.py -q
```

Run the full suite:

```bash
python -m pytest -q
```
