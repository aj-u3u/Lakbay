# Routing Guide

This document explains how Lakbay should handle route planning in a simple,
implementation-ready way.

Source: [OSRM API documentation](https://project-osrm.org/docs/)

## Approved current scope — 10 November 2026

Use the saved place pin for approximate route planning, Top 5 travel estimates,
and AI itinerary context. A separately verified visitor arrival point is not a
requirement for this version. Defer its admin editor and retain the existing
optional fields, validation and compatibility with reviewed arrival data.

Current services already fall back to place pins. Keep the approximation labels,
warnings, and suppression of turn-by-turn steps for unverified arrivals. An OSRM
road result can have `is_estimated=false` for its road calculation while
`arrival_points_verified=false`; it is still an approximate approach to the place.
Read both the coordinate basis and verification status when presenting it.
Unreachable results and straight-line fallbacks must retain their own labels;
a map pin does not prove visitor access, opening status or a ferry crossing.

## What Routing Means In Lakbay

### Saved-trip route preservation — approved 10 November 2026

The user approved correcting the traveler display while deferring deployment
and phone checks. This fits the existing route/trip/planning phases and uses the
current trip response and route APIs; it adds no database fields or endpoint.

The traveler retains the full saved route and its planning snapshot in
`TripRoutePlan`. A top-level saved `route` takes precedence over an older planning
preview. The saved stop list supplies visit order, starting point, mode and
whether the last leg returns to the start. When there is no route summary,
planning state supplies available choices without inventing a route.

Opening a saved trip restores that snapshot without an OSRM request. The map
keeps its recorded geometry, legs, estimates and warnings; no geometry is
fabricated if none was saved. Unverified arrivals do not gain maneuver steps.
Saved-trip GPS tracking does not trigger automatic rerouting.

The traveler can explicitly request **Recalculate route**. That action uses
`POST /routes/preview`, the chosen start/mode/return choice, and the saved visit
order. Its result is labeled **Recalculated preview** and does not write to the
trip or replace its saved itinerary. A failed request leaves the displayed route
intact. **Show saved route** restores the original snapshot. Session refresh
retains the same request choices. Existing callers that request optimization
continue to use `/routes/optimize` by default.

Implementation is in the sibling traveler application's `lib/models/trip_route_plan.dart`,
`lib/providers/route_ways_controller.dart`, `lib/providers/live_route_tracker.dart`,
`lib/services/api_service.dart` and the existing trip dashboard. Regressions cover
saved order/return/mode, trip reloading and copying, stale requests, missing
geometry, session refresh, explicit recalculation/restoration/failure, GPS and
narrow-screen layouts. This does not implement accommodation selection, the
pre-save itinerary/route review, multi-day scheduling or a new optimizer.

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

### Attraction and arrival coordinates

An attraction coordinate identifies the place for discovery, recommendations,
and an approximate itinerary map. A visitor arrival coordinate identifies the
public gate, parking area, trailhead, or pier where a route should end. Keep
these as separate facts, with a source and review date for each arrival point.

An attraction coordinate may support a provisional stop order or distance
estimate when the result is labeled as a planning estimate. It must not be
presented as a verified arrival point,
final travel time, or turn-by-turn destination. If opening status or required
booking or permits are unresolved, the itinerary should ask the traveler to
confirm them before the trip.

For waterfalls, mountain resorts, beaches with multiple access points, and
islands, use a verified visitor arrival point before giving road directions.
Represent a ferry or boat connection as a separate leg between verified piers.
Do not route a road profile across that connection. A destination reported
closed or awaiting reopening should not be offered as an available stop until
its access is reconfirmed.

The route service uses `Destination.arrival_lat/lng` when an admin has marked
the destination `route_ready=true` with an arrival source URL and verification
time. Otherwise it uses `Destination.lat/lng` and adds a planning-preview
warning. `route_ready` records that the arrival coordinate was reviewed; it
does not establish current opening hours, permit availability, or boat service.
Those facts still need a separate access check before travel.

### API fields for the map and itinerary

The admin destination create/update API accepts `arrival_lat`, `arrival_lng`,
`arrival_source_url`, `arrival_verified_at`, and `route_ready`. Both coordinates
must be supplied together. Setting `route_ready=true` requires coordinates,
source URL, and verification time. Changing a route-ready arrival coordinate
requires a fresh source URL and verification time in the same update.

`POST /api/v1/routes/preview` keeps the requested stop order;
`POST /api/v1/routes/optimize` suggests an order. Both responses include:

| Field | Use |
| --- | --- |
| `stops[].coordinate_basis` | `origin`, `verified_arrival`, or `attraction` |
| `arrival_points_verified` | True only when every destination stop uses a verified arrival point |
| `polyline`, `polyline_encoding` | Draw the returned encoded polyline (`polyline5`) on a map when the provider supplies one |
| `legs[].distance_km`, `legs[].duration_minutes` | Show distance and ETA for each stop pair |
| `legs[].steps[]` | Show maneuver text, meters, and seconds only for routes with verified arrival points |
| `order_method` | How the stop order was chosen: `requested` (kept as given), `exact` (every order compared with OSRM travel times), `osrm_trip` (OSRM's suggested order) or `nearest_neighbor_2opt` (straight-line estimate when OSRM is unavailable, and for public transport) |
| `is_estimated`, `route_provider`, `warnings` | Explain provider quality and fallback estimates |
| `ferry_crossings[]` | Boat parts of an OSRM road route: `name`, `distance_km`, `duration_minutes`, boarding point `from_lat/from_lng` and landing point `to_lat/to_lng`. Each crossing also adds a warning to check the schedule and fare |

OSRM routes are requested with `overview=full`, so the `polyline` follows the
road at street zoom. The earlier `overview=simplified` line had about 25
points for a 20 km route and strayed up to about 95 m from the road, which was
visible on the live map and close to the 100 m off-route threshold.

OSRM's driving profile can include ferries, such as the Sasa – Kinawitnon RoRo
crossing to Samal. The route still reports `travel_mode=driving`; the boat
part is listed in `ferry_crossings` instead of being hidden. The crossing time
does not include waiting at the pier. Google Routes responses do not yet report
ferries.

OSRM and configured Google Routes supply road geometry and directions for
driving. OSRM walking support depends on the configured walking profile.
Public transport and Haversine fallback remain estimates without road geometry
or turn-by-turn directions. When an attraction coordinate is used, the road
polyline may still be shown as a provisional planning line; suppress navigation
instructions in the UI. A saved trip route stores the same stop basis, geometry,
and steps in `trip_routes`, so an itinerary can reopen its route snapshot. The
saved-route API checks any claimed verified arrival coordinate against the
admin-reviewed destination before accepting verified directions.

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
- The API needs a road distance and duration estimate. Traveler directions
  additionally require a verified arrival point.
- The user wants to preview a selected itinerary route.

Simple meaning:

```text
Here are the stops in this exact order. Tell me the road distance and travel
time.
```

### OSRM Table Service

OSRM Table creates a distance and duration matrix between many places. Lakbay
uses it (`OSRMClient.matrix`) for the exact stop-order search described below.

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
- A request to optimize one destination from an origin also uses OSRM Route:
  there is no destination order to optimize. This applies to the traveler
  Location & Route card and checks the road snap at both endpoints.
- `POST /routes/optimize` for driving and walking chooses the stop order in
  three steps, and reports the one it used in `order_method`:
  1. **Exact** (`exact`): with 11 stops or fewer (the 10-destination limit plus
     the traveler's start), one OSRM Table request gives the travel time between
     every pair of stops, and the backend compares every possible order with
     Held-Karp dynamic programming. The cheapest order wins, using one-way road
     times, so it respects direction. OSRM Route then draws that order. If OSRM
     reports no road between any pair of stops, or the Table or Route request
     fails, this step is skipped.
  2. **OSRM Trip** (`osrm_trip`): used for more than 11 stops, or when the exact
     step was skipped. OSRM suggests an order that is not guaranteed to be the
     shortest.
  3. **Nearest neighbor plus 2-opt** (`nearest_neighbor_2opt`): used when OSRM
     is unavailable. The backend builds an order over Haversine distances by
     always going to the nearest unvisited stop, then reverses sections of the
     route wherever that shortens it, which removes crossed paths. It is
     estimated (`is_estimated=true`).
- `public_transport` is not routed on roads. It uses step 3 over stored
  coordinates.
- `POST /routes/preview` and the one-destination-from-origin case keep the
  requested order and report `requested`.
- Haversine distance is also used as the fallback distance estimate.

All ordering methods keep the traveler's start first when an origin is given or
`preserve_first_destination` is true, and when `return_to_origin` is true the
trip's last leg back to the start is counted in the comparison. When the
requested order is just as good as the best order found, it is kept, so a list
is not reshuffled for no gain. The ordering code is in
`app/features/routes/ordering.py` and is tested in `tests/test_route_ordering.py`.

Limits to know about:

- A normal optimized route makes two OSRM requests (Table, then Route) instead
  of one. If OSRM is slow or down, both can time out before the estimate is used.
- Both ordering methods run inside the request handler. The exact search takes
  about 0.16 seconds for 11 stops and 2-opt about 0.5 seconds for the 26-stop
  worst case, so consider moving them to a worker thread if traffic grows.
- Live traffic (`use_live_traffic`) only adds ETA to the chosen order. It does
  not change which order is chosen.

Reason for this design:

- OSRM gives road-aware travel times, so the exact comparison reflects real
  roads and one-way streets, not straight lines.
- The exact search stays fast because route requests are small.
- Nearest neighbor with 2-opt is easy to explain and test, and still removes
  obvious route loops when roads are unavailable.
- The route response keeps its original fields while adding `order_method`,
  optional geometry, directions, and arrival verification for Flutter.

Fallback behavior:

```text
If OSRM is unavailable, use Haversine distance and fallback speeds, ordering
stops with nearest neighbor plus 2-opt.
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

OSRM can prepare separate driving and walking graphs, depending on the hosted
setup. The service URL must actually point to the matching graph; a different
profile word in the URL does not switch graphs. Public transport is more complex
because it usually requires transit schedule data, so Lakbay should initially treat
`public_transport` as an estimated mode unless a proper transit data provider is
added later.

Recommended behavior:

- `driving`: use OSRM driving profile.
- `walking`: use a separately configured OSRM foot-profile service if available.
- `public_transport`: use stored transportation rates and estimated durations,
  then clearly mark the result as estimated.

In the planning preview, a hired car routes as `driving` when every selected
catalog choice is one. A hired car is a catalog vehicle whose transport mode is
`private_vehicle`, `private vehicle`, `private car`, `car rental` or `taxi`, or
whose vehicle type names a taxi (the live Taxi record uses `public_transport`).
Its operator drives, so it needs no traveler road-access confirmation and gets
no traveler fuel estimate; its listed fare is the cost. A hired car selected
with shared transport such as a bus or van stays an estimated
`public_transport` route.

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
- Each signed-in user may make `ROUTE_REQUESTS_PER_MINUTE` (default `10`)
  preview and optimize requests combined in a rolling minute. Further requests
  return `429` with error code `route_rate_limited`, a `Retry-After` header,
  and `details.retry_after_seconds`. The limit is per process unless
  `PROVIDER_USAGE_REDIS_URL` is configured. It protects the routing provider
  when the traveler app requests a new route during live tracking.

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

The response now includes an optional encoded polyline and per-leg directions
when the route provider supplies them; see the API field table above.

## Environment Variables

Use these variables in `.env`:

```env
OSRM_BASE_URL=https://router.project-osrm.org
OSRM_WALKING_BASE_URL=
OSRM_REQUEST_TIMEOUT_SECONDS=30
OSRM_PROFILE_DRIVING=driving
OSRM_PROFILE_WALKING=walking
ROUTE_MAX_DESTINATIONS=10
ROUTE_REQUESTS_PER_MINUTE=10
```

`OSRM_BASE_URL` may point to the public demo server during development. Before
production or formal high-volume testing, use a hosted routing provider or a
self-hosted OSRM server.
The deployed service needs its own `OSRM_BASE_URL` environment variable; a
developer's local `.env` does not configure Render. If Drive shows
`route_provider=haversine` and `is_estimated=true`, check that setting and the
backend's `Driving OSRM route lookup failed` log before treating the result as
a road route.

`OSRM_BASE_URL` serves driving. Configure `OSRM_WALKING_BASE_URL` only with a
separately verified foot-profile graph. The public demo's `/walking/` path is
not sufficient evidence of a walking graph. Without a walking service, walking
returns a Haversine estimate with `is_estimated=true` and no turn-by-turn line.
If the selected service is missing or fails, the backend returns the same
clearly labeled estimate.

**Walking service in use (11 November 2026):** Render sets
`OSRM_WALKING_BASE_URL=https://routing.openstreetmap.de/routed-foot`, the
FOSSGIS community foot-profile server. A test walk in central Davao City
returned 1,416 m in 18.9 minutes (4.5 km/h) there, while the public demo's
`/walking/` path returned the 1,449 m car route in 3.6 minutes. The FOSSGIS
server also answered Trip and Table requests. It is a fair-use service without
an uptime guarantee (see its
[usage policy](https://routing.openstreetmap.de/about.html)), so the OSRM
client identifies itself with a `Lakbay-API` User-Agent, and failures still
fall back to the labeled Haversine estimate. The local `.env` leaves the
setting empty unless a developer adds it.

For route previews, the OSRM client checks the provider's waypoint snap
distances. Every requested point must have a returned waypoint within 250 meters.
A one-destination route from an origin uses the same check even when the client
calls `/routes/optimize`. If the driving lookup fails, the backend logs the
OSRM error and returns a labeled Haversine estimate with no road geometry.
A missing waypoint or a more distant road snap makes the provider route
unconfirmed, so the route service returns a clearly labeled estimate instead.
This avoids presenting a road path to a nearby but different location as a
confirmed route to a visitor entrance. The limit is a conservative planning
guard, not a guarantee that a gate is open or that the last approach is usable.

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

Phase 6 remains stateless and does not store raw OSRM responses. Phase 7 stores
the selected route summary in `trip_routes`, including its line and directions:

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
