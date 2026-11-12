# Expenses And Shared Costing API Guide

This guide covers Phase 9: Expenses And Shared Costing.

Phase 9 records actual trip spending and calculates equal shared costs between
active trip members. Child-aware or weighted costing is intentionally deferred to
a later Phase 9.5 enhancement. The current implementation stores
`split_method = "equal"` so the API contract can expand later without changing
the basic expense flow.

## Endpoints

```text
GET    /api/v1/trips/{trip_id}/expenses
POST   /api/v1/trips/{trip_id}/expenses
GET    /api/v1/trips/{trip_id}/expenses/summary
GET    /api/v1/trips/{trip_id}/expenses/{expense_id}
PATCH  /api/v1/trips/{trip_id}/expenses/{expense_id}
DELETE /api/v1/trips/{trip_id}/expenses/{expense_id}
```

All endpoints require a bearer access token.

## Migration

Phase 9 adds expense tables, so a migration is required:

```text
0008_expenses_shared_costing
0009_expense_integrity
```

After receiving the Phase 9 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0009_expense_integrity (head)
```

## Created Tables

```text
trip_expenses
trip_expense_splits
```

## Expense Categories

```text
transportation
accommodation
meals
activities
other
```

## Expense Status

```text
active
voided
```

Voided expenses are kept in the database but excluded from active summaries.

## Split Method

Phase 9 supports:

```text
equal
```

Equal splits divide the expense amount by the active trip members when the
expense is created. If the amount is corrected later, the split is recalculated
across the existing split participants so removed members do not disappear from
historical expense responsibility. If cents do not divide evenly, the leftover
cents are assigned deterministically to the first members by `trip_member_id`.

## Permissions

- Active trip members can view expenses and summaries.
- Active trip members can create expenses paid by themselves.
- Owners and organizers can create expenses paid by any active trip member.
- The creator, owner, or organizer can update or void an active expense.
- Removed members cannot access trip expenses.
- Archived trips are read-only for expenses.

## Create Expense Example

Use `paid_by_trip_member_id` from:

```text
GET /api/v1/trips/{trip_id}/members
```

Request:

```json
{
  "title": "Dinner at Matina",
  "description": "Group dinner",
  "category": "meals",
  "amount": "1200.00",
  "paid_by_trip_member_id": 3,
  "expense_date": "2026-10-10",
  "notes": "Paid in cash",
  "split_method": "equal"
}
```

The response includes generated split rows:

```json
{
  "trip_expense_id": 1,
  "trip_id": 1,
  "paid_by_trip_member_id": 3,
  "paid_by_user_id": 7,
  "paid_by_full_name": "Juan Dela Cruz",
  "paid_by_email": "juan@example.com",
  "created_by_user_id": 7,
  "category": "meals",
  "title": "Dinner at Matina",
  "description": "Group dinner",
  "amount": "1200.00",
  "expense_date": "2026-10-10",
  "split_method": "equal",
  "status": "active",
  "notes": "Paid in cash",
  "splits": [
    {
      "trip_expense_split_id": 1,
      "trip_expense_id": 1,
      "trip_member_id": 3,
      "user_id": 7,
      "full_name": "Juan Dela Cruz",
      "email": "juan@example.com",
      "share_amount": "600.00",
      "created_at": "2026-10-10T12:00:00Z"
    }
  ],
  "created_at": "2026-10-10T12:00:00Z",
  "updated_at": "2026-10-10T12:00:00Z"
}
```

## Summary Example

```json
{
  "trip_id": 1,
  "total_budget": "10000.00",
  "total_spent": "2500.00",
  "remaining_budget": "7500.00",
  "over_budget_amount": "0.00",
  "is_over_budget": false,
  "category_breakdown": [
    {
      "category": "meals",
      "total": "1200.00"
    }
  ],
  "member_balances": [
    {
      "trip_member_id": 3,
      "user_id": 7,
      "full_name": "Juan Dela Cruz",
      "email": "juan@example.com",
      "paid_total": "1200.00",
      "share_total": "600.00",
      "net_balance": "600.00"
    }
  ]
}
```

Positive `net_balance` means the member should receive money. Negative
`net_balance` means the member owes money.

## Deferred Child-Aware Costing

Some travelers may bring children whose activity, food, transportation, or
accommodation costs are free, half price, or full price. That is important, but
it affects budget estimates, AI itinerary planning, trip reports, and expense
sharing. To avoid inconsistent behavior, Phase 9 keeps equal member splits and
defers child-aware weighted costing to a future Phase 9.5.

Recommended future shape:

```text
adult = 1.00 share
child = configurable share such as 0.00, 0.50, or 1.00
```

## Testing

Run the Phase 9 tests:

```bash
python -m pytest tests/test_phase9_expenses.py -q
```

Then run the full test suite:

```bash
python -m pytest -q
```
