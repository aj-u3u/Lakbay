# Panel Feedback Improvement Guide

Prepared: 12 November 2026  
Status: Documentation and source-code assessment only. Recommendations are not implemented by this guide.

## 1. Purpose, source, and boundaries

This guide maps the panel feedback to the current Lakbay+ repository: what exists, where it lives, what remains incomplete, and how a future improvement could be verified. It complements [the initial user observations](OBSERVATIONS_AND_IMPROVEMENT.md); it does not replace or modify them.

Source: [Lakbay+ Panel Feedback & Presentation Transcript](<../references/Lakbay+ Panel Feedback & Presentation Transcript.pdf>), nine PDF pages. Page references below use physical PDF pages, starting at 1. Timestamps refer to the recording represented in the transcript, not to a verified calendar date.

The PDF contains an executive summary, direct panel discussion, a team debrief, and administrative conversation. These have different evidentiary weight:

- **Panel feedback:** recommendations or questions in the panel discussion.
- **Team debrief:** the team's interpretation and possible solutions after the presentation. These are not automatically panel requirements.
- **Presentation gap:** a feature was not demonstrated; this alone does not prove it is missing.
- **Administrative note:** grading, submission, and scheduling discussion, separate from product requirements.

Some transcript passages contain uncertain wording or unclear speakers. Prefer the timestamped passage over a broader executive-summary interpretation, and preserve uncertainty rather than inventing a precise requirement.

Only this Markdown document is created. Application code, the source PDF, the earlier guide, API contracts, databases, migrations, dependencies, and deployment settings remain unchanged.

### Assessment labels

| Label | Meaning |
|---|---|
| Implemented in inspected code | A relevant code path exists; this is not a claim of a successful live workflow. |
| Partially implemented | Supporting code exists, but the full requested behavior or integration is incomplete. |
| Not found in inspected paths | No relevant implementation was located in the reviewed paths; not a claim about every possible branch or deployment. |
| Presentation gap | Existing behavior needs to be shown or demonstrated more clearly. |
| Requires runtime verification | Device, deployed API, data, timing, or cross-account behavior must still be checked. |

## 2. Application structure and shared data flow

```text
apps/admin_app/                  Flutter administrator workspace
  lib/screens/                  Destination, place-review, and rate editors
  lib/services/                 API client and administrator session

apps/traveler_app/               Flutter traveler application
  lib/screens/                  Discovery, planner, trips, maps, and groups
  lib/widgets/                  Cards, party details, and cost controls
  lib/models/                   Destination, trip, and planning representations
  lib/providers/                Shared authentication and trip/planning state
  lib/services/                 API client and local persistence

services/api/                   Shared FastAPI backend
  app/features/                 Feature routers, schemas, services, repositories, models
  app/integrations/             AI, routing, weather, storage, and place lookup
  app/db/                       SQLAlchemy sessions and Alembic migrations
  tests/                        Backend verification
```

Admin changes flow through the admin API client into backend services and database records. Travelers retrieve those shared records through their own API client and models. Planning state and selected catalog IDs then feed backend recommendations, cost previews, route calculations, AI generation, and trip saving.

For most feedback, the integration boundary matters as much as the individual screen. A database field is not sufficient if the admin cannot maintain it, the API does not return it, the traveler drops it during parsing, or AI planning never receives it.

## 3. Feedback-to-code traceability matrix

| ID | Topic and source | Current assessment | Main areas |
|---|---|---|---|
| PF-01 | Davao scope; panel, 00:00 and 06:00-07:40, pp. 2, 4 | Davao-focused catalog/prompts exist; explicit regional routing enforcement requires review. | Catalog, AI prompts, route origin inputs, map starting points. |
| PF-02 | Stop sequencing and backtracking; panel, 02:05-02:34 and 12:15-13:13, pp. 3, 5 | Ordering algorithms exist; itinerary/map consistency requires runtime verification. | Route service, ordering helpers, planning preview, result/group maps. |
| PF-03 | One map and editable stops; team debrief, 23:16-25:00, pp. 7-8 | Multi-stop route requests exist; a complete add/remove/reorder experience is not established by the inspected paths. | Planner selections, shared state, saved destination IDs, map controls. |
| PF-04 | Practical travel guidance and Samal crossings; panel, 01:33 and 14:07-15:11, pp. 3, 5-6 | Road modes and ferry metadata exist; mixed-mode access remains partial. | Transport rates, planning routing, route schemas, traveler guidance. |
| PF-05 | Venue hours, fees, tours, and amenities; panel, 01:00-01:33, p. 3 | Several fields exist; structured corkage, tour packages, and paid amenities are not in the inspected destination contract. | Admin destination/rate editors, catalog schemas, destination details. |
| PF-06 | Arbitrary activity prices; panel, 16:00-17:40, p. 6 | Explicit cost controls exist, but manual activity amounts remain a UX and data-model concern. | Activity controls, cost projection, fee provenance, AI context. |
| PF-07 | Budget assistance in itinerary prompts; panel, 03:27-04:21, p. 3 | Cost previews exist; automatic allocation and budget suggestions remain proposals. | Planning cost engine, review sheets, AI generation. |
| PF-08 | Discovery lists should have actionable cards; panel, 08:58-11:15, pp. 4-5 | Cards exist, but recommendation/state conditions limit their use. | Chat intent, structured recommendations, suggestion cards. |
| PF-09 | Clear traveler-count/date prompts; panel, 09:42-11:15, p. 5 | Current controls use explicit traveler/day/night fields; historical wording and current conversational behavior need verification. | Chat prompts, review sheets, party fields, shared state. |
| PF-10 | Slow chat; team debrief, 21:30, p. 7; also executive summary, p. 2 | Timeouts, pending state, and backend metrics exist; measured latency is not established. | AI calls, retrieval, routing, provider retries, evaluation. |
| PF-11 | Show group itinerary sharing; panel, 03:07, p. 3 | Membership/sharing foundations exist; primarily a presentation gap until exercised across accounts. | Saved trips, registered-email membership, notifications, permissions. |
| PF-12 | Benchmark activity presentation; panel, 17:40, p. 6 | Suggested UX research; no external benchmark performed for this guide. | Activity grouping, venue details, pricing explanation. |
| PF-13 | Prepare prompts and demonstrate objectives; panel, 01:00 and 03:27-04:21, p. 3 | Rehearsal/evidence work rather than proof of missing functionality. | Demo scenarios, checked data, end-to-end workflow evidence. |

## 4. Detailed findings and proposed improvements

### PF-01: Keep routing within the Davao Region

**Interpretation.** People outside Davao may discover and plan trips online. The panel recommends starting local route optimization from a Davao arrival point, hotel, terminal, or city rather than routing the whole Manila-to-Davao journey. The introductory mention of Mindanao should not silently expand the product to all of Mindanao.

**Current code.** [AI prompts](../services/api/app/integrations/groq/prompts.py) describe Davao Region travel, and [retrieval intent](../services/api/app/features/ai/retrieval_intent.py) understands regional/district requests. [Route schemas](../services/api/app/features/routes/schemas.py) validate global coordinate ranges; those checks are not a Davao boundary rule. The [result map](../apps/traveler_app/lib/screens/planner/planner_results_screen.dart) and [group map](../apps/traveler_app/lib/screens/collaboration/group_dashboard_screen.dart) can use device coordinates as a start point.

**Proposed improvement.** Distinguish the traveler's current location from the local itinerary start. For an outside-region traveler, request a local arrival/start point before optimizing local travel. Keep flights or other travel into Davao as contextual information rather than claiming end-to-end multimodal routing. Define regional-origin validation consistently across UI, preview, and direct route requests before implementation.

**Acceptance.** A Manila-based user can browse Davao destinations, select a Davao start, and obtain a local route. An outside-region GPS point is not silently submitted as the start of the Davao itinerary.

### PF-02: Optimize the selected itinerary, then present the same order

**Interpretation.** The panel's concern is efficient sequencing of several chosen stops from a starting point. It is broader than finding nearby attractions and does not require a full turn-by-turn navigation product.

**Current code.** [RouteService](../services/api/app/features/routes/service.py) already supports multiple destination IDs, an origin, and an optional return. [Ordering helpers](../services/api/app/features/routes/ordering.py) provide exact Held-Karp ordering for small cost matrices and nearest-neighbor/2-opt ordering; the service also uses OSRM Trip with fallback behavior. Public-transport paths can be estimated. The response describes its ordering method and route provenance.

**Proposed improvement.** Validate that the requested stops, optimized order, numbered map markers, journey legs, and itinerary display agree. Show what was optimized and when a result is estimated. Do not replace the existing algorithms merely because the demonstration failed to explain them. Automatic reordering should be a clear action, distinct from preserving the traveler's chosen order. Consider timing, opening hours, or fixed lunch appointments as separate constraints; shortest travel order alone does not prove schedule feasibility.

**Acceptance.** With a fixed Tagum start and multiple reviewed Davao stops, show the requested versus suggested sequence and consistent legs/markers. A fallback remains labeled as an estimate. Avoid claiming that every heuristic route is mathematically optimal.

### PF-03: Support a coherent multi-stop map and editing experience

**Attribution.** The detailed add/delete/reorder discussion is in the team debrief. The panel's direct sequencing feedback supports the underlying multi-stop need.

**Current code.** Both [result maps](../apps/traveler_app/lib/screens/planner/planner_results_screen.dart) and [group maps](../apps/traveler_app/lib/screens/collaboration/group_dashboard_screen.dart) pass `Trip.destinationIds` to routing, with a single-catalog-destination fallback. The [Trip model](../apps/traveler_app/lib/models/trip.dart) retains destination IDs. [TripProvider](../apps/traveler_app/lib/providers/trip_provider.dart) supports replacing planning destination IDs, but currently clears dependent selections, allowances, and generated options. Existing multi-stop API support does not establish a complete persistent stop editor.

**Proposed improvement.** Build on the shared stop IDs rather than introducing an independent map-only list. Adding, removing, or reordering stops should reconcile affected transport, activities, costs, route, and generated options. Preserve applicable information where possible; disclose invalidated choices. A future design must distinguish per-day stop order, whole-trip order, manual order, and optimized order. Do not assume a separately locked final destination is supported by the current route request.

**Acceptance.** After a stop edit, map markers, itinerary, cost preview, and saved/reopened trip agree. Removed stops leave no stale selected activities or duplicate charges. An old route response cannot replace a newer edit.

### PF-04: Explain transport choices and ferry connections honestly

**Interpretation.** The panel discusses practical private-car/taxi travel and local ferry or barge crossings. The direct discussion favors reducing complicated bus/jeep routing; the summary's broader list should not be treated as a demand to build a complete transit network.

**Current code.** [Route travel modes](../services/api/app/features/routes/schemas.py) are `driving`, `walking`, and `public_transport`. [Planning routing](../services/api/app/features/planning/routing.py) recognizes hired-car/taxi contexts and flags mixed or non-road connections. [Route responses](../services/api/app/features/routes/schemas.py) can include ferry crossings, while [transportation records](../services/api/app/features/transportations/models.py) store destination-related rates. A ferry segment in a provider result does not establish a current sailing schedule, fare, pier wait, or guaranteed boarding access.

**Proposed improvement.** Present the chosen travel method, local start, road legs, terminal/transfer guidance, and unresolved crossing assumptions together. Keep estimated fares, fuel, vehicle ferry costs, and passenger charges distinct so they are not duplicated. Preserve warnings where mixed-mode routing is unsupported instead of drawing a road line that implies a confirmed crossing.

**Acceptance.** A Samal scenario identifies whether a ferry/barge connection is known, estimated, or unresolved. Users see what is and is not included in the journey estimate. Do not introduce flight navigation or full public-transit routing as an implied panel requirement.

### PF-05: Make venue metadata maintainable and visible

**Current code.** [Destination schemas](../services/api/app/features/destinations/schemas.py) and [models](../services/api/app/features/destinations/models.py) include operating hours, entrance/overnight descriptions, travel notes, accessibility, coordinates, and optional arrival metadata. The [admin destination editor](../apps/admin_app/lib/screens/destination_editor.dart) maintains several of these fields. Accommodation/transport use separate rate records through [Market Rates](../apps/admin_app/lib/screens/market_rates_screen.dart). Travelers consume catalog information through [destination models](../apps/traveler_app/lib/models/destination.dart), [rate models](../apps/traveler_app/lib/models/catalog_rate.dart), and [destination details](../apps/traveler_app/lib/screens/destinations/destination_details_screen.dart).

Dedicated canonical corkage, day-tour package, and paid-amenity fields are not present in the inspected destination contract. A prose description may mention these; that is not equivalent to structured price coverage or charging units.

**Proposed improvement.** First review existing catalog values and their rendering before adding fields. Display known hours and fees with relevant inclusions and units. Distinguish unknown information from confirmed free entry. If structured packages/amenities are introduced later, plan the admin editor, API, traveler parsing, preview, and AI context together; identify schema/migration effects before approval.

**Acceptance.** A reviewed admin edit appears in traveler details after refresh and is represented consistently in planning. Day-tour, overnight lodging, entrance, corkage, and optional services are not conflated or charged twice.

### PF-06: Do not assign arbitrary prices to free or included activities

**Current code.** [Planning activity options](../services/api/app/features/planning/service.py) are derived from destination activity descriptions. They are not a structured catalog of verified activity fees. [Activity controls](../apps/traveler_app/lib/widgets/inputs/activity_selection_fields.dart) allow separate amounts or inclusion in another allowance. [Cost projection](../services/api/app/features/planning/costs.py) requires explicit coverage and checks overlapping inclusions. This explains why a selected activity can currently demand a manual amount.

**Proposed improvement.** Distinguish venue admission, included activities, optional paid services, and optional personal spending. A confirmed free/included walk or personal photography should not receive an invented price. Paid photography services, equipment rental, food, or horseback riding are separate choices when supported by data. Unknown cost remains unknown until supported by a price or an accepted estimate; do not infer free entry or universal photography permission from an activity name.

Apply automatic suggestions to actual spending categories, as agreed in [OBS-001](OBSERVATIONS_AND_IMPROVEMENT.md), without allocating a fee to every selected activity. Selecting an included activity should not force a price-entry task. Preserve backend coverage checks to prevent double counting.

**Acceptance.** Reviewed free/included activities do not add a charge. A selected paid service adds its applicable cost once. Missing prices are clearly identified and are never silently converted to a verified zero.

### PF-07: Assist with budgeting while preserving cost provenance

**Attribution.** The panel suggests demonstrating itinerary prompts with budget information and asks whether entrance data exists in the database. The preference for automatic, editable breakdowns and labeled estimates was separately selected by the user during this planning conversation; it should not be represented as a verbatim panel requirement.

**Current code.** [Planning costing](../services/api/app/features/planning/costs.py) totals explicit allowances and supported rate assumptions. [Conversational review](../apps/traveler_app/lib/screens/planner/conversational_review_sheet.dart) and [detailed review](../apps/traveler_app/lib/screens/planner/chat_plan_review_sheet.dart) collect those amounts. [AI generation](../services/api/app/features/ai/service.py) uses the planning preview and validates generated output. Automatic budget distribution is not implemented by this guide.

**Proposed improvement.** Use the stated whole-party budget as a ceiling; suggest editable food, lodging, transport, activity, and incidental allowances. Separate catalog-based amounts, system estimates, manual overrides, reserve, and unallocated money. Do not force the entire budget to be spent or reduce known prices to hide a shortfall. A request with no budget can receive a disclosed suggested estimate and a clarification step; do not bypass the existing positive-budget generation contract.

**Acceptance.** Previously collected days/nights/party/budget appear in review. Travelers can accept or adjust suggestions without typing every line. Missing-cost estimates retain their provenance through generation and saving. Default estimation policy still needs specification before feature implementation.

### PF-08: Return actionable cards for ordinary discovery requests

**Current code.** The [conversational planner](../apps/traveler_app/lib/screens/planner/conversational_planner_screen.dart) already renders structured destination suggestions with an Add action. [Suggestion models](../apps/traveler_app/lib/models/chat_destination_suggestion.dart) carry real catalog IDs. However, frontend suggestions are displayed only while no destination is selected. In [AI planning chat](../services/api/app/features/ai/service.py), structured recommendations are also currently conditional on no selected destinations, and missing interests produces a shortfall message instead of a ranked result. [Retrieval intent](../services/api/app/features/ai/retrieval_intent.py) and [catalog retrieval](../services/api/app/features/ai/rag.py) are separate pieces of this flow.

**Proposed improvement.** Distinguish browsing a location's catalog from ranking a personalized Top 5. A general Davao City discovery query should be able to return actionable catalog cards without forcing an interest merely to browse. Continued discovery should remain possible after a stop is added. Use structured IDs for Add actions; do not convert arbitrary model prose into trusted catalog records. Keep selected destinations visible when refreshing suggestions.

**Acceptance.** The panel's ordinary tourist-spot request yields cards for available catalog matches or a clear empty state. Add uses the correct ID once. Asking for more places after adding a stop does not silently replace the existing plan or hide all useful discovery actions.

### PF-09: Ask for traveler counts and dates clearly

**Current code.** The review sheets have explicit Days, Nights, Travelers, and Whole-trip budget fields. [Party controls](../apps/traveler_app/lib/widgets/inputs/party_details_fields.dart) validate adults and child ages against the total. [Planning schemas](../services/api/app/features/planning/schemas.py) enforce related values. [Chat prompts](../services/api/app/integrations/groq/prompts.py) specify structured updates and avoid inferring nights from days alone. [Quick preview](../apps/traveler_app/lib/screens/auth/quick_preview_screen.dart) is currently a guest introduction, so historical onboarding wording should not be assumed to remain in that screen.

**Proposed improvement.** Ask for the number of travelers with a clear count example. Collect registered group members later in the sharing workflow. Distinguish dates from duration and days from nights; prefill confirmed values rather than asking for them again. Update related party/duration values together and explain contradictions. Treat the validation error reported in [OBS-002](OBSERVATIONS_AND_IMPROVEMENT.md) as a separate unconfirmed defect, not a cause established by the panel transcript.

**Acceptance.** New users understand that planning requires counts, not names. Adults plus children match the total. Two days and one night remain distinct. Conflicting edits explain the correction without discarding the draft.

### PF-10: Measure chat latency before selecting optimizations

**Attribution.** Slow chat is mentioned in the executive summary and at 21:30 in the team debrief. It is historical feedback, not a current timing measurement.

**Current code.** The [traveler API client](../apps/traveler_app/lib/services/api_service.dart) applies request timeouts, including 60-second AI calls. The planner has a pending indicator. [AI services](../services/api/app/features/ai/service.py), the [Groq client](../services/api/app/integrations/groq/client.py), [provider usage controls](../services/api/app/core/provider_usage.py), and [evaluation metrics](../services/api/app/features/evaluation/service.py) provide relevant boundaries for investigation. A timeout value is not a normal-response measurement or a performance target.

**Proposed improvement.** Measure total user-visible time separately from model time, retrieval, route-provider work, retries, and cold-start effects. Then evaluate reduced redundant work, appropriate model selection, caching of eligible read-only results, or a simpler request path. Keep useful progress, retry, and state-preservation behavior. Do not increase a timeout and call the speed issue fixed.

**Acceptance.** Repeated test scenarios record stage timings and failures under stated conditions. Any future target is explicit and measured; this guide invents no latency guarantee or provider-price claim.

### PF-11: Demonstrate group itinerary sharing using real membership

**Current code.** The [group dashboard](../apps/traveler_app/lib/screens/collaboration/group_dashboard_screen.dart) adds an existing registered user by email after the trip is saved. [TripService](../services/api/app/features/trips/service.py) checks management/access, saves active membership, and creates a notification. [Trip endpoints](../services/api/app/features/trips/router.py), task flows, expenses, memories, and [notifications](../services/api/app/features/notifications/service.py) support shared-trip activity. The label Invite does not prove an email invitation is sent; the inspected path adds a registered account to the trip.

**Proposed improvement.** Rehearse with two real test accounts on the same backend: owner saves an itinerary, adds a member, and the member refreshes or signs in to open the same trip. Show at least one shared action and its permissions. Do not introduce public share links, anonymous access, email delivery, or administrator access to every private trip as implied requirements.

**Acceptance.** Both accounts see the same saved trip; supported changes appear after refresh; a nonmember cannot read private trip data. A local placeholder member or locally seeded name is not evidence of sharing.

### PF-12: Benchmark activity organization without expanding into booking

**Interpretation.** Klook is suggested as a UX reference for clear activity presentation. The transcript does not require copying its interface or implementing commerce.

**Proposed research.** Compare how a traveler distinguishes a venue, admission, included experiences, optional paid services, per-person/group prices, and itinerary additions. Record concrete interaction improvements for Lakbay's existing cards, details, and budget review. Attribute any later comparison to the actual reviewed version/date.

**Acceptance.** A future benchmark produces specific recommendations that fit Lakbay's catalog and planning scope. No booking, payment, inventory, or commercial availability claim is introduced without separate requirements. No external Klook review was performed for this document.

### PF-13: Demonstrate objectives with prepared prompts and evidence

Prepare prompts against reviewed catalog data and record the actual outcome. The three prompts below are proposed rehearsal inputs, not passed tests. Availability of named places, route quality, and affordability must be checked before using them in a defense.

| Scenario | Proposed prompt/action | Evidence to capture |
|---|---|---|
| Discovery to cards | "Can you provide me a list of tourist spots in Davao City?" Then add one result and ask for another place. | Catalog-backed cards, working Add actions, retained selection, clear detail prompts. |
| Overnight planning and budget | "Help me plan a Kaputian trip for 3 days and 2 nights for 2 adults, with a PHP 10,000 whole-trip budget. Show the costs and assumptions." | Catalog match or clear clarification, distinct days/nights, cost sources, explicit crossing limitations, validated options or a meaningful blocker. |
| Multiple stops and group sharing | "Starting in Tagum City, help us plan a day trip to People's Park and the National Museum in Davao City for 2 adults using a private vehicle, within a PHP 5,000 whole-trip budget." Save a valid option and add the second registered test account. | Appropriate catalog IDs/local origin, one multi-stop sequence and map, disclosed estimates, successful save, member access and shared action. |

If a scenario exposes a missing capability or uncertain data, record it rather than modifying the expected result to disguise the gap. Prepare a clearly labeled fallback demonstration for unavailable network/provider conditions.

## 5. Proposed work sequence and phase alignment

These priorities are recommendations for a future implementation plan, not approval to execute code changes.

| Order | Work package | Feedback | Expected outcome |
|---|---|---|---|
| 1 | Verify the deployed/current build, catalog facts, and reported validation failures. | PF-05, PF-09; OBS-002 | Known reproduction paths, data limitations, and actionable errors. |
| 2 | Correct fee/coverage presentation and define automatic editable budgeting. | PF-05, PF-06, PF-07; OBS-001 | Useful estimates without arbitrary activity charges or duplicate costs. |
| 3 | Make discovery cards and detail collection consistent. | PF-08, PF-09 | Browsing leads naturally into a retained plan. |
| 4 | Verify local origin selection, stop sequencing, multi-stop editing, and transport explanations. | PF-01, PF-02, PF-03, PF-04 | One understandable local journey aligned with the itinerary. |
| 5 | Measure and address demonstrated latency bottlenecks. | PF-10 | Evidence-backed performance improvements. |
| 6 | Run two-account sharing checks and rehearse the objective-based demo. | PF-11, PF-12, PF-13 | Verifiable behavior and clear presentation. |

Use the existing [core focus](../services/api/docs/core_focus.md): Phase 2 for catalog data, Phase 3 for discovery/recommendations, Phase 4 and Phase 15C-15E for costs and AI context, Phase 5 for AI planning, Phase 6 and Phase 15A for routing, Phases 7-8 and 13 for shared trips/notifications, and Phase 14/15G for evaluation and presentation evidence. These are refinements of existing areas rather than an automatic new product phase.

Honor the [approved place-pin planning scope](../services/api/docs/objectives_panel_upgrade_plan_2026-11-09.md): approximate planning may use saved place coordinates; verified arrival points are not a blanket prerequisite for Top 5 or itinerary context. Keep estimate labels and optional verified arrival data. Do not revive a deferred arrival editor or require a new provider merely because older documentation suggests it.

### Interface and persistence review for later work

- Start with existing catalog, `/ai/chat`, `/planning/preview`, `/planning/feedback`, `/routes/preview`, `/routes/optimize`, and trip/member endpoints. Do not assume each feedback item requires a new endpoint.
- Structured corkage, packages, paid amenities, estimate provenance, or persistent stop editing may affect API and persistence. Define the minimum cross-client contract and migration impact before implementation.
- Keep backend validation authoritative and preserve stable catalog IDs, ownership/membership checks, planning revisions, and generation-option saving.
- Treat the older objectives plan as dated context. Where a document and current code disagree, state the discrepancy and use inspected code for implementation claims; require live verification for deployment claims.

## 6. Future verification checklist and existing test entry points

No runtime tests were executed for this documentation update. The files below are starting points for future tests, not proof that the full panel workflow passes.

| Area | Scenarios | Existing test entry points |
|---|---|---|
| Local routing and stop order | Davao origin, outside-region GPS, fixed origin, manual/optimized order, route fallback. | [Route ordering](../services/api/tests/test_route_ordering.py), [planning routes](../services/api/tests/test_planning_routes.py), [route geometry](../apps/traveler_app/test/route_geometry_test.dart). |
| Ferry and transport coverage | Samal crossing, missing fares, unresolved connections, provider geometry labels. | [Ferry crossings](../services/api/tests/test_route_ferry_crossings.py), [provider geometry](../services/api/tests/test_route_provider_geometry.py), [backend planning costs](../services/api/tests/test_planning_costs.py). |
| Venue and activity costs | Admin edits reach travelers; free/included/paid/unknown costs; no duplicate inclusion. | [Catalog flow](../services/api/tests/test_catalog_planning_flow.py), [activity controls](../apps/traveler_app/test/activity_selection_fields_test.dart), [catalog integration](../apps/traveler_app/test/catalog_integration_test.dart), [admin editor](../apps/admin_app/test/destination_editor_test.dart). |
| Discovery and retained state | Generic location query, structured cards, add once, discover after selection, newer edits win. | [Retrieval intent](../services/api/tests/test_ai_retrieval_intent.py), [planning chat](../services/api/tests/test_planning_chat.py), [conversational planner](../apps/traveler_app/test/conversational_planner_screen_test.dart), [planning contract](../apps/traveler_app/test/chat_planning_contract_test.dart). |
| Party and confirmation | Count wording, adults/children consistency, days/nights, retained values, actionable rejection. | [Party fields](../apps/traveler_app/test/party_details_fields_test.dart), [preview contract](../services/api/tests/test_planning_preview.py), [review feedback](../apps/traveler_app/test/planning_feedback_review_test.dart). |
| Saving and sharing | Current option saved, cancellation/failure retained, owner/member/nonmember access, cross-account refresh. | [AI option saving](../services/api/tests/test_planning_ai_save.py), [group collaboration](../services/api/tests/test_phase8_group_collaboration.py), [client collaboration failures](../apps/traveler_app/test/collaboration_failure_test.dart), [notifications](../services/api/tests/test_phase13_notifications.py). |
| Latency and reliability | Record stage timings, retries, rate-limit responses, unavailable providers, retained draft. | [Groq provider usage](../services/api/tests/test_provider_groq_usage.py), [provider guards](../services/api/tests/test_provider_usage_guards.py), [evaluation](../services/api/tests/test_phase14_evaluation.py). |

For the live demonstration, record app/build identity, backend environment, checked catalog records, expected outcome, actual outcome, and limitations. Avoid treating a mocked response, a sample preview destination, or a screen title as evidence of persisted backend behavior.

## 7. Historical administrative notes

The source records re-presentation planning, agreement-form discussion, and a distinction between an exam-component score and the final course grade. Its later conversation mentions a Tuesday 2:00-4:00 PM slot and other scheduling details.

These are historical transcript notes, not a verified current appointment or assessment record. Do not infer a calendar date, calculate a final grade, create reminders, contact anyone, upload forms, or modify the application because of this section. Confirm current academic logistics through the team and institution separately.

## 8. Open decisions before feature implementation

- Define automatic estimate defaults, scaling, reserve behavior, manual-override handling, and provenance; the agreed interaction is automatic and editable, not a fixed allocation formula.
- Define the local-origin boundary policy and how an outside-region traveler selects a supported Davao start.
- Decide the minimum venue/package/activity data model only after reviewing existing data and supported units.
- Define stop-editing behavior across days, itinerary ordering, saved routes, cost invalidation, and regenerated options.
- Decide whether non-road guidance remains advisory or receives a separately specified connection model.
- Choose latency targets from measured baseline conditions rather than inventing guarantees in this guide.

These decisions belong to subsequent planning. The current document is complete as a feedback-to-code assessment; it is not a decision-complete specification for all future application changes.

## 9. Verification limits for this guide

- All nine pages were examined through text extraction, including the timestamped transcript rather than only the executive summary.
- PDF extraction used the document's embedded Unicode mappings. No visual PDF rendering or layout verification was performed; uncertain transcription wording remains uncertain.
- Code findings describe the inspected checkout. Historical observations, older planning documents, and current deployed behavior may differ.
- No live app interaction, hosted database inspection, external UX benchmark, provider-price research, or runtime acceptance testing was performed.
- No recommendations in this guide have been implemented. Only the requested Markdown file is added; the source PDF and initial observations guide are preserved.
