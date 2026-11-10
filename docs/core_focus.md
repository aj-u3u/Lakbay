# Lakbay Core Focus

This document defines the incremental build plan for Lakbay Backend. The goal is
to build the API in phases so every layer is understandable, testable, and useful
before adding the next layer.

## Guiding Principle

Build the backend from stable foundations to advanced intelligence:

1. Authentication and data ownership first.
2. Clean destination and rate data second.
3. Deterministic recommendation and budget logic third.
4. AI generation only after the backend has reliable structured data.
5. Collaboration, reports, and quality evaluation after the main trip workflow is
   stable.

## Phase 0: Project Foundation

Purpose: prepare the backend workspace.

Scope:

- FastAPI project skeleton.
- Environment variable setup.
- SQLAlchemy base and database session.
- Alembic migration setup.
- Global error handling.
- Health check endpoint.
- CORS configuration for Flutter.

Done when:

- The API can start locally.
- The database connection is configured through `.env`.
- Alembic can detect models and run migrations.
- The API exposes `GET /api/v1/health`.
- CORS is configured for early Flutter development.
- Standard API error responses are registered.

Decisions already made:

- Use a new Neon database, so the first real migration can create the approved
  revised schema instead of baselining an old database.
- Use `venv` and `pip` for Python dependency management.
- Use `/api/v1` as the standard API prefix.
- Allow all CORS origins during early local development, with a comment reminding
  developers to restrict origins before production.
- Use `Asia/Manila` as the application timezone.
- Use Cloudinary for uploaded images. Upload endpoints should accept
  `multipart/form-data`, then return a Cloudinary URL. Other endpoints that need
  an image should accept that URL in an `application/json` request body.
- Start with OSRM public/demo routing for development. Revisit hosted or
  self-hosted OSRM before production or heavy testing.
- Prepare a seed data plan for Davao destinations, rates, categories, vibes, and
  districts.
- Use short-lived JWT access tokens plus refresh tokens. Refresh tokens should be
  rotated and revocable once auth tables are implemented.

PostGIS decision:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

This command is sufficient to enable PostGIS if the Neon project supports the
extension and the connected database role has permission. In Alembic, place it in
the first migration before creating `geography` or `geometry` columns.

## Phase 1: Authentication And Users

Purpose: establish secure user identity and access control.

Scope:

- User registration.
- User login.
- Password hashing.
- JWT access tokens.
- Refresh token strategy.
- Current-user dependency.
- User profile endpoint.
- Basic role support: `user` and `admin`.

Done when:

- Flutter can register and log in a user.
- Protected endpoints reject unauthenticated requests.
- Admin-only endpoints are enforceable.

Implementation notes:

- Normal registration accepts `full_name`, `email`, `password`, and
  `confirm_password`.
- `confirm_password` exists only in the Pydantic request schema and is not stored
  in the database.
- Public admin registration is allowed through
  `POST /api/v1/auth/register/admin`, but it must require
  `ADMIN_REGISTRATION_CODE`.
- Login uses an `application/json` request body for Flutter.
- Email verification is deferred to a later phase or security enhancement.
- `avatar_url` is editable in Phase 1, but Cloudinary upload endpoints are
  deferred to the upload/photo phase.

## Phase 2: Destination Data Foundation

Purpose: create reliable Davao Region travel data.

Scope:

- Destination model.
- Destination categories, vibes, accessibility flags, district, coordinates, and
  cost fields.
- Accommodation rates.
- Transportation rates.
- Admin CRUD for destinations and rates.
- Optional PostGIS support for destination coordinates.

Done when:

- Admins can preload destinations.
- The system has at least five tourist locations per target district.

On 1 November 2026 the configured Neon catalog had 30 active destinations:
five in each target district. The numeric Phase 2 coverage target is met.
All 30 remain `route_ready=false`; visitor arrival and access verification
continues separately. See the [coverage review](phase2_coverage_arrival_continuation_2026-11-01.md).
- Users can browse and filter destinations.

Current implementation notes:

- Phase 2 currently uses simple text fields for `category`, `vibes`, and
  `activities`.
- Destination delete is a soft delete through `is_active=false`.
- Accommodation and transportation delete actions mark records unavailable.
- The Phase 2 migration creates a PostGIS `geography(Point,4326)` column and a
  geospatial index for destinations.
- Destination browsing uses `limit` and `offset` pagination with a maximum
  limit of `100`.
- API and database validation enforce basic numeric ranges for coordinates,
  costs, capacity, and travel duration.
- Attraction coordinates remain separate from optional verified visitor arrival
  coordinates. New destinations default to `route_ready=false`; admin review
  supplies arrival coordinates, source, and verification time before routing
  uses the arrival point.
- Starter Davao destination seed data lives in
  `app/seeds/davao_destinations.py`.
- Admin-only OSM candidates can be staged from the dated regional review and
  enriched with fees, activities, hours, category, and access evidence before
  publication. Unpublished candidates do not enter traveler results. Published
  attraction pins remain `route_ready=false` until arrival verification. On
  4 November 2026, the configured Neon database held 648 staged candidates and
  still held 30 active destinations.
- Rate currency and charging unit columns were added in `dfc235ae4bed`.
  New admin-entered rates use PHP and an explicit unit. Older seeded rates
  retain a null unit until verified by an admin.
- Endpoint details are documented in `docs/destinations.md`.

## Phase 3: Preferences And Recommendation Signals

Purpose: capture user intent and convert it into destination matches.

Scope:

- User preference signals.
- Preferred categories, vibes, budget class, activities, location, duration, and
  accessibility needs.
- Destination scoring service.
- At least five feasible destination recommendations.
- Destination interactions: view, save, rate, add to itinerary.
- Destination popularity scoring.

Done when:

- A user can submit preferences and receive ranked destination suggestions.
- Recommendations are explainable using stored destination data.
- Interactions can influence popularity or future suggestions.

Current implementation notes:

- Phase 3 uses deterministic scoring only. AI itinerary generation remains
  deferred to Phase 5.
- User preference requests are saved in `user_preference_signals`.
- Destination actions are saved in `destination_interactions`.
- Aggregate counters and popularity boost data are saved in
  `destination_popularity`.
- Repeated `view` interactions are allowed. `save`, `rate`, and
  `add_to_itinerary` are stabilized to one signal per user per destination.
- Recommendation results exclude zero-score destinations when ranking
  preferences are provided.
- `add_to_itinerary` is recorded only as an interaction signal in Phase 3. Real
  itinerary creation remains deferred to a later phase.
- Endpoint details are documented in `docs/recommendations.md`.

## Phase 4: Budget Engine

Purpose: make itinerary options financially useful.

Scope:

- Budget input.
- Estimated transportation, accommodation, meals, and activity costs.
- Budget validation.
- Over-budget filtering.
- Remaining budget calculation.
- Percent usage.
- Spending breakdown by category.

Done when:

- Generated or manually created trip plans can be checked against a user budget.
- Over-budget itinerary options are removed or clearly rejected.
- Budget analytics can be returned to Flutter.

Current implementation notes:

- Phase 4 is currently stateless and does not create budget tables.
- The endpoint is `POST /api/v1/budgets/estimate`.
- `destinations.estimated_cost` is treated as the destination/activity estimate.
- Accommodation and transportation costs come from selected Phase 2 rate rows.
- Meal estimate is calculated from
  `meal_cost_per_day * traveler_count * day_count`.
- Over-budget estimates return `200 OK` with `is_over_budget=true`.
- Endpoint details are documented in `docs/budgets.md`.

## Phase 5: AI Itinerary Generation

Purpose: generate structured itinerary options from user preferences and selected
destinations.

Reference: see `docs/models.md` before implementing any Groq model integration.

Scope:

- Groq client integration.
- Prompt templates.
- Model configuration.
- AI response schemas.
- AI output validation.
- Generation of at least five itinerary options.
- Model comparison logging for response time, relevance, and recommendation
  accuracy.

Done when:

- The API can call a configured Groq model.
- AI itinerary responses are parsed into validated backend schemas.
- Invalid AI output is rejected or repaired before saving.
- Model performance can be measured.

Current implementation notes:

- Phase 5 adds `POST /api/v1/ai/itineraries/generate`.
- The endpoint returns validated itinerary drafts only. It does not create saved
  trips yet.
- AI prompts must use selected Phase 2 destination, accommodation, and
  transportation IDs. Free-text invented places should be rejected by validation.
- Generated options are validated for JSON shape, every selected destination
  ID, day count, budget adherence, activity-cost arithmetic, and minimum option
  count. Returned drafts flag unverified hours, missing ferry fare basis, group
  cost assumptions, and unchecked travel times.
- Groq model IDs are read from environment variables. Do not hard-code model IDs.
- Each model attempt is logged in `ai_generation_runs` with model ID, prompt
  version, response time, token usage, validation status, and fallback status.
- Endpoint details are documented in `docs/ai_itineraries.md`.

Important note:

- Confirm the exact available Groq model IDs in the Groq console before enabling
  live calls. Some model IDs from the proposal may be deprecated depending on the
  account tier.

## Phase 6: Route Optimization

Purpose: arrange destinations into efficient travel sequences.

Reference: see `docs/routing.md` before implementing routing endpoints or route
optimization services.

Scope:

- Haversine distance calculation.
- OSRM route lookup.
- Travel mode support: private vehicle, public transport, walking.
- Route distance and duration summaries.
- Optimized destination order.
- Live travel time cache when needed.

Done when:

- Selected destinations can be sorted into an efficient route.
- The API can return total estimated distance and duration.
- The route result can be attached to an itinerary or trip.

Current implementation notes:

- Phase 6 starts with stateless route results. It does not create route tables or
  save route summaries yet.
- The implemented endpoints are `POST /api/v1/routes/preview` and
  `POST /api/v1/routes/optimize`.
- `preview` keeps the destination order from the request.
- `optimize` asks OSRM Trip for a suggested order when OSRM is configured and
  the travel mode is supported.
- Driving and walking use OSRM when available, then fall back to Haversine
  estimates if OSRM is unavailable.
- `public_transport` is estimated in Phase 6 and does not call OSRM.
- Route saving remains deferred to Phase 7 Trip Management.
- Endpoint details are documented in `docs/routing.md`.

## Phase 7: Trip Management

Purpose: persist selected plans as real trips.

Scope:

- Create trip.
- Save selected itinerary.
- Update trip notes, budget, dates, and destination summary.
- View trip details.
- Delete or archive trip.
- Trip itinerary activities by day and time.

Done when:

- A user can turn an itinerary option into a saved trip.
- Trip details can be retrieved consistently by Flutter.
- Only the trip owner or authorized member can access it.

Current implementation notes:

- Phase 7 started owner-only. Phase 8 extends trips with members and shared
  visibility.
- The implemented endpoints are `POST /api/v1/trips`, `GET /api/v1/trips`,
  `GET /api/v1/trips/{trip_id}`, `PATCH /api/v1/trips/{trip_id}`,
  `DELETE /api/v1/trips/{trip_id}`, `POST /api/v1/trips/{trip_id}/archive`,
  `POST /api/v1/trips/{trip_id}/route`, and
  `GET /api/v1/trips/{trip_id}/route`.
- Delete is a soft delete. Trips are marked `archived` instead of being removed.
- Saved routes are stored in `trip_routes` using the Phase 6 route summary
  shape.
- The Phase 7 migration creates `trips`, `trip_destinations`,
  `trip_itinerary_days`, `trip_itinerary_activities`, and `trip_routes`.
- Endpoint details are documented in `docs/trips.md`.

## Phase 8: Group Collaboration

Purpose: support shared travel planning.

Scope:

- Travel groups.
- Group membership.
- Invite or add members.
- Member roles.
- Shared trip visibility.
- Trip task CRUD.
- Task status: Pending, Ongoing, Completed.
- Assigned member and due date fields.

Done when:

- A trip can have multiple members.
- Members can view shared trip information.
- Members can create, assign, update, and complete tasks.

Current implementation notes:

- Phase 8 uses the existing `trips` table as the group container.
- The implemented collaboration tables are `trip_members` and `trip_tasks`.
- The implemented endpoints are `GET /api/v1/trips/{trip_id}/members`,
  `POST /api/v1/trips/{trip_id}/members`,
  `PATCH /api/v1/trips/{trip_id}/members/{member_id}`,
  `DELETE /api/v1/trips/{trip_id}/members/{member_id}`,
  `GET /api/v1/trips/{trip_id}/tasks`,
  `POST /api/v1/trips/{trip_id}/tasks`,
  `GET /api/v1/trips/{trip_id}/tasks/{task_id}`,
  `PATCH /api/v1/trips/{trip_id}/tasks/{task_id}`, and
  `DELETE /api/v1/trips/{trip_id}/tasks/{task_id}`.
- The Phase 8 migration is `0007_group_collaboration`.
- Endpoint details are documented in `docs/group_collaboration.md`.

## Phase 9: Expenses And Shared Costing

Purpose: track actual trip spending and member shares.

Scope:

- Expense records.
- Expense categories: transportation, accommodation, meals, activities, other.
- Member contributions.
- Individual share calculation.
- Balance summary per member.
- Group budget analytics.

Done when:

- The API can compute `Individual Share = Total Trip Cost / Number of Members`.
- The API can show who paid, who owes, and remaining budget.
- Flutter can display category spending breakdowns.

Current implementation notes:

- Phase 9 uses `trip_expenses` and `trip_expense_splits`.
- The implemented split method is `equal`.
- Equal splits are stored when expenses are created. Amount corrections
  recalculate across the expense's existing split participants.
- Voided expenses are soft-deleted and excluded from active summaries.
- Archived trips are read-only for expense writes.
- The Phase 9 stabilization migration adds same-trip integrity constraints for
  expense payers and split members.
- Child-aware or weighted costing is deferred to a future Phase 9.5 because it
  affects budgets, itinerary generation, reports, and expense sharing together.
- Endpoint details are documented in `docs/expenses.md`.

## Phase 10: Memories And Photo Uploads

Purpose: store trip photos and memories.

Scope:

- Image upload endpoint.
- Storage provider integration.
- Trip memory records.
- Caption, location tag, uploader, and timestamps.
- Basic like/comment counters if needed.

Done when:

- Users can upload photos for a trip.
- Members can see who uploaded each photo.
- Photos are associated with trips and destinations.

Current implementation notes:

- Phase 10 uses `trip_memories`.
- Images are uploaded to Cloudinary through
  `POST /api/v1/trips/{trip_id}/memories/upload`.
- Memory metadata is saved separately through
  `POST /api/v1/trips/{trip_id}/memories`.
- Uploads accept JPEG, PNG, and WebP images by default.
- Deleted memories are soft-deleted with `status=deleted`.
- Archived trips are read-only for memory writes.
- Endpoint details are documented in `docs/memories.md`.

## Phase 11: Reports

Purpose: export trip summaries for users.

Scope:

- PDF report generation.
- Final route summary.
- Itinerary schedule.
- Costs incurred.
- Member contributions.
- Budget breakdown.
- Optional review/feedback summary.

Done when:

- The API can generate a downloadable PDF trip report.
- The report contains route, cost, itinerary, and contribution details.

Current implementation notes:

- Phase 11 uses on-demand report generation and does not create report tables.
- `GET /api/v1/trips/{trip_id}/reports/summary` returns the JSON data used by
  the report.
- `GET /api/v1/trips/{trip_id}/reports/pdf` returns a downloadable PDF.
- Reports include existing trip, destination, itinerary, group task, route,
  expense, and member data.
- Review and feedback data remain deferred to Phase 12.

## Phase 12: Reviews And Feedback

Purpose: evaluate trip quality and recommendation usefulness.

Scope:

- Post-trip rating.
- Accuracy rating.
- Route efficiency rating.
- Budget adherence rating.
- Overall experience rating.
- Written comments.
- Feedback analytics for future evaluation.

Done when:

- Users can submit reviews after trips.
- Reviews are attached to users, trips, and optionally destinations.
- Data can support ISO/IEC 25010 evaluation.

Current implementation notes:

- Phase 12 uses `trip_reviews`.
- Reviews can be created, updated, or deleted only for completed trips.
- Each active user can submit one active trip-level review per trip and one
  active destination-level review per trip destination.
- Deleted reviews are soft-deleted with `status=deleted`.
- `GET /api/v1/trips/{trip_id}/reviews/summary` returns trip-level average
  ratings for later evaluation. Destination-level reviews are excluded from
  whole-trip averages to avoid overweighting one user's feedback.
- The Phase 12 stabilization migration adds same-trip reviewer integrity so the
  stored review user must belong to the same trip as the review.

## Phase 13: Notifications

Purpose: keep users informed about relevant trip activity.

Scope:

- Notification records.
- New trip invite.
- Task assignment.
- Task updates.
- Expense updates.
- Itinerary updates.
- Read/unread state.

Done when:

- Users can fetch their notifications.
- Group-related events create notifications.
- Notifications are scoped to the correct user.

Current implementation notes:

- Phase 13 uses `notifications`.
- Notifications are in-app only. Push, email, and SMS are deferred.
- `read_at = null` means unread.
- Deleted notifications are soft-deleted with `status=deleted`.
- Users can list their notifications, filter unread items, get unread count,
  mark one notification as read, mark all as read, and soft-delete their own
  notifications.
- Notification events are created for trip member adds, task assignment/update,
  expense create/update/void, trip updates, and route updates.
- Endpoint details are documented in `docs/notifications.md`.

## Phase 14: Quality, Performance, And Evaluation

Purpose: harden the application for user testing and thesis evaluation.

Scope:

- API tests.
- Migration tests.
- Seed data checks.
- AI latency logging.
- Recommendation quality metrics.
- ISO/IEC 25010 evaluation support.
- Security review.
- Performance review for expensive endpoints.

Done when:

- Core endpoints have tests.
- AI and recommendation metrics can be exported or reviewed.
- The backend is ready for Flutter integration testing and user assessment.

Current implementation increment:

- `GET /api/v1/evaluation/summary` provides admin-only, read-only AI attempt,
  catalog engagement, and destination-readiness aggregates from existing tables.
  Catalog interactions are not attributed to recommendation impressions, so the
  response does not claim recommendation accuracy.
- Phase 14 endpoint/security tests and an offline Alembic upgrade/downgrade SQL
  smoke test are in `tests/test_phase14_evaluation.py` and
  `tests/test_phase14_migrations.py`. Live Postgres migration reversal, external
  provider checks, and device integration remain separate gates.
- The response contract and verification steps are in
  `docs/phase14_evaluation.md`.

## Phase 15: AI Geo-Analytics Planning Enhancements

Purpose: address panel recommendations without rewriting the working backend.
Phase 15 should be added in small sub-phases so each enhancement can be reviewed,
tested, and explained before the next one is implemented.

Guiding rule:

```text
Keep the existing feature modules and endpoints stable. Add enhancement layers
beside them unless a specific schema change is approved.
```

### Phase 15A: Routing Algorithm Review

Purpose: document and stabilize the route optimization strategy.

Scope:

- Compare OSRM Trip, OSRM Table, Haversine, nearest-neighbor, 2-opt, and exact
  small-set TSP-style approaches.
- Keep the current Phase 6 route endpoints working.
- Prefer OSRM road travel time when available.
- Use Haversine and nearest-neighbor as understandable fallbacks.

Done when:

- `docs/routing.md` explains the chosen routing algorithm and fallbacks.
- The current route response remains compatible with Flutter.

### Phase 15B: Geo-Analytics Destination Grouping

Purpose: make geo-analytics more than map display.

Scope:

- Group destination suggestions by proximity, district, route feasibility, and
  recommendation score.
- Return the top destination groups that are practical for one itinerary.
- Keep this stateless first, using existing destination coordinates and scores.

Done when:

- The backend can explain why destinations belong together.
- Grouping can be used by AI itinerary generation later.
- No trip data needs to be saved just to preview groups.

### Phase 15C: Activity-Based Budget Projection

Purpose: improve budget estimates by looking at planned activities, not only
destination-level estimates.

Scope:

- Use existing itinerary activity `estimated_cost` values first.
- Add activity catalog tables only after the stateless projection is reviewed.
- Return a clearer cost projection by destination, activity, transportation,
  accommodation, meals, and miscellaneous costs.

Done when:

- Users can see where estimated costs come from before saving a trip.
- The budget projection can be passed to AI as controlled context.

Implemented increment: the planning preview returns destination-scoped activity
options and requires an explicit cost assumption for each selected activity.
Both Flutter chat review sheets now let travelers select those returned options
and mark each as a separate whole-trip estimate or explicitly included in a
destination or food allowance. The backend preview handles the total and rejects
overlapping coverage. Activity fees and durations remain unknown in the catalog;
structured activity prices are future data work.

### Phase 15D: Child-Aware Costing

Purpose: support trips that include children whose fees may be free, half price,
or full price depending on age and activity rules.

Scope:

- Start with request-level traveler age groups.
- Do not change expense sharing until budget behavior is approved.
- Use explicit pricing rules instead of assuming who should pay.

Done when:

- Budget estimates can represent adult and child costs fairly.
- Child-aware rules can later be reused by expenses and reports.

Implemented backend increment: `POST /api/v1/planning/preview` accepts optional
`adult_count`, `child_ages`, and nonoverlapping free/half/full age-band rules for
selected destinations, activities, and per-person catalog transport. Missing
child prices keep the projection partial; traveler rules are labeled as
assumptions. Existing whole-trip allowances remain valid. Both Flutter chat
review sheets collect party ages and allow a mutually exclusive whole-trip
allowance or age-based rule for each destination. Activity and per-person
transport child age-band controls remain pending. No schema or expense sharing changed.
See `docs/child_aware_costing.md`.

### Phase 15E: AI Geo-Analytics Itinerary Context

Purpose: let AI generate itineraries from backend-calculated geo-analytics
instead of asking AI to guess route feasibility.

Scope:

- Pass top recommendations, destination groups, route summaries, budget
  projections, travel mode context, and warnings into the AI prompt.
- Keep backend validation responsible for IDs, costs, route feasibility, and
  budget limits.
- Keep the existing AI itinerary endpoint unless a new orchestration endpoint is
  approved.

Done when:

- AI itinerary options are based on route-aware and budget-aware context.
- AI still uses only allowed destination, accommodation, and transportation IDs.

Implemented: planning-enabled itinerary generation reuses the stateless planning
preview for selected catalog IDs, cost provenance, and origin-inclusive route
context. It ranks interest matches among those selected IDs and, when a route
summary exists for at least two stops, reuses Phase 15B to score eligible
destination groups. The prompt, API response, and generation-run audit summary
carry these results, travel mode, route provider/estimate/arrival verification,
budget completeness, and warnings. The group calculation has its own route calls
and per-user limiter. Unknown-cost destinations are excluded from scored groups;
an empty group result is explicit. Every AI option still must use exactly the
selected IDs and pass backend budget validation. A chosen validated option can
be saved with its preview and route in Phase 7 trip records. Optional Phase 15D
age rules now flow through the same preview budget and AI prompt. Live route
readiness depends on verified visitor
arrival points in the catalog.

### Phase 15F: Itinerary Feedback

Purpose: provide feedback before a user saves or follows an itinerary.

Scope:

- Check route efficiency, budget fit, pacing, activity load, travel mode fit,
  child suitability, and missing data.
- Start with a stateless evaluation response.
- Save evaluation runs only if Phase 14 metrics require persistence.

Done when:

- Flutter can show actionable itinerary feedback such as over-budget warnings,
  high travel-time warnings, or child-pricing notes.

Current implementation increment:

- `POST /api/v1/planning/feedback` reuses the stateless planning preview and
  returns structured advisory findings for missing data, budget fit, arrival
  verification, route quality, pacing, activity load, and kid-friendly flags.
  It does not infer child prices or compare unrequested route alternatives.
- The request/response contract and review thresholds are in
  `docs/itinerary_feedback.md`; focused tests are in
  `tests/test_phase15f_itinerary_feedback.py`.
- The traveler app now reviews these findings before saving a generated option
  in either chat planning UI. Its dialog tests cover acknowledgment, required
  findings, failed checks, child choice, and a narrow mobile layout.

### Phase 15G: Capstone Diagram And Objective Alignment

Purpose: keep the manuscript and diagrams aligned with the implemented backend.

Scope:

- Update the use case diagram with specific backend functions.
- Correct the data flow diagram by treating group member as a user role or
  internal trip membership record, not as a separate external entity.
- Rephrase objectives so they are concise, clear, and technically accurate.

Done when:

- Capstone documentation can explain the system without overstating unfinished
  features.

### Phase 15H: Live Position On Route Map

Purpose: show the traveler's moving position on the route map while the map
screen is open, and refresh the route when they leave it.

Plan: [live_tracking_plan_2026-11-07.md](live_tracking_plan_2026-11-07.md)
(Stages 1–2). Stage 1 was approved on 7 November 2026; Stage 2 needs separate
approval. Background tracking (plan Stage 3) and live replanning (plan Stage 4,
proposal Step 9) are not part of this phase. Sharing a traveler's live location
with other people is out of scope.

Scope:

- Foreground GPS on the traveler map screen with a moving position marker,
  accuracy circle, and follow-me camera.
- Remaining distance and time along the returned route line.
- Off-route detection with a limited automatic route refresh.
- Arrival notice, labeled "near" when only an attraction pin is known.
- Clear weak, stale, denied, offline, and estimated states.
- Backend: per-user limit on `POST /api/v1/routes/preview` and
  `/routes/optimize` (`ROUTE_REQUESTS_PER_MINUTE`, default 10).

Done when:

- The position updates within about 5 seconds of movement while the map screen
  is open, and GPS stops when it closes.
- Leaving the route refreshes it at most once per minute.
- No position is stored or shared by the backend; no schema change is made.

### Phase 15I: Personalized Top 5 Weighted Scoring

Purpose: base the Top 5 on the traveler's interests, start point, travel mode,
budget, party, and trip length, as the panel and adviser asked.

Scope: [top5_weighted_scoring_scope_2026-11-10.md](top5_weighted_scoring_scope_2026-11-10.md),
approved on 10 November 2026 with its four recommended decisions.

- A weighted scoring model (Simple Additive Weighting) in
  `app/features/recommendations/scoring.py`: interest 0.35, travel 0.25,
  budget 0.20, group fit 0.10, popularity 0.10.
- `POST /api/v1/recommendations/top-places` with a 0–100 score, factor
  breakdown, reasons, and labels for how travel time and cost were measured.
- One OSRM Table request for travel times; Haversine fallback.
- Verified road routes fill the list first; approximate places fill the rest
  with a label.
- Planning chat uses the same ranking.
- `POST /api/v1/recommendations` and Phase 15B grouping are unchanged; no
  schema change.

Implemented on 10 November 2026; see `docs/recommendations.md`. The traveler
app's Top 5 entry points were switched to the new endpoint the same day, with
travel labels and the factor breakdown
([scope](top5_app_button_scope_2026-11-10.md)).

## Suggested MVP Boundary

The first usable MVP should include:

- Phase 0: Project Foundation.
- Phase 1: Authentication And Users.
- Phase 2: Destination Data Foundation.
- Phase 3: Preferences And Recommendation Signals.
- Phase 4: Budget Engine.
- Phase 5: AI Itinerary Generation.
- Phase 6: Route Optimization.
- Phase 7: Trip Management.

Group collaboration, expenses, photos, reports, and reviews can follow after the
individual trip planning flow is working.

## Approval Checkpoints

Ask the user before starting each implementation phase.

For every phase, confirm:

- Which tables/models will be created or changed.
- Which endpoints will be added.
- Which environment variables are needed.
- Whether a migration should be generated.
- Whether test files should be added in the same phase.

No phase should move from planning to implementation without explicit user
permission.
