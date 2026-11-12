# Reviews And Feedback API Guide

This guide covers Phase 12: Reviews And Feedback.

Phase 12 lets active trip members submit post-trip feedback for completed trips.
Reviews can be attached to the whole trip or optionally to one destination that
belongs to the trip.

## Endpoints

```text
POST   /api/v1/trips/{trip_id}/reviews
GET    /api/v1/trips/{trip_id}/reviews
GET    /api/v1/trips/{trip_id}/reviews/summary
GET    /api/v1/trips/{trip_id}/reviews/{review_id}
PATCH  /api/v1/trips/{trip_id}/reviews/{review_id}
DELETE /api/v1/trips/{trip_id}/reviews/{review_id}
```

All endpoints require a bearer access token.

## Migration

Phase 12 adds:

```text
0011_trip_reviews
0012_review_integrity
```

After receiving the Phase 12 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0012_review_integrity (head)
```

## Review Rules

- The trip must have `status = completed` before a member can create, update, or
  delete a review.
- Active trip members can list and view active reviews.
- Removed members and outsiders cannot access reviews.
- The review author can update or delete their own review.
- Delete is a soft delete with `status = deleted`.
- Soft-deleted reviews are hidden from normal lists and summary averages.

## Duplicate Rules

Each active user can have:

- one active trip-level review per trip.
- one active destination-level review per trip destination.

If a review is soft-deleted, the user can submit another active review for the
same trip or destination.

## Ratings

Each rating is required and must be between `1` and `5`:

```json
{
  "post_trip_rating": 5,
  "accuracy_rating": 4,
  "route_efficiency_rating": 5,
  "budget_adherence_rating": 4,
  "overall_experience_rating": 5,
  "comments": "The route and budget estimate were useful."
}
```

Optional `destination_id` must belong to the trip:

```json
{
  "destination_id": 1,
  "post_trip_rating": 5,
  "accuracy_rating": 5,
  "route_efficiency_rating": 4,
  "budget_adherence_rating": 4,
  "overall_experience_rating": 5
}
```

## Summary

The summary endpoint returns review count and average ratings for trip-level
reviews only. Destination-level reviews remain available in the review list, but
they are not mixed into the whole-trip averages so one user cannot overweight
the trip summary by reviewing many destinations.

```json
{
  "trip_id": 1,
  "review_count": 2,
  "average_post_trip_rating": "4.50",
  "average_accuracy_rating": "4.00",
  "average_route_efficiency_rating": "4.50",
  "average_budget_adherence_rating": "3.50",
  "average_overall_experience_rating": "4.50"
}
```

These averages support later ISO/IEC 25010-style evaluation in Phase 14.

## Testing

Run the Phase 12 tests:

```bash
python -m pytest tests/test_phase12_reviews.py -q
```

Then run the full test suite:

```bash
python -m pytest -q
```
