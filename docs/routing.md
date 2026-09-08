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

## Suggested API Endpoints

These endpoint names are planning suggestions only.

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

### Get trip route

```text
GET /api/v1/trips/{trip_id}/route
```

Purpose:

```text
Return the saved route summary for a trip.
```

## Route Response Should Be Easy For Flutter

Return a clear shape:

```json
{
  "travel_mode": "driving",
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
  ]
}
```

Keep route responses simple first. Add map polylines later only when Flutter
needs them.

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

Do not store every raw OSRM response at first. Store the useful summary:

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
