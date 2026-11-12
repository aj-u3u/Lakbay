# Group Collaboration API Guide

This guide covers Phase 8: Group Collaboration.

Phase 8 lets a saved trip become a shared planning space. The trip itself is the
group container. Members and collaboration tasks are stored in separate tables.

## Endpoints

```text
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

## Migration

Phase 8 adds collaboration tables, so a migration is required:

```text
0007_group_collaboration
```

After receiving the Phase 8 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0007_group_collaboration (head)
```

## Created Tables

```text
trip_members
trip_tasks
```

The migration backfills one active `owner` member row for each existing trip.

## Roles

```text
owner
organizer
member
```

- `owner`: full control and can archive the trip.
- `organizer`: can manage members, update trip-level details, save routes, and
  manage tasks.
- `member`: can view the shared trip and manage collaboration tasks.

## Member Status

```text
active
removed
```

Removed members lose access to the shared trip. A removed user can be added again
later by the owner or an organizer.

## Add Member Example

The user must already exist in Lakbay.

```json
{
  "email": "friend@example.com",
  "role": "member"
}
```

The API returns the created member record:

```json
{
  "trip_member_id": 2,
  "trip_id": 1,
  "user_id": 4,
  "full_name": "Friend User",
  "email": "friend@example.com",
  "role": "member",
  "status": "active",
  "joined_at": "2026-09-19T12:00:00Z",
  "created_at": "2026-09-19T12:00:00Z",
  "updated_at": "2026-09-19T12:00:00Z"
}
```

## Create Task Example

Use `assigned_trip_member_id` from `GET /api/v1/trips/{trip_id}/members`.

```json
{
  "title": "Book lunch",
  "description": "Find a place near the route.",
  "assigned_trip_member_id": 2,
  "due_date": "2026-10-10"
}
```

Task status values:

```text
pending
ongoing
completed
```

When a task is marked `completed`, the API sets `completed_at`.

## Testing

Run the Phase 8 tests:

```bash
python -m pytest tests/test_phase8_group_collaboration.py -q
```

Then run the full test suite:

```bash
python -m pytest -q
```
