# Lakbay+ multi-day planning and live trip adjustment proposal

Date: 4 November 2026  
Status: proposal only; no application code, schema, or deployed service changed

## 1. Decision and phase alignment

**Product decision:** Home search and Planner search/chat feed one shared trip
draft. The backend calculates a date-aware itinerary for each day, a connected
route, and a sourced cost projection. During an active trip, optional foreground
location updates can trigger a proposed schedule revision. The traveler accepts
the revision before it changes the saved trip.

| Review item | Decision |
| --- | --- |
| Feature | Shared place selection, multi-day schedule, budget-aware choices, and live trip adjustment |
| Current work | Phase 2 destination review continues; Phase 15 planning enhancements exist |
| Phase alignment | Fits Phase 15 if split into small increments; structured destination facts belong to Phase 2 |
| Recommended phase | Add a dated scheduling increment after 15F and a later live-adjustment increment; retain existing Phase 6/7/15 endpoints |
| Schema impact | New structured hours, date exceptions, activity prices, and possibly live-plan revision records require separate approved Alembic migrations |
| Authorization | This document is planning work. Get explicit approval for each implementation scope and every schema change under `AGENTS.md`. |

## 2. What exists and what is missing

- Backend `GET /api/v1/destinations` already supports `search`, district/category
  filters, and pagination. Only active, published destinations are public.
- `POST /api/v1/planning/preview` keeps selected IDs, group and budget
  assumptions, route preferences, options, and an itemized cost preview. It has
  `day_count` (1–30) and at most ten selected destination IDs. It does **not**
  receive actual trip dates, per-day hours, fixed-day assignments, or a separate
  route per day.
- Current route preview/optimization covers one journey with one travel mode.
  Driving and a properly configured walking profile can use OSRM; public
  transport and Haversine fallbacks are estimates. None is a timetable.
- AI itinerary generation currently requires `total_budget > 0` and validates
  the specified day count, selected IDs, and budget. Each AI day currently
  requires at least one activity. A no-budget trip, rest day, or travel-only day
  needs a deliberately revised contract.
- Trip records already have dates, itinerary days/activities, members, and a
  saved route summary. A full multi-day schedule and accepted live revisions do
  not yet have a first-class contract.
- The traveler Home screen has destination search. Destination details have
  **Add to My Trip** and a Planner entry point. Passing a new destination into
  the chat planner currently resets the chat planning state to that one place.
  The traveler screens already receive position updates while certain screens
  are open; this is not trip-wide tracking or live replanning.
- The admin app has a destination editor with free-text operating hours and
  fees. `is_available` on accommodation/transport records is not a dated
  booking or vacancy check. The 648 staged OSM candidates are not public pins.

## 3. Traveler scenarios the design must handle

| Scenario | Expected behavior |
| --- | --- |
| Home search then Planner | Add several published places without leaving Home; Planner opens the same draft and keeps every selected ID. |
| Planner text or search | Resolve a place name to catalog choices; ask the traveler to confirm ambiguous matches; never silently replace selected places. |
| Place absent from catalog | Explain that it is not yet reviewed. Offer a place request; do not silently publish a staged OSM object or fabricate an entrance, hours, or fee. |
| Traveler selects places | Mark each must-visit or optional; preserve must-visits and any traveler-pinned day/order. Explain infeasibility instead of dropping them. |
| Traveler wants suggestions | Rank **published** places by interests, access, dates, travel time, party, and budget; traveler confirms any new IDs before generation. |
| Two, three, or more days | Return one schedule and route per day plus whole-trip totals. A day may be a rest or long-transfer day. Support the existing 1–30-day API range initially; benchmark before raising the ten-place limit. |
| Dates not chosen | Show a provisional sequence only. Do not claim a venue is open or a room is available on an unknown date. |
| Solo/group, adults/children | Count per-person fees by eligible age rule; count shared vehicles and rooms once at their proper charging unit. Group budget may be whole-trip or per-person. |
| Own vehicle | Price fuel from routed kilometers and explicit efficiency/fuel-price assumptions; add parking, tolls, and required ferry vehicle fees separately. |
| Commute or mixed modes | Each leg records its actual mode, transfer, estimate source, and fare. Without verified timetable data, mark service and connection timing unconfirmed. |
| Budget ₱15,000 | Treat the chosen budget scope as a limit only when all required costs are known; show known subtotal, unknowns, reserve, and remaining budget separately. Offer cheaper feasible alternatives. |
| No budget | Still plan and estimate cost. Do not invent a budget or mark the trip as under budget. |
| Venue closed/booking unavailable | Move an optional visit, propose another eligible venue, or report that a must-visit cannot fit. Weekly hours do not prove a dated booking exists. |
| No verified arrival point | Show the attraction pin and provisional road approach; label the gap/entrance as unverified and suppress destination turn-by-turn claims. |
| Unplanned stop or traffic delay | Recalculate ETA to remaining stops, check full visit against closing time, and present a revision only when the change matters. Do not infer why the traveler stopped from GPS alone. |
| Location denied/offline/stale | Keep the saved itinerary usable, offer manual “I'm here,” “Taking a break,” and “Leaving now,” and label any route or ETA as stale/estimated. |
| Group trip | Use the organizer's device as the shared progress source by default; members can view accepted revisions. Do not track all members without their separate opt-in. |

## 4. Proposed user experience

1. **Collect places.** Home cards/details show **Add to plan** and a persistent
   **Plan (N places)** entry. Planner shows the same list and an **Add places**
   search. **Plan this place** opens the existing draft with the place appended;
   **Start new plan** is a separate, explicit action. Keep the current saved-trip
   action distinct from this unsaved draft action.
2. **Set the trip.** Ask for dates or number of days, origin/final endpoint,
   party composition, vehicle/commute/walking preferences, optional budget and
   its scope, daily travel hours, must-visits, fixed days, and pace. Ask for
   missing facts only when the current choice needs them.
3. **Preview.** Show Day 1 … Day N tabs or cards. Each contains start/end,
   ordered stops, arrival/departure, visit duration, mode-specific legs, map
   geometry, venue opening status, and that day's cost. Show whole-trip cost,
   remaining budget when supplied, and a visible **Needs confirmation** list.
4. **Adjust.** Allow drag/reassign between days, lock a day or stop, swap an
   optional place, change hotel or mode, and recalculate. Preserve manually
   locked decisions. Show why a request is impossible.
5. **Save.** Persist the chosen verified IDs, daily plan, route/cost snapshot,
   source timestamps, and unresolved assumptions. The existing trip owner/member
   rules continue to apply.
6. **Live Trip.** The traveler taps **Start trip** and opts into in-use location.
   Show current position and ETA. When a visit will not fit before closing,
   show the original schedule and 1–3 feasible changes with time/cost effects.
   The traveler chooses **Apply**, **Keep plan**, or **Pause updates**.

## 5. Planning contract and calculation rules

### Inputs

Use actual `start_date`/`end_date` when known and `Asia/Manila` local venue
times. Each selected place needs `destination_id`, `priority` (required or
optional), optional `fixed_day`, optional time window/booking slot, and visit
duration. Include party ages/count, budget scope and optional amount, start/end
points per day, overnight stay candidates, travel-mode choices, meal/rest
buffers, and preference tags.

### Feasibility before optimization

For each candidate visit: `arrival >= opening`, `departure = arrival + visit
duration <= closing`, and required booking/access constraints must hold. The
travel leg must connect from the previous stop; the day must end within its
allowed time; the overnight location must connect Day D to Day D+1. Unknown
hours or availability produce **unconfirmed**, never **open**. Hard constraints
are required visits, access, confirmed bookings, day locks, group capacity, and
time windows. Optional stops may be changed only with a visible explanation.

### Route objective

1. Find feasible day assignments and visit order across the whole date range.
2. Default: minimize travel **time** among feasible plans. Offer shortest
   **road/walking distance** only when a tested distance-weighted network/profile
   is available. The distance of an OSRM fastest-route matrix is not proof of a
   shortest-distance route.
3. Use traveler preferences and cost as tie-breakers or constraints according
   to the chosen plan. Cap excessive daily travel/transfer time.
4. Request final route geometry for each chosen leg after order is settled.
   Haversine is a proximity/backup estimate only, without a road polyline or
   directions. Unverified attraction pins keep a labeled last-mile gap.

For a small selected set, compare a deterministic feasible baseline with an
OR-Tools time-window solution. Bound solver time and return a solution-quality
status; a heuristic result must not be called mathematically shortest. The
OSRM Table service can supply road duration/distance matrices for supported
profiles. For public transport, add a timetable engine only after usable local
schedule data is confirmed.

### Money rules

`trip estimate = destination/entrance + selected activities + accommodation
+ transport legs/fuel + meals + parking/tolls + reserve`. Store/display each
line's `amount`, `quantity`, `unit`, `party applicability`, `source`, `checked
at`, and `confidence` (catalog price, traveler assumption, unknown). Apply
adult/child rules only when documented; do not count an included activity twice.
For one hotel: `room count × night count × per-room-night price`, subject to
capacity and dated vacancy checks. For commute: sum every required passenger
leg and transfer. A budget fit is **confirmed** only if every required cost is
known and the amount is within the whole-trip or per-person limit; otherwise
show a partial projection and the unknowns.

### Live revision rules

Only an active saved trip may start a live session. Use recent location with
timestamp and accuracy; ignore stale/inaccurate points. Recalculate from the
current position and time, preserving completed stops, current confirmed visit,
required stops, bookings, fixed-day choices, and accepted group decisions.
Trigger a suggestion when a meaningful delay threatens the next closing window
or day end; add a cooldown so GPS jitter cannot spam the traveler. A stationary
point alone does not identify an unplanned stop. Let the traveler mark pause,
arrival, departure, or skipped optional stop manually.

Rank revisions: keep all must-visits if feasible; shift to another day; reorder
remaining stops; offer a shorter visit only if the traveler accepts it; replace
an optional stop with a reviewed place that is open, accessible, nearby, and
within the known budget. Return **no feasible alternative** when appropriate.
Preview changes in ETA, cost, and remaining days before acceptance. Save an
accepted revision with a version number and previous-version audit; reject an
accept request based on an older version. Do not retain raw GPS history merely
to update ETA. Stop location monitoring at trip end or user opt-out.

### Worked three-day example

These amounts and times are **illustrative traveler assumptions**, not actual
Davao venue prices or verified hours. Four adults select five published places
for three dated days, two nights, one vehicle, and a ₱15,000 **whole-group**
budget. They mark Place B as required on Day 1 and let Lakbay assign the rest.

| Day | Calculated structure | Required check |
| --- | --- | --- |
| 1 | Origin → A → B → Hotel | B's full visit ends before its verified closing time; hotel can receive the group. |
| 2 | Hotel → C → D → Hotel | Both visits and return fit Day 2; overnight rooms cover four adults. |
| 3 | Hotel → E → final endpoint | E is open on that date; return leg fits the requested finish time. |

Illustrative cost: entrance/activities ₱2,400 + two rooms × two nights ×
₱1,500 = ₱6,000 + vehicle fuel ₱1,800 + meals ₱2,400 + parking ₱200 +
reserve ₱200 = **₱13,000**, leaving **₱2,000** if every required price is
known. If a required fee is unknown, display ₱13,000 as the **known/assumed
subtotal** and budget fit as **unconfirmed**.

During Day 2, the group pauses. Recomputed arrival at D is 4:40 pm; its
confirmed close is 5:00 pm and planned visit lasts one hour. The plan is now
infeasible. Lakbay offers to move D to Day 3 if Day 3 remains feasible, swap
an optional stop for another reviewed open place, or keep the plan with an
explicit closing warning. Applying a change recalculates both Day 2 and Day 3
routes and the whole-trip price. If B's fixed Day 1 booking were threatened,
Lakbay would report a conflict rather than move it silently.

### Proposed contract shape (review before coding)

Extend `POST /api/v1/planning/preview` compatibly or add a versioned
`POST /api/v1/planning/schedule-preview`; do not change old clients' response
meaning. A new request would carry `start_date`, `end_date`, daily start/end
windows, `destination_selections` with ID/required/fixed-day/visit-minutes,
origin and overnight choices, party, optional budget plus scope, transport
preferences, and `input_revision`. A response would contain:

```text
status: feasible | feasible_with_unconfirmed_facts | infeasible
days[]: date, start/end, timed visits, route legs, mode, map geometry, daily cost
trip: total distance/time, cost lines, budget status, remaining amount if known
conflicts[]: place/date/time/reason and suggested correction
provenance[]: source and checked time for hours, fee, arrival, route, room
```

Live adjustment should use two actions: **preview** the remaining schedule
from a current observation, then **accept** a selected proposal with trip ID
and expected plan version. The server checks ownership/membership and returns
a version conflict if another accepted edit changed the trip in the meantime.

## 6. One-step-at-a-time implementation map

Path roots below are exact project locations:

- Backend (`B`): `C:/Users/Arjane/Documents/Coding/lakbay_backend_final`
- Traveler Flutter (`T`): `C:/Users/Arjane/Documents/Coding/UI_FOR_LAKBAY`
- Admin Flutter (`A`): `C:/Users/Arjane/Documents/Coding/FINAL_ADMINLAKBAY`

Each step is a separate reviewable change. Proposed new files are labeled
**new**. Edit existing schemas/tables only after the specific change is
approved. Backend changes need focused tests and the existing suite; Flutter
changes need targeted widget/state tests and a device run. Do not commit unrelated
work already present in these workspaces.

### Step 0 — prove the existing path and deliver the review queue

**Why:** Public pins and new planning behavior cannot be tested against an
unshipped API or staged-only places. **Change:** audit the current deployed
backend version, migration head, catalog response, route provider, walking
profile, and 30 active places; deploy only the already reviewed candidate-queue
change through the normal release process. **Locations:** B
`app/features/destinations/candidate_router.py`, `docs/destinations.md`,
`app/integrations/osrm/client.py`; A `lib/services/api_service.dart`,
`lib/screens/destinations_screen.dart` (new candidate review screen adjacent to
it). **Tools:** Alembic status/review, FastAPI OpenAPI, targeted API smoke checks,
OSRM test instance. **Done:** deployed queue can list staged records for admin;
travelers still see only published destinations; no accidental bulk publish.

### Step 1 — one shared place basket

**Why:** Home-to-Planner currently resets chat selection. **Change:** add a
single draft state with append/remove/deduplicate by destination ID, a
**Plan (N)** entry, **Add to plan** on cards/details, and in-Planner search.
Entering from a destination appends unless the traveler explicitly starts
afresh. Preserve the existing saved-trip action as a separate choice.
**Locations:** T `lib/providers/trip_provider.dart`,
`lib/models/chat_planning_session.dart`, `lib/screens/home/home_screen.dart`,
`lib/screens/destinations/destination_details_screen.dart`,
`lib/screens/planner/conversational_planner_screen.dart`,
`lib/services/api_service.dart`; tests `test/trip_provider_test.dart`,
`test/conversational_planner_screen_test.dart`. **Tools:** existing Flutter
Provider, backend `GET /api/v1/destinations?search=`, Flutter widget tests.
**Done:** select three places through mixed entry points and see exactly those
three IDs in one draft after back navigation and reopening Planner.

### Step 2 — optional budget and explicit suggestion flow

**Why:** No-budget travelers cannot complete current AI generation. **Change:**
make budget optional in *new planning mode* with an explicit `budget_status`;
keep known cost and unknown cost separate. Distinguish “selected places” from
“find places for me”; add suggested published IDs to the basket only after
confirmation. Retain compatibility for existing budget-required calls until
migration is complete. **Locations:** B `app/features/planning/schemas.py`,
`app/features/planning/costs.py`, `app/features/ai/schemas.py`,
`app/features/ai/validators.py`, `app/features/recommendations/service.py`;
T `lib/models/chat_planning_session.dart`,
`lib/screens/planner/conversational_review_sheet.dart`; tests B
`tests/test_planning_preview.py`, `tests/test_planning_ai_save.py`, T
`test/chat_planning_contract_test.dart`. **Tools:** Pydantic validation,
existing recommendation scorer, Decimal money. **Done:** no-budget trip returns
a cost projection without invented limit; ₱15,000 whole-group/per-person
requests are distinct; suggestions cannot silently replace selected IDs.

### Step 3 — admin-confirmed schedule, activity, and price facts

**Why:** Free-text hours and general `is_available` cannot prove a dated visit.
**Change:** create structured weekly hours, dated closures/exception openings,
visit duration, booking requirement/status, sourced activity and entrance
price rules (unit, age/date applicability, checked time). Keep attraction pin
separate from a verified arrival point. Accommodation needs dated vacancy or
**unconfirmed**; a general available flag is insufficient. **Locations:** B
`app/features/destinations/models.py`, `schemas.py`, `service.py` and **new**
`app/features/destinations/availability.py`; B
`app/features/accommodations/models.py`; **new** migration under
`app/db/migrations/versions/`; A `lib/screens/destination_editor.dart`,
`lib/screens/accommodation_screen.dart`, `lib/services/api_service.dart`;
tests B `tests/test_phase2_destination_data.py`, A
`test/destination_editor_test.dart`. **Tools:** SQLAlchemy, Alembic,
Postgres, admin source URLs, date/time validation. **Done:** admin can mark a
venue closed on a specific date and planner reads it as closed; unknown remains
unknown. Review and approve exact schema before implementation.

### Step 4 — dated, one-day feasibility preview

**Why:** This isolates opening-hour logic before full multi-day optimization.
**Change:** extend planning preview or add a versioned schedule-preview route
for actual date, day start/end, visit durations, fixed stops, and travel/break
buffers. Return timed stops, infeasibility reasons, and source quality.
**Locations:** B `app/features/planning/router.py`, `schemas.py`, `service.py`,
`routing.py`, **new** `app/features/planning/availability.py`, **new**
`app/features/planning/schedule.py`; T
`lib/screens/planner/conversational_review_sheet.dart`,
`lib/services/api_service.dart`; tests **new** B
`tests/test_planning_schedule.py`. **Tools:** Python `zoneinfo`
(`Asia/Manila`), OSRM Route/Table, deterministic scheduling tests. **Done:**
every visit fits entirely inside a verified open interval or is flagged; a
closed required stop produces an explanation.

### Step 5 — N-day schedule and overnight continuity

**Why:** One whole-journey route cannot represent Day 1 hotel arrival and Day 2
hotel departure. **Change:** return a day list with per-day start/end, route,
timed stops, and daily/whole-trip totals. Preserve day locks, required places,
rest/transfer days, and one or more overnight locations. Start with one travel
mode per day. Use a bounded solver for small sets after a deterministic baseline
works. **Locations:** B planning `schemas.py`, `schedule.py`, `routing.py`,
`service.py`; B `app/integrations/osrm/client.py` (Table integration);
T `lib/screens/planner/planner_results_screen.dart`; tests B
`tests/test_planning_routes.py`, **new** `tests/test_multiday_schedule.py`.
**Tools:** OSRM Table/Route, OR-Tools time windows, Python zoneinfo. **Done:**
for 3 days/2 nights, Day 1 ends at the chosen stay, Day 2 starts there, and
all selected required places appear exactly once unless repeat is requested.

### Step 6 — whole-trip money by day, party, and charging unit

**Why:** A feasible itinerary may still exceed budget, and group price units
vary. **Change:** project adult/child entrance/activity fees, room capacity ×
nights, each transport leg, fuel/parking/tolls, meals, reserve, and unknowns.
Allow cost breakdown by day and whole trip. Do not present partial cost as
confirmed budget fit. **Locations:** B `app/features/planning/costs.py`,
`schemas.py`, `service.py`; B `app/features/budgets/service.py` only where its
existing contract is reused; T `lib/screens/planner/chat_plan_review_sheet.dart`,
`lib/screens/planner/planner_results_screen.dart`; tests B
`tests/test_planning_costs.py`, `tests/test_phase4_budget_engine.py`.
**Tools:** Python Decimal, existing charging units and child rules. **Done:**
solo, four-adult vehicle, adult/child commute, no-budget, and partial-price
examples have explainable totals without double counting.

### Step 7 — mode-specific routes and honest optimization labels

**Why:** Mixed transport and shortest distance are distinct from the current
single-mode fastest route. **Change:** model each leg's mode and transfer point;
validate a separate foot network; use road and walking routes only where valid.
Add a shortest-distance option only with a tested distance-weighted graph.
Public transport stays estimate-only until real schedule data exists. Ferries
are separate scheduled legs. **Locations:** B `app/features/routes/schemas.py`,
`service.py`, `app/integrations/osrm/client.py`, planning `routing.py`;
T `lib/screens/planner/planner_results_screen.dart`,
`lib/screens/destinations/destination_details_screen.dart`; tests B
`tests/test_phase6_routes.py`, `tests/test_route_provider_geometry.py`.
**Tools:** separate OSRM car/foot profiles, optional distance-weighted OSRM
instance, later GTFS/OpenTripPlanner if a valid Davao feed is available.
**Done:** fastest and shortest are correctly labeled; no straight-line estimate
is drawn as a road route; unknown commute schedules remain unconfirmed.

### Step 8 — grounded AI wording and saved multi-day snapshot

**Why:** AI must not undo a feasible schedule or make up opening times/costs.
**Change:** supply the backend-calculated daily schedule and cost provenance to
Groq; validate exact selected IDs, day assignment, time windows, budget status,
and unresolved warnings. Allow a rest/travel day in the schema. Save selected
day routes and schedule metadata with trip revision compatibility.
**Locations:** B `app/features/ai/service.py`, `schemas.py`,
`validators.py`, `app/features/trips/service.py`, `schemas.py`, `models.py`,
`app/features/trips/router.py`; T
`lib/screens/planner/conversational_planner_screen.dart`,
`lib/screens/planner/planner_results_screen.dart`; tests B
`tests/test_phase5_ai_itineraries.py`, `tests/test_planning_ai_save.py`,
`tests/test_phase7_trips.py`. **Tools:** Groq for wording only, Pydantic for
output validation, existing trip ownership checks. **Done:** saved trip
reopens with the same accepted dates, stops, modes, costs, and warnings.

### Step 9 — in-use Live Trip and proposed revisions

**Why:** User stops and delays can make later visits impossible. **Change:**
start/pause/end an opt-in live session; observe location while the trip screen
is open; estimate remaining ETA and full visit feasibility; propose and preview
reordered/reassigned/alternative stops; accept only against current trip
version. Add manual arrival, break, depart, and skip actions. Do not transmit
every GPS point when a meaningful change event suffices. **Locations:** B
**new** `app/features/trips/live_service.py`, **new**
`app/features/trips/live_schemas.py`, `app/features/trips/router.py`,
planning `schedule.py`, `app/features/routes/service.py`;
T **new** `lib/screens/trips/live_trip_screen.dart`,
`lib/screens/trips/trips_screen.dart`, `lib/services/api_service.dart`;
tests **new** B `tests/test_live_trip_replanning.py`, T
`test/live_trip_screen_test.dart`. **Tools:** existing Geolocator, OSRM;
optional configured traffic-aware provider for driving ETA; mock GPS clock and
route calls in tests. **Done:** a 45-minute delay before a 5 pm close yields
a clear warning and feasible options; no accepted plan changes automatically.

### Step 10 — optional background and group progress

**Why:** Live ETA while the screen is closed has OS-specific permission,
battery, and privacy costs. **Change:** only after foreground behavior works,
offer explicit background-location opt-in during an active trip, platform
notification/indicator, stop switch, short retention, and one organizer progress
source. Members see accepted plan revisions, not the organizer's raw trace.
**Locations:** T `android/app/src/main/AndroidManifest.xml`,
`ios/Runner/Info.plist`, **new** `lib/services/live_location_service.dart`;
B `app/features/trips/live_service.py`, `app/features/trips/service.py`,
`app/features/notifications/service.py`; tests T device/integration tests,
B group ownership/version tests. **Tools:** Android foreground/background
location APIs, iOS Core Location, Flutter Geolocator only where its platform
support meets the lifecycle need. **Done:** opt-out or trip end stops updates;
denial degrades to manual progress; no cross-member location leak.

## 7. Release gates and quality checks

- Data: use a small pilot of admin-reviewed venues with confirmed district,
  category, access, hours, duration, fees, and arrival source. Recheck hours and
  prices before treating a dated itinerary as confirmed. Do not mass-publish
  the staged OSM queue.
- Algorithm: fixed fixture scenarios for closed days, split opening intervals,
  time-zone boundaries, midnight transfer, unreachable road pair, duplicate
  place, optional/rest day, group capacity, child fee, multi-mode transfer,
  booking-required venue, and a hard budget with unknown cost. For small cases,
  compare the solver's answer against exhaustive enumeration to catch wrong
  ordering. Bound route requests and solver runtime.
- API: schema validation, existing-client compatibility, authenticated access,
  trip ownership/member permissions, stale plan-version conflicts, rate limits,
  provider outage fallback, and migration upgrade/downgrade review.
- UI: test both Home and Planner entry points, preserved draft after navigation,
  date/day edits, readable route/uncertainty labels, explicit apply/keep actions,
  denied location, offline mode, and small phone layouts.
- Field test: pilot driving and walking routes at several Davao venues with a
  verified entrance, one attraction-only pin, and a cross-province long drive.
  Compare mapped approach, ETA, and closing-time warning with observed travel.
- OSM-derived data/map use requires visible attribution. Public OSM tiles and the
  OSRM demo have separate usage limits; production routing/map infrastructure
  needs a suitable provider or self-hosted service. Review any paid-provider
  terms before combining its route output with a separate map display.

## 8. External tool references

- [OSRM HTTP API: Route, Table, Trip and profiles](https://project-osrm.org/docs/v26.6.1/http)
- [OSRM profile weighting](https://github.com/Project-OSRM/osrm-backend/blob/master/docs/profiles.md)
- [OSRM demo server usage](https://github.com/Project-OSRM/osrm-backend/wiki/Demo-server)
- [OR-Tools routing with time windows](https://developers.google.com/optimization/routing/vrptw)
- [GTFS schedule reference](https://gtfs.org/documentation/schedule/reference/)
- [OpenTripPlanner data sources](https://docs.opentripplanner.org/en/latest/Data-Sources/)
- [Android background location](https://developer.android.com/develop/sensors-and-location/location/background)
- [Apple background location](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background)
- [OSM attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines)
- [OSM tile usage policy](https://operations.osmfoundation.org/policies/tiles/)
