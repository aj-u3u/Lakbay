# Geo-Analytics Enhancement Plan

This document describes the geo-analytics plan and the implemented Phase 15B
destination-grouping endpoint. Later AI and routing enhancements remain planned.

## Phase 15B Implementation

`POST /api/v1/geo-analytics/destination-groups` requires a traveler access token.
It reads destination records and that traveler's latest saved recommendation
preferences. It does not save groups or create a preference signal.

Example request:

```json
{
  "destination_ids": [1, 2, 3, 4],
  "travel_mode": "driving",
  "group_size": 3,
  "max_groups": 3,
  "max_separation_km": 50,
  "max_route_minutes": 240,
  "max_destination_cost": "3500.00"
}
```

The request accepts 2–10 unique active destination IDs. `group_size` is 2–4
and cannot exceed the ID count; `max_groups` is 1–5. Driving, walking, and
public transport follow the existing route contract. The cost limit is optional;
the route and separation limits have the defaults shown above. A group is
excluded if its furthest straight-line pair exceeds the separation limit, its
summed destination estimates exceed the cost limit, or its route duration
exceeds the route limit. Missing or inactive IDs return 404; invalid request
shapes return 422.

The service enumerates groups of the requested size, then ranks them using
preference score, proximity, and district similarity. It asks the existing route
service to optimize at most ten shortlisted groups and scores the returned
route facts. The response contains `groups`, `candidates_considered`, and
top-level `warnings`. Each group includes IDs, route order, total score, score
components, route provider, distance, duration, estimated status, destination
cost, reasons, and warnings. Different returned groups may share destinations.

The implemented `geo` score uses the formula below. Components are 0–100:

```text
geo = 0.40 × proximity + 0.35 × route_efficiency
    + 0.15 × district + 0.10 × travel_mode_fit

group_score = 0.35 × preference + 0.25 × geo + 0.20 × budget_fit
            + 0.10 × popularity + 0.05 × accessibility
            + 0.05 × child_friendliness
```

Proximity is based on the furthest pair as a fraction of the separation limit.
Route efficiency is based on route duration as a fraction of the route limit.
District score is 100 when every destination has the same district, 50 for a partial match,
and 0 when none agree. Travel-mode fit is 100 for a returned road route, 50
for an estimated driving/walking route, and 30 for estimated public transport.
Saved preference scores reuse Phase 3 scoring without its popularity boost; no
saved preference gives a neutral score of 50 and a warning. When a cost limit is
given, budget fit is `100 × (1 − destination_cost / cost_limit)`; with no cost
limit it is neutral at 50. Accessibility and child-friendliness reflect the
share of destinations flagged accordingly.

`estimated_destination_cost` is the sum of catalog estimates only. It excludes
transport, lodging, meals, and other expenses, so the full trip budget endpoint
remains necessary. Haversine and public-transport estimates retain the route
service's provider, estimated flag, and warnings. The endpoint makes no AI call.

`GEO_GROUP_REQUESTS_PER_MINUTE` defaults to 10 per authenticated user. Excess
requests return 429 with `geo_group_rate_limit_exceeded`. This development
limiter is in memory per worker; a shared rate-limit store is needed for a
multi-worker deployment.

## Purpose

Geo-analytics should help Lakbay answer more useful travel-planning questions
than simple map display.

Mapping answers:

```text
Where is this destination?
```

Geo-analytics answers:

```text
Which destinations are practical to visit together?
How much travel time will this group require?
Which destination group best fits the user's preferences, budget, and travel
mode?
```

## Current Foundation

The backend already has:

- destination latitude and longitude.
- optional PostGIS geography support.
- destination recommendation scores.
- route preview and route optimization.
- OSRM routing support for driving and walking.
- Haversine fallback estimates.
- budget estimates.
- AI itinerary generation from selected database records.

Phase 15 should build on these pieces instead of replacing them.

## Planned Geo-Analytics Inputs

Geo-analytics should use:

- selected or recommended destinations.
- destination coordinates.
- district and location text.
- recommendation scores.
- destination popularity.
- accessibility and child-friendly flags.
- selected travel mode.
- route distance and duration.
- budget estimate or projection.

## Destination Grouping

Destination grouping should return clusters of places that are practical to
visit together.

Initial grouping criteria:

- destinations are near each other.
- destinations are in the same or nearby district.
- route travel time is reasonable.
- combined estimated cost fits the user's budget.
- the group has strong recommendation scores.
- the group matches the user's transportation mode.

Earlier response concept (the Phase 15B contract above is authoritative):

```json
{
  "groups": [
    {
      "group_number": 1,
      "title": "Davao City Short-Stay Cluster",
      "destination_ids": [1, 2, 3],
      "average_recommendation_score": 82.5,
      "geo_score": 88.0,
      "estimated_total_cost": "3500.00",
      "estimated_route_duration_minutes": 95,
      "reasons": [
        "Destinations are close enough for a same-day itinerary.",
        "The group matches preferred activities and budget class."
      ],
      "warnings": []
    }
  ]
}
```

## Suggested Geo Score Formula

Start with an explainable formula:

```text
geo_score =
  proximity_score * 0.40
+ route_efficiency_score * 0.35
+ district_cluster_score * 0.15
+ travel_mode_fit_score * 0.10
```

Suggested meaning:

- `proximity_score`: higher when destinations are closer together.
- `route_efficiency_score`: higher when total route duration is practical.
- `district_cluster_score`: higher when destinations are in the same or nearby
  district.
- `travel_mode_fit_score`: higher when the route can be reasonably handled by
  the selected travel mode.

The score should be explainable in API responses. Avoid hidden or AI-only
ranking logic for the first version.

## Recommendation Plus Geo Score

The current recommendation score should remain useful. Geo-analytics should add
route practicality, not erase preference matching.

Planned combined formula:

```text
final_group_score =
  preference_score * 0.35
+ geo_score * 0.25
+ budget_fit_score * 0.20
+ popularity_score * 0.10
+ accessibility_score * 0.05
+ child_friendliness_score * 0.05
```

This keeps user preferences as the largest factor while still considering
distance, budget, popularity, accessibility, and children.

## Routing Algorithm Direction

Geo-analytics should use the routing service rather than duplicating routing
logic.

Recommended direction:

- Use OSRM road durations when available.
- Use OSRM Table later for pairwise travel-time matrices.
- Use Haversine nearest-neighbor fallback when OSRM is unavailable.
- Add 2-opt improvement later if route loops become a problem.

Do not let AI calculate the route by itself. AI can explain route choices, but
the backend should calculate route facts.

## Travel Modes

Geo-analytics should eventually account for:

- `land`
- `air`
- `sea`
- `mixed`

Initial behavior:

- `land`: use OSRM or Haversine estimates.
- `air`: use stored transportation price and duration.
- `sea`: use stored transportation price and duration.
- `mixed`: combine stored transportation segments and land route estimates.

OSRM should not be used to pretend it can calculate boat or airplane routes.

## AI Itinerary Integration

AI itinerary generation should receive backend-calculated geo context:

```json
{
  "top_recommendations": [],
  "destination_groups": [],
  "optimized_route": {},
  "budget_projection": {},
  "travel_mode_context": {},
  "warnings": []
}
```

AI should use this context to organize the itinerary schedule, but the backend
should still validate:

- destination IDs.
- accommodation IDs.
- transportation IDs.
- costs.
- route feasibility.
- day count.
- budget adherence.

## Implemented First Step

Phase 15B added the stateless endpoint:

```text
POST /api/v1/geo-analytics/destination-groups
```

It:

1. Accepts destination IDs and reads the user's latest saved preferences.
2. Loads destination scores and coordinates.
3. Builds practical destination groups.
4. Returns group scores, route estimates, cost estimates, reasons, and warnings.

No migration was needed because results are not saved.

