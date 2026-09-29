# Alembic Migration Manual

This project uses Alembic to manage database schema changes for the FastAPI
backend. Alembic compares SQLAlchemy models against the current Neon Postgres
database and generates migration files.

## One-Time Setup

1. Create and activate a virtual environment.

```bash
python -m venv .venv
.venv\Scripts\activate
```

2. Install dependencies.

```bash
pip install -r requirements.txt
```

3. Create a `.env` file from `.env.example`.

```bash
copy .env.example .env
```

4. Paste your Neon connection string into `DATABASE_URL`.

Use the async SQLAlchemy driver format:

```env
DATABASE_URL=postgresql+asyncpg://USER:PASSWORD@HOST/DATABASE?ssl=require
```

If Neon gives you a `postgresql://` or `postgres://` URL, the app config will
convert it to `postgresql+asyncpg://` at runtime. It also converts
`sslmode=require` to `ssl=require` for `asyncpg`.

## Standard Migration Workflow

Follow this order whenever you add or change database tables.

1. Create or update a SQLAlchemy model.

Example location:

```text
app/features/destinations/models.py
```

Every model must inherit from `app.db.base.Base`.

```python
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Destination(Base):
    __tablename__ = "destinations"

    destination_id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(nullable=False)
```

2. Make sure the model is inside a feature folder.

Alembic automatically imports files that match:

```text
app/features/*/models.py
```

3. Generate a migration.

```bash
alembic revision --autogenerate -m "create destinations table"
```

4. Open the generated file in:

```text
app/db/migrations/versions/
```

5. Review the generated migration before running it.

Check that Alembic did not accidentally drop existing tables, remove important
columns, or generate unwanted changes. Edit the migration file if needed.

6. Apply the migration.

```bash
alembic upgrade head
```

7. Confirm the database is at the latest revision.

```bash
alembic current
```

## Downgrading

To undo the latest migration:

```bash
alembic downgrade -1
```

To return to a specific revision:

```bash
alembic downgrade REVISION_ID
```

Only downgrade in development unless you have a tested production rollback plan.

## Working With An Existing Neon Database

If the Neon database already contains the current Lakbay tables, do not blindly
run a generated "create all tables" migration against it.

Recommended baseline flow:

1. Create SQLAlchemy models that match the current database schema.
2. Generate an initial migration.

```bash
alembic revision --autogenerate -m "baseline existing schema"
```

3. Review the migration carefully.
4. If the database already matches that migration, mark it as applied without
   running the SQL:

```bash
alembic stamp head
```

Use `stamp head` only when the database schema already matches the migration.
For a fresh empty database, use `alembic upgrade head` instead.

For the current Lakbay setup, the team has chosen to use a new Neon database.
That means the first approved migration should normally create the revised
schema from scratch, then be applied with:

```bash
alembic upgrade head
```

## Current Migration Chain

The current approved chain is:

```text
0001_create_auth_tables
a1aa9ddabfe3_update_user_table_added_contact
0002_destination_data_foundation
0003_recommendation_signals
0004_recommendation_stability
0005_ai_generation_runs
0006_trip_management
0007_group_collaboration
0008_expenses_shared_costing
0009_expense_integrity
0010_trip_memories
0011_trip_reviews
0012_review_integrity
0013_notifications
```

For a fresh Neon database, run:

```bash
alembic upgrade head
```

Then confirm:

```bash
alembic current
```

The Phase 2 destination seed data can be loaded after the migration succeeds:

```bash
python -m app.seeds.davao_destinations
```

The seed command should be run only after the destination, accommodation, and
transportation tables exist.

The Phase 3 recommendation migration creates:

- `user_preference_signals`.
- `destination_interactions`.
- `destination_popularity`.

The Phase 3 stabilization migration adds a partial unique index for destination
interactions. A user can record repeated `view` interactions, but can only have
one `save`, one `rate`, and one `add_to_itinerary` signal per destination.

The Phase 5 AI itinerary migration creates:

- `ai_generation_runs`.
- model and prompt metadata.
- response time and token usage fields.
- validation status and error tracking fields.
- input and output summary JSON fields for model comparison review.

Phase 6 route preview and optimization is stateless. It does not add a migration
because route summaries are not saved until the trip management phase.

The Phase 7 trip management migration creates:

- `trips`.
- `trip_destinations`.
- `trip_itinerary_days`.
- `trip_itinerary_activities`.
- `trip_routes`.

Delete/archive behavior is implemented as a status update to `archived`, not a
hard database delete.

The Phase 8 group collaboration migration creates:

- `trip_members`.
- `trip_tasks`.

It also backfills one active `owner` membership row for each existing trip using
`trips.owner_user_id`.

The Phase 9 expenses migrations create:

- `trip_expenses`.
- `trip_expense_splits`.

It stores equal split rows for active trip members and keeps voided expenses in
the database for audit history. The stabilization migration also adds same-trip
integrity constraints so expense payers and split members must belong to the
same trip as the expense.

The Phase 10 memories migration creates:

- `trip_memories`.

It stores Cloudinary image URLs, upload ownership, captions, optional trip
destination links, and soft-delete status for trip memories.

The Phase 12 reviews migrations create and stabilize:

- `trip_reviews`.

It stores completed-trip feedback ratings, optional destination-level review
links, soft-delete status, and partial unique indexes that allow one active
trip-level review and one active destination-level review per user. The
stabilization migration adds same-trip reviewer integrity so the review user
must belong to the same trip as the review.

The Phase 13 notifications migration creates:

- `notifications`.

It stores in-app notification events, recipient and actor links, optional trip
links, entity references, structured metadata, read timestamps, and soft-delete
status.

The Phase 2 destination migration also includes database check constraints for:

- destination latitude and longitude ranges.
- non-negative destination estimated cost.
- non-negative accommodation and transportation prices.
- positive accommodation capacity.
- non-negative transportation duration when provided.

## PostGIS Notes

The current schema draft includes `geography(Point,4326)` and a GiST index. That
requires the PostGIS extension in Postgres.

For the first real migration, add this before creating geospatial columns:

```python
op.execute("CREATE EXTENSION IF NOT EXISTS postgis")
```

Equivalent SQL:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
```

Do not create application models for PostGIS system objects such as
`spatial_ref_sys`, `geometry_columns`, or `geography_columns`. Those are managed
by PostGIS itself.

For SQLAlchemy geospatial columns, use GeoAlchemy2:

```python
from geoalchemy2 import Geography

geom = mapped_column(Geography(geometry_type="POINT", srid=4326))
```

## Useful Commands

```bash
alembic history
alembic current
alembic heads
alembic check
alembic revision -m "manual migration"
alembic revision --autogenerate -m "describe schema change"
alembic upgrade head
alembic downgrade -1
```

## Team Rule

Never edit the production database manually after migrations are introduced.
Schema changes should happen in this order:

1. Update model.
2. Generate migration.
3. Review migration.
4. Test migration locally or on a development Neon branch.
5. Apply with `alembic upgrade head`.
