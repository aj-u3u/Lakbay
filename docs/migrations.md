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
