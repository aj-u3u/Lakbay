# Real-time live position tracking plan

**Status:** Stage 1 approved by the user on 7 November 2026 and recorded as
[Phase 15H](core_focus.md) in `core_focus.md`. Stages 2–4 are not approved.
Each stage needs separate approval under `AGENTS.md`. Implementation progress
is noted in section 5.7.

**Repositories:** backend `lakbay_backend_final` (B) and traveler app
`UI_FOR_LAKBAY` (T). The admin app is not affected.

## 1. Summary

Today the traveler app reads GPS only to choose a route's starting point. The
map does not follow the traveler, the route is not recalculated while moving,
tracking stops when the screen closes, and nothing is shared with the group.

This plan makes position tracking real-time in four stages. Each stage is
useful on its own and can stop there.

| Stage | What the traveler gets | Repos | Schema change | Size |
| --- | --- | --- | --- | --- |
| 1. Live position on the route map | A moving "you are here" dot, follow-me camera, remaining distance and time, automatic new route when off course, arrival notice | T, plus a small B rate limit | None | Medium |
| 2. Live trip progress | "Start trip" for a saved multi-stop trip: next stop, progress through stops, mark arrived or skipped | T (uses existing B endpoints) | None | Medium |
| 3. Background tracking | Tracking continues with the screen off, with a visible notification and stop switch | T | None | Medium |
| 4. Live replanning | Suggested schedule changes after delays | B and T | Per proposal | Large; already planned as Step 9 of the [multi-day proposal](multiday_live_trip_proposal_2026-11-04.md#L384) |

**Out of scope:** sharing a traveler's live location with other people,
including group members. This keeps the multi-day proposal's rule that members
see accepted plan revisions, not each other's raw location.

**Recommendation:** approve Stage 1 first. Decide on Stages 2–3 after Stage 1
has been tested on a real phone.

## 2. Phase alignment review

Format from [new_feature.md](new_feature.md).

```text
Feature:            Real-time live position tracking
Current phase:      Phase 2 (destination data and arrival verification), with
                    Phase 14 hardening and small Phase 15 increments
Requested phase:    Not stated
Phase alignment:    Stages 1–2: Fits current phase if reduced
                    Stage 3:    Requires new phase
                    Stage 4:    Better for existing later plan (proposal Step 9)
Recommended phase:  Add "Phase 15H: Live position on route map" to
                    docs/core_focus.md for Stages 1–2. Keep Stages 3–4 with the
                    multi-day proposal (Steps 9–10), or add Phase 16 if approved.

Reason:
Stages 1–2 reuse the existing GPS stream, route endpoints, saved trip routes
and trip status. They add no tables and no new external service. Stage 3 adds
background permissions, store review and a stricter privacy notice, which
matches the proposal's later steps.

Possible database changes:  None for Stages 1–3.
Possible environment variables:
  Stage 1: ROUTE_REQUESTS_PER_MINUTE (optional; has a default).
Recommendation:     Approve Stage 1 scope first.
```

## 3. What exists today

Checked on 7 November 2026 against local code. The traveler app checkout had
uncommitted changes; they are included in what was read.

| Area | Current behavior | Where |
| --- | --- | --- |
| GPS stream | Destination details, planner results and group dashboard subscribe to `Geolocator.getPositionStream` (high accuracy, every 10 m) while open | T `lib/screens/destinations/destination_details_screen.dart:154`, `lib/screens/planner/planner_results_screen.dart:126`, `lib/screens/collaboration/group_dashboard_screen.dart:230` |
| Use of new positions | Stored in screen state only; the route is not reloaded | Same files; `_reloadRoutes` runs on load or start/mode change |
| Map screen | Receives a fixed `origin` in `RouteMapArgs`; does not read GPS | T `lib/screens/maps/route_map_screen.dart` |
| Map widget | Draws origin, stops, destination, entrance and route; refits the camera when its inputs change | T `lib/widgets/maps/lakbay_route_map.dart` (`_signature`, `didUpdateWidget`) |
| Route loading | `RouteWaysController.load(origin:…, force:)` fetches drive/walk/commute ways | T `lib/providers/route_ways_controller.dart:89` |
| Route geometry | Backend returns `polyline5`; the app decodes it | T `lib/models/route_geometry.dart` (`decodePolyline5`) |
| Route API | `POST /api/v1/routes/preview` and `/routes/optimize` with `origin {label, lat, lng}`, `destination_ids` (1–25), `travel_mode` | B `app/features/routes/schemas.py` |
| Route rate limit | **None** on `/routes/*`. Only the planning preview has a per-user limiter (`PLANNING_ROUTE_REQUESTS_PER_MINUTE`, default 10) | B `app/features/routes/router.py`, `app/features/planning/dependencies.py:67` |
| Trip status | `planned`, `ongoing`, `completed`, `archived`; changeable through `PATCH /api/v1/trips/{id}` | B `app/features/trips/schemas.py` |
| Saved route | `GET /api/v1/trips/{id}/route` returns the stored stops, legs and geometry | B `app/features/trips/models.py` (`TripRoute`) |
| Android | `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` only; no background or foreground-service permission | T `android/app/src/main/AndroidManifest.xml` |
| iOS | `NSLocationWhenInUseUsageDescription` and the older `NSLocationAlwaysUsageDescription`; no `NSLocationAlwaysAndWhenInUseUsageDescription`; no background mode | T `ios/Runner/Info.plist` |
| Backend location storage | None. No endpoint, table, or socket receives traveler positions | B `app/` |

Known limits that affect tracking:

- **Arrival points:** 0 of 30 destinations have a verified arrival point, so
  turn-by-turn steps are hidden and routes end at attraction pins.
- **Walking:** no foot-profile routing service is configured, so walking routes
  are straight-line estimates without a road line.
- **Routing provider:** the public OSRM demo server is for light use only
  ([usage policy](https://github.com/Project-OSRM/osrm-backend/wiki/Demo-server)).
  Frequent rerouting must be limited.
- **Hosting:** Render's free instance sleeps when idle; the first request after
  a quiet period can take about 45 seconds.

## 4. Goals, non-goals and principles

**Goals**

1. The traveler sees their position move on the map in close to real time
   (about every 2–5 seconds or 5 m of movement while the map is open).
2. Remaining distance and time update as they move.
3. A new route is fetched automatically when they leave the route, without
   overloading the backend or OSRM.
4. The app says clearly when GPS is weak, denied, stale or estimated.

**Non-goals for Stages 1–3**

- Turn-by-turn voice navigation. Hand off to Google Maps for that if needed.
- Storing a location history.
- Sharing location with other people, including group members (out of scope
  for this plan).
- Changing a saved itinerary automatically (Stage 4 only suggests changes; the
  traveler must accept them).

**Principles**

- **Opt-in and visible.** Tracking starts only from a clear action and shows a
  "Live" indicator while running. One tap stops it.
- **Least data.** Positions stay on the phone. The only position sent to the
  backend is a route request's starting point, which already happens today.
- **Honest labels.** Estimated routes, attraction pins and stale GPS are always
  labeled; an estimate is never shown as navigation.
- **Battery-aware.** High-accuracy GPS runs only while needed and stops when
  the screen closes (Stages 1–2) or the trip ends (Stage 3).

## 5. Stage 1 — live position on the route map

### 5.1 Traveler flow

1. The traveler opens a route from destination details, planner results or the
   group dashboard. The map screen opens as today.
2. If location permission is granted, a blue dot with an accuracy circle
   appears and the camera follows it. A **Live** badge shows in the top bar.
3. A bottom card shows **remaining distance**, **time left** and the route
   source ("Road route", "Estimate").
4. Panning the map turns follow-me off; a **Re-center** button turns it back on.
5. If the traveler leaves the route, a banner says "Off route — finding a new
   route…". The new road line replaces the old one when it arrives. The old
   line stays visible until then.
6. Near the destination the card shows **"You've arrived"** (or "You're near
   the destination" when only an attraction pin is known).
7. Leaving the screen stops GPS.

States the screen must handle:

| State | What the traveler sees |
| --- | --- |
| Permission not yet asked | Map as today; button "Show my position" |
| Permission denied | Notice with "Open settings"; map works without the dot |
| Location services off | Notice "Turn on location" |
| Waiting for first fix | Dot hidden; "Finding your location…" |
| Weak GPS (accuracy worse than 50 m) | Dot shown with a large circle; "Weak GPS signal" |
| Stale GPS (no update for 30 s) | Dot greyed; "Location not updating" |
| Offline or backend error during reroute | Keep old route; "Couldn't update the route. Retrying…" |
| Estimated route (walking, public transport, fallback) | Straight-line remaining distance; label "Estimate"; no off-route rerouting |

### 5.2 Technical design (traveler app)

**New `LiveLocationService`** (`lib/services/live_location_service.dart`)

- Wraps `Geolocator.getPositionStream` with platform settings:
  - Android: `AndroidSettings(accuracy: high, distanceFilter: 5,
    intervalDuration: 2 s)`.
  - iOS: `AppleSettings(accuracy: bestForNavigation, distanceFilter: 5,
    activityType: automotiveNavigation or fitness for walking,
    pauseLocationUpdatesAutomatically: true)`.
- Filters readings: drop accuracy worse than 50 m (keep for the "weak" state
  only), drop timestamps older than 30 s, drop jumps faster than 200 km/h.
  (Changed from 10 s during implementation: GPS time and the phone clock can
  differ by several seconds, and 10 s risked dropping every reading on some
  phones. 30 s still drops cached fixes from earlier trips.)
- Exposes a broadcast stream of `LivePosition {lat, lng, accuracyM, speed,
  heading, timestamp}` plus a status (`waiting`, `ok`, `weak`, `stale`,
  `denied`, `serviceOff`).
- Pauses when the app goes to the background (`AppLifecycleState.paused`) and
  resumes on return. One shared instance; the three existing screens can move
  to it later instead of keeping separate streams.

**New route progress logic** (`lib/models/route_progress.dart`, pure Dart,
no Flutter imports so it is easy to unit test)

- `project(position, polyline)`: nearest point on the route line and the
  distance from it.
- `remainingDistance`: length of the line from the projected point to the end.
- `timeLeft`: remaining distance × (route duration ÷ route distance), labeled
  as an estimate. The backend's leg durations are used where available.
- `OffRouteDetector`: off route when the distance from the line is more than
  the threshold for 3 consecutive good readings (or 15 s). Back on route
  resets it.
- `ArrivalDetector`: arrived when within the arrival radius for 2 consecutive
  readings.

**Map widget changes** (`lib/widgets/maps/lakbay_route_map.dart`)

- Add a separate `livePosition` input that draws the dot, heading arrow and
  accuracy circle.
- Keep `livePosition` **out of** `_signature()`. Otherwise every GPS update
  would refit the camera to the whole route.
- Add `followLive` mode: move the camera to the dot on each update
  (`MapController.move`), and report a user pan so the screen can turn follow
  off.

**Map screen changes** (`lib/screens/maps/route_map_screen.dart`)

- Subscribe to `LiveLocationService` in `initState`; cancel in `dispose`.
- Hold `followLive`, the latest position, progress values and reroute state.
- Show the Live badge, progress card, Re-center button and state banners.

**Rerouting** (`lib/providers/route_ways_controller.dart`)

- Add `reroute(LatLng from)`: calls the existing `load(origin: from,
  force: true)` for the selected way only, keeps the previous way while
  loading, and swaps when ready.
- Reroute policy (all must be true): off-route detector fired; selected way is
  a provider road route (`is_estimated=false`); at least 60 s since the last
  reroute; fewer than 20 reroutes this session; device online.

**Proposed starting values** (to tune after field tests)

| Setting | Driving | Walking |
| --- | --- | --- |
| GPS updates on phones | Every 2 s, even when still | Every 3 s, even when still |
| GPS distance filter (browsers only) | 5 m | 3 m |
| Ignore reading if accuracy worse than | 50 m | 30 m |
| Off-route distance | 100 m | 50 m (only when a real walking route exists) |
| Off-route confirmation | 3 readings or 15 s | 3 readings or 20 s |
| Reroute cooldown | 60 s | 60 s |
| Max reroutes per session | 20 | 20 |
| Arrival radius, verified arrival point | 50 m | 30 m |
| Arrival radius, attraction pin only | 150 m, shown as "near" | 100 m, shown as "near" |
| Stale after no update for (phones only) | 30 s | 30 s |
| Ferry zone around the pier-to-pier line | 500 m | 500 m |

### 5.3 Backend changes (small)

AGENTS.md requires rate limits on expensive routing endpoints, and rerouting
will add calls. Proposed:

- Add a per-user limiter to `POST /api/v1/routes/preview` and
  `/routes/optimize`, reusing the pattern in
  `app/features/planning/dependencies.py`.
- New optional setting `ROUTE_REQUESTS_PER_MINUTE`, default **10**. Exceeding
  it returns `429` with code `route_rate_limited` and a `Retry-After` header.
- No change to request or response shapes. No migration.

Note: the limiter is in-memory per process. With one Render instance that is
acceptable; with several workers, use the existing optional Redis provider
backing (`PROVIDER_USAGE_REDIS_URL`) or accept per-worker limits.

### 5.4 Files

| Repo | File | Change |
| --- | --- | --- |
| T | `lib/services/live_location_service.dart` | New |
| T | `lib/models/route_progress.dart` | New |
| T | `lib/widgets/maps/lakbay_route_map.dart` | Live dot, accuracy circle, follow mode |
| T | `lib/screens/maps/route_map_screen.dart` | Subscribe, card, badges, reroute trigger |
| T | `lib/providers/route_ways_controller.dart` | `reroute()` |
| T | `lib/services/api_service.dart` | Handle `429 route_rate_limited` (wait and retry once) |
| T | `test/route_progress_test.dart` | New |
| T | `test/live_location_service_test.dart` | New |
| T | `test/route_map_live_test.dart` | New |
| B | `app/features/routes/router.py`, `app/features/routes/dependencies.py` (new or existing), `app/core/config.py` | Route rate limit |
| B | `.env.example`, `docs/routing.md` | Document the limit |
| B | `tests/test_phase6_routes.py` | 429 test |

### 5.5 Tests

**Unit (T):** projection onto a polyline; remaining distance on straight,
curved and looping routes; off-route detector ignores one bad reading and
fires after the confirmation count; cooldown and session cap; arrival detector
for verified point and attraction pin; reading filter drops inaccurate, stale
and impossible-speed readings.

**Widget (T):** dot appears from a fake position stream; camera follows until
the user pans; Re-center restores follow; weak/stale/denied banners; estimate
label on a route without a road line; GPS subscription is cancelled on
dispose.

**Backend (B):** 11th route request in a minute returns `429` with
`Retry-After`; requests from a different user are not affected; existing
route tests still pass.

**Manual, on device:**

1. Android emulator: Extended controls → Location → Routes, play a GPX route
   that leaves the road line halfway. Expect one reroute, not many.
2. iOS simulator: Features → Location → Freeway Drive.
3. Real phone, Davao City: drive a 3–5 km route to a Group A destination
   (for example People's Park); walk the last part; check battery use over
   20 minutes.
4. Turn airplane mode on mid-route; expect the old route to stay and a retry
   notice.

### 5.6 Done when

- The dot moves within about 5 seconds of real movement while the map screen
  is open.
- Remaining distance and time change as the traveler moves.
- Leaving the route by more than the threshold triggers at most one new route
  per minute, and the new line is shown.
- Weak, stale, denied, offline and estimated states are labeled.
- GPS stops when the map screen closes (checked in the widget test and in the
  Android location indicator).
- All existing T and B tests still pass; the new tests pass.

### 5.7 Implementation progress (8 November 2026)

Stage 1 code and automated tests are written in both working trees. Nothing is
committed, pushed or deployed. The on-device checks in section 5.5 have not
been run.

Verification on 8 November 2026: backend `python -m pytest -q` passed
460 tests (5 new); traveler app `flutter analyze` reported no issues and
`flutter test` passed 121 tests (39 new). The full app run first exposed a
pending permission-check timer when the map closed during a check; the check
is now cancelled on close and covered by a test.

**Fixes after the first screenshot test (8 November 2026).** A Samal route
showed a line cutting across buildings and "Location not updating" while
still. Three fixes followed:

1. **Road line detail (B).** OSRM requests now use `overview=full` instead of
   `simplified`. Measured from Davao City center: Philippine Eagle Center
   went from 24 to 941 points and Eden Nature Park from 26 to 1,009; the
   simplified lines strayed up to 95 m and 84 m from the road.
2. **Ferry crossings (B and T).** OSRM's driving profile includes the
   Sasa – Kinawitnon RoRo ferry (1.6 km, about 20 min) on routes to Samal, and
   the backend had reported it as plain driving. The response now lists
   `ferry_crossings` with boarding and landing points and adds a warning. The
   app shows "Ferry: … · ≈ 20 min" and "On the ferry: …", and pauses
   off-route checks within 500 m of the pier-to-pier line.
   `lib/services/api_service.dart` gained one line to pass the field through.
3. **False "Location not updating" (T).** Phones now report on a time
   interval with no distance filter, and iOS no longer pauses updates
   automatically. Browsers only report changes, so the stale state is turned
   off there.

After these fixes: backend 465 tests passed (5 new in
`tests/test_route_ferry_crossings.py`); app `flutter analyze` clean and
126 tests passed.

**Backend (B)**

| File | Change |
| --- | --- |
| `app/core/config.py` | `route_requests_per_minute` (default 10) |
| `app/features/routes/dependencies.py` | New per-user limiter using the existing `ProviderLimiter` (`app/core/provider_usage.py`) |
| `app/features/routes/router.py` | Limit applied to `/routes/preview` and `/routes/optimize` |
| `tests/conftest.py` | Clears the route limiter between tests |
| `tests/test_route_rate_limit.py` | New: 429 with `Retry-After`, shared preview/optimize budget, per-user isolation, unauthenticated requests, window expiry |
| `.env.example`, `docs/routing.md` | Document `ROUTE_REQUESTS_PER_MINUTE` |

Release note: `app/core/provider_usage.py` exists only in the local working
tree, not on `origin/main`. The route limit must be released together with it.

**Traveler app (T)**, branch `codex/step1-shared-place-basket`, uncommitted

| File | Change |
| --- | --- |
| `lib/models/live_position.dart` | New: reading model and filter |
| `lib/models/route_progress.dart` | New: projection, remaining time, off-route and arrival detectors, reroute gate, tuning values |
| `lib/services/live_location_service.dart` | New: foreground GPS wrapper; iOS background updates explicitly off |
| `lib/providers/live_route_tracker.dart` | New: progress, off-route, limited reroute, arrival |
| `lib/providers/route_ways_controller.dart` | `reroute()` keeps the current line while loading |
| `lib/widgets/maps/live_location_marker.dart` | New: live dot and start ring |
| `lib/widgets/maps/lakbay_route_map.dart` | Live dot, accuracy circle, follow mode, hand-move callback |
| `lib/screens/maps/route_map_screen.dart` | Tracking lifecycle, notices, progress pill, Re-center button |
| `test/live_tracking_fakes.dart`, `test/route_progress_test.dart`, `test/live_location_service_test.dart`, `test/live_route_tracker_test.dart`, `test/route_map_live_test.dart` | New tests and fakes |

Differences from section 5.4:

- `lib/services/api_service.dart` was not changed. A rate-limited or failed
  reroute returns no route, the old line stays, and the next attempt waits for
  the 60 s cooldown, which is at least the server's largest `Retry-After`.
- The tracking logic lives in a separate `LiveRouteTracker` so it can be
  tested without a device; the screen only displays it.
- The backend rate-limit test is a new file instead of an addition to
  `tests/test_phase6_routes.py`, which has uncommitted local changes.

## 6. Stage 2 — live trip progress for a saved trip

**Depends on:** Stage 1.

### 6.1 Traveler flow

1. On a saved trip, the traveler taps **Start trip**. The app sets the trip
   status to `ongoing` through the existing `PATCH /api/v1/trips/{id}`.
2. A Live Trip screen loads the saved route (`GET /api/v1/trips/{id}/route`)
   and shows the map from Stage 1 plus a **Next stop** card.
3. Arrival at a stop is detected (Stage 1 arrival rule) and the traveler
   confirms **Arrived**. They can also tap **Skip** or **Taking a break**.
4. After each stop, the next leg becomes active. If the traveler is far from
   the saved route, the app offers a new route from their position to the next
   stop (Stage 1 reroute rules).
5. **End trip** sets the status to `completed`, which also unlocks post-trip
   reviews.

### 6.2 Design notes

- Stop progress (arrived, skipped, current stop) is stored **on the phone**
  for this stage, keyed by trip ID. No new table.
- Members are notified through the existing trip-update notification when the
  status changes. Check the wording ("Trip started") before release.
- Only the trip owner can start or end the trip unless the existing member
  rules already allow members to patch status; confirm in
  `app/features/trips/service.py` before implementation.
- Manual buttons cover the case where GPS is denied, matching the proposal's
  "I'm here", "Taking a break" and "Leaving now".

### 6.3 Files

T new `lib/screens/trips/live_trip_screen.dart`; T
`lib/screens/trips/trips_screen.dart` (Start trip button); T
`lib/services/api_service.dart` (status patch, saved route fetch if missing);
T new `test/live_trip_screen_test.dart`. Backend: none expected; confirm
status-transition rules.

### 6.4 Done when

- A saved 3-stop trip can be started, progressed stop by stop, and ended.
- Arrived and Skip work with GPS on and off.
- Ending the trip sets `completed` and stops GPS.

## 7. Stage 3 — background tracking

**Depends on:** Stage 2 working in the foreground.

### 7.1 Changes

- **Android** (`android/app/src/main/AndroidManifest.xml`):
  `ACCESS_BACKGROUND_LOCATION`, `FOREGROUND_SERVICE`,
  `FOREGROUND_SERVICE_LOCATION`; use Geolocator's
  `AndroidSettings(foregroundNotificationConfig: …)` so a notification shows
  "Lakbay+ is tracking your trip" with a Stop action. Ask for "Allow all the
  time" separately, after foreground permission, with an explanation screen.
- **iOS** (`ios/Runner/Info.plist`): add
  `NSLocationAlwaysAndWhenInUseUsageDescription` and `UIBackgroundModes` →
  `location`; set `allowBackgroundLocationUpdates: true` and
  `showBackgroundLocationIndicator: true` in `AppleSettings`.
- **Lifecycle:** background tracking runs only during an `ongoing` trip and
  stops at End trip, opt-out, or after 12 hours without movement.
- **Battery:** lower accuracy in the background (balanced, 25 m filter) unless
  the traveler is within 1 km of the next stop.

### 7.2 Store and policy work

- Google Play requires a background location declaration and a short video
  showing why it is needed. Prepare this before submission.
- App Store review checks that "Always" is justified; the explanation text
  must describe trip progress, not general tracking.
- Update the privacy notice in the app and in capstone documentation.

### 7.3 Done when

- With the screen off, progress continues and arrival is still detected.
- The notification is visible the whole time and Stop works.
- Denying "Allow all the time" falls back to foreground-only tracking without
  errors.

## 8. Stage 4 — live replanning

Already specified as [Step 9](multiday_live_trip_proposal_2026-11-04.md#L384)
of the multi-day proposal: recalculate the remaining schedule after delays,
suggest changes, and save only after the traveler accepts. It depends on the
proposal's multi-day schedule (Steps 1–8) and structured opening hours. This
plan does not repeat that design; Stages 1–3 supply the live position it needs.

## 9. Risks and decisions needed

| # | Decision or risk | Recommendation |
| --- | --- | --- |
| 1 | Approve Stage 1 scope, including the backend route rate limit | Approve |
| 2 | Add Phase 15H to `core_focus.md` | Yes, for Stages 1–2 |
| 3 | Public OSRM demo limits | Keep reroute caps; plan a hosted or self-hosted OSRM before real user testing |
| 4 | Walking routes are estimates | No walking rerouting until a foot-profile service exists |
| 5 | 0 verified arrival points | Arrival notice shows "near" until points are verified; continue Phase 2 work |
| 6 | Render cold start (about 45 s) | Keep the old route during reroute; consider a paid instance before user testing |
| 7 | Battery use | Measure in the Stage 1 device test; adjust filters |
| 8 | Play Store background location review (Stage 3) | Prepare the declaration early |
| 9 | Starting values in section 5.2 | Treat as defaults to tune after device tests |

## 10. Proposed order and approval checkpoints

1. Approve this plan's Stage 1 scope (or request changes).
2. Update `docs/core_focus.md` with Phase 15H (documentation only).
3. Implement Stage 1 backend rate limit with tests; deploy.
4. Implement Stage 1 app changes with tests; device test; review results.
5. Decide on Stage 2; implement and test.
6. Decide on Stage 3.
7. Stage 4 follows the multi-day proposal's own steps and approvals.

Each checkpoint confirms tables, endpoints, environment variables, migrations
and tests, as required by [core_focus.md](core_focus.md#L767).
