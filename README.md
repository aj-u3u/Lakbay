# Lakbay Backend

Backend API for the Lakbay Flutter travel planning app for the Davao Region.

## Stack

- FastAPI
- SQLAlchemy
- Alembic
- Neon Postgres
- PostGIS through GeoAlchemy2
- JWT authentication

## Setup

Create and activate a virtual environment:

```bash
python -m venv .venv
.venv\Scripts\activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Create your environment file:

```bash
copy .env.example .env
```

Set at least these values in `.env`:

```env
DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST/DATABASE?ssl=require
JWT_SECRET_KEY=change-this
ADMIN_REGISTRATION_CODE=change-this
```

## Database

Run migrations:

```bash
alembic upgrade head
```

Confirm the current revision:

```bash
alembic current
```

Load starter destination data after the tables exist:

```bash
python -m app.seeds.davao_destinations
```

## Run The API

```bash
uvicorn app.main:app --reload
```

Open:

```text
http://127.0.0.1:8000/docs
```

For the admin browser and Android client setup, see
[`docs/client_integration.md`](docs/client_integration.md).

## Current Endpoint Groups

Phase 14 evaluation (admin only):

```text
GET /api/v1/evaluation/summary?window_days=30
```

See [`docs/phase14_evaluation.md`](docs/phase14_evaluation.md) for metric
definitions and verification limits.

Pre-trip feedback:

```text
POST /api/v1/planning/feedback
```

See [`docs/itinerary_feedback.md`](docs/itinerary_feedback.md) for advisory
findings and review thresholds.

Authentication and users:

```text
POST /api/v1/auth/register
POST /api/v1/auth/register/admin
POST /api/v1/auth/login
POST /api/v1/auth/refresh
POST /api/v1/auth/logout
GET  /api/v1/users/me
PATCH /api/v1/users/me
```

Destination data:

```text
GET    /api/v1/destinations
GET    /api/v1/destinations/{destination_id}
POST   /api/v1/destinations
PATCH  /api/v1/destinations/{destination_id}
DELETE /api/v1/destinations/{destination_id}
```

`GET /api/v1/destinations` supports filters plus `limit` and `offset`
pagination. The default limit is `50`, and the maximum limit is `100`.

Accommodation and transportation data:

```text
GET    /api/v1/destinations/{destination_id}/accommodations
POST   /api/v1/destinations/{destination_id}/accommodations
PATCH  /api/v1/accommodations/{accommodation_id}
DELETE /api/v1/accommodations/{accommodation_id}

GET    /api/v1/destinations/{destination_id}/transportations
POST   /api/v1/destinations/{destination_id}/transportations
PATCH  /api/v1/transportations/{transportation_id}
DELETE /api/v1/transportations/{transportation_id}
```

Recommendations:

```text
POST /api/v1/recommendations
GET  /api/v1/recommendations/preferences/latest
POST /api/v1/destinations/{destination_id}/interactions
GET  /api/v1/destinations/{destination_id}/popularity
```

Budget estimates:

```text
POST /api/v1/budgets/estimate
```

Routes:

```text
POST /api/v1/routes/preview
POST /api/v1/routes/optimize
```

Geo-analytics destination grouping:

```text
POST /api/v1/geo-analytics/destination-groups
```

Trips:

```text
POST   /api/v1/trips
GET    /api/v1/trips
GET    /api/v1/trips/{trip_id}
PATCH  /api/v1/trips/{trip_id}
DELETE /api/v1/trips/{trip_id}
POST   /api/v1/trips/{trip_id}/archive
POST   /api/v1/trips/{trip_id}/route
GET    /api/v1/trips/{trip_id}/route
```

AI itinerary drafts:

```text
POST /api/v1/ai/itineraries/generate
```

Admin-only endpoints require an admin bearer token.

## Tests

Run everything:

```bash
python -m pytest -q
```

Run Phase 2 destination tests only:

```bash
python -m pytest tests/test_phase2_destination_data.py -q
```

Run Phase 4 budget tests only:

```bash
python -m pytest tests/test_phase4_budget_engine.py -q
```

Run Phase 5 AI itinerary tests only:

```bash
python -m pytest tests/test_phase5_ai_itineraries.py -q
```

Run Phase 6 route tests only:

```bash
python -m pytest tests/test_phase6_routes.py -q
```

Run Phase 15B grouping tests only:

```bash
python -m pytest tests/test_phase15b_geo_analytics.py -q
```

Run Phase 7 trip tests only:

```bash
python -m pytest tests/test_phase7_trips.py -q
```

## Project Guides

- `AGENTS.md`: rules for Codex and contributors.
- `docs/core_focus.md`: phase-by-phase build plan.
- `docs/manual.md`: prompting and workflow manual for developers.
- `docs/migrations.md`: Alembic migration procedure.
- `docs/auth.md`: Phase 1 auth guide.
- `docs/destinations.md`: Phase 2 destination API and seed guide.
- `docs/recommendations.md`: Phase 3 recommendation API guide.
- `docs/budgets.md`: Phase 4 budget estimate API guide.
- `docs/ai_itineraries.md`: Phase 5 AI itinerary guide.
- `docs/routing.md`: Phase 6 route preview and optimization guide.
- `docs/trips.md`: Phase 7 trip management guide.
- `docs/geo_analytics.md`: Phase 15B grouping API and later geo-analytics plan.
- `docs/new_feature.md`: template for reviewing new feature ideas.
