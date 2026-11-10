# Objectives and panel upgrade plan — 9 November 2026

## Approved scope update — 10 November 2026

The user approved using the saved place pin (`lat/lng`) for the current version's
Top 5, itinerary context, and route estimates. A separately reviewed visitor
arrival point is optional and is not a prerequisite for these planning flows.
Defer the arrival-point admin editor; keep existing fields and validation for
future use and continue honoring any already verified arrival data. No schema
or routing-code change is needed to adopt this scope.

Label pin-based routes as approximate planning results. A road path to a pin
does not establish a public entrance, opening status, or boat connection. Admin
review still covers place identity, pin location, access, prices, and hours;
unknown facts stay explicit. Do not set `route_ready=true` merely because a pin
exists. See the [current audit and handoff](claude_codex_objectives_audit_2026-11-10.md)
for implementation status; unamended observations below are dated 9 November.

Scope: one plan that merges two planning sources from 9 November 2026:

- the audit of the backend against the six study objectives and the panel's
  comments (the earlier version of this file); and
- the Codex planning conversation about admin place prefill, a personalized
  Top 5, multi-stop routes, and travelers arriving by plane or boat, with a
  follow-up review of that conversation against the code.

Planning only. No application code, database, `.env.example`, or
`docs/models.md` was changed by this document. Every step needs separate
approval under `AGENTS.md`; steps that change the schema are marked.

What was checked, and how:

- Catalog figures (30 active destinations, 0 route-ready, 648 staged candidates)
  come from [system_issues_audit_2026-11-06.md](system_issues_audit_2026-11-06.md)
  and [step0_readiness_audit_2026-11-05.md](step0_readiness_audit_2026-11-05.md).
  They were not re-checked against the live database on 9 November.
- Backend statements were checked against the code in this repository.
- Traveler-app statements were checked in `../UI_FOR_LAKBAY` for the destination
  parser, the home card fee label, the Top 5 request and the route call. The
  commute guide and the admin app were not checked.

## 1. Panel comments

| Panel comment | State | Evidence |
| --- | --- | --- |
| Geo-analytics, not just mapping | Done | `POST /geo-analytics/destination-groups` scores groups by proximity, route efficiency, district, mode fit, preference, budget, popularity, accessibility and child-friendliness (`app/features/geo_analytics/service.py`). |
| Group suggestions ranked by a formula | Done for one user | Weights exist in code. They use only the requester's preferences, not the whole group's. |
| Children free or half price by age | Partly done | Planning preview accepts `child_ages` and free/half/full age bands (`planning/costs.py`). Activity and per-person transport bands, saved trips and expense sharing are not covered. |
| AI itinerary from geo-analytics | Done | Phase 15E passes groups, routes, budget and warnings to the prompt; the backend still validates IDs and budget. |
| Top 5 destinations | Implemented; catalog and device checks remain | Weighted Top 5 accepts approximate place pins; zero verified arrival points does not block it. Return fewer than five with an explanation when insufficient places qualify. |
| Top 5 based on the user's budget, location, vibes and vehicle | Implemented on current branches | The traveler uses the weighted Top 5 contract; see the 10 November audit for scoring, route labels, and the >50-candidate filtering edge case. |
| Multi-stop route, not a straight line | Partly done | `POST /routes/optimize` orders several stops and returns OSRM road geometry for driving and walking. Public transport is ordered by nearest neighbor with estimated distances (`routes/service.py:146`). The Codex scan reported that the app's commute guide can draw straight segments; not re-checked. |
| Land, plane, boat | Mostly missing | `TravelMode` is `driving`, `walking`, `public_transport` only (`routes/schemas.py:6`). Air/sea appear as regex warnings and a ferry-fare check. `transport_mode` is free text. |
| Cost projection by activity | Partly done | Projection works, but the catalog has no structured activity prices or durations. |
| Feedback on the itinerary | Done | `POST /planning/feedback` returns findings. No overall score or alternatives. |

## 2. Objectives

| Objective | State | Gaps |
| --- | --- | --- |
| 1. At least 5 destinations via geo-analytics | Implemented; quality checks remain | Place pins are permitted for approximate planning. Complete catalog/access/cost review, phone verification, and the >50-candidate filtering correction; do not require entrance verification for this version. |
| 2. Compare three Groq models | Weak | Compare slots are empty in `.env.example`. Metrics cover latency, success and validity only; no relevance or accuracy score. Evaluation states it does not measure recommendation accuracy. |
| 3. Itinerary through an AI chatbot | Implemented; integration gaps remain | RAG, retrieval intent and planning chat exist. Place pins can supply route context. The per-person budget correction is tested locally; stay selection, catalog quality and device verification remain. |
| 4. Adaptive route optimization (Haversine + OSRM) | Partly done | OSRM Trip with nearest-neighbor/Haversine fallback. Nothing selects a method by stop count; walking is an estimate until a foot-profile OSRM exists; no air or sea legs. |
| 5. Group coordination | Done | Trips, members, tasks, expenses, notifications. No group preference or child-age aggregation. |
| 6. ISO/IEC 25010 evaluation | Partly done | Completed-trip app assessments shipped in `05fa6e5` ([app_assessments.md](app_assessments.md)): six ratings informed by selected ISO/IEC 25010:2023 characteristics, with an admin summary. No study protocol, recommendation-acceptance link, or export yet. |

## 3. Comparison models (corrected)

Comparison set, replacing the Llama 3.3 70B / Llama 3.1 8B / Qwen 3.6 27B wording
in the original objective and in `docs/models.md` lines 12–14 and 110:

```text
GROQ_MODEL_COMPARE_A=qwen/qwen3.8-27b
GROQ_MODEL_COMPARE_B=openai/gpt-oss-120b
GROQ_MODEL_COMPARE_C=openai/gpt-oss-20b
```

- No code hard-codes the old names; `app/integrations/groq/model_selector.py`
  reads these environment variables.
- `docs/models.md` still lists the Llama models as deprecated (shutdown
  16 August 2026). It needs updating when approved.
- Reword Objective 2 in the manuscript to name the new models.
- Default rate limits are 2 requests/minute and 100/day. Raise them for
  benchmark runs.
- The fallback model is `qwen/qwen3.8-27b`. Decide whether comparison runs
  disable fallback so a failed model is recorded as a failure.

## 4. Ground rules for place data

These rules apply to every step below.

1. **Suggested → confirmed → published.** OSM tags and any AI text are
   suggestions. Only values an admin accepts and saves become traveler-facing,
   and only published records reach recommendations, planning and AI prompts.
2. **Unknown is not "no".** A suitability flag with no evidence stays unknown.
   It must not become kid-friendly or not kid-friendly by default.
3. **Hours and prices need a source and a check date.** OSM `fee=yes` means a
   fee exists, not an amount. Prices go into the existing accommodation and
   transportation rate records, not free text.
4. **The traveler app reads saved records only.** It never calls OSM or an AI
   provider when a card opens.
5. **Directions are computed, not stored.** Distance and directions come from
   each traveler's starting point through the routing service. Use the saved
   place pin for the current approximate planning flow. Entrance review is an
   optional later improvement; a pin does not prove an entrance.
6. **Estimates are labeled.** A straight line or a coordinate estimate is never
   shown as road directions or a real commute.

## 5. Already in place for the new work

| Area | What exists | Gap |
| --- | --- | --- |
| Staged places | OSM candidate queue; publishing requires access verification and sets `route_ready=False` (`candidate_service.py:124`). | Publishing carries name, description, district, location, category, activities, coordinates, costs, fees and hours only. Travel notes, suitability and photo are not carried over. |
| Admin OSM lookup | **Uncommitted** in the working tree: `GET .../osm/search`, `GET .../osm/{type}/{id}/suggestions`, `GET .../{candidate_id}/osm-suggestions`, an Overpass client with caching and rate limits, `tests/test_osm_place_review.py`, and notes in [destinations.md](destinations.md). No schema change. | Not reviewed or committed. The public Overpass instance returned HTTP 406 from the development environment during a live check, so live lookup does not work yet. |
| Photos | Cloudinary upload client used for trip memories (`app/integrations/storage/`). | Destination photos accept a pasted URL only; no admin upload endpoint. |
| Itinerary warnings | Every itinerary warns that opening hours are unverified (`ai/service.py:640`). | The warning cannot change because no verification date exists. |
| Suitability flags | Backend columns default to `False` (`destinations/models.py:84`). | The app parser defaults `is_kid_friendly` and `is_elderly_friendly` to `true` when missing (`UI_FOR_LAKBAY/lib/models/destination.dart:507`). The two sides disagree, and neither can say "unknown". |
| Place details in the app | The parser reads fees, hours, activities, suitability flags and coordinates. | The app does not parse `how_to_get_there`, `travel_notes` and the other travel fields the backend stores. A missing fee becomes "Not listed", so the home card shows "From Not listed" (`destination_card.dart:223`). |
| Routes | `POST /routes/optimize` with OSRM for driving and walking; the app already calls it (`UI_FOR_LAKBAY/lib/providers/route_ways_controller.dart`). | Public transport is an estimate; walking needs a foot-profile OSRM; no air or sea legs. |

## 6. Plan

| Step | Name | Schema change | Phase in `core_focus.md` |
| --- | --- | --- | --- |
| 1 | Unblock the data | No (data work) | 2 |
| 2 | Finish the admin OSM lookup | No | 2 |
| 3 | Personalized Top 5 | No | 3, 6 |
| 4 | Unknown suitability and check dates | **Yes** | 2 |
| 5 | Destination photos | No | 2, 10 |
| 6 | Place details in the traveler app | No (app only) | 2 |
| 7 | Multi-stop routes and adaptive optimization | No | 6 |
| 8 | Land, air and sea travel | **Yes** | 6 (scope addition) |
| 9 | Group and child-aware scoring | Likely | 8, 15 |
| 10 | Activity-based cost projection | **Yes** | 4 |
| 11 | Model comparison with real metrics | **Yes** | 5, 14 |
| 12 | Richer itinerary feedback | No | 12 |
| 13 | ISO/IEC 25010 evaluation | Likely | 14 |

### Step 1 — Unblock the data (no code)

- Review the 30 live destinations' identities and place pins, access status,
  hours, fee amounts and charging units. Keep unsupported values unknown.
- Publish reviewed candidates one at a time where coverage or suitability is
  insufficient. Five places per district already exist; eligibility depends on
  the request and must not be filled with unsuitable places.
- Check destination 7's image delivery and fill missing images. The 10 November
  audit observed HTTP 403 from its environment; confirm the cause before editing.
- Keep walking results labeled as estimates until a separate foot-profile OSRM
  service is available. Walking-service setup is a separate operational task.

Done when: representative requests return suitable results from reviewed place
data, explain shortfalls, and carry honest route and cost labels. Demonstrate five
where five actually qualify. Visitor-arrival verification is deferred; the
[manual arrival checklist](lakbay_manual_arrival_checklist.md) remains optional
future work rather than a Top 5 or itinerary-generation gate.

### Step 2 — Finish the admin OSM lookup (code, no schema change)

- Review the uncommitted OSM increment listed in section 5, run its tests, and
  commit it as one change.
- Find an Overpass instance that answers from the deployment environment, or fix
  the request that receives HTTP 406. Manual entry must keep working when OSM is
  unavailable (the API already returns `osm_unavailable`).
- Admin flow: enter a name and approximate location, or open a staged place →
  pick the correct OSM match (a name match alone never auto-selects) → review
  each suggestion beside the current value and its source tag → accept, edit or
  reject → save. Saving requires a confirmed place identity and reviewed pin;
  existing publication checks for category, district, purpose and access evidence
  remain. A separate visitor-entrance coordinate is optional.
- Check for an existing Lakbay destination before publishing (the lookup already
  reports nearby same-name destinations and existing candidates).
- Travel notes, suitability and photo for a staged place: publish first, then
  complete them in the destination editor with `PATCH /destinations/{id}`. The
  place stays `route_ready=false` until its arrival is verified. Adding these
  columns to `destination_candidates` would be a schema change; only do it if
  admins need to finish everything before publishing.

### Step 3 — Personalized Top 5 (code, no schema change)

Addresses the panel comment that Top 5 must follow the user's preferences.

- Make the app's Top 5 button use one route-aware request with the user's
  current planning state: origin, travel mode or vehicle, interests and vibes,
  day count, traveler count, child ages, and total budget. Today it sends only
  vibes, categories, districts and a budget class.
- Add budget to the route-aware ranking. Treat a whole-trip budget as a
  whole-trip limit, not as the maximum price of every single place.
- Apply firm filters first (inactive, required accessibility, unreachable by the
  chosen mode), then rank by preference match, travel time from the origin,
  affordability and suitability. Popularity is only a secondary factor.
- Return a short reason for each place, for example "matches your nature vibe"
  or "about 40 minutes by car from your start".
- Decide the shortfall behavior: return fewer than five with a reason, or show
  unverified places labeled "approximate location".
- Label the home page "Popular" list as a general list, separate from the
  personalized Top 5.
- Document the exact score formula in `docs/recommendations.md`.

### Step 4 — Unknown suitability and check dates (schema change, needs approval)

- Make the suitability flags nullable so `null` means unknown. Recommendation
  filters treat unknown as not matching a required need.
- Add check dates for hours and fees, with a source URL. Keep it small: a few
  columns on `destinations`, not a per-field history table.
- Use the hours check date to decide the itinerary opening-hours warning instead
  of always showing it. Keep the other schedule and access cautions.
- Change the app parser so a missing flag is unknown, not `true`.
- Write the Alembic migration, review it, and test upgrade and downgrade.

### Step 5 — Destination photos (code, no schema change)

- Add an admin-only `multipart/form-data` upload endpoint that reuses the
  Cloudinary client and saves the returned URL to `image_url`. Validate type and
  size. Keep pasted URLs as an option.
- When the matched OSM place has an `image` or `wikimedia_commons` tag, show it
  as a suggestion. The admin checks that it shows the right place and records
  the credit and license.
- Show a placeholder when a place has no photo.

### Step 6 — Place details in the traveler app (app only)

**10 November follow-up:** the five travel fields below are now retained and
shown through the existing tips section; edited/cleared values are covered by
refresh regressions. Backend itinerary context also retains these details and
rate currency/charging units. The admin editor's exact save payload is tested.
Deployment/device verification and the other presentation gaps remain; see the
[current handoff](claude_codex_objectives_audit_2026-11-10.md).

- Parse the travel fields the backend already returns (`how_to_get_there`,
  `travel_notes`, `best_time_to_visit`, `what_to_bring`, `estimated_travel_time`).
- Keep the home card short. Show hours, location, activities, fees,
  accommodation, transport, photo and directions on the details page.
- Show missing values plainly, and fix the "From Not listed" fee label.
- Refresh the catalog after an admin publishes or edits a place.

### Step 7 — Multi-stop routes and adaptive optimization

- Send all selected stops together with the start point, travel mode and
  return choice. Optimization may change the order; it never drops a stop.
- Show the backend polyline, numbered stops, each leg's distance and time, and
  the total. Offer "keep my order" and recalculate when a stop, start point,
  mode or return choice changes.
- Choose the method by stop count: exact search for small sets, OSRM Trip or
  nearest-neighbor plus 2-opt for larger ones. Report the method used and why.
  Keep the Haversine fallback, labeled as an estimate.
- For multi-day trips, group stops by day and optimize from each day's start
  (hotel or arrival point). Check opening hours, visit length and travel time.
- Commute: keep it an estimate and list missing connections until boarding
  points and transfers are verified.
- Add edge-case tests (1–2 stops, unreachable stops, estimated routes) and
  update `docs/routing.md` with the algorithm comparison.

### Step 8 — Land, air and sea travel (schema change, needs approval)

- Add a travel category (`land`, `air`, `sea`, `mixed`) to transport records and
  normalize `transport_mode`, with an Alembic migration.
- Represent a trip as legs, each with its own mode, duration, fare, source and
  confidence. Example: Cebu → Davao airport (air) → hotel (land) → stops (road).
- Admins keep verified airport and port connections with fare references and a
  check date. Travelers can enter a booked flight or ferry, or an allowance.
- Measure local reach in Top 5 from the arrival airport, port or hotel.
- Model non-road legs from catalog transport rows; Haversine is for display
  only. Reuse OSRM ferry-crossing data.
- Feed these legs into cost projection and itinerary feedback.
- Never show an invented departure time. Live schedules are out of scope
  (section 7).

### Step 9 — Group and child-aware scoring (schema change likely)

- Aggregate members' saved preferences; show per-member fit and a group score.
- Store party composition (adults, child ages) on trips/members.
- Extend age-band rules to activities and per-person transport.
- Leave expense sharing unchanged until budget rules are approved.

### Step 10 — Activity-based cost projection (schema change, needs approval)

- Add structured activity records (fee, duration, charging unit, source); seed
  them for live places after the stateless projection is reviewed.
- Give activities stable IDs. Planner option IDs hash the activity label today
  (`planning/service.py:250`), so renaming a label can break a saved selection.
- Group projection by destination, activity, transport, stay and meals; flag
  unknown prices instead of treating them as zero.

### Step 11 — Model comparison with real metrics (schema change, needs approval)

1. Set `AI_MODEL_COMPARISON_ENABLED=true` and the three IDs from section 3,
   locally and on Render.
2. Check prompts and output parsing against all three models. The GPT-OSS
   models are reasoning models, so `itinerary_schema.py` and `client.py` may
   need per-model reasoning and response-format settings.
3. Build a fixed benchmark of 20–30 prompts covering districts, budget levels,
   party composition including children, travel categories, and one- and
   multi-day trips. Every model gets identical inputs.
4. Store a per-run score: valid JSON, valid destination IDs, budget fit, route
   feasibility, preference match, child-pricing correctness, plus an optional
   human relevance rating.
5. Extend the evaluation endpoint to report accuracy, latency (average and
   95th percentile), validity and failure rate per model.
6. Record findings in `docs/phase14_evaluation.md`; keep raw results for the
   manuscript and add `outputs/` to `.gitignore`.

### Step 12 — Richer itinerary feedback

- Add an overall score and ranked alternatives (cheaper, shorter, more
  kid-friendly) to `/planning/feedback`. Keep it advisory and stateless.

### Step 13 — ISO/IEC 25010 evaluation (schema change likely)

- Build on the completed-trip app assessments. Decide with the adviser whether
  six statements are enough or more characteristics need questions.
- Add CSV export of the anonymized responses for the manuscript.
- Link recommendation results to later interactions so acceptance can be
  measured (evaluation currently notes this link is missing).
- Agree the user-testing protocol with the adviser.

## 7. Deferred or out of scope

| Item | Reason |
| --- | --- |
| AI-drafted descriptions, activities or suitability (Gemini or Groq) | Adds hallucination risk for little gain. If added later, use the existing Groq integration and draft only from supplied source text. |
| Live flight and ferry schedules and fares | No reliable data source. Step 8 uses admin-verified connections and user-entered bookings. |
| Full per-field source and verification history | Step 4's check dates cover the capstone need. |
| Name search through the public Nominatim service | Its usage policy forbids autocomplete and limits request rates. Overpass search near a point covers the admin flow. |
| Destinations outside the Davao Region | Separate scope decision. Travelers from elsewhere are handled by Step 8. |

## 8. Order and risks

1. Verify the locally fixed per-person budget flow on a device, then finish
   Step 1's place-pin, access and cost review. Arrival-point editing is deferred.
2. Review Step 2's pending admin work and verify the saved-data-to-app flow.
3. Validate Step 3's implemented weighted Top 5 and resolve its shortlist edge case.
4. Steps 4, 5 and 6 to complete place data end to end.
5. Step 7, then Step 8.
6. Steps 9 and 10.
7. Step 11, then Step 13, which needs participants, so start recruiting early.
8. Step 12 whenever there is room.

Capstone demo target: admin-reviewed places → explainable Top 5 → an approximate
multi-stop Davao day plan using place pins, with access and cost uncertainties
shown. A trip that starts in Luzon or the Visayas is the next route milestone.

Risks:

- The public Overpass instance returned HTTP 406 from development; live OSM
  lookup is not confirmed.
- Production uses the public OSRM demo host.
- From the 6 November audit, not re-checked: rotate the Groq key and confirm
  `DEBUG=false` on Render; local `main` was behind `origin/main`.
- The OSM lookup work and today's review files are uncommitted.

## 9. End-to-end checks

Run these before calling the place, Top 5 and route steps done:

- New and staged places with complete data, partial data, no OSM match, several
  matches, a wrong match, a wrong photo, and OSM unavailable.
- Missing hours, conflicting fees, no accommodation, and an unroutable place pin.
- Pin-based routes remain approximate and do not expose verified turn-by-turn
  directions. Existing optional verified-arrival behavior remains compatible.
- Rejected or unconfirmed suggestions never appear in the app, recommendations
  or AI prompts.
- Admin save → backend record → app refresh → planning preview → itinerary
  generation all show the same saved values.
- Top 5 with different budgets, start points and travel modes returns different,
  explained results, or fewer than five with a reason.
- Multi-stop routes with 1, 2 and many stops, an unreachable stop, and a provider
  failure that falls back to a labeled estimate.
