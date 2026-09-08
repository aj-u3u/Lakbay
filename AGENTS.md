# Lakbay Backend Agent Guide

This file defines how AI coding agents should work inside the Lakbay backend
project. Treat it as the project operating manual before making any changes.

## Project Summary

Lakbay is the backend API for a Flutter mobile travel planning application for
the Davao Region. The backend will support account management, destination
recommendations, AI-generated itineraries, route optimization, budget tracking,
group trip planning, photo uploads, PDF reports, and post-trip reviews.

The planned stack is:

- FastAPI for the API framework.
- SQLAlchemy for ORM models.
- Alembic for database migrations.
- Neon Postgres as the database.
- PostGIS or latitude/longitude calculations for geoanalytics.
- Groq API for AI itinerary generation and model comparison.
- OSRM for route travel distance and duration.
- JWT authentication for protected endpoints.

## Working Rules

1. Always ask the user for permission before implementing code changes.
2. Documentation-only changes may be made when the user directly requests them.
3. Do not change existing database tables, columns, relationships, or model names
   without explaining the reason and getting approval first.
4. Do not run destructive commands, reset files, delete migrations, or overwrite
   user work unless the user explicitly asks for it.
5. Keep the backend feature-based. Do not move toward a large flat structure.
6. Prefer small, reviewable changes over broad rewrites.
7. Use environment variables for credentials and API keys. Never hard-code
   secrets.
8. Validate AI outputs before saving them to the database.
9. Use Alembic for schema changes. Do not manually edit the database after
   migrations are introduced.
10. Keep Flutter-specific logic out of the backend. The API should expose clean
    request and response contracts for the mobile app.

## Preferred Project Structure

```text
app/
  main.py
  api.py

  core/
    config.py
    database.py
    security.py
    exceptions.py
    dependencies.py

  db/
    base.py
    session.py
    migrations/

  features/
    auth/
      router.py
      schemas.py
      models.py
      service.py
      repository.py

    users/
    destinations/
    rates/
    recommendations/
    ai/
    itineraries/
    routes/
    trips/
    tasks/
    expenses/
    photos/
    reports/
    reviews/
    admin/

  integrations/
    groq/
      client.py
      prompts.py
    osrm/
      client.py
    storage/
      client.py

tests/
```

## Feature Module Pattern

Each feature should usually contain:

- `router.py`: FastAPI endpoints.
- `schemas.py`: Pydantic request and response models.
- `models.py`: SQLAlchemy ORM models.
- `service.py`: business logic.
- `repository.py`: database queries.
- `dependencies.py`: feature-specific dependencies when needed.

Keep business logic out of routers. Routers should parse requests, call services,
and return responses.

## Migration Rules

Use the migration manual at `docs/migrations.md`.

Standard flow:

```bash
alembic revision --autogenerate -m "describe schema change"
alembic upgrade head
```

Before generating a migration:

1. Create or update SQLAlchemy models.
2. Ensure models live under `app/features/*/models.py`.
3. Confirm the model change was approved by the user.
4. Generate the migration.
5. Review the generated migration file manually.
6. Apply the migration only after review.

For an existing Neon database, use `alembic stamp head` only when the database
already matches the migration state.

## Database Planning Notes

The current pasted schema includes:

- users
- destinations
- accommodations
- transportations
- trips
- trip_itineraries
- trip_tasks
- trip_memories
- notifications
- destination_interactions
- destination_popularity
- user_preference_signals
- live_travel_time
- live_weather_cache

Potential improvements to discuss before coding:

- Use consistent singular or plural naming across models.
- Fix spelling from `Accomodations` to `Accommodations` in documentation and
  feature names.
- Replace string-only fields such as `date_range`, `cost`, and `assignee` with
  normalized columns or foreign keys where appropriate.
- Add group membership tables instead of relying only on `is_group` and
  `num_travelers`.
- Add expense tables for actual shared costs and member contributions.
- Add AI generation run tables for model comparison metrics.
- Avoid modeling PostGIS-managed system objects such as `spatial_ref_sys`,
  `geometry_columns`, and `geography_columns`.

## API Design Priorities

Build the API in thin, stable layers:

1. Authentication and users.
2. Admin-managed destinations and rates.
3. Recommendation logic.
4. AI itinerary generation.
5. Route optimization.
6. Trips and group planning.
7. Expenses and analytics.
8. Photos, reports, reviews, and notifications.

## New Feature Review

Use `docs/new_feature.md` when the user proposes a new feature. Every proposed
feature must be compared against the current phase in `docs/core_focus.md`
before implementation.

Codex should respond with a phase alignment review first. If the feature belongs
to a later phase, recommend deferring it or splitting it into a smaller
current-phase version. If no existing phase fits, recommend a clear change to
`docs/core_focus.md`.

Do not implement a new feature until the user approves the reviewed scope.

## Security Expectations

- Use password hashing for stored passwords.
- Use access tokens and refresh tokens.
- Protect all user-owned resources with ownership or membership checks.
- Separate admin-only endpoints from traveler endpoints.
- Apply request validation on every endpoint.
- Rate-limit expensive AI and routing endpoints.
- Validate uploaded files by type, size, and ownership.

## Testing Expectations

Add tests when implementation begins. Prioritize:

- Authentication flows.
- Permission checks.
- Recommendation filtering.
- Budget calculations.
- Route optimization edge cases.
- AI response validation.
- Migration upgrade and downgrade checks.

## Agent Response Style

When proposing implementation:

1. Explain the intended change briefly.
2. Ask for permission before editing code.
3. After approval, make the smallest useful change.
4. Verify the change.
5. Summarize touched files and next steps.

When the user says they are still planning, do not implement backend behavior.
Limit work to analysis, documentation, and clearly requested planning artifacts.
