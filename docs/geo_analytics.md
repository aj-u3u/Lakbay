# Geo-Analytics Enhancement Plan

This document defines the planned geo-analytics enhancement for Lakbay. It is a
planning document first. Do not treat every item here as already implemented.

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

Example response concept:

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

## First Implementation Recommendation

Start with a stateless endpoint in a future enhancement:

```text
POST /api/v1/geo-analytics/destination-groups
```

It should:

1. Accept user preferences or destination IDs.
2. Load destination scores and coordinates.
3. Build practical destination groups.
4. Return group scores, route estimates, cost estimates, reasons, and warnings.

No migration is required for the first version if results are not saved.

