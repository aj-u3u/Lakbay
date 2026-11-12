# Top 5 weighted scoring — scope for approval (10 November 2026)

Status: **approved on 10 November 2026 with the four recommended decisions, and
implemented** (Phase 15I in [core_focus.md](core_focus.md); details in
[recommendations.md](recommendations.md)). This follows the review format in
[new_feature.md](new_feature.md) and is Step 3 of the
[objectives and panel upgrade plan](objectives_panel_upgrade_plan_2026-11-09.md).

Changes from the proposal made during implementation:

- `preferred_districts` is a hard filter, counted as `outside_preferred_districts`.
- `limit` accepts 1 to 10 (default 5).
- With no interests, planning chat still returns no recommendations and says no
  interests were supplied; the endpoint ranks by the other factors.

## Review summary

```text
Feature:            Personalized Top 5 places using a weighted scoring model
Current phase:      Phase 15: AI Geo-Analytics Planning Enhancements (latest: 15H)
Requested phase:    Phase 15
Phase alignment:    Fits current phase
Recommended phase:  New sub-phase 15I, "Personalized Top 5 weighted scoring"
Database changes:   None
New env variables:  None
```

Reason: Phase 3 already lists budget, location, duration and accessibility as
preference inputs and promises "at least five feasible destination
recommendations". Phase 15B already scores destination groups with a weighted
formula. This step applies the same kind of formula to single places and adds the
inputs the app does not send today. Following the Phase 15 rule, it adds a new
layer beside the existing endpoints instead of changing them.

## The problem today

| Path | What it uses | Gap |
| --- | --- | --- |
| App "Show Top 5" button → `POST /recommendations` | Vibes, categories, districts, budget class (`UI_FOR_LAKBAY/lib/providers/trip_provider.dart:679`) | Ignores start point, vehicle, peso budget and party. The start point is used only to display distance after ranking. |
| Planning chat → `rank_planning_candidates` (`recommendations/service.py:36`) | Interests, start point, driving or walking | Keeps only places with a verified entrance (0 of 30 today), so it returns nothing. Ignores budget. Distance only breaks ties. |

## Method: weighted scoring model (Simple Additive Weighting)

1. **Filter** places that cannot work (hard rules below).
2. **Normalize** each factor to 0–1.
3. **Weight and add**, then multiply by 100.
4. **Order** and return up to five, each with a breakdown and reasons.

```text
score = 100 × (0.35 × Interest + 0.25 × Travel + 0.20 × Budget
               + 0.10 × GroupFit + 0.10 × Popularity)
```

The interest, travel and budget weights match the existing Phase 15B group formula
(`geo_analytics/service.py:215`). Phase 15B splits its last 20% into popularity
10%, accessibility 5% and child-friendliness 5%; this scope combines
accessibility and children into one group-fit factor, because required
accessibility is already a hard filter for a single place.

### Factors

| Factor | Weight | Type | Normalization (0–1) | Missing data |
| --- | --- | --- | --- | --- |
| Interest | 0.35 | Benefit | Interests matched ÷ interests selected, matched against category, vibes and activities | No interests given: 0.5 and a reason asking for a vibe |
| Travel | 0.25 | Cost | `1 − minutes ÷ max_minutes`; `max_minutes` is 180 for a day trip, 300 for two or more days | No start point: 0.5 and a reason asking for one |
| Budget | 0.20 | Cost | `r = cost ÷ per-person budget`; 1 if `r ≤ 0.5`, `(1 − r) ÷ 0.5` if `r ≤ 1` | Cost not listed: 0.5, labeled "Cost not listed". No budget given: 0.5 |
| Group fit | 0.10 | Benefit | Needs met ÷ needs. A child in `child_ages` needs kid-friendly; 5 or more travelers need group-friendly | No needs: 1 |
| Popularity | 0.10 | Benefit | `min(100, popularity_score) ÷ 100`, the same scaling as Phase 15B | No interactions: 0 |

### Travel time source

| Situation | How minutes are found | Label shown |
| --- | --- | --- |
| Driving or walking, verified entrance | One OSRM Table request from the start point to all candidates | Road route |
| Driving or walking, no verified entrance | Same OSRM Table request, using the attraction pin | Approx. location |
| OSRM unavailable | Haversine at the existing fallback speeds (40 km/h driving, 5 km/h walking) | Straight-line estimate |
| Public transport | Haversine at 30 km/h until commute hubs and legs exist | Commute estimate |

A new `OSRMClient.table()` method makes one request for all candidates instead of
one route request per place. Adaptive route optimization (next step) needs the
same method for its travel-time matrix.

### Hard filters

A place is removed, and counted in a "skipped" summary, when:

- it is inactive;
- a required accessibility flag is not true;
- the user gave interests and none match (the existing rule: never fill the list
  with unrelated places);
- its listed cost is above the per-person budget;
- its travel time is above `max_minutes`;
- it needs a boat or ferry and the mode is driving or walking (existing
  `_has_non_road_access_hint` rule; revisited when plane and ship legs are added).

### Worked example

Start: Bajada, Davao City, by car. Budget ₱3,000 for 2 adults and 1 child
(₱1,000 per person). Interests: nature, family. All three places are
kid-friendly.

| Place | Interest | Travel | Budget | Group fit | Popularity | Score |
| --- | --- | --- | --- | --- | --- | --- |
| A: matches both, 55 min, ₱385 per person | 1.00 | 0.69 | 1.00 | 1.00 | 0.90 | 91 |
| B: matches one, 25 min, ₱200 per person | 0.50 | 0.86 | 1.00 | 1.00 | 0.60 | 75 |
| C: matches both, 150 min, ₱800 per person | 1.00 | 0.17 | 0.40 | 1.00 | 1.00 | 67 |

Place A: `100 × (0.35 × 1.00 + 0.25 × 0.69 + 0.20 × 1.00 + 0.10 × 1.00 + 0.10 × 0.90) = 91`.

## Backend scope

### New endpoint

`POST /api/v1/recommendations/top-places` (authenticated traveler, rate-limited
with the existing route request limiter because it calls OSRM).

Request (all optional except as noted):

```json
{
  "interests": ["nature", "family"],
  "preferred_districts": [],
  "origin": {"label": "Bajada", "lat": 7.0912, "lng": 125.6127},
  "travel_mode": "driving",
  "total_budget": "3000.00",
  "budget_scope": "whole_trip",
  "adult_count": 2,
  "child_ages": [7],
  "day_count": 1,
  "requires_kid_friendly": false,
  "requires_wheelchair_accessible": false,
  "limit": 5
}
```

Response, per place: rank, destination ID, name, district, image, `score`
(0–100), `breakdown` (each factor's 0–1 value and weighted points), `reasons`,
travel minutes and distance with their label, cost with its label, and
`route_verified`. Also: `method: "simple_additive_weighting"`, the weights used,
`total_candidates`, a `skipped` summary by reason, and `shortfall_reason` when
fewer than five qualify.

The request saves a preference signal the same way `POST /recommendations`
does, so Phase 15B grouping keeps using the latest preferences.

### Files

| File | Change |
| --- | --- |
| `app/features/recommendations/scoring.py` (new) | Pure functions: normalization, weights, score, reasons. No database or network access, so they are easy to test |
| `app/features/recommendations/schemas.py` | Request and response models |
| `app/features/recommendations/service.py` | `rank_top_places()`: load active places, filter, get travel times, score, order |
| `app/features/recommendations/router.py` | The new endpoint |
| `app/integrations/osrm/client.py` | `table()` method with the existing timeout and error handling |
| `tests/test_top_places_scoring.py` (new) | Unit and endpoint tests (below) |
| `docs/recommendations.md` | Formula, weights, normalization, filters, worked example |
| `docs/core_focus.md` | Phase 15I entry once approved |

Unchanged: `POST /recommendations`, `POST /geo-analytics/destination-groups`,
all tables and migrations.

## Decisions needed before coding

1. **Unverified places.** Today 0 of 30 places have a verified entrance.
   - A. Strict: show only verified places. The Top 5 stays empty until entrances
     are verified.
   - **B. Recommended:** verified places fill the list first, ordered by score;
     the remaining slots go to approximate places, ordered by score and labeled
     "Approx. location". As entrances are verified, the list becomes fully
     verified with no code change. Only verified places are described as
     route-feasible.
2. **Planning chat.** Switch `rank_planning_candidates` to the new service in
   this step, so the button and the chat give the same Top 5? **Recommended:
   yes.** It changes the chat's documented strict behavior (decision 1) and its
   tests.
3. **Cost unit.** `estimated_cost` has no confirmed unit
   ([planning_preview.md](planning_preview.md)). **Recommended:** treat it as per
   person, compare it with the per-person budget (`total_budget ÷ travelers` for
   a whole-trip budget), and label it "Catalog estimate". Confirming each
   place's charging unit is data work for admins.
4. **Unknown cost.** `POST /recommendations` drops unknown-cost places when a
   maximum cost is set. **Recommended:** keep them with a budget score of 0.5 and
   the label "Cost not listed", because most places have no cost yet.

## Tests

- Scoring functions: each normalization, including edge values (0 minutes, exactly
  `max_minutes`, `r = 0.5`, `r = 1`); weights add up to 1; the score equals the sum
  of the breakdown points; the worked example gives 91, 75 and 67.
- Personalization: changing the start point, budget, travel mode or children
  changes the order.
- Filters: each hard filter removes the place and increments the right `skipped`
  count.
- Missing data: no start point, no budget, no interests, unknown cost, OSRM
  failure (falls back to Haversine with the right label).
- Decision 1: verified places come first; approximate places carry their label.
- Endpoint: requires sign-in, is rate-limited, and leaves `POST /recommendations`
  responses unchanged.
- Full suite passes.

## Acceptance criteria

- The Top 5 responds to budget, start point, travel mode, interests and party.
- Every score is 0–100 and equals the sum of its breakdown.
- Every place shows reasons and labels for travel time and cost.
- With today's data (no verified entrances) the endpoint returns labeled results
  instead of nothing; once entrances are verified, they appear as road routes
  without code changes.
- Existing endpoints and tests are unchanged.
- `docs/recommendations.md` documents the formula, weights and worked example.

## Not in this step

- Traveler app changes (`UI_FOR_LAKBAY`): calling the new endpoint from
  `trip_provider.dart` and showing the score breakdown card. Separate approval.
- Fuel, fares and lodging in the budget factor. The planning preview already
  handles those and is reused later.
- Adaptive route optimization, commute hubs and legs, and plane and ship legs.
  Each gets its own scope.
- AHP weight survey. The weights above are documented starting values; AHP or a
  sensitivity analysis can adjust them without code changes.
