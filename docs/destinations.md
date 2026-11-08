# Destination Data Guide

## Arrival point for routing

`lat` and `lng` identify the attraction for discovery. `arrival_lat` and
`arrival_lng` identify a reviewed visitor gate, parking area, trailhead, or
pier. Admins can set `route_ready=true` only when the arrival pair has an
`arrival_source_url` and `arrival_verified_at`. New destinations default to
`route_ready=false`; do not promote candidate map pins automatically.

Route readiness covers the coordinate used for routing. Check opening status,
required permits or bookings, access mode, and seasonal closures separately
before treating a destination as available to travelers. For islands, route to
a verified pier and model the boat crossing as a separate transport leg.

This document explains the Phase 2 destination, accommodation, and
transportation API in plain terms.

## Purpose

Phase 2 gives Lakbay a clean travel data foundation. Admins can manage Davao
Region destinations, stay options, and transportation estimates. Travelers can
browse active destinations and see available rates.

`estimated_cost=null` means the destination cost is unknown; `0.00` means a
known zero planning estimate. An omitted create value is stored as null.
Budget estimates return `destination_cost_unknown` with the affected IDs when
selected destinations lack a cost. A maximum-cost recommendation filter
excludes unknown-cost destinations; an uncapped discovery request can return
them with `estimated_cost=null`. Group scoring omits unknown-cost destinations
and warns that they were excluded. Admins may update a cost to a sourced
estimate later, or clear it back to null when the prior estimate is unreliable.

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
Each row includes its stable `accommodation_id`, `currency`, and
`charging_unit`. The client should refetch this list when the detail page is
opened or refreshed; deactivated rows no longer appear.

```text
GET /api/v1/destinations/{destination_id}/transportations
```

Returns available transportation options for one active destination.
Each row includes its stable `transportation_id`, `currency`, and
`charging_unit`.

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

Accommodation and transportation rates use **PHP**. Admins choose a charging
unit for each newly entered rate:

| Rate | Allowed `charging_unit` | Meaning |
| --- | --- | --- |
| Accommodation | `per_room_per_night` | One room for one night |
| Accommodation | `per_room_per_stay` | One room for the stated stay |
| Transportation | `per_person` | One passenger on the listed route leg |
| Transportation | `per_vehicle` | One vehicle on the listed route leg |
| Transportation | `per_group` | One group on the listed route leg |

Migration `dfc235ae4bed` adds `currency` and `charging_unit` without
changing any rate IDs. Existing rows receive `currency=PHP` and
`charging_unit=null`; their price basis must be verified by an admin before
being presented as a confirmed unit. The admin editor requires a unit when
saving a rate. API callers should send the same fields. A null unit is exposed
as unverified to older clients and existing records; no client should infer a
unit from the vehicle type or room name.

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

To load only the five independently reviewed public visitor attractions, use
`python -m app.seeds.davao_destinations --curated-only`. This excludes the older
starter batch and adds no accommodation or transportation rates. The evidence,
coordinate provenance, fee limitations, and routing gaps are recorded in
[`davao_curated_visitor_seed_2026-11-01.md`](davao_curated_visitor_seed_2026-11-01.md).

To load only the four discovery-only attractions with unknown costs, use
`python -m app.seeds.davao_destinations --discovery-only` after migration
`95bb71db451f`. The [four-place source and import review](davao_discovery_visitor_seed_2026-11-01.md)
records their approximate coordinates and remaining access work.

To load the separate eight-place Phase 2 coverage batch, use
`python -m app.seeds.davao_destinations --coverage-only` after the same
migration. Its [source review](davao_coverage_completion_seed_2026-11-01.md)
records each attraction point and unresolved visitor rules. The configured
Neon catalog now has five active destinations in each target district.

## Testing

Run the Phase 2 tests:

```bash
python -m pytest tests/test_phase2_destination_data.py -q
```

Run the full suite:

```bash
python -m pytest -q
```

## OSM candidate review queue

The Phase 2 OSM review queue is **admin only**. It stores candidate places separately
from public `destinations`. Staged and rejected candidates are absent from
traveler browse, recommendations, itineraries, and route planning. The source
inventory and first-pass decisions are in
[`davao_region_osm_catalog_review_2026-11-04.md`](davao_region_osm_catalog_review_2026-11-04.md).

Migration `2026_11_04_0800` creates `destination_candidates` with a unique OSM
type/ID, source URL and tag, proposed place pin, review fields, and a link to a
published destination. It does not change the existing `destinations` table.
Review the migration before applying it to the intended database.

Preview the 648 unique visitor candidates from the six province/city inventories:

```bash
python -m scripts.stage_osm_destination_candidates
```

After the migration is applied, stage them once with:

```bash
python -m scripts.stage_osm_destination_candidates --apply
```

The command is idempotent by OSM type and ID. It leaves the 1,261 special cases
and 14 restricted or closed source rows in the review file for separate work.
Staging does **not** publish any place. A repeated run does not overwrite admin
edits or a published candidate.

On 4 November 2026, migration `2026_11_04_0800` was applied to the configured
Neon database and the importer staged 648 unique candidates. A second run
inserted zero rows. Read-back found 648 staged candidates, zero published
candidates, and the original 30 active destinations.

| Admin endpoint | Purpose |
| --- | --- |
| `POST /api/v1/admin/destination-candidates` | Stage one additional reviewed OSM object, including a special case from the audit. The OSM URL must match its type and ID. |
| `GET /api/v1/admin/destination-candidates?review_status=staged&limit=50&offset=0` | List the queue; `review_status` can be `staged`, `rejected`, or `published`. |
| `GET /api/v1/admin/destination-candidates/{candidate_id}` | Read one candidate and its OSM source. |
| `PATCH /api/v1/admin/destination-candidates/{candidate_id}` | Correct name, pin, category, description, activities, fees, hours, visitor purpose, and access evidence. |
| `POST /api/v1/admin/destination-candidates/{candidate_id}/reject` | Reject with `{"reason":"..."}`. |
| `POST /api/v1/admin/destination-candidates/{candidate_id}/publish` | Create one active destination and link it to the reviewed candidate. |

An admin can add verified fees, activities, hours, and description while a
candidate is staged. Unknown values stay null. The suggested OSM category is
only a clue; the admin must confirm `district`, enter a catalog `category`, and
write a `visitor_purpose`
before publishing. Publication also requires `access_policy` (`public`,
`customers`, or `permit`), an HTTP(S) `access_source_url`, and a timezone-aware
`access_verified_at`. The admin should use current operator, government, or
other reliable access evidence. `review_notes` can record remaining questions.
The publish action blocks a nearby catalog place with the same name and links
the new record to its OSM candidate. Admins should still check aliases and
different OSM objects that represent one venue.

Published destinations use the reviewed attraction `lat`/`lng`, with
`route_ready=false` and no arrival coordinates. Their public pin can appear
through the normal destination API. A gate, trailhead, or receiving pier needs
separate verification before turn-by-turn directions are enabled. Later fee or
activity edits use the existing admin `PATCH /api/v1/destinations/{id}` endpoint.
The backend queue has no Flutter admin screen in this change; that client can
use these endpoints when its UI is added.
