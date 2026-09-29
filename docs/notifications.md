# Notifications API Guide

This guide covers Phase 13: Notifications.

Phase 13 adds in-app notifications for trip collaboration events. It does not
send email, SMS, or push notifications yet.

## Endpoints

```text
GET    /api/v1/notifications
GET    /api/v1/notifications/unread-count
PATCH  /api/v1/notifications/{notification_id}/read
PATCH  /api/v1/notifications/read-all
DELETE /api/v1/notifications/{notification_id}
```

All endpoints require a bearer access token.

## Migration

Phase 13 adds:

```text
0013_notifications
```

After receiving the Phase 13 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0013_notifications (head)
```

## Event Types

The backend creates notifications for:

```text
trip_member_added
task_assigned
task_updated
expense_created
expense_updated
expense_voided
trip_updated
trip_route_updated
```

Notifications are scoped to the recipient user. Users cannot read or delete
another user's notifications.

Display names such as `actor_full_name` and `trip_title` are snapshotted in
notification metadata when the notification is created. This keeps old
notifications readable without exposing later trip title or actor name changes to
removed trip members.

## Listing Notifications

```bash
GET /api/v1/notifications?limit=20&offset=0
```

Optional filters:

```text
unread_only=true
event_type=task_assigned
trip_id=1
```

Example response:

```json
[
  {
    "notification_id": 1,
    "recipient_user_id": 5,
    "actor_user_id": 2,
    "actor_full_name": "Juan Dela Cruz",
    "trip_id": 10,
    "trip_title": "Davao Weekend Trip",
    "event_type": "task_assigned",
    "title": "New task assigned",
    "message": "Juan Dela Cruz assigned you a task: Book van rental.",
    "entity_type": "trip_task",
    "entity_id": 7,
    "metadata": {
      "actor_full_name": "Juan Dela Cruz",
      "trip_title": "Davao Weekend Trip",
      "trip_task_id": 7,
      "task_title": "Book van rental",
      "status": "pending"
    },
    "is_read": false,
    "read_at": null,
    "status": "active",
    "created_at": "2026-09-22T10:30:00Z",
    "updated_at": "2026-09-22T10:30:00Z"
  }
]
```

## Read State

Unread notifications have:

```json
{
  "is_read": false,
  "read_at": null
}
```

Marking one notification as read is idempotent:

```bash
PATCH /api/v1/notifications/1/read
```

Marking all notifications as read:

```bash
PATCH /api/v1/notifications/read-all
```

Example response:

```json
{
  "updated_count": 3,
  "unread_count": 0
}
```

## Delete Behavior

Delete is a soft delete:

```bash
DELETE /api/v1/notifications/1
```

Deleted notifications are stored with `status=deleted` and hidden from normal
lists and unread counts.

## Testing

Run the Phase 13 tests:

```bash
python -m pytest tests/test_phase13_notifications.py -q
```

Then run the related regression tests:

```bash
python -m pytest tests/test_phase7_trips.py tests/test_phase8_group_collaboration.py tests/test_phase9_expenses.py tests/test_phase13_notifications.py -q
```

Then run the full test suite:

```bash
python -m pytest -q
```
