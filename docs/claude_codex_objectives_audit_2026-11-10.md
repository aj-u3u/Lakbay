# Lakbay+ objectives, unfinished work, and Claude Code handoff audit

## Approved cleanup follow-up — fixes and unused code, 10 November 2026

The user approved fixing two blocking issues and removing duplicated and
unused code that serves no study objective or panel comment. No schema,
endpoint, provider setting or live data changed. The backend work was committed
on `route-order-cleanup-20261110`, which builds on the three
`codex/release-budget-catalog-20261110` commits. On 10 November `main` was
fast-forwarded to `d8a0af4` and Render auto-deployed it; the user confirmed the
deploy in Render's events. No migration was needed. Phone checks against the
deployed backend have not been run yet. The traveler and admin changes below
remain uncommitted.

- **F6 fixed.** Top 5 now picks its 50 routed places by their score with a
  straight-line travel estimate, so distant places cannot crowd out nearby ones
  (`B:app/features/recommendations/service.py`). A new 51-place regression
  failed with the old rule and passes now.
- **F7 fixed.** Feedback requires the start's map pin only when
  `route_preferences` requests a route (`B:app/features/planning/feedback.py`).
- **Backend duplicates merged.** The catalog selection lookups and four checks
  that were copied into `ai/`, `budgets/` and `trips/` (and the route lookup)
  now live in `B:app/features/destinations/catalog_selection.py`. The two
  identical rate-limiter classes share `PerUserRequestLimiter` in
  `B:app/core/provider_usage.py`; their names, error codes and messages are
  unchanged. Unused `AIGenerationRunResponse`, `GroqChatMessage` and
  `TripRepository.list_trip_members` were removed; review comment trimming now
  uses one shared type.
- **Traveler unused code removed.** The 13 unreachable files listed below, the
  uncalled `generatePlan()` → `generateAIItinerary()` chain with its three
  private helpers, the null `fetchItineraryFeedback()` stub, `Trip.seedMembers`
  and `AppNotification.mockNotifications`. Tests of deleted code were removed;
  the four feedback-dialog tests now run through a test host that follows the
  conversational planner's review-then-save order.
- **Admin unused code removed.** The six unreachable files listed below. The
  legacy `/transport`, `/accommodation`, `/activities` and `/meals` routes still
  resolve to the current screens.
- **Dated docs archived.** 32 superseded dated reports and datasets moved to
  `B:docs/archive/` with links updated; the OSM staging script reads its default
  input from there. Current dated plans, scopes and this handoff stay in `docs/`.

Kept on purpose: endpoints no app calls yet but that support an objective or the
use-case diagram (destination groups, evaluation summary, trip reviews, expense
summary, budget estimate, trip routes), Google Routes live traffic, weather,
seed data and the separate Haversine uses.

Verification: full backend suite **509 passed, 1 skipped** (the limiter clock
test was repointed to the moved class); traveler **238 passed**, admin **38
passed**; both apps analyze with no issues; no broken relative Markdown links.
Tests used isolated SQLite and mocked providers.

## Approved follow-up scope — place pins, 10 November 2026

The user approved using saved place pins for the current version's Top 5,
AI itinerary context and approximate route planning. A separate visitor-arrival
point and its admin editor are deferred. This is a current-phase scope reduction
across catalog, recommendations and routing, supported by existing behavior.
It requires no application-code or database change. Keep existing optional
arrival fields, validation and compatibility with any already reviewed arrival.

**This supersedes F2's original high priority:** zero route-ready records is not
a blocker for pin-based planning. Admins still review identity, pin location,
access evidence, prices and hours. Preserve approximation labels and suppress
verified turn-by-turn directions for unverified arrival points. Do not set
`route_ready=true` from a pin or infer a ferry connection. See the
[updated objectives plan](objectives_panel_upgrade_plan_2026-11-09.md) and
[routing guide](routing.md). Older plans and Claude's script may require arrival
work; that part is deferred rather than automatically authorized for execution.

Verification for this scope update: **7 existing focused tests passed** across
`tests/test_top_places_scoring.py` and `tests/test_phase6_routes.py` (40 deselected).
They cover pin-based ranking, unverified road snaps, labeled straight-line and
commute fallbacks, pin-based road previews with suppressed maneuver steps, and
optional verified-arrival compatibility. Tests used isolated SQLite and mocked
providers; this is not phone or live-route verification. This follow-up changed
documentation only and preserved the earlier approved budget fix.

## Approved implementation follow-up — saved place data, 10 November 2026

The user then approved implementing the admin-to-traveler data-flow corrections.
This remains current-phase catalog/planning work; no schema change, live catalog
correction, staged-place publication, or Groq-assisted catalog drafting is part
of this slice.

- The admin editor already saves place pins, fees, hours and the five travel-detail
  fields without a separate arrival point. Its added regression verifies the
  exact PATCH payload and confirmed save; no admin runtime rewrite is needed.
- The traveler model now retains `best_time_to_visit`, `how_to_get_there`,
  `estimated_travel_time`, `travel_notes` and `what_to_bring`. Nonempty saved
  values reach the existing Travel Notes & Tips section. Refresh replaces old
  values, cleared fields stay empty, and catalog records do not borrow demo tips.
- The itinerary catalog payload now includes description, place pin, optional
  arrival metadata, access/travel details, and each rate's currency/charging unit.
  Missing units remain null. Prompt rules retain uncertainty and treat catalog
  notes as reference data. Prompt audit versions were advanced; output
  validation and the budget guard remain in place.
- The new backend regression exercises admin-only edits through public reads,
  weighted Top 5, pin-based planning preview and messages sent to mocked Groq.
  It covers rates with known and unknown charging units. This does not add the
  accommodation selector identified in F4 or repair the saved-route issue in F5.

Code and regression files: `B:app/features/ai/service.py`,
`B:app/integrations/groq/prompts.py`, `B:tests/test_catalog_planning_flow.py`,
`T:lib/models/destination.dart`, `T:test/catalog_saved_details_test.dart`, and
`A:test/destination_editor_test.dart`. See [ai_itineraries.md](ai_itineraries.md)
and the Phase 5 study lesson for the data flow. The original F9 evidence below
describes the pre-fix state; its missing-suitability-default issue remains open.

Device discovery found Windows and Edge only, with no connected phone. The real
admin-save -> deployed API -> phone refresh/generation journey and the earlier
budget fix's phone check remain pending. No deployment or live data edit was
performed by this follow-up.

Validation completed after this correction: **58 focused backend tests passed**,
**204 traveler tests passed**, and **38 admin tests passed**; both Flutter apps
reported no analysis issues. The new backend regression reproduced a missing
pin in the original Groq catalog payload before the correction. The new traveler
regression first failed because its model lacked the saved travel fields.
Client tests ran in isolated copies before applying only the tested files with
original-file hash guards. Logs and original-file backups are under ignored
`B:tmp/place-data-flow-20261110/`. No commit or push was made.

## Scope, evidence, and limits

**Pre-save itinerary review:** the conversational planner can request a route
when the start has a map pin and the traveler has chosen transport and whether
to return. The request keeps the selected destination order. The itinerary card
opens a review of the exact generation run before the existing feedback check
and save. The review shows the day-by-day activities, recorded route and leg
distances and times, budget scope, and cost breakdown. It labels AI activity
prices as drafts and shows when pin-based routing is approximate. The route
describes the overall trip.

**Generation route order:** the prompt and validator now share the ordered stops
from the calculated planning route. The validator checks every option before
it reaches review. It allows consecutive activities at one place and rejects
reordered stops or a return visit without a matching route stop. Driving route
requests now collect road-access confirmation. After a confirmed journey
changes, the whole route request is removed (`route_preferences` becomes null),
not only the confirmation. The traveler taps **Calculate route** and confirms
road access again. The backend chat does this for start, destination and return
changes. Chat cannot change the transport selection; the traveler app clears the
route request itself for transport, start, destination and return changes made
in its own controls. The tests cover kept and optimized order, a conflicting
option, fallback, and the return leg through save and reopen. The focused runs
passed 108 backend tests and 38 traveler tests. The backend round-trip cases
used simulated Groq and OSRM responses.

**Commit status, updated 10 November:** the backend part of this work
(`app/features/ai/validators.py`, `app/features/ai/service.py`,
`app/integrations/groq/prompts.py` at `phase15e_calculated_route_order_v5`, and
`tests/test_planning_ai_save.py` / `tests/test_planning_chat.py`) is committed as
`fafddf3` on `route-order-cleanup-20261110`, after the three
`codex/release-budget-catalog-20261110` commits, and is on `main` and deployed
since `d8a0af4`. That release branch itself still
uses `phase15e_scored_groups_catalog_facts_v4`. The traveler app's matching
route-clearing change in `lib/models/chat_planning_session.dart` is still
uncommitted.

**Same-day transfer warning:** the traveler review compares the gap between
consecutive activity starts at different destinations with the recorded leg
for that direction. When travel alone takes longer, **Check before travel**
shows the affected day, stops and route estimate. The traveler can continue
to save. The check needs readable start times and a calculated leg. Full
scheduling still needs activity durations, overnight travel and opening hours.
The focused run passed 27 traveler tests, including the warning at a narrow
phone width and the existing review, save and reopen flows.

The traveler can confirm an intentionally route-free itinerary. A missing
requested route or a mismatch between itinerary visits and route stops blocks
confirmation. Changes to the selection or plan revision invalidate the review.
The existing save endpoint takes the reviewed run and option IDs and persists
the associated route and cost projection. Deployment and phone checks remain
deferred. The previously built APK predates this work.

Local verification passed all **238 traveler tests**, including 18 new review
regressions. Static analysis of the changed files found no issues. The applied
files match the reviewed copies, and the other original traveler files were
verified by hash. Logs and original-file backups are under
`B:tmp/pre-save-review-20261110/`.

**Route-preservation follow-up:** the user deferred deployment and phone checks
and approved fixing saved-route preservation next. The local traveler correction
retains the embedded route/planning snapshot, restores it without a new route
request, and preserves its start, order, mode and return leg. Explicit
recalculation uses the keep-order preview endpoint, is labeled as a preview, and
does not overwrite the saved trip. Failed requests retain the previous display;
the original saved route can be restored. Saved-trip GPS does not automatically
reroute. See [routing.md](routing.md) and F5 below. No backend runtime, schema,
provider configuration or live data change is included in this correction.
The earlier release commits and debug APK are preserved and do not yet contain
this later route fix; they must be reviewed/rebuilt when release work resumes.

Validation: **220 traveler tests passed**, including 16 new regressions across
saved-route models, API requests/session refresh, trip screens and GPS behavior.
Flutter analysis reported no issues. The UI source scan reported no findings;
physical-device visual/behavior verification remains deferred by the user.
Ten tested traveler implementation/regression files were applied only after
original-file hash checks; all unrelated traveler source, tests and assets are
unchanged. Test copies, logs, original-file backups and a patch containing only
this correction are under ignored `B:tmp/route-preservation-20261110/`.
This is a working-checkout correction on top of the pending trip-view work,
not an additional commit on the earlier isolated release branches.

**Earlier release preparation:** the user approved starting the
change review. Fix-only commits now exist on isolated `codex/release-*` branches.
They passed 58 focused backend, 193 traveler and 29 admin tests; both apps analyze
clean. The smaller client counts exclude other unfinished work. See the
[release review](release_review_2026-11-10.md) for exact commit IDs, worktree
locations, inherited branch scope and remaining deployment/device checks.
The original source branches and unrelated pending changes are preserved.
The reviewed traveler branch also produced an installable debug APK; its path,
commit and SHA-256 are recorded in the release review. It has not been tested on
a phone, and no remote push, merge or deployment was performed during preparation.
Final device discovery now detects a physical Android 15 phone. The earlier
no-phone observation is historical; installation and the end-to-end phone check
remain pending after backend deployment.

Audit date: **10 November 2026, Asia/Shanghai**. This is a handoff for Claude Code,
Codex, and the project owner. The user requested a review of plans, unfinished and
uncommitted work, unused/duplicated code, and logic that interferes with the study
objectives, including Claude Code's work and history.

Repositories:

- **B — backend:** `C:/Users/Arjane/Documents/Coding/lakbay_backend_final`.
- **T — traveler:** `C:/Users/Arjane/Documents/Coding/UI_FOR_LAKBAY`.
- **A — admin:** `C:/Users/Arjane/Documents/Coding/FINAL_ADMINLAKBAY`.

Evidence includes current source and Git state, linked worktrees, six saved Claude
sessions, Claude's saved map plan, project instructions, the master objectives
plan and related plans, isolated tests, and read-only Neon/public API checks.
References such as `T:lib/services/api_service.dart:1073` use these repository
labels. Line numbers describe the inspected working files and may move.

Labels used below:

- **Confirmed:** directly observed in source, Git, or a read-only live query.
- **Reproduced:** exercised with controlled synthetic data or an isolated test.
- **Partial:** a working foundation exists, but the stated requirement has gaps.
- **Planned:** a proposal exists without an integrated implementation.
- **Needs device/live verification:** source and tests do not prove the user journey.

The original read-only audit changed no application source, existing user work,
database records, migrations, provider settings, or branches. The user authorized
this Markdown handoff as the documentation deliverable, then separately approved
the F1 budget correction recorded below. Test copies and audit metadata are under ignored
`B:tmp/full-review-20261110/`; tests used isolated databases/mocked providers.
No live login, save, publication, itinerary generation, or paid model call was
performed. Existing public API reads and Neon transactions were read-only.

This is a broad source/contract audit, not certification of every runtime path,
production build, security property, or research result. In particular, no Android
journey, browser save-to-phone journey, background tracking trial, or battery test
was run. Static reference scans identify cleanup candidates; callbacks, legacy
routes, external consumers, and tests must be considered before deletion.

## Executive findings

1. **A per-person budget can prevent itinerary generation before Groq is called.**
   The traveler sends the unconverted amount while the backend requires the
   whole-trip equivalent. A synthetic PHP 3,000-per-person, three-traveler plan
   reproduced `planning_input_mismatch`; PHP 9,000 passed the same guard.
   **Follow-up: corrected locally on 10 November; see F1 implementation below.**
2. **The normal admin flow cannot make a destination route-ready.** Existing
   backend arrival fields are absent from the admin editor. Live data still has
   30 active places, zero route-ready places, and 648 staged candidates.
   **Follow-up: arrival editing is deferred under the approved pin-based scope;
   this is not a prerequisite for the current Top 5 or itinerary flow.**
3. **The active planner clears accommodation selections.** Saved-stay display and
   backend rate contracts exist, but the current confirmation form sends an empty
   `selected_accommodation_ids` list and uses a lodging allowance.
4. **Displayed routes can lose saved planning choices.** The shared route
   controller requests a fresh optimized open route (`returnToStart: false`);
   it does not consume the saved trip-route contract or preserve a saved round trip.
   **Follow-up: corrected locally; see the approved route-preservation update and F5.**
5. **Top 5 has a reproduced scaling edge case.** It truncates candidates to 50
   before route-feasibility filtering. A reachable 51st candidate was omitted,
   yielding zero results. Today's 30-place catalog does not trigger that case.
6. **Research model comparison is further along than older plans imply.** All
   three comparison slots are configured locally, and the database contains
   generation attempts from all three models. The traveler still sends
   `compare_models: false`; a controlled quality benchmark and research reporting
   remain incomplete.
7. **There is real disconnected/duplicate implementation.** Thirteen traveler
   library files and six admin library files are unreachable from their current
   `main.dart` import graphs. Two old planning sheets still have tests. Backend
   catalog query/validation bodies are duplicated across feature modules.
8. **Much work is local rather than absent.** The traveler has 15 pending files,
   the admin has 32, and additional work exists in linked worktrees. Preserve and
   review those changes; do not reimplement or bulk-merge them.

The newer idea, **OSM discovery -> Groq/Qwen draft -> admin verification ->
publication -> ranked recommendations and routing**, is feasible as a separately
scoped Phase 2 extension. Groq-assisted catalog drafting is **not implemented** in
the inspected destination flow. Keep catalog drafting separate from traveler
itinerary requests, retain sources and unknown values, and require review before
publication. This audit does not approve implementation or schema changes.

## Current repositories and pending work

| Repository | Inspected branch / HEAD | Pending work at audit start | Important release distinction |
| --- | --- | --- | --- |
| Backend | `top5-app-docs`, `0378516` | Clean | Local `main` already contains weighted Top 5 backend code (`04f6b6d`), OSM lookup/fallback, app-assessment backend, and admin user directory. `0378516` adds Top 5 app-scope documentation. |
| Traveler | `top5-weighted-scoring`, `d89ba1d` | 9 modified + 6 untracked files | 17 commits are absent from local `main`; this branch includes shared basket/planner/map work as well as Top 5. |
| Admin | `codex/step0-admin-review`, `525c78d` | 25 modified + 7 untracked files | Current dashboard/editor/OSM/user/assessment improvements are predominantly uncommitted. |

These are local Git observations. No fetch, push, merge, checkout, reset, or
deployment was performed. Remote-tracking references are not a fresh check of the
remote service.

### Traveler pending files

Modified:

- `lib/core/routes/app_routes.dart`.
- `lib/models/trip.dart`.
- `lib/providers/trip_provider.dart`.
- `lib/screens/collaboration/group_dashboard_screen.dart`.
- `lib/screens/trips/trips_screen.dart`.
- `lib/services/api_service.dart`.
- `lib/widgets/cards/activity_tile.dart`.
- `lib/widgets/maps/route_directions.dart`.
- `lib/widgets/maps/route_ways_list.dart`.

New:

- `lib/models/app_assessment.dart`.
- `lib/screens/trips/app_assessment_screen.dart`.
- `lib/widgets/cards/app_assessment_card.dart`.
- `test/app_assessment_screen_test.dart`.
- `test/trips_card_layout_test.dart`.
- `test/view_trip_hierarchy_test.dart`.

This combines trip completion/assessment, My Trips/View Trip redesigns, and small
display corrections. `trip_provider.dart` and `api_service.dart` also contain
already-committed Top 5 work: preserve both layers when making a focused commit.

### Admin pending groups

- Destination editor/list, candidate review, OSM suggestion panel and tests.
- Overview, users, app-assessment results, profile/settings, avatar and session work.
- Market Rates, navigation shell/sidebar/topbar, responsive/common components.
- README, test updates, and `.impeccable` design-context files.

These are several reviewable changes, not one feature. The current Trip
Information page remains an explicit capability placeholder; an admin-wide trip
directory is not implemented merely because the navigation item exists.

### Linked worktrees and branch-only work

| Location / branch | Observed work | Handling |
| --- | --- | --- |
| `B:tmp/step2_backend`, `codex/step2-optional-budget` | Commit `962042a`: guided planning without a budget, plus earlier quality-gate commits; clean worktree | Not integrated into current backend. Compare APIs and tests against current Top 5 before porting. |
| `B:tmp/step2_flutter`, `codex/step2-optional-budget` | Commit `80d0672`: optional budget and confirmed catalog suggestions; seven modified platform-generated files | Not integrated into current traveler. Generated files are not evidence of additional finished product behavior. |
| `B:tmp/quality_gate_strict_check`, `codex/quality-gate-strict-check` | Three modified tracked files plus an itinerary-schema file, strict JSON test/manual script, and output directory | Strict-output experiment is not fully committed there. Compare with current `B:app/integrations/groq/itinerary_schema.py`, which already exists. |
| `lakbay_backend_quality_gate`, `codex/itinerary-quality-gate` | `99f9964` / `0e59bf8` quality-gate history | Some equivalent behavior now exists in the current tree. Different commit ancestry alone does not prove missing code. |
| `UI_FOR_LAKBAY_quality_gate`, `codex/itinerary-quality-gate` | Quality-warning history plus seven generated-platform modifications | Compare behavior before merge; do not replace the newer conversational planner. |
| `B:tmp/drive_route_check` | Audit commit `a1467bf` | An evidence artifact, not a missing application feature. |
| Walking/cost/release review worktrees | Older release/audit snapshots | Keep as historical until intentionally reconciled. A differently named commit can duplicate a release already integrated another way. |

## Claude Code session reconciliation

Six project session logs were inspected under the user's local `.claude/projects`
folders. Historical assistant claims were checked against the current tree rather
than accepted as proof of deployment.

| Session prefix | Main work / final recorded state | Current reconciliation |
| --- | --- | --- |
| `95ffaa53` (backend project) | Catalog coordinates/arrival review, Mount Apo split, Samal beaches; user said **Yes, apply**, then Claude hit its limit | The correction script remains in Claude's temporary scratchpad. The live catalog still has the old records and no published candidates. |
| `a5ec6cfd` (backend project) | Detailed road geometry, ferry metadata, GPS/stale-position fixes; historical final said uncommitted | These implementations are present in the current code/history. That old final is not the current Git status. Device/release proof remains separate. |
| `deae1952` (backend project) | Confirm Amounts/save dead-end fixes; missing origin map pin downgraded in the app | Current app contains the workaround. Backend feedback still labels all missing preview inputs as required. |
| `d582cbba` (backend project) | Weighted Top 5 backend/app, selective commits, explanation of unrelated app edits | Backend Top 5 is on local main; traveler `d89ba1d` is committed on its feature branch; trip/assessment edits remain uncommitted. |
| `7b27cb65` (traveler project) | Shared map redesign and local browser run | Shared map components exist. Historical run/tiling claims are not a fresh phone or production check. |
| `fa9c47ab` (traveler project) | Conversational planner, Top 5 details, overflow fixes; remaining route/model/group/evaluation UI | Assessment screens and the pre-save route review now exist locally. Model-comparison presentation remains open. |

Additional Claude material reviewed:

- `T:CLAUDE.md`, `T:AGENTS.md`, `T:knowledge.md`, and project onboarding/admin-integration instructions.
- `.claude/plans/snuggly-zooming-pie.md`: shared map redesign plan. Its old three-screen map layout and tile-provider assumptions have been superseded in places.
- `B:docs/objectives_panel_upgrade_plan_2026-11-09.md` and the two approved Top 5 scopes dated 10 November.
- `B:docs/multiday_live_trip_proposal_2026-11-04.md`, `B:docs/live_tracking_plan_2026-11-07.md`.
- `T:Lakbay_UI_UX_Feature_Enhancement_Plan_v2.md`, `T:PRODUCT.md`, `T:LAKBAY_PHASE_0_1_CONTRACT_AUDIT.md`.
- `A:skills/ui-development/references/admin-ui-plan.md`, current admin README, and backend phase/feature guides.

The approved catalog script is at:

`C:/Users/Arjane/AppData/Local/Temp/claude/38daf65ab48dece4/95ffaa53-e8a8-4c6b-8e8e-56b23130d701/scratchpad/apply_catalog_fixes.py`

It was read, not executed. It commits individual service operations and creates a
new Kapatagan destination without a rerun guard. Therefore a partially completed
run could leave changes applied and a later rerun could create a duplicate.
Reconcile the actual database, review each source/pin/access claim, and make an execution
plan before running it. Do not interpret the prior approval as permission to run
it during this read-only audit.

## Confirmed logic and integration findings

### F1 — Per-person budget mismatch blocks generation

**Priority:** high. **Status:** source-confirmed and reproduced with synthetic data.

- `T:lib/services/api_service.dart:1073` sends `state['total_budget']` as the
  generation request's `total_budget`, including when `budget_scope='per_person'`.
- `B:app/features/planning/service.py:91` calculates the whole-trip equivalent.
- `B:app/features/ai/service.py:753` checks the generation amount against
  `preview.whole_trip_budget` and rejects a mismatch before making a Groq call.

Example: PHP 3,000 per person for three travelers yields a PHP 9,000 preview, but
the current client sends PHP 3,000. The guard returns `planning_input_mismatch`;
using PHP 9,000 passed the same guard. Existing passing tests do not cover this
client/backend combination.

The active review form also initializes its budget input from the raw state
amount and writes `budget_scope='whole_trip'` on confirmation
(`T:lib/screens/planner/conversational_review_sheet.dart:465`). A scope conversion
needs explicit, consistent handling; do not silently reinterpret a per-person
amount as the entire party's budget.

Smallest corrective scope: agree one request contract, preserve the user's budget
scope, convert exactly once, and add a cross-contract regression scenario for
multiple travelers. No schema change is inherently required for this correction.

**Approved follow-up implementation — 10 November 2026: fixed locally.**

- `TripProvider.generateChatItinerary()` passes the canonical
  `whole_trip_budget` from the current backend preview to
  `ApiService.generatePlanningItinerary()`. The client does not multiply or round
  the budget itself. A missing canonical amount asks the traveler to refresh
  instead of falling back to the ambiguous state amount.
- The generation request uses that whole-trip amount, while `planning_state`
  retains the user's original amount and `budget_scope`. Authentication retry
  retains the same canonical amount.
- The active confirmation form preserves `per_person` scope and labels its input
  and guided question accordingly. Whole-trip over-budget comparisons use the
  canonical preview amount.
- Budget chips/editor label per-person values and retain centavos instead of
  rounding the editable value to whole pesos.
- The backend runtime and database schema are unchanged. Three parametrized
  backend regression cases protect the existing guard for whole-trip,
  single-person and multiple-person budgets, including rejection of a raw
  per-person amount where the whole-trip total is required.

Files changed for the fix:

- `T:lib/services/api_service.dart`.
- `T:lib/providers/trip_provider.dart`.
- `T:lib/screens/planner/conversational_review_sheet.dart`.
- `T:lib/widgets/planner/trip_chips_bar.dart`.
- `T:test/chat_planning_contract_test.dart`.
- `T:test/conversational_review_fee_test.dart`.
- `T:test/trip_chips_bar_test.dart`.
- `B:tests/test_phase15e_ai_geo_context.py`.

Verification: all three new traveler regressions failed against the original
code, then passed with the fix; the full current traveler suite passed **201
tests**, static analysis reported **no issues**, and the focused backend
budget/context checks passed **8 tests**. The generation contract test covers
PHP 3,000.05 per person becoming PHP 9,000.15 for three travelers and PHP 12,000.20
after changing to four, while the original per-person amount remains unchanged.
Existing whole-trip generation remains covered.

The fix was tested on an isolated copy, then the seven verified traveler files
were copied into the actual checkout only after checking original fingerprints;
other pending edits were preserved. Original copies are retained under ignored
`B:tmp/per-person-budget-fix-20261110/original-backup/`. No commit, push,
deployment, live AI generation, or phone check was performed for this fix.

### F2 — Admin cannot complete visitor-arrival verification

**Priority:** deferred by the approved pin-based scope above (originally high).
**Status:** source-confirmed; live data confirms no completed arrivals.

`A:lib/screens/destination_editor.dart:150` lists editable fields but omits
`arrival_lat`, `arrival_lng`, `arrival_source_url`, `arrival_verified_at`, and
`route_ready`. The backend already validates these fields
(`B:app/features/destinations/service.py:90`). Candidate publication correctly sets
`route_ready=False` (`B:app/features/destinations/candidate_service.py:124`).

An admin can publish an attraction but cannot finish its arrival evidence through
the current screens. A future arrival-review section can use existing contracts;
it is not the next implementation slice for the current version. Keep the backend checks.
Attraction coordinates, a road snap, visitor access, and a verified entrance are
different facts.

### F3 — Catalog and pricing data remain incomplete

**Priority:** high for a defensible demo. **Status:** read-only live observations.

| Live check | Result |
| --- | --- |
| Active / route-ready destinations | 30 / 0 |
| District coverage | Five active places in each of six target districts |
| Staged / published candidates | 648 / 0 |
| Destinations with unknown `estimated_cost` | 12 |
| Destinations with no image URL | 29 |
| Destinations with neither directions nor travel notes | 19 |
| Available accommodation rows / unknown charging unit | 12 / 12 |
| Available transportation rows / unknown charging unit | 12 / 12 |
| Neon Alembic version observed | `2026_11_09_0900` |

Tudaya Falls still contains `description='Sariwang hangin at dalampasigan'` and
`operating_hours='Nighttime visits'`. Samal and Mount Apo remain generic records;
the reviewed Samal beach candidates have not been published. The sole stored
image URL returned HTTP 403 from this audit environment; that does not prove it
fails in every browser, but it has not been validated as usable.

Unknown prices are intentionally distinguished from free prices, and group
scoring can exclude unknown-cost places. Do not fix the gaps by inserting zero,
inventing prices, or forcing five unrelated results. Top 5 can still return
approximate matches under its approved policy; zero verified arrivals does not
mean the newer Top 5 endpoint is necessarily empty.

### F4 — Accommodation selection is disconnected from the active planner

**Priority:** medium. **Status:** source-confirmed integration gap.

`T:lib/screens/planner/conversational_review_sheet.dart:472` sends
`selected_accommodation_ids: []`, clears accommodation pricing, and uses a
whole-trip lodging allowance. No accommodation selector exists in the active
conversational flow. The backend accepts catalog stays, and the pending View Trip
screen can display saved stay IDs, but the ordinary current planner does not
create those selections. Tests displaying fixture-backed stays do not prove a
traveler can select them in the real flow.

Decide whether the current phase intentionally supports allowances only. If
catalog stays are required, connect a selected stay, its charging unit, capacity,
nights, and canonical ID through preview -> generation -> saving -> View Trip.
Do not describe catalog availability as room vacancy or a booking confirmation.

### F5 — The map route does not preserve the saved planning route contract

**Priority:** medium. **Status:** corrected locally in the approved follow-up;
deployment and phone verification deferred by the user. The evidence below
describes the original behavior.

`T:lib/providers/route_ways_controller.dart:39` calls route optimization with
`returnToStart: false`. Its request interface has no saved return/order choice.
`T:lib/models/trip.dart` does not retain the saved route snapshot, and the traveler
API layer does not consume the backend trip-route read endpoint. The View Trip
screen computes a new route from its chosen start rather than displaying the
stored route as such.

Consequences: a saved round trip can be shown as an open route, and a chosen
itinerary order can be reoptimized on display. Recalculation should be explicit
and labeled. Add the planned keep-order/optimize choice, preserve return choice,
and distinguish a saved snapshot from a new route from the user's location.

### F6 — Top 5 truncates before feasibility filtering

**Priority:** medium, triggered as the catalog grows. **Status:** fixed locally
on 10 November (see the cleanup follow-up at the top). The evidence below
describes the original behavior.

`B:app/features/recommendations/service.py:165` sorts candidates without their
actual travel score and keeps only `MAX_ROUTED_CANDIDATES=50` before routing and
distance filtering. A synthetic catalog with 50 more-popular places 240 minutes
away and a less-popular 51st place 10 minutes away returned zero results and
`too_far=50`. The reachable place was never routed.

The current live catalog has 30 places, so this is not evidence of a current
30-place outage. It matters before publishing many of the 648 candidates. Keep
provider requests bounded while expanding or choosing the shortlist in a way
that can still find feasible/verified places. Add a >50-place regression case.

### F7 — Feedback and generation disagree about an unpinned origin

**Priority:** medium contract debt. **Status:** fixed locally on 10 November
(see the cleanup follow-up at the top); the app workaround still matches.

`B:app/features/planning/feedback.py:27` marks any missing preview input as
required, including `origin.coordinates`. The traveler intentionally ignores a
map-pin-only requirement when no route was requested
(`T:lib/models/planning_feedback.dart:83`). Generation also permits that case.

Claude repaired the visible dead end in the traveler, so do not report the old
save failure as still universal. The backend response nevertheless remains
inconsistent for other/future clients. Align feedback severity with whether a
route actually needs coordinates, while retaining the requirement for road
calculations.

### F8 — Comparison exists, but its research/UI path is incomplete

**Priority:** high for Objective 2. **Status:** partial, not unstarted.

The local configuration has comparison enabled and three slots populated. A
read-only aggregate found itinerary-generation attempts for all three models:

| Model | Audited attempts | Valid successful outputs |
| --- | --- | --- |
| `qwen/qwen3.8-27b` | 11 | 6 |
| `openai/gpt-oss-120b` | 5 | 4 |
| `openai/gpt-oss-20b` | 5 | 3 |

These are historical database totals, not a controlled comparison or model
quality ranking. Inputs, failures, configuration changes, and conditions may
differ. Dated comparison artifacts also exist under `B:outputs/`.

In particular, `outputs/groq-comparison-2026-11-05/README.md` documents a
**fixed-request pilot**, with the same two-day, four-traveler, three-place request
run three times against each model and fallback disabled. Each model produced
one response classified as valid out of three attempts in that historical test.
The accompanying manual review found missing places/ferry information and cost
arithmetic problems. That pilot predates the current stricter coverage/cost
validators: its old "valid" labels must not be treated as current validator
results. Preserve it as baseline evidence, then rerun a versioned, broader
benchmark after the selected corrections. Research comparison is therefore
**started**, but not yet a defensible final model-quality conclusion.

The traveler hardcodes `compare_models: false` in generation. There is no complete
comparison/evaluator view. `B:app/features/evaluation/service.py` reports latency,
outcome, and validation statistics; it explicitly says catalog interactions do
not measure recommendation accuracy. Finish the fixed benchmark, grounded
preference/route/cost scoring, human rubric, reporting/export, and consistent
model names in the manuscript. Local settings do not prove Render settings.

### F9 — Saved travel information is discarded by the traveler model

**Priority:** medium. **Status:** travel-field loss corrected locally in the
approved follow-up above; suitability-default issue remains open.

Admins/backend can store `how_to_get_there`, `travel_notes`, `best_time_to_visit`,
`what_to_bring`, and `estimated_travel_time`. The current traveler parser does not
retain them; catalog `Destination.extra` produces empty travel notes
(`T:lib/models/destination.dart:534`). A successful admin save therefore does not
deliver these fields to the traveler display.

The same parser defaults missing child/elderly suitability to true
(`T:lib/models/destination.dart:506`), while backend flags default to false. A
proper unknown state needs an agreed contract and, if database flags become
nullable, separately approved schema work. Missing evidence is not a positive
suitability claim.

### F10 — Routing/scheduling requirements exceed the current implementation

**Status:** partial/planned rather than a regression in the existing route API.

- OSRM Trip and Haversine/nearest-neighbor fallback exist. OSRM Table is now used
  for Top 5; it is not an integrated adaptive exact/2-opt route optimizer.
- The active itinerary option view lacks the full planned ordered-route review
  with keep-order/optimize, each leg's time/distance, and per-day route controls.
- No day-by-day time-window solver, structured weekly/date-exception schedule,
  booked flight/boat leg system, or accepted live itinerary revision exists.
- The local walking service setting is empty. Walking remains estimated unless
  the deployed environment has a separately verified foot graph; that deployment
  setting was not read.
- The current request requires a positive budget and at least one activity per
  day. Optional-budget work is on a different branch; rest/travel-only-day
  contracts need deliberate review. Do not relax ID/cost validation as a shortcut.
- Foreground route tracking exists. Saved-trip progress, background tracking,
  and live schedule replanning are separate stages.

### F11 — Some presentation and configuration still overstate capabilities

**Status:** confirmed source facts; actual running build configuration unknown.

- `T:lib/screens/profile/profile_screen.dart:976` claims trip records/photos are
  stored in local database tables; logout copy also claims offline maps/trips.
  The inspected app has no implemented durable offline trip/map database.
- `T:lib/models/commute_guide.dart` contains hardcoded hubs, directions, fares,
  and duration heuristics. These are active estimates, not all admin-managed
  transportation records. Preserve honest estimate labels until they are
  replaced by verified connection data.
- A localhost admin page defaults to the local API while the traveler defaults
  to Render. Set a shared explicit API URL during cross-app verification.
- The health endpoint does not identify a build SHA. An endpoint existing in
  live OpenAPI does not establish that every local file is deployed.

## Unused and duplicated code

### Files unreachable from the current app entry points

The scan followed relative and same-package imports/exports from the current
`lib/main*.dart` files. Manual checks confirmed that current main navigation uses
`ConversationalPlannerScreen`, and admin legacy route names resolve directly to
the newer workspaces. No deferred/conditional library import requiring an
additional entry point was found in these files.

**Traveler — 13 files:**

| File | Assessment |
| --- | --- |
| `lib/screens/planner/chat_ai_options_sheet.dart` | Old option sheet; tested directly but disconnected from the current app. |
| `lib/screens/planner/chat_plan_review_sheet.dart` | Old review form; tested directly but disconnected. Do not update it alone to fix the active planner. |
| `lib/services/gemini_service.dart` | Unused legacy wrapper around the backend; not a live Gemini integration. |
| `lib/core/utils/geo.dart` | Former app-side Haversine helper; still tested, no production import after Top 5 switched to backend travel values. |
| `lib/services/dialog_service.dart` | Unconnected utility. |
| `lib/services/toast_service.dart` | Unconnected utility. |
| `lib/widgets/cards/promo_card.dart` | Unconnected component. |
| `lib/widgets/loaders/inline_loader.dart` | Unconnected loader components. |
| `lib/widgets/loaders/loading_overlay.dart` | Unconnected overlay. |
| `lib/widgets/loaders/skeleton_loader.dart` | Unconnected skeleton family. |
| `lib/widgets/shared/confirm_dialog.dart` | Unconnected dialog. |
| `lib/widgets/shared/pulsing_dot.dart` | Unconnected component. |
| `lib/widgets/shared/toast_notification.dart` | Unconnected toast. |

**Admin — six files:**

- `lib/core/davao_region_boundaries.dart`.
- `lib/screens/accommodation_screen.dart`.
- `lib/screens/activities_screen.dart`.
- `lib/screens/meals_screen.dart`.
- `lib/screens/transport_screen.dart`.
- `lib/widgets/glass_card.dart`.

The four old admin screen wrappers have been replaced by direct routing to
`MarketRatesScreen`/`DestinationsScreen`. Keep compatibility URL behavior even if
unused wrapper files are later removed.

### Other unused or misleading remnants

- `T:TripProvider.generatePlan()` has no caller in the inspected app/tests. Its
  older `generateAIItinerary()` chain overlaps the active planning-aware path.
- `T:ApiService.fetchItineraryFeedback()` always returns null and has no caller.
  The active implementation is `fetchPlanningFeedback()`; do not mistake the
  stub for missing backend itinerary feedback.
- `Destination.davaoDestinations` and `AppNotification.mockNotifications` have no
  production references beyond declaration. They are cleanup candidates.
- `Trip.mockTrips` still has a fallback reference, although the current dashboard
  build requires a supplied persisted trip. It is not safe to label every mock
  declaration as unused without tracing its guard and tests.
- Single-occurrence public-method scans also found candidates such as old profile
  setters, but **framework lifecycle methods were excluded from dead-code
  findings**. A callback's lack of a textual caller is not proof it is dead.

### Duplication that exists but should not trigger a broad rewrite

- AI, budget, and trip repositories have identical accommodation/transport lookup
  bodies; their services duplicate destination/rate ownership and missing-ID
  checks. These are real maintenance duplicates within a feature-based design.
- Geo-group and planning-route limiter `check()` implementations are identical.
- The old review/AI-option sheets duplicate responsibilities of the newer
  conversational review/results flow, with separate tests that can drift.
- Preference-only recommendations, weighted single-place Top 5, and destination
  grouping are **different contracts**. Some older scoring is still used for
  selected itinerary context. Do not delete a live endpoint or merge scoring
  formulas merely because the names overlap.
- Haversine exists for different purposes: backend fallback routing, proximity,
  client commute heuristics, and a now-disconnected helper. Similar formulas do
  not establish that all copies should be removed.

Prioritize behavior/contract corrections, then remove or consolidate one proven
unused path at a time with approval. Passing tests of a disconnected screen are
not proof that the current user journey implements that screen's functionality.

## Objective coverage

| Study objective | Current evidence | Remaining work |
| --- | --- | --- |
| 1. At least five suitable destinations through geo-analytics | Weighted Top 5, explanations, filters, groups, and traveler integration implemented | Place-pin/access/cost review; phone proof; fix >50 shortlist behavior. Arrival verification is deferred. Return an honest shortfall when fewer than five qualify. |
| 2. Compare three Groq models | Comparison selection/audits exist, all three models have recorded attempts, local configuration is enabled | Controlled benchmark, quality/relevance evidence, comparison UI/reporting and final manuscript names. |
| 3. AI-chat itinerary generation | RAG, canonical planning state, preview, structured validation, audited options, run-based saving; per-person correction tested locally | Device-check corrected budget flow; connect intended stay selection; optional-budget decision/integration; catalog and approximate route-context completion. |
| 4. Adaptive route optimization with Haversine and OSRM | OSRM routes/Trip, Haversine/nearest-neighbor fallback, shared maps and foreground tracker, saved-route preservation and ordered pre-save review | Deferred deployment and device verification, adaptive algorithm selection, multi-day constraints, walking graph and mixed-mode work. |
| 5. Group coordination | Members/invites, tasks, expenses, memories, notifications, reports and ownership/membership checks exist | Review/commit current View Trip changes; group preference aggregation and party-age persistence. Do not reimplement invitations as if none exist. |
| 6. ISO/IEC 25010-informed evaluation | Completed-trip assessment backend and admin summaries; pending traveler/admin forms implemented locally | Review/commit forms; user-testing protocol, anonymized export, and recommendation-result attribution. Perception ratings do not establish full technical conformance. |

## Master-plan status

Source: `B:docs/objectives_panel_upgrade_plan_2026-11-09.md`. Its status tables
predate newer work; use this reconciliation rather than copying them unchanged.

| Step | Current assessment | Smallest remaining scope |
| --- | --- | --- |
| 1. Unblock data | Not completed live; pins approved for current planning | Review place identities/pins, access/cost/image corrections and publication; walking service separately. Arrival review deferred. |
| 2. Admin OSM lookup | Backend implemented; admin changes local | Review/commit UI, distinguish staged vs published identity, verify saved place facts and shared-server flow. Arrival editor deferred. |
| 3. Personalized Top 5 | Implemented on current branches | Correct identified edge case, check phone flow, carefully integrate app branch; core backend is already on local main. |
| 4. Unknown suitability/check dates | Planned; current flags still boolean defaults | Agreed unknown/source/date contract and approved migration. |
| 5. Destination photos | Pasted URL exists; upload flow planned | Admin upload/source/license review and traveler delivery. |
| 6. Traveler place details | Saved travel fields connected locally; refresh regression added | Deploy/device-check edited and cleared fields, images, rates and unit labels. Catalog/rate refetch already exists. |
| 7. Multi-stop/adaptive routes | Saved route preservation and ordered pre-save review implemented locally | Review and integrate these changes when release resumes. Adaptive optimization remains open. |
| 8. Land/air/sea | Road-ferry metadata exists; mixed-mode itinerary legs planned | Approved connection/leg/source contracts and schema scope; do not invent timetables. |
| 9. Group/child scoring | Party-level costing and destination age bands exist | Group aggregation, persistent composition, activity/transport age controls in the active UI. |
| 10. Activity cost catalog | Stateless allowances/projection work | Structured activity price/duration/source records and stable IDs; current options derive identity from labels. |
| 11. Model comparison metrics | Framework and real historical runs exist | Controlled quality benchmark, evaluator/reporting/export and methodological review of old artifacts. |
| 12. Richer feedback | Advisory findings implemented | Consistent requirements, optional overall score and alternatives; the null legacy client method is not the active path. |
| 13. App/study evaluation | Backend implemented; forms local | Finish release/device flow, protocol/export/attribution. |

Do not automatically treat every proposal as approved implementation. Existing
backend/schema approval rules still apply.

## Other plans and documentation drift

| Plan / guidance | Reconciliation |
| --- | --- |
| Multi-day/live-trip proposal (4 November) | Shared destination basket exists in current traveler code. Optional-budget work exists on separate branches. Structured schedules, date exceptions, accepted live revisions and mixed legs are not integrated. |
| Live tracking plan (7 November) | Stage 1 foreground implementation and tests exist. Its statement that all work is uncommitted is stale. Saved-trip progress, background tracking and schedule replanning remain separate later stages; device verification is still needed. |
| Claude saved map plan | Shared route components replaced the original duplicated map blocks. The older planner-results screen described there is not the current conversational result flow. Do not recreate it from old filenames/line numbers. |
| Traveler UI/UX v2 | Several flows, cards, costs, notifications, maps and trip details exist. Complete activity pricing, catalog stays in the planner, durable offline storage, secure password recovery and a full study/model-comparison presentation do not follow merely from the design plan. |
| Admin UI plan | Shell, responsive components, rich editor, OSM, users and assessment views have local implementations. Several old statements that the backend has no user directory/rate consumption are stale. Admin-wide trip inspection/moderation remains unavailable. |
| `PROJECT_CONTEXT.md` | Historical 6 November snapshot. Its lack-of-OSRM-Table, no-user-directory and broad dirty-tree claims are stale. It also predates current Top 5 and pending assessment screens. |
| `docs/routing.md` | Still describes Table and saved-trip routes as deferred in places; Table now exists for Top 5 and trip route endpoints exist. Adaptive routing remains separate. |
| Top 5 app scope (10 November) | Status still says not committed even though traveler commit `d89ba1d` exists. Preserve the accepted change that list-level warnings were not shown; per-card labels remain. |
| `docs/models.md` / manuscript wording | Old comparison model names and future-tense audit-table wording require reconciliation with actual model IDs and existing generation-run storage. |
| Traveler onboarding guidance | Says default API is localhost and recommends preserving catalog fallbacks. Actual default is hosted Render, and live catalog failures deliberately do not substitute sample destinations. |
| October Phase 0/1 contract audit | Useful historical evidence, not current status. Its five-test count, analyzer issues, Git state and feature gaps have since changed. |

Use code, current contracts, observed Git state and dated live measurements to
resolve conflicts. A past test count or assistant completion statement is not a
current deployment receipt.

## Verification results

The table below records the original read-only audit. F1's later approved fix has
its separate, newer results in the implementation note above.

| Check | Result / limit |
| --- | --- |
| Full traveler tests, isolated copy of current files | **198 passed** |
| Full admin tests, isolated copy of current files | **37 passed** |
| Traveler static analysis (`lib`, `test`) | **No issues found** |
| Admin static analysis (`lib`, `test`) | **No issues found** |
| Full backend suite | **500 passed, 1 skipped, 58 warnings**; 1,019.39 seconds. The skipped test is the optional real-Postgres app-assessment integration test; a test database URL was not configured. Warnings concern existing dependency/API deprecations. |
| Earlier focused catalog/backend checks in this chat | 49 passed |
| Earlier focused Top 5/backend checks in this chat | 46 passed |
| Earlier focused Top 5 app checks | 29 passed on its committed snapshot |
| Synthetic per-person budget example | Current payload rejected; whole-trip-equivalent payload accepted |
| Synthetic >50-place Top 5 example | Reproduced feasible candidate omission and incorrect zero-result shortfall |
| Read-only Neon catalog/AI aggregates | Transaction read-only setting confirmed on; rolled back |
| Public API health/OpenAPI/catalog reads | 200; expected Top 5/OSM/publication contracts present; public catalog returns 30 places |
| Unauthenticated candidate queue read | 401 |
| One read-only live OSM example | Roxas Grounds recovered from staged inventory after provider timeout; details recovered through official OSM fallback |
| Diff whitespace checks | Passed for the three main checkouts; existing Windows line-ending warnings remain informational |
| Source fingerprint comparison | Every pre-existing `.py`, `.dart`, `.md`, `.yaml`, and `.toml` file in the recorded main-checkout inventories retained its original hash. Git status matched the baseline in all three repositories except for this authorized new report. |

The synthetic checks were diagnostic invocations, not source/test-file changes.
They do not constitute fixes. Existing full tests can pass while cross-client
contracts or larger-catalog cases remain uncovered.

## Recommended work sequence

1. **Release/device-check the locally corrected per-person budget flow.** The
   approved source fix and regression checks are complete; retain the backend
   guard and preserve this change when committing shared traveler files.
2. **Review a small set of catalog places and the admin save flow:** place
   identity/pin, access evidence, fees and charging units, hours and image delivery.
   The saved-travel-field and itinerary-prompt corrections are implemented locally;
   complete deployment/device verification and actual source-backed data review.
   Arrival-point editing is deferred. Reconcile the old catalog script with this
   scope and its partial-run/rerun behavior before any separately approved execution.
3. **Review and commit pending work in coherent slices.** Separate traveler
   completion/assessment, View Trip changes, admin catalog/OSM, admin reporting,
   and shell/profile changes. Preserve shared-file edits.
4. **Connect intended catalog stays/travel information** through the active
   planner and traveler models. Confirm price units and explicit unknowns.
5. **Verify route preservation and pre-save review when release work resumes.**
   Check the displayed itinerary, route order and saved route together. The user
   deferred deployment and phone checks.
6. **Fix the >50 Top 5 shortlist behavior** before a large candidate-publication
   campaign. Validate a few published places end to end first.
7. **Reconcile optional-budget/quality branches by behavior**, then choose an
   approved scope for integration. Do not merge old planner contracts over the
   current UI or assume patch-ancestry means a feature is absent.
8. **Complete the three-model research path** with a controlled benchmark,
   quality rubric, report/export and final manuscript wording.
9. **Schedule later schema-heavy work**: nullable suitability/check dates,
   structured activities/hours, mixed travel legs, group composition and live
   revisions. Keep those as separately reviewed increments.
10. **Clean proven unused code and stale documentation** after the behavioral
    corrections. Update the tests to exercise active paths and retain legacy
    public API/route compatibility where required.

The Groq-assisted catalog drafting proposal can be scoped alongside steps 2/4,
after the admin can review saved place pins and factual evidence. OSM supplies source data,
Groq prepares drafts, the admin verifies/publishes, the backend ranks/validates,
and OSRM computes route facts. No stage should turn an unsupported generated
price, entrance, schedule, or suitability statement into a verified fact.

## Instructions for the next coding session

1. Read this report, `AGENTS.md`, `docs/core_focus.md`, and `docs/new_feature.md`.
2. Recheck all three main worktrees and any branch you intend to use. Preserve
   the pending files and distinguish existing user edits from the intended slice.
3. Treat this report as evidence and a work queue, **not implementation approval**.
   Ask before code changes, explain and obtain specific approval for schema
   changes, and use reviewed Alembic migrations where required.
4. Reproduce the chosen issue against the active code path before fixing it.
   Tests of the disconnected old sheets are not sufficient.
5. Keep unknown values explicit, retain ownership/admin checks and AI validation,
   and do not auto-publish the staged catalog or run the old bulk script as part
   of unrelated work.
6. Validate the smallest correction, then update this report's relevant status.
   Record live/device observations separately from mock tests and historical runs.
7. Do not delete old code, generated files, worktrees, migrations, or user output
   merely because this audit marks them as candidates for review.
