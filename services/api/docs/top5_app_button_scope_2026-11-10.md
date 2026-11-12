# Traveler app Top 5 button — scope for approval (10 November 2026)

Status: **approved on 10 November 2026 with the three recommended decisions, and
implemented in `UI_FOR_LAKBAY`** (not yet committed there). One change from the
proposal: the list-level `warnings` are parsed but not shown in "See details",
because each card already carries its travel label and cost note. The other
pending app work was left untouched.

This connects the
traveler app (`UI_FOR_LAKBAY`) to the Phase 15I personalized Top 5
([scope](top5_weighted_scoring_scope_2026-11-10.md),
[recommendations.md](recommendations.md)). The backend does not change.

```text
Feature:            App Top 5 uses the weighted scoring endpoint
Repository:         UI_FOR_LAKBAY (Flutter traveler app)
Related phase:      Phase 15I (backend done)
Backend changes:    None
Database changes:   None
```

## The problem today

The mood starters, home mood chips, "Show my Top 5 places" button and "Show Top
5 places" link all call `TripProvider.requestTopRecommendations`
(`lib/providers/trip_provider.dart:667`). It sends only vibes, categories and a
budget class to the old `POST /recommendations`
(`lib/services/api_service.dart:924`), then the app computes a straight-line
distance for display. The start point, travel mode, peso budget, children and
trip length never affect the ranking, so the panel's concern is not visible in
the app.

Planning chat already uses the new ranking; its cards receive the new fields
but do not show them yet.

## Changes

| File | Change |
| --- | --- |
| `lib/services/api_service.dart` | New `fetchTopPlaces()` calling `POST /recommendations/top-places`, with the same sign-in check, token refresh retry and 30-second timeout as today. Remove `fetchRankedRecommendations()`, which nothing else uses. |
| `lib/providers/trip_provider.dart` | `requestTopRecommendations()` builds the request from the planning state (below) and drops the app-side straight-line distance, because the backend now returns travel time. |
| `lib/models/ranked_recommendations.dart` | Read `items`, `total_candidates`, `shortfall_reason`, `warnings` and `verified_count`. |
| `lib/models/chat_destination_suggestion.dart` | Read `breakdown`, `route_verified`, `travel_basis`, `travel_minutes`, `travel_distance_km` and `cost_basis`. The planning chat items carry the same fields, so chat cards improve too. |
| `lib/widgets/planner/recommendation_list.dart` | Card shows the match percent (as now), travel time with a label ("Road route", "Approx. location", "Straight-line estimate", "Commute estimate"), and the first reason. |
| `lib/widgets/planner/recommendation_details.dart` | "See details" shows the five factor bars (interest, travel, budget, group fit, popularity) with their points, all reasons, and the warnings. |
| `lib/screens/planner/conversational_planner_screen.dart` | With no results, the chat shows the backend's `shortfall_reason` (for example "No active catalog destination matches the supplied travel interests.") instead of the generic message. |

### Request built from the planning state

| Request field | From |
| --- | --- |
| `interests` | The tapped vibe, or the planning state's `interests` |
| `origin` | The planning state's `origin`, only when it has `lat` and `lng` |
| `travel_mode` | `mode:personal_vehicle` → `driving`, `mode:walking` → `walking`, any other transport choice → `public_transport`, none → `driving` (the same rule as planning chat) |
| `total_budget`, `budget_scope` | The planning state |
| `traveler_count`, `adult_count`, `child_ages`, `day_count` | The planning state, when present |
| `limit` | 5 |

## Decisions needed before coding

1. **Old endpoint call.** Remove `fetchRankedRecommendations()` once nothing
   uses it? **Recommended: yes**, with its tests updated.
2. **Labels.** Use "Road route" only for `route_verified` places, and "Approx.
   location" for the rest? **Recommended: yes**, matching the backend rule that
   only verified places are described as route-feasible.
3. **Unrelated unfinished work in the app.** `trip_provider.dart` and
   `api_service.dart` already contain someone else's uncommitted changes (trip
   completion, app assessments, formatting), and seven other files are modified.
   **Recommended:** edit around them without reverting anything, and commit only
   after you decide how to handle that work.

## Tests and checks

- Update `test/top_recommendations_test.dart` for the new response: breakdown,
  labels, `shortfall_reason`, and the request body built from the planning state
  (start point, mode mapping, budget, children).
- Update `test/conversational_planner_screen_test.dart`: the button calls the new
  endpoint, and an empty result shows the backend reason.
- A widget test for the five factor bars in the details sheet.
- `dart format` on changed files, then `flutter analyze` and `flutter test`
  (Flutter 3.41.7 is installed).

## Acceptance criteria

- Every Top 5 entry point sends the start point, travel mode, budget, party and
  trip length, and the order changes when they change.
- Each card shows match percent, travel time with its label, and a reason.
- "See details" shows the five factors and all reasons.
- An empty result shows the backend's explanation.
- `flutter analyze` reports no new issues and `flutter test` passes.

## Not in this step

- Interest synonyms (`streetfood` → `street food`) or limiting vibe chips to
  catalog words. Separate small step.
- Any backend change.
