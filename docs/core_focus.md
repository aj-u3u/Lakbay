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
- Users can browse and filter destinations.

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

Important note:

- Confirm the exact available Groq model IDs before implementation. Some model
  IDs from the proposal may be deprecated depending on the account tier.

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
