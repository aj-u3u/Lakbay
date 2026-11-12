# Trip Management API Guide

This guide covers Phase 7: Trip Management. Phase 8 extends these trip records
with shared members and collaboration tasks.

Phase 7 turns selected destinations, itinerary drafts, budget estimates, and
route summaries into saved trips. After Phase 8, owners and active trip members
can view shared trip information.

## Endpoints

```text
POST   /api/v1/trips
POST   /api/v1/trips/from-ai-option
GET    /api/v1/trips
GET    /api/v1/trips/{trip_id}
PATCH  /api/v1/trips/{trip_id}
DELETE /api/v1/trips/{trip_id}
POST   /api/v1/trips/{trip_id}/archive
POST   /api/v1/trips/{trip_id}/route
GET    /api/v1/trips/{trip_id}/route
GET    /api/v1/trips/{trip_id}/members
POST   /api/v1/trips/{trip_id}/members
PATCH  /api/v1/trips/{trip_id}/members/{member_id}
DELETE /api/v1/trips/{trip_id}/members/{member_id}
GET    /api/v1/trips/{trip_id}/tasks
POST   /api/v1/trips/{trip_id}/tasks
GET    /api/v1/trips/{trip_id}/tasks/{task_id}
PATCH  /api/v1/trips/{trip_id}/tasks/{task_id}
DELETE /api/v1/trips/{trip_id}/tasks/{task_id}
```

All endpoints require a bearer access token.

## Save a selected planning itinerary

After a planning-enabled AI generation response, send:

```json
{"generation_run_id": 42, "option_number": 3, "start_date": null, "end_date": null, "notes": null}
```

Use the actual `selected_generation_run_id` and chosen `option_number` from
the response. The backend loads that user's validated run, then creates the
trip, selected destination and rate references, itinerary days and activities,
the preview's route summary, and its cost snapshot in one transaction. It
rejects missing cost estimates, invalid selections, or a requested route with
no summary. The trip's `estimated_total_cost` comes from the backend preview;
AI activity costs remain draft estimates and are labeled in
`planning_snapshot`. `GET /api/v1/trips/{trip_id}` returns the same snapshot
and route after a server restart. Older trips have `planning_snapshot: null`.

Migration `2026_10_18_0500` adds nullable `trips.planning_snapshot` JSON and
follows `dfc235ae4bed` in the Alembic chain. Review the migration before
applying it to the configured database.

## Access Rule

Trip owners and active trip members can view shared trip details. Owners and
organizers can manage members and update trip-level details. Only the owner can
archive a trip.

If a non-member asks for another user's trip, the API returns
`404 trip_not_found`. This avoids leaking whether another user's trip exists.

## Migration

Phase 7 adds real persistence tables, so a migration is required:

```text
0006_trip_management
```

After receiving the Phase 7 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0006_trip_management (head)
```

## Created Tables

```text
trips
trip_destinations
trip_itinerary_days
trip_itinerary_activities
trip_routes
```

The `trips.status` field supports:

```text
planned
ongoing
completed
archived
```

Delete is a soft delete. `DELETE /api/v1/trips/{trip_id}` marks the trip as
`archived`.

## Create Trip Example

Use real destination IDs from `GET /api/v1/destinations`.

```json
{
  "title": "Davao Weekend Trip",
  "description": "Relaxed two-day trip.",
  "start_date": "2026-10-10",
  "end_date": "2026-10-11",
  "traveler_count": 2,
  "total_budget": "10000.00",
  "estimated_total_cost": "7500.00",
  "destination_ids": [1, 2],
  "notes": "Prefer relaxed pacing.",
  "itinerary_days": [
    {
      "day_number": 1,
      "title": "Arrival and city walk",
      "summary": "Explore nearby spots.",
      "activities": [
        {
          "activity_order": 1,
          "time": "09:00",
          "title": "Visit destination",
          "description": "Walk around the selected destination.",
          "destination_id": 1,
          "accommodation_id": null,
          "transportation_id": null,
          "estimated_cost": "500.00",
          "notes": "Bring water."
        }
      ]
    }
  ]
}
```

Validation rules:

- `destination_ids` must be active destinations.
- Duplicate destination IDs are rejected.
- Activity destination IDs must belong to the trip's selected destinations.
- Accommodation and transportation IDs must exist, be available, and belong to
  selected destinations.
- `end_date` must be on or after `start_date`.
- Day numbers must be unique.
- Activity order values must be unique per day.

## Save Route Example

Use the response from Phase 6 route preview or optimization.

```json
{
  "travel_mode": "driving",
  "route_provider": "osrm",
  "is_estimated": false,
  "total_distance_km": "12.50",
  "total_duration_minutes": 30,
  "stops": [
    {
      "order": 1,
      "destination_id": 1,
      "name": "People's Park",
      "lat": 7.0644,
      "lng": 125.6078,
      "is_origin": false
    }
  ],
  "legs": [],
  "warnings": []
}
```

Route stops can include an origin with `destination_id=null`, but any non-null
destination ID must belong to the trip.

## Testing

Run the Phase 7 tests:

```bash
python -m pytest tests/test_phase7_trips.py -q
```

Run the full suite:

```bash
python -m pytest -q
```
