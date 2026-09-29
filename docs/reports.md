# Reports API Guide

This guide covers Phase 11: Reports.

Phase 11 generates on-demand trip reports from existing trip, route, itinerary,
expense, and member data. It does not create report tables.

## Endpoints

```text
GET /api/v1/trips/{trip_id}/reports/summary
GET /api/v1/trips/{trip_id}/reports/pdf
```

All endpoints require a bearer access token.

## Report Summary

The summary endpoint returns JSON containing:

- Trip overview.
- Destinations.
- Itinerary days and activities.
- Saved route summary, when available.
- Expense totals, category breakdown, and member balances.
- Trip members.

Use this endpoint in Flutter when you want to preview report data before
downloading the PDF.

## PDF Download

The PDF endpoint returns:

```text
Content-Type: application/pdf
Content-Disposition: attachment; filename="lakbay-trip-{trip_id}-report.pdf"
```

The PDF is generated when requested. It is not stored in the database.

## Permissions

- Active trip members can generate reports.
- Removed members and outsiders cannot access reports.
- Archived trips remain readable, so reports can still be generated.

## Migration

Phase 11 does not add a table and does not need an Alembic migration.

## Testing

Run the Phase 11 tests:

```bash
python -m pytest tests/test_phase11_reports.py -q
```

Then run the full test suite:

```bash
python -m pytest -q
```
