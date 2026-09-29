# Routing Guide

This document explains how Lakbay should handle route planning in a simple,
implementation-ready way.

Source: [OSRM API documentation](https://project-osrm.org/docs/)

## What Routing Means In Lakbay

Routing answers this question:

```text
Given a list of places, what order should the traveler visit them in, and how
long will the route take?
```

Lakbay should use routing for:

- Sorting selected destinations into a practical order.
- Estimating total distance.
- Estimating total travel time.
- Showing route summaries in itineraries and PDF reports.
- Comparing itinerary options.

## Core Concepts

### Coordinate

A coordinate is a latitude and longitude pair.

Example:

```text
lat: 7.1907
lng: 125.4553
```

In most database models, store this as:

```text
lat
lng
geom
```

`lat` and `lng` are easy for Flutter and normal API responses. `geom` is useful
for PostGIS queries if PostGIS is enabled.

### Haversine Distance

Haversine estimates the straight-line distance between two coordinates.

Use it for:

- Quick nearby-destination filtering.
- Fallback distance estimates.
- Pre-sorting destinations before asking OSRM.

Do not use it as the final road distance because roads are not straight lines.

### OSRM Route Service

OSRM Route finds the best road path between coordinates in a fixed order.

Use it when:

- The backend already knows the order of destinations.
- The API needs turn-by-turn-ready distance and duration.
- The user wants to preview a selected itinerary route.

Simple meaning:

```text
Here are the stops in this exact order. Tell me the road distance and travel
time.
```

### OSRM Table Service

OSRM Table creates a distance and duration matrix between many places.

Use it when:

- The backend needs to compare travel time between every destination pair.
- The route optimizer needs data for deciding the best order.

Simple meaning:

```text
Tell me the travel time from every place to every other place.
```

### OSRM Trip Service

OSRM Trip attempts to solve the best order for visiting multiple places.

Use it when:

- The user has selected several destinations.
- The backend wants OSRM to suggest an efficient visit order.

Simple meaning:

```text
Here are all the places. Suggest a good order to visit them.
```

## Algorithm Recommendation

Lakbay should use a hybrid routing strategy. The goal is not to invent a custom
map engine, but to combine reliable route data with understandable fallback
logic.

Current implementation:

- OSRM Route is used for fixed-order route preview.
- OSRM Trip is used for suggested route order when available.
- Haversine distance is used as a fallback estimate.
- Haversine nearest-neighbor is used as the fallback optimization method.

Recommended enhancement path:

1. Keep OSRM Route and OSRM Trip for the current route endpoints.
2. Add OSRM Table later when the backend needs a full travel-time matrix.
3. Use nearest-neighbor to create a first route order when OSRM optimization is
   unavailable.
4. Add 2-opt improvement later to reduce route loops and inefficient backtracking.
5. Use exact small-set TSP-style optimization only for small destination sets
   when route accuracy matters more than simplicity.

Recommended first-choice algorithm:

```text
OSRM road duration data + nearest-neighbor ordering + optional 2-opt improvement
```

Reason:

- OSRM gives road-aware distance and duration.
- nearest-neighbor is easy to explain and test.
- 2-opt can improve obvious route loops without making the service hard to
  maintain.
- the existing route response can stay the same for Flutter.

Fallback behavior:

```text
If OSRM is unavailable, use Haversine distance and fallback speeds.
```

Do not treat fallback estimates as live traffic. They should be marked with
`is_estimated=true`.

## Recommended Routing Flow

For Lakbay, keep the routing flow understandable:

1. User selects destinations or accepts AI-generated destinations.
2. Backend loads each destination's coordinates.
3. Backend removes invalid or duplicate coordinates.
4. Backend uses Haversine for quick sanity checks.
5. Backend calls OSRM to estimate road distance and duration.
6. Backend returns an ordered route summary to Flutter.
7. Backend stores the final route summary when the itinerary becomes a trip.

## Current Development Choice

For early development, Lakbay will use the OSRM public/demo route service.

This is acceptable for experiments and low-volume testing, but it should not be
treated as the final production routing setup. Before production or formal
high-volume testing, decide whether to use a hosted routing provider or a
self-hosted OSRM server.

## Transportation Modes

Start with these modes:

- `driving`
- `walking`
- `public_transport`

OSRM commonly supports road-network profiles such as driving and walking,
depending on the hosted OSRM setup. Public transport is more complex because it
usually requires transit schedule data, so Lakbay should initially treat
`public_transport` as an estimated mode unless a proper transit data provider is
added later.

Recommended behavior:

- `driving`: use OSRM driving profile.
- `walking`: use OSRM walking profile if available.
- `public_transport`: use stored transportation rates and estimated durations,
  then clearly mark the result as estimated.

Planned Phase 15 travel categories:

- `land`
- `air`
- `sea`
- `mixed`

Recommended behavior:

- `land`: use OSRM when available, then Haversine fallback.
- `air`: use stored fare and duration data. Do not route with OSRM.
- `sea`: use stored fare and duration data. Do not route with OSRM.
- `mixed`: combine land route estimates with stored air or sea transportation
  segments.

This keeps route calculations honest. OSRM should not be used to estimate plane
or boat paths.

## Implemented API Endpoints

Phase 6 starts with stateless route responses. Route results are calculated and
returned to Flutter, but they are not saved to trips yet.

### Preview route

```text
POST /api/v1/routes/preview
```

Purpose:

```text
Given destination IDs and a travel mode, return the estimated route order,
distance, and duration without saving it permanently.
```

### Optimize route

```text
POST /api/v1/routes/optimize
```

Purpose:

```text
Given destination IDs, travel dates, and travel mode, return the best suggested
visit order.
```

### Attach route to itinerary

```text
POST /api/v1/itineraries/{itinerary_id}/route
```

Purpose:

```text
Generate and save a route summary for an itinerary.
```

This is deferred until Phase 7 because itinerary and trip persistence is not
implemented yet.

### Get trip route

```text
GET /api/v1/trips/{trip_id}/route
```

Purpose:

```text
Return the saved route summary for a trip.
```

This is deferred until Phase 7 because saved trip routes do not exist yet.

## Request Shape

Preview route:

```json
{
  "destination_ids": [1, 2, 3],
  "travel_mode": "driving",
  "origin": {
    "label": "Davao City",
    "lat": 7.1907,
    "lng": 125.4553
  },
  "return_to_origin": false
}
```

Optimize route:

```json
{
  "destination_ids": [1, 2, 3],
  "travel_mode": "driving",
  "origin": null,
  "return_to_origin": false,
  "preserve_first_destination": true
}
```

Request rules:

- `destination_ids` must contain active destination rows.
- Duplicate destination IDs are rejected.
- The default maximum is `10` destinations per route request.
- `travel_mode` can be `driving`, `walking`, or `public_transport`.
- `origin` is optional and is not saved as a destination.
- `return_to_origin=true` appends the origin when provided. If there is no
  origin, it returns to the first route stop.
- `preserve_first_destination` only applies to route optimization.

## Route Response Should Be Easy For Flutter

Return a clear shape:

```json
{
  "travel_mode": "driving",
  "route_provider": "osrm",
  "total_distance_km": 42.5,
  "total_duration_minutes": 88,
  "is_estimated": false,
  "stops": [
    {
      "order": 1,
      "destination_id": 1,
      "name": "Destination A",
      "lat": 7.1907,
      "lng": 125.4553
    }
  ],
  "legs": [
    {
      "from_destination_id": 1,
      "to_destination_id": 2,
      "distance_km": 12.4,
      "duration_minutes": 25
    }
  ],
  "warnings": []
}
```

Keep route responses simple first. Add map polylines later only when Flutter
needs them.

## Environment Variables

Use these variables in `.env`:

```env
OSRM_BASE_URL=https://router.project-osrm.org
OSRM_REQUEST_TIMEOUT_SECONDS=30
OSRM_PROFILE_DRIVING=driving
OSRM_PROFILE_WALKING=walking
ROUTE_MAX_DESTINATIONS=10
```

`OSRM_BASE_URL` may point to the public demo server during development. Before
production or formal high-volume testing, use a hosted routing provider or a
self-hosted OSRM server.

If `OSRM_BASE_URL` is missing or OSRM fails, the backend returns a Haversine
estimate with `is_estimated=true`.

## Testing

Run the Phase 6 tests:

```bash
python -m pytest tests/test_phase6_routes.py -q
```

Run the full suite:

```bash
python -m pytest -q
```

The route tests mock OSRM. They do not call the public demo server.

## Edge Cases

The route service should handle:

- A destination missing coordinates.
- Only one destination selected.
- Duplicate destinations.
- OSRM being unavailable.
- OSRM returning no route.
- Very far destinations that do not make sense for one day.
- Travel mode unsupported by the configured OSRM server.

## Storage Recommendation

Do not store every raw OSRM response at first. Phase 6 does not store route
results at all. When trip persistence is implemented later, store the useful
summary:

- Trip or itinerary ID.
- Travel mode.
- Ordered stops.
- Total distance.
- Total duration.
- Route provider.
- Whether the route is estimated.
- Creation time.

Raw provider responses can be logged later if debugging or research metrics
require them.
