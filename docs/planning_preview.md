# Selectable Travel Planning Preview

Status: reviewed scope approved for phased implementation; Phases 1-4 are
implemented and tested.

The preview-to-AI save extension now uses this preview as generation context.
Verified catalog `charging_unit` values appear as known rate bases; legacy null
units still require explicit traveler assumptions. See `docs/ai_itineraries.md`
for option generation and `docs/trips.md` for atomic save and restart behavior.
Phase 15D adds optional request-level child ages and explicit free/half/full
pricing bands to this same budget contract; see `docs/child_aware_costing.md`.
Requested on: 2026-10-03.
Approved on: 2026-10-03.
The complete preview described below is the target behavior. The phased rollout
separates that target from the current implementation, which begins with catalog
choices and caller-supplied planning state.

## Feature Review And Phase Alignment

- Feature: a travel planning preview with selectable transportation and activity
  options, calculated expenses, and a route summary.
- Current implementation: catalog choices, normalized planning state, cost
  completeness, opt-in routes/fuel estimates, and planning-aware chat support.
- Existing foundation: Phase 2 destinations and rates, Phase 3 recommendations,
  Phase 4 budgets, Phase 5 AI, and Phase 6 routes.
- Recommended phase: Phase 15C activity-based budget projection and Phase 15E AI
  geo-analytics context. Destination discovery/grouping belongs to Phase 15B.
- Route integration reuses the global Phase 6 routing foundation. The preview
  rollout numbers below describe this feature's increments, separately from the
  global phases in `docs/core_focus.md`.
- Alignment: fits the existing enhancement phases with a stateless first version;
  no new phase is needed.
- Reason: travelers should choose practical options while the backend calculates
  the consequences, instead of supplying prices themselves.

## Approved Phased Rollout

| Phase | Scope | Status |
| --- | --- | --- |
| 1: Catalog choices | Protected, stateless `POST /api/v1/planning/preview`; normalize caller state, return destination summaries and transport/activity choices, and disclose missing inputs or invalid selections. | Implemented and tested. |
| 2: Cost completeness | Add explicit charge units, labeled allowances, inclusion checks, itemized estimates, unresolved costs, and budget-fit rules. | Implemented and tested. |
| 3: Routes and fuel | Integrate journey legs, route distance/duration, return preference, disclosed fuel assumptions, and unresolved connections. | Implemented and tested on 2026-10-07. |
| 4: Chat and Flutter contract | Carry structured planning state through chat and deliver the contract for Flutter preview cards and selections. | Implemented and tested on 2026-10-09. |

The implementation keeps the existing feature modules and database schema. Each
phase is a small change that can be tested independently before the next layer is
added. Any later schema change still needs explicit approval and migration review.

## Implemented Phase 1 Foundation

Phase 1 adds the authenticated choices endpoint using the current catalog. The
caller sends the complete planning state on each request; the backend returns
normalized state, destination summaries, transportation and descriptive activity
options, `missing_inputs`, `selection_problems`, and `next_actions`.

This phase does not calculate a budget, optimize a route, estimate fuel, or derive
state from chat. It does not implement Flutter screens or create saved trips,
preview sessions, or new database models. Prices already stored in catalog rate
rows remain catalog information; they do not establish a complete journey cost or
a supported charge unit.

The behavior, tables, and acceptance criteria in the following target sections
include later phases. They are not all claims about the Phase 1 endpoint.

Phase 2 builds on this contract by adding cost completeness and an additive
`budget` response. It keeps catalog choices, normalized caller state, selection
problems, and revision handling. Its scope is request-level allowances and
explicit estimated rate-unit assumptions using existing catalog records. It
does not change database models or add live providers, routing, or chat state
extraction. The Phase 2 extension below describes the implemented cost contract.

Phase 3 adds optional `route_preferences` and `fuel_assumptions` while retaining
the choices and cost contracts. Without route preferences, existing requests
continue to use the catalog and cost logic without a routing-provider call.
The Phase 3 contract below is implemented and tested. Phase 4 adds planning-aware
chat responses and the state/revision contract for Flutter.

Phase 1 validation on 2026-10-03: 107 tests passed across the planning preview,
destination catalog, budget engine, AI retrieval/chat, and health suites. After
the final stale-selection assertion and review edits, all 17 preview tests passed.
These checks used the test SQLite database and no live AI or routing providers.

Phase 2 validation on 2026-10-03: 78 tests passed across the planning preview,
destination catalog, budget engine, and health suites. After the final fare
overlap correction, all 45 planning preview and cost tests passed. These checks
used controlled test data, without live database, AI, or routing calls.

Phase 3 validation on 2026-10-07: 144 tests passed across planning choices/costs/
routes, the existing route and budget engines, destination data, configuration,
and health. After correcting access-note matching so road-trip prose such as
"air-conditioned bus" does not imply air transport, all 54 final route/fuel tests
passed, including the new regressions. These checks use isolated SQLite data and
mock routing providers, without live Neon, OSRM, Groq, or Google Routes calls.
Swagger checks with actual catalog IDs and live OSRM, and development Postgres
integration checks, remain manual validation steps.

Phase 4 validation on 2026-10-09: all 6 planning-aware chat tests passed. They use
isolated SQLite data and a fake Groq client to cover state carry-forward, revision
echoing, UI-owned selection preservation, catalog-grounded destination updates,
origin coordinate handling, and rejection of invalid model output or unsupported
destination IDs. No live Groq or routing provider was called.

## Phase 4 Chat And Flutter Contract

Flutter keeps the complete `PlanningState` for the current planning session and
sends it with each planning-aware chat request. It increments `input_revision`
when its current inputs change and ignores responses for older revisions. The
backend applies only validated, explicit constraint updates from chat, then
recalculates the preview from the complete resulting state.

The existing authenticated `POST /api/v1/ai/chat` endpoint accepts optional
`planning_state` and `input_revision` fields. When `planning_state` is omitted,
ordinary chat behavior remains in effect. When supplied, the model returns a
structured `chat_response` and partial `state_updates`. Updates are restricted to
origin, catalog destination IDs, budget, traveler count, duration, return
preference, and interests. Chat can update an origin label but cannot invent its
coordinates; Flutter supplies coordinates from a traveler-selected map point.
Transport, activity, accommodation, route, fuel, and
pricing selections stay under the preview UI's control. A newly proposed
destination ID must be present in retrieved catalog context; otherwise the
backend preserves the current destination and asks for clarification.

The response adds `planning` with the echoed revision, accepted state updates,
an update status, and a fresh `preview` containing normalized state, catalog
choices, budget, route, fuel, missing inputs, selection problems, and next
actions. Malformed or invalid structured model output leaves the caller's state
unchanged and still returns its recalculated preview. The stateless
`POST /api/v1/planning/preview` endpoint remains available for card selection and
recalculation without an AI call.

To try the endpoint, restart the backend, open `/docs`, authorize with a user
access token, and send the request below with actual catalog IDs. Copy the
returned state into the next request, change selected option IDs, and increment
`input_revision`.

### Phase 1 Base Request And Response

Send `POST /api/v1/planning/preview` with an existing user access token in the
`Authorization: Bearer <access_token>` header.

| Request field | Phase 1 foundation behavior |
| --- | --- |
| `input_revision` | Nonnegative caller revision, echoed in the response. |
| `state.origin` | Optional `label` and paired `lat`/`lng`. Missing coordinates are disclosed without preventing catalog choices. |
| `state.destination_ids` | Up to ten unique active catalog IDs, kept in the caller's chosen order. Missing/inactive IDs remain in state and produce selection problems. |
| `state.total_budget`, `budget_scope` | Positive entered budget and `whole_trip` or `per_person` scope. Both are retained; `whole_trip_budget` separately converts a per-person budget when traveler count is known. |
| `state.traveler_count`, `day_count`, `night_count` | Optional count fields. Nights are explicit and cannot exceed days; omitted nights are not inferred. |
| `state.return_to_origin` | Optional explicit return preference; no route is calculated yet. |
| `state.interests`, `reserve_amount` | Retained requested interests and nonnegative reserve. Interests do not create catalog activities, and reserve is not used in a cost calculation in this phase. |
| `state.selected_transport_option_ids`, `selected_activity_option_ids` | Unique identifiers returned by this endpoint. Invalid or outdated selections remain visible for correction. |

For an illustrative day trip, replace destination ID `1` and the origin with the
active catalog destination and actual starting point selected by the traveler:

```json
{
  "input_revision": 1,
  "state": {
    "origin": {
      "label": "Davao City",
      "lat": 7.0707,
      "lng": 125.6096
    },
    "destination_ids": [1],
    "total_budget": "15000.00",
    "budget_scope": "whole_trip",
    "traveler_count": 1,
    "day_count": 1,
    "night_count": 0,
    "return_to_origin": true,
    "interests": ["sightseeing"],
    "reserve_amount": "0.00",
    "selected_transport_option_ids": ["mode:personal_vehicle"],
    "selected_activity_option_ids": []
  }
}
```

`mode:personal_vehicle` identifies the personal-vehicle draft choice. Catalog
transport options use `transportation:<transportation_id>`. Activity options use
server-generated `activity:<destination_id>:<activity_key_hash>` identifiers;
copy the actual returned `option_id` into the next request instead of inventing
one or submitting a label or price. Changing destination IDs requires reviewing
selections that no longer belong to those destinations.

| Response field | Phase 1 foundation behavior |
| --- | --- |
| `status` | `needs_selection_review` when selections have problems; otherwise `needs_details` when essential inputs are missing; otherwise `choices_available`. This is a choices status, not a budget-fit result. |
| `state`, `input_revision` | Retained caller state after request normalization, including unavailable selections, plus the echoed revision. Each request supplies the full state; the backend does not merge a previous request or chat history. |
| `whole_trip_budget` | Normalized budget limit, or null when a per-person amount cannot be converted. It is distinct from the expense totals added by Phase 2. |
| `destinations` | Summaries for active selected destinations, including their original `activities_description`. |
| `transport_options` | Personal-vehicle and available catalog transport choices with `selected`, listed rates where stored, route labels, `route_match`, and `missing_information`. |
| `activity_options` | Descriptive short activity labels derived from the destination catalog, stable option IDs, `selected`, and unresolved fee/duration information. |
| `missing_inputs` | Missing origin/coordinates, destination IDs, budget, travelers, days, nights, or return preference. |
| `selection_problems` | Missing/inactive destinations and unavailable, mismatched, or forged option IDs. Validly shaped requests return HTTP 200 with these problems instead of silently replacing selections. |
| `next_actions` | `complete_details`, `review_selections`, `choose_transport`, and/or `choose_activities` when applicable. |

Every transport option has `journey_complete=false`. A label-based `route_match`
does not prove service coverage or journey feasibility. Catalog `listed_price`
retains its recorded amount while `price_basis` remains null; unresolved fare
basis, connections, return coverage, or route applicability are disclosed.
Personal-vehicle fuel and other expenses are also unresolved. Activity
`charge_type` is `unknown`, with null `price`, `price_basis`, and
`duration_minutes`; a parsed activity name never establishes a free or priced
offering.

Phase 1 originally returned no `budget` or `route` objects. Phase 2 adds
`budget`, accommodation choices, and the cost inputs below. Phase 3 adds optional
route/fuel calculation and response objects. Dates/times and chat state extraction
remain later-phase work. Unknown request fields, duplicate IDs, incomplete
coordinate pairs, or invalid numeric constraints receive request validation
errors.

## Phase 2 Cost Contract

Phase 2 uses the same authenticated endpoint, complete-state requests, and echoed
`input_revision`. Existing choices and state fields remain available. The new
cost inputs are optional, so a Phase 1 request still works and returns a partial
budget when required costs lack coverage.

| New state field | Meaning |
| --- | --- |
| `selected_accommodation_ids` | Unique available room/stay IDs associated with the selected destinations. Returned `accommodation_options` expose name, room type, capacity, server-owned `listed_price`, and selection state. |
| `cost_allowances` | Explicit traveler allocations with `category` and nonnegative `amount`. Transportation, food, other, and accommodation allowances cover the category for the whole trip. A destination allowance additionally requires its `destination_id`; an activity allowance requires its returned activity `option_id`. |
| `cost_allowances[].includes_activity_option_ids` | Optional exact selected activity IDs covered by a food or destination allowance. Food can include any valid selected activity, such as coffee or dining. A destination allowance can include only activities belonging to that destination. |
| `transport_pricing` | Assumed basis for a selected catalog transport `option_id`: `per_person`, `per_vehicle`, or `per_group`, plus `charge_count`, `vehicle_count` where applicable, and `journey_scope` of `listed_leg` or `round_trip`. These are traveler assumptions about a recorded rate, not verified provider terms. |
| `accommodation_pricing` | Assumed basis for a selected `accommodation_id`: `per_room_per_night` or `per_room_per_stay`, with explicit `room_count` and `night_count`. Room quantities must represent the selected travelers and stay. |

The backend reads raw transport and accommodation prices from the current
catalog; clients cannot override those prices. An explicit basis produces a
`catalog_price_with_assumed_basis` cost line. It does not change the catalog
option's unknown `price_basis` or establish that the price is current or
verified. A whole-trip transportation or accommodation allowance replaces the
corresponding catalog calculations, so that amount is not added again.

For a single destination, a priced outbound leg is required even for a one-way
trip. A return trip needs both directions or an explicit round-trip assumption.
Overlapping matched fares, such as a round-trip fare plus a separate return fare
or two alternatives for the same direction, require selection review and are
excluded from calculated costs. A multi-destination journey remains partial
unless a whole-trip transportation allowance covers its unresolved legs. Phase 3
adds a road-route summary, not automatic fare composition or confirmation of
public-transport/ferry connections. Label matches alone do not verify a route.

Destination `estimated_cost` is not automatically added because its inclusions
and unit are unresolved. Supply a destination allowance to cover that cost.
Selected activities need their own allowance or explicit inclusion in a food or
destination allowance. Covered activities appear as zero-amount lines with
`source=included_in_allowance` and an `included_in` reference to the covering
allowance, rather than charged twice. The zero line records inclusion in the
traveler's allocation; it does not declare the activity free.

An activity cannot be covered by both food and destination allowances, or by an
inclusive allowance and a separate activity allowance. Those overlaps produce
selection problems and a partial estimate instead of duplicate charges. Invalid
or unselected activity IDs also require correction. A zero allowance is an
explicit traveler estimate; it never marks the catalog destination, activity,
room, or transport as verified free.

The two Flutter chat review sheets use the returned activity IDs for selection.
For each selected activity, the traveler confirms a separate whole-trip amount
or inclusion in a destination or food allowance. Submission accepts destination
inclusion only when that destination uses a whole-trip allowance, rather than
an age-based fee rule. Unavailable saved activity IDs are shown for removal.
These choices remain traveler estimates; the backend preview calculates the
itemized total and generation readiness.

### Phase 2 Day-Trip Example

This example allocates money for a personal-vehicle day trip. Every amount is an
illustrative traveler allowance, not an actual entrance fee, fare, fuel estimate,
or menu price. Replace destination ID `1` and the origin with the selected active
catalog destination and actual starting point. Use returned activity IDs if the
traveler later selects an activity.

```json
{
  "input_revision": 2,
  "state": {
    "origin": {
      "label": "Davao City",
      "lat": 7.0707,
      "lng": 125.6096
    },
    "destination_ids": [1],
    "total_budget": "15000.00",
    "budget_scope": "whole_trip",
    "traveler_count": 1,
    "day_count": 1,
    "night_count": 0,
    "return_to_origin": true,
    "interests": ["sightseeing"],
    "reserve_amount": "1000.00",
    "selected_transport_option_ids": ["mode:personal_vehicle"],
    "selected_activity_option_ids": [],
    "selected_accommodation_ids": [],
    "cost_allowances": [
      {"category": "transportation", "amount": "1200.00"},
      {"category": "destination", "destination_id": 1, "amount": "100.00"},
      {"category": "food", "amount": "500.00"},
      {"category": "other", "amount": "200.00"}
    ],
    "transport_pricing": [],
    "accommodation_pricing": []
  }
}
```

With valid selections and complete cost coverage, these allocations produce
`priced_subtotal=2000.00`, `total_estimate=2000.00`,
`suggested_trip_funds=3000.00`, and `remaining_budget=12000.00`. Zero nights and
no selected accommodation add no stay cost. The transportation allowance covers
the cost estimate. This request supplies no route preferences, so personal-vehicle
route feasibility and fuel remain unresolved. The opt-in Phase 3 example below
requests a route and an assumed fuel estimate separately.

### Budget Response

The response adds `accommodation_options` and a `budget` object:

| Budget field | Meaning |
| --- | --- |
| `completeness` | `complete` when required expenses have explicit coverage; otherwise `partial`. Completeness refers to the estimate's cost coverage, independently of route confidence. |
| `fit` | `fits_estimate`, `over_budget`, or `undetermined`. A partial subtotal cannot establish that a trip fits. |
| `priced_subtotal`, `category_totals` | Calculated cost lines, grouped by category, without the separately held reserve. |
| `total_estimate`, `suggested_trip_funds` | Full estimate and estimate plus reserve when complete; null when required costs remain unresolved. |
| `reserve_amount` | Funds held aside and counted when comparing required trip funds to the whole-trip budget. |
| `remaining_budget`, `over_budget_amount` | Complete-estimate comparison against the whole-trip budget; final remaining funds are unresolved for a partial estimate. |
| `minimum_over_budget_amount` | Known excess when priced subtotal plus reserve already exceeds the budget, even if other costs are missing. |
| `lines` | Itemized category, reference, amount, source, unit/quantity/basis where calculable, and explicit inclusion reference where applicable. |
| `missing_costs`, `assumptions` | Uncovered required costs and disclosed traveler allocations or unit assumptions. |

Invalid selections and invalid allowance/pricing references remain in state and
produce selection problems. They cannot establish complete cost coverage.
`next_actions` can now include `complete_costs` or `reduce_costs`. The top-level
choices `status` remains distinct from `budget.fit`.

Phase 2 introduced no route object, live fuel provider, Groq call, saved preview,
or database schema change. Phase 3 extends the response as described below. Fuel
allowances and assumed fare units remain estimates. Verified pricing/provenance,
normalized pricing tables, booking, and child-specific charges still require
separately reviewed work.

## Phase 3 Route And Fuel Contract

Phase 3 is implemented and tested. It uses the same authenticated, stateless endpoint and
adds `route` and `fuel` response objects. Existing requests without
`state.route_preferences` remain provider-free; `route.status` is
`not_requested`. Fuel assumptions alone do not start a provider request.

| New state field | Meaning |
| --- | --- |
| `route_preferences` | Supplying this object opts into a route preview. It requires origin coordinates, active selected destinations, an explicit return preference, and an unambiguous supported transport selection. |
| `route_preferences.optimize_order` | Defaults to false, preserving the requested stop order. True explicitly requests optimization while preserving the origin as the first stop. The returned route order does not rewrite caller state. |
| `route_preferences.road_access_confirmed` | Defaults to false. Personal-vehicle fuel needs explicit traveler confirmation of full road access. Confirmation does not override catalog boat/ferry/island/sea/air access hints or mixed/non-road transport selections. |
| `fuel_assumptions.kilometers_per_liter`, `price_per_liter` | Positive traveler estimates of fuel efficiency and fuel price. Fuel price is supplied by the traveler; no live fuel-price provider is used. |
| `fuel_assumptions.vehicle_count` | Defaults to one. Fuel scales by vehicle count, independently of traveler count. |
| `fuel_assumptions.parking_amount`, `toll_amount`, `vehicle_ferry_amount`, `other_vehicle_amount` | Optional whole-trip allocations for all selected vehicles. Null means unresolved; explicit zero means a traveler allocation of zero, not a verified absence of fees. These amounts are not multiplied again by vehicle count. |

Selecting only `mode:personal_vehicle` requests driving. With route preferences,
`mode:walking` is available for a walking preview. Compatible catalog road
transport choices produce a public-transport estimate; they do not establish
real services, timetables, or fare coverage. Mixed modes, unavailable choices,
non-road vehicles, and catalog access hints requiring boat/ferry/sea/air
connections require review before a road summary can be returned.

Walking does not automatically complete transport cost coverage. Supply a
whole-trip transportation allowance, including an explicit zero if appropriate.
It does not remove destination or selected activity expenses.

The route reuses the existing Phase 6 service and configured OSRM integration.
It includes the origin, selected destinations, and return leg when requested.
Provider failures may produce an explicitly estimated Haversine fallback. No
live traffic is requested by this preview. Provider summaries must retain the
origin, all selected destinations, and any requested return; an incomplete
summary is discarded for review. A summary is a distance/duration estimate,
independently of whether public services or road access are verified.

| Response field | Meaning |
| --- | --- |
| `route.status` | `not_requested`, `needs_details`, `needs_review`, or `calculated`. A summary can still accompany a review requirement; inspect missing information and warnings. |
| `route.travel_mode`, `order_strategy` | Resolved `driving`, `walking`, or `public_transport` mode where supported, and `preserve_order` or `optimize`. |
| `route.summary` | Nullable route summary with `route_provider`, `is_estimated`, distance, duration, ordered stops, travel legs, and warnings. Fallback/public-transport estimates do not establish real road distance or service coverage. |
| `route.missing_information`, `warnings` | Missing inputs, unavailable selections, access confirmation, unresolved connections, and provider/fallback limitations. |
| `fuel.status` | `not_requested`, `needs_details`, `unavailable`, or `calculated`. A route result alone does not guarantee a fuel result. |
| `fuel.distance_km`, `liters`, `amount`, `vehicle_count` | Calculated fuel values when supported; unresolved values remain null. Fuel uses road distance / kilometers per liter * vehicle count * price per liter. |
| `fuel.included_in`, `assumptions`, `missing_information` | The covering whole-trip transportation allowance when supplied, disclosed efficiency/price assumptions, and the information needed before fuel can be calculated. |

Fuel is calculated only for a sole personal-vehicle selection with confirmed road
access and a complete, nonestimated OSRM driving summary whose travel legs cover
the requested journey. Haversine, walking, public-transport, mixed, sea, and
incomplete routes cannot supply the required fuel distance. Catalog access hints
cannot be dismissed merely by setting `road_access_confirmed=true`.

Without a whole-trip transportation allowance, supported fuel becomes a
`transportation` budget line with `source=route_with_traveler_assumptions`.
Parking, toll, vehicle-ferry, and other vehicle allocations are separate lines.
Any omitted vehicle allocation leaves the budget partial; no omitted fee is
silently treated as zero. A whole-trip transportation allowance replaces fuel
and these vehicle-fee calculations. A calculated fuel result may still be shown
with `included_in=allowance:transportation` for reference, without adding it again.
`next_actions` can include `review_route` or `complete_fuel_details`.

### Phase 3 Swagger Example

Restart the backend, authorize in `/docs`, and use the following request for a
known road-accessible active catalog destination. Replace destination ID `1` and
the origin with the actual selected destination and starting point. Confirm road
access only when the full journey supports it. The efficiency and price below
are illustrative assumptions, not live values. Every zero vehicle-fee amount is
an explicit traveler allocation; it is not a claim that a provider charges no fee.

```json
{
  "input_revision": 3,
  "state": {
    "origin": {
      "label": "Davao City",
      "lat": 7.0707,
      "lng": 125.6096
    },
    "destination_ids": [1],
    "total_budget": "15000.00",
    "budget_scope": "whole_trip",
    "traveler_count": 1,
    "day_count": 1,
    "night_count": 0,
    "return_to_origin": true,
    "interests": ["sightseeing"],
    "reserve_amount": "1000.00",
    "selected_transport_option_ids": ["mode:personal_vehicle"],
    "selected_activity_option_ids": [],
    "selected_accommodation_ids": [],
    "cost_allowances": [
      {"category": "destination", "destination_id": 1, "amount": "100.00"},
      {"category": "food", "amount": "500.00"},
      {"category": "other", "amount": "200.00"}
    ],
    "transport_pricing": [],
    "accommodation_pricing": [],
    "route_preferences": {
      "optimize_order": false,
      "road_access_confirmed": true
    },
    "fuel_assumptions": {
      "kilometers_per_liter": "12.00",
      "price_per_liter": "75.00",
      "vehicle_count": 1,
      "parking_amount": "0.00",
      "toll_amount": "0.00",
      "vehicle_ferry_amount": "0.00",
      "other_vehicle_amount": "0.00"
    }
  }
}
```

The response depends on the selected coordinates, access notes, and provider
result. This example promises no fixed distance, fuel amount, or budget total.
If OSRM road coverage is unavailable, inspect route/fuel statuses and keep the
budget partial until the missing cost is covered. Adding a labeled whole-trip
transportation allowance can cover estimated costs without resolving road or
ferry access.

### Route Request Limit

Opt-in route previews are limited per authenticated user to ten requests in a
sliding sixty-second window by default. Set the optional environment variable
`PLANNING_ROUTE_REQUESTS_PER_MINUTE` to change that limit. Exceeding it returns
HTTP 429 with `planning_route_rate_limit_exceeded` and
`error.details.retry_after_seconds`. Cost-only requests do not consume this route
limit.

The limiter is in memory per worker; it is not shared across multiple server
workers and resets on process restart. Production deployments requiring a shared
limit need a separately reviewed shared limiter. No new database table, migration,
paid provider, or API key is required by this Phase 3 scope.

## First Version: Target Behavior

The preview starts with an identified catalog destination or selected group of
destinations. It offers transportation and activity choices, preserves selections,
and recalculates expenses and routes without creating a saved trip.

If the destination is only a broad area, resolve a catalog destination first.
Five ranked destination suggestions are a separate discovery step. They are not
five transport choices or five itinerary variants.

The first version supports adult travelers, trip duration, explicit overnight
count, optional accommodation selection, and an optional spending reserve.
Unknown accommodation or other costs produce a partial preview. Child pricing,
booking, live availability guarantees, and permanent preview storage are outside
this first version.

## Traveler Flow

1. The traveler supplies or selects origin, destination, trip duration, traveler
   count, and total budget. Existing chat details prefill these fields.
2. A compact summary lets the traveler edit those details. Ask only for missing
   information that changes the plan.
3. Show transport options for the actual journey, followed by relevant activity
   options. Explain missing route coverage or prices on the affected option.
4. The traveler selects transport and activities. Paid activities are optional
   unless they are explicitly required for access to the destination.
5. Update the preview card, expense breakdown, remaining budget, and route.
6. Allow changes without restarting the conversation or erasing other choices.
7. After selection, the existing trip workflow may save the chosen plan. Creating
   or updating the preview itself saves no trip.

Example: a traveler has already said solo, Davao City origin, Panabo Seawall,
one day, no accommodation, and their budget. The planner retains those facts and
offers applicable transport and recorded activities. Coffee and sweets can be a
requested interest or food allowance; the system does not claim a particular
cafe, menu price, or transport service exists without supporting data.

## Trip Details And Conversation Memory

| Detail | Rule |
| --- | --- |
| Origin | Retain its label and coordinates. A city name may prefill the label, but a pickup/start point is needed for a meaningful route. Offer a map or location selector. |
| Destination | Use active catalog IDs. An unresolved named place cannot become a priced catalog destination through AI text alone. |
| Budget | Display the currency as PHP and clearly label whether it is the whole-trip budget. Default scope is whole trip; an explicitly per-person budget must be converted with traveler count. |
| Travelers | Retain the count. "Solo" resolves to one; an unspecified count needs a compact selector. |
| Duration | Store days and overnight count separately. A stated day trip has zero nights. Do not silently convert every two-day trip into one paid night. |
| Return journey | Offer an editable return-to-origin choice. A suggested day-trip return is visible in the summary rather than hidden in calculations. |
| Activities | Retain requested interests and selected destination activities separately. A requested interest does not establish local availability. |
| Dates and times | Optional for early previews. Missing hours or activity durations leave schedule feasibility unresolved. |

Flutter holds the structured planning state for the current planning session and
sends it with subsequent messages and recalculation requests. The backend returns
the normalized state and applies explicit changes. Short chat history alone is
not the source of truth for already supplied preferences.

A newer explicit value replaces an older value: "one day, no accommodation"
updates an earlier two-day plan. Changing a destination retains budget, travelers,
and other preferences until the traveler changes them, while rechecking options
that depend on the destination.

## Transportation Choices

Each choice identifies its mode, covered travel legs, price basis, estimated
duration where supported, and unresolved connections or expenses.

- Personal vehicle: no passenger fare. Calculate fuel only when road distance,
  fuel efficiency, and fuel price assumptions are available and disclosed. Show
  applicable parking, tolls, and vehicle ferry expenses separately.
- Public or hired transport: use applicable catalog fares. Identify whether the
  fare is per person or per vehicle and whether it covers one leg or a return.
- Mixed journey: compose supported legs, such as land transport plus ferry plus
  a local transfer. A fare for one leg does not cover the whole trip.
- Walking: offer it where the selected route is appropriate. Walking does not
  remove destination entrance or activity charges.

Fuel estimate: road kilometers / kilometers per liter * price per liter.
This is an estimate, not a live fuel-price quotation.

Do not assume identical outbound and return fares unless the rate basis supports
that calculation. A local vehicle option must not imply it serves the entire
intercity journey. Options with unresolved applicability can be inspected, but
cannot be presented as confirmed complete transport plans.

Selecting a mode with missing costs is allowed for a draft. Those costs remain
visible and make the budget partial unless the traveler adds a labeled allowance.
Known unsuitable or unavailable choices are disabled with a reason.

## Activity Choices

Each activity card shows a name, associated destination, description, optional
duration, charge type, and pricing evidence.

The existing `activities` field is descriptive text. The first version can derive
descriptive options from recognizable catalog activities and assign stable option
identifiers tied to the destination and activity key. Ambiguous text stays a
description rather than becoming an invented paid product.

Reconstruct and validate those option identifiers on the server. Client-supplied
labels, prices, or AI-generated activities cannot become catalog facts.

Activity charge types are:

- Included: explicitly covered by an entrance fee or selected package.
- Separately priced: has a known fee basis and quantity.
- Free: supporting information explicitly establishes no activity charge.
- Unknown: offered/described, but its fee or inclusion is unresolved.

An existing numeric zero or a default value alone does not prove an activity is
free. Requested activities absent from the catalog remain interests requiring
confirmation, rather than advertised destination offerings.

## Pricing And Budget Rules

Each calculated line needs an amount, quantity, charge basis, category, source or
assumption, and inclusion/exclusion relationship. Catalog estimates and traveler
allowances are labeled estimates; a catalog row alone does not prove verification.

- Distinguish per-person, per-group, per-vehicle, per-room, per-night, and per-leg
  charges before multiplying them.
- Display source references and verification dates when available. Missing
  provenance remains visible; do not invent a source or verification date.
- A day trip with no stay has no accommodation expense. Overnight stays require
  actual night/room quantities and a compatible rate basis.
- Avoid counting both a destination estimate and activity fees when they cover
  the same expense. Ambiguous inclusions make the relevant breakdown partial.
- Food allowances are adjustable allocations, distinct from verified menu prices.
  Coffee must not be counted both as a selected purchase and inside a food
  allowance that already covers it.
- A reserve is money held aside, not an activity expense. Show it separately and
  include it when comparing suggested trip funds against the total budget.
- Unknown required expenses stay unknown. Do not silently use zero for them.

Expected expenses = transport + entrance/activities + accommodation + food +
other selected expenses, with overlapping inclusions counted once.

Suggested trip funds = expected expenses + selected reserve.

| Preview result | Meaning |
| --- | --- |
| Complete estimate | Every required cost has a calculation basis or an explicit allowance. Show total estimate, suggested trip funds, and remaining budget. |
| Partial estimate | Show the calculated subtotal and the unpriced items. Full total and final remaining budget are unresolved. |
| Fits estimated budget | All required costs are represented and suggested trip funds are within budget. Label allowances and unverified estimates. |
| Over budget | The complete estimate exceeds budget, or the priced subtotal plus reserve already exceeds it. For a partial estimate, show the minimum known excess. |
| Budget fit undetermined | Missing costs could change affordability; a low subtotal cannot establish that the trip fits. |

An over-budget selection remains editable. Suggest a cheaper supported option or
removing an optional expense; do not silently substitute another plan. Unknown
prices cannot win a "cheapest" comparison.

## Route Behavior

- Use origin coordinates, selected stops, transport mode, and return preference.
- Preview a single-destination journey. Suggest an efficient stop order for
  multiple destinations while preserving explicit order constraints.
- Return estimated distance, duration, travel legs, provider, and limitations.
- Label straight-line fallback estimates clearly; they cannot establish the
  actual road distance needed for a reliable fuel estimate.
- Existing public-transport routing estimates do not prove real services,
  timetables, or connections. Use fare/route evidence separately.
- Road optimization cannot establish that an island is accessible by car or that
  a ferry connection is available. Keep unresolved legs explicit.
- Budget coverage and route confidence are independent. A priced preview may
  still have an unresolved route or schedule.

## Preview Card

The card contains:

- Destination name and trip summary: travelers, duration, stay requirement.
- Selected transport and activities, with controls to change them.
- Itemized expenses, selected reserve, and suggested trip funds when calculable.
- Remaining budget or an over-budget amount when calculable.
- Route summary and travel-time estimate.
- Cost coverage, estimates/allowances, and unresolved details beside the affected
  item rather than buried in an AI paragraph.
- Actions to change transport, change activities, inspect the breakdown, and
  select the plan for the existing save-trip workflow.

When sufficient comparable information exists, the interface may show alternate
plans using the returned choices. The first version does not require three or
five variants and does not fabricate variants to meet a count.

## Target Backend Contract

Endpoint: `POST /api/v1/planning/preview`.
Phase 1 begins with choices and normalized state; Phase 2 adds cost completeness.
Phase 3 adds the opt-in road-route and fuel layer described above. Chat and
Flutter integration remain Phase 4, while this target contract also covers later
connection/pricing refinements.

Use the same endpoint for the initial preview and subsequent recalculations.
The request carries the complete current state, making the first version
stateless. Recalculation does not require a Groq call.

| Request group | Contents |
| --- | --- |
| Constraints | Origin label/coordinates, destination IDs, whole-trip budget, travelers, days/nights, interests, dates/times when known, return preference. |
| Selections | Transport choice and fare IDs by leg, activity option IDs, optional accommodation IDs, explicit allowances, reserve. |
| Revision | Client input revision, echoed to prevent older responses replacing newer selections. |

| Response group | Contents |
| --- | --- |
| Normalized state | Resolved constraints, retained selections, missing essential inputs. |
| Choices | Selectable transport/activity options, related IDs, charge basis, inclusion rules, source metadata, applicability and missing information. |
| Budget | Itemized calculated amounts, priced subtotal, nullable full estimate and remaining budget, reserve, coverage, fit status, assumptions and missing costs. |
| Route | Stops/legs, distance/time, provider, estimate status, unresolved legs and schedule information. |
| Selection problems | Unavailable, stale, mismatched, or incompatible choices and suitable replacements when known. |
| Next actions | Choose/change options, resolve genuinely missing information, or refresh stale choices. |

Flutter ignores responses for an older input revision. The backend reloads current
catalog facts and recomputes costs rather than trusting client totals. Changed
catalog facts are disclosed; invalid selections remain visible for correction
and are never silently replaced.

AI may parse a message into proposed state changes or explain the calculated
preview. The backend validates those changes, options, quantities, and totals.
Cards and recalculation should remain usable if Groq is unavailable.

## Approved Implementation Boundary

New module: `app/features/planning/` with thin router, schemas, and service.
Phase 1 reads existing destination and rate data. Phase 2 adds cost completeness;
Phase 3 coordinates the existing route service with explicit fuel assumptions.
Flutter will render structured choices and submit
selected identifiers when its integration contract is delivered.

Initial database changes: none required for stateless previews and descriptive
activity choices. This leaves some prices unresolved until supporting data exists.
An itemized activity catalog, normalized fare/room charge units, verified source
metadata, persistent preview sessions, or transport-leg relationships would need
separate schema approval and Alembic migration review.

Environment variables and external services: Phase 3 reuses configured OSRM
routing and adds optional `PLANNING_ROUTE_REQUESTS_PER_MINUTE` for its route
limiter. Groq integration belongs to Phase 4. No new paid provider or API key is
proposed.

Security: use existing authentication, validate active destinations and available
rates, reject mismatched or forged option identifiers, recalculate prices on the
server, and rate-limit costly routing/AI operations. The existing trip ownership
checks apply when a selected plan is saved later.

## Target Acceptance Criteria

1. Known origin, budget, traveler count, and duration carry forward across chat
   turns and card selections; newer explicit values update the matching fields.
2. Selecting transport or activities updates the preview without clearing
   unrelated preferences or valid selections.
3. Displayed catalog choices reference applicable active/available records;
   unsupported requested activities remain distinguishable from catalog offers.
4. Missing fees and unknown charge units remain distinguishable from verified
   free or included items.
5. Personal-car calculations disclose fuel assumptions and other unresolved
   travel expenses; selecting a car never automatically makes travel free.
6. Passenger, room/night, return-leg, and inclusion rules prevent unsupported
   multiplication and duplicate charges.
7. A day trip with explicitly no accommodation adds no stay charge.
8. Partial budgets do not claim affordability; an already over-budget subtotal
   still produces an actionable over-budget result.
9. Route fallbacks and unresolved public-transport/ferry legs remain explicit.
10. Invalid or changed options are disclosed instead of silently substituted;
    older responses cannot replace newer previews in Flutter.
11. Forged option IDs and client price changes cannot alter catalog charges.
12. Preview generation and recalculation work without AI and create no saved trip.

Phase 1 tests cover its catalog/state boundary. Tests for subsequent phases
should exercise the remaining target behaviors with controlled
catalog data, including missing-price, over-budget, outdated-selection, route
fallback, and return-journey cases.
