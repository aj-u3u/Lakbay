# Destination Data Guide

This document explains the Phase 2 destination, accommodation, and
transportation API in plain terms.

## Purpose

Phase 2 gives Lakbay a clean travel data foundation. Admins can manage Davao
Region destinations, stay options, and transportation estimates. Travelers can
browse active destinations and see available rates.

## Public Endpoints

These endpoints are safe for normal Flutter users.

```text
GET /api/v1/destinations
```

Returns active destinations. Use query parameters to filter the catalog:

```text
search
district
category
budget_class
difficulty_level
kid_friendly
wheelchair_accessible
pet_friendly
family_friendly
couple_friendly
group_friendly
limit
offset
```

Pagination defaults:

- `limit=50`
- `offset=0`
- Maximum `limit` is `100`.

```text
GET /api/v1/destinations/{destination_id}
```

Returns one active destination. Inactive destinations are hidden from public
reads.

```text
GET /api/v1/destinations/{destination_id}/accommodations
```

Returns available accommodation options for one active destination.

```text
GET /api/v1/destinations/{destination_id}/transportations
```

Returns available transportation options for one active destination.

## Admin Endpoints

These endpoints require an admin access token.

```text
POST /api/v1/destinations
PATCH /api/v1/destinations/{destination_id}
DELETE /api/v1/destinations/{destination_id}
```

The delete endpoint is a soft delete. It sets `is_active=false` instead of
removing the record.

```text
POST /api/v1/destinations/{destination_id}/accommodations
PATCH /api/v1/accommodations/{accommodation_id}
DELETE /api/v1/accommodations/{accommodation_id}
```

The accommodation delete endpoint marks the record unavailable.

```text
POST /api/v1/destinations/{destination_id}/transportations
PATCH /api/v1/transportations/{transportation_id}
DELETE /api/v1/transportations/{transportation_id}
```

The transportation delete endpoint marks the record unavailable.

## Data Shape Notes

For Phase 2, these fields are intentionally simple text fields:

- `category`
- `vibes`
- `activities`

This keeps data entry easy while the team is still validating the destination
catalog. If the app later needs strict filtering, these can become lookup tables
or tag tables in a later migration.

The destination model stores both:

- `lat` and `lng` for simple API responses and Flutter maps.
- `geom` as a PostGIS `geography(Point,4326)` column for future geo queries.

Money fields use two decimal places and must fit `Numeric(10, 2)`:

- `destinations.estimated_cost`
- `accommodations.price`
- `transportations.price`

The API validates those values before saving, and the database migration adds
basic check constraints for coordinates, costs, capacity, and travel duration.

## Migration

The Phase 2 migration is:

```text
0002_destination_data_foundation
```

It creates:

- `destinations`
- `accommodations`
- `transportations`
- PostGIS extension setup
- destination geospatial index
- database check constraints for key numeric fields

Apply it after reviewing the migration:

```bash
alembic upgrade head
```

Confirm the database revision:

```bash
alembic current
```

## Seed Data

After applying migrations, insert starter Davao destination data:

```bash
python -m app.seeds.davao_destinations
```

The seed script is idempotent by destination name. Running it again skips
destinations that already exist, but still checks for missing accommodation and
transportation seed rows under those destinations.

## Testing

Run the Phase 2 tests:

```bash
python -m pytest tests/test_phase2_destination_data.py -q
```

Run the full suite:

```bash
python -m pytest -q
```
