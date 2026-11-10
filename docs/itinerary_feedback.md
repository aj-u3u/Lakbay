# Phase 15F: Pre-Trip Itinerary Feedback

`POST /api/v1/planning/feedback` is a protected, stateless companion to
`POST /api/v1/planning/preview`. It accepts the same `input_revision` and
`state`, plus optional top-level `traveling_with_children`. It returns the
underlying planning preview and advisory findings before a traveler saves or
follows a plan. It creates no trip or evaluation row and does not call AI.
Routing remains opt-in through `state.route_preferences` and uses the same
per-user planning route limit as preview.

Example request:

```json
{
  "input_revision": 7,
  "traveling_with_children": true,
  "state": {
    "destination_ids": [12],
    "total_budget": "3000.00",
    "traveler_count": 2,
    "day_count": 1,
    "night_count": 0,
    "return_to_origin": true
  }
}
```

`status` is `needs_details` when a selected option is invalid or required trip
details are missing, `needs_review` when advisory warnings remain, and
`no_flagged_issues` otherwise. This is **not** a booking, access, safety, or
save permission decision. Every finding has a stable `code`, `category`,
`severity` (`required`, `review`, or `info`), `message`, and optional `fields`
and `destination_ids`. `input_revision` lets Flutter discard a response for an
older user edit. `preview` contains the matching itemized budget, route, fuel,
selection problems, and next actions; the feedback endpoint does not recalculate
different prices.

## Rules

| Area | Finding | Rule |
| --- | --- | --- |
| Data | `selection_invalid`, `trip_details_missing` | Surface preview selection problems and missing inputs as required details. A missing start map pin (`origin.coordinates`) is required only when `route_preferences` requests a route. |
| Budget | `catalog_cost_unknown` | Selected active destination has `estimated_cost=null`; `0.00` is a known zero and is not flagged. An allowance does not make the catalog price known. |
| Budget | `budget_incomplete`, `over_budget` | Use preview completeness and fit. A partial plan can still prove a minimum overage. |
| Route | `arrival_unverified` | Selected destination is not marked `route_ready`; attraction coordinates do not establish visitor access. |
| Route | `route_not_requested`, `route_needs_review`, `route_estimated` | No route was requested, route inputs/provider need review, or a calculated route is estimated/uses unverified arrivals. |
| Route order | `route_order_not_compared` | More than two destinations have a calculated route in original order. No alternative order was compared, so the API makes no efficiency claim. |
| Pacing | `travel_time_high` | Calculated total route time exceeds four hours times the number of days. This is an even-spread review heuristic, not a day schedule. |
| Travel mode | `walking_distance_high` | Calculated walking distance exceeds 10 km times the number of days. Terrain and ability remain unknown. |
| Activities | `activity_load_high` | More than four valid selected catalog activities per day. Activity durations remain unknown. |
| Suitability | `child_suitability_review` | `traveling_with_children=true` and a selected destination is not marked kid friendly. This does not calculate child prices or confirm age restrictions. |

Findings use active catalog records and the same preview result returned in the
response. Unavailable destination IDs remain selection problems; they are not
silently replaced. Missing costs never become zero, and provider fallback routes
never become verified arrivals. No activity duration, day allocation, child age,
or operator rule is inferred from free-text descriptions.

The [Phase 15F tests](../tests/test_phase15f_itinerary_feedback.py) exercise the
contract and representative warning combinations. The existing
[planning preview guide](planning_preview.md) defines the underlying choices,
costs, and route calculation. The traveler app calls feedback before saving a
generated option in both its options sheet and conversational planner. It shows
findings in a review dialog, lets the traveler rerun the check with or without
children, and requires current feedback before continuing. Required findings
disable save; review findings can be acknowledged. The app keeps the existing
preview endpoint and save API unchanged. The local Flutter tests cover this
flow; a deployed backend and device check remain separate verification steps.
