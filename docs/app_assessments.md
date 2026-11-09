# Completed-Trip Mobile App Assessment

This feature collects traveler-reported app quality separately from the existing
trip and destination reviews. The six statements are informed by selected
ISO/IEC 25010:2023 product-quality characteristics. Their ratings measure user
perception; they do not prove technical performance, security, or ISO conformity.

## Flow and permissions

1. A trip manager marks the trip `completed` through the existing trip update
   endpoint. A past end date alone does not make an assessment eligible.
2. Each active trip member can submit one app assessment for that trip. A unique
   database constraint also rejects simultaneous duplicate requests.
3. A member can view only their own assessment. Other trip members do not see it.
4. An active admin can view summary measures and paginated responses. Admin
   responses omit user IDs, trip IDs, names, and emails. Free-text comments can
   still contain information voluntarily entered by travelers.

The first version is submit-once. Changing or withdrawing a response would need
an explicit follow-up workflow; the client does not imply that answers are
editable.

## Traveler endpoints

```text
GET  /api/v1/trips/{trip_id}/app-assessment/me
POST /api/v1/trips/{trip_id}/app-assessment
```

`GET /me` returns `{"assessment": null}` when the current member has not
submitted. Unknown trips, outsiders, and removed members receive 404. Creation
requires `status=completed`; a planned or ongoing trip receives 400. A duplicate
receives 409.

The POST body must contain all six rating keys. Each value is an integer from 1
to 5 or `null` for not applicable. At least one rating must be numeric. `comment`
(up to 2,000 characters) and `app_version` (up to 32 characters) are optional.

```json
{
  "functional_suitability_rating": 5,
  "information_accuracy_rating": 4,
  "performance_rating": 3,
  "interaction_rating": 4,
  "reliability_rating": 5,
  "sharing_clarity_rating": null,
  "comment": "The route view helped during the trip."
}
```

| Field | Traveler statement | Interpretation |
| --- | --- | --- |
| `functional_suitability_rating` | Lakbay had the tools I needed to plan and follow this trip. | Perceived functional suitability |
| `information_accuracy_rating` | The itinerary and cost information was useful for my actual trip. | Perceived functional suitability and information usefulness |
| `performance_rating` | Screens and trip details loaded quickly enough when I needed them. | Perceived performance efficiency |
| `interaction_rating` | I could find and understand the trip information I needed. | Perceived interaction capability |
| `reliability_rating` | The app worked reliably throughout my trip. | Perceived reliability |
| `sharing_clarity_rating` | I understood who could see my shared trip information. | Perceived control and clarity, not a security audit |

The response includes the submitted values, `app_assessment_id`, `trip_id`,
`question_version=1`, and `submitted_at`.

## Admin endpoints

```text
GET /api/v1/evaluation/app-assessments/summary?window_days=30
GET /api/v1/evaluation/app-assessments?window_days=30&limit=50&offset=0
```

`window_days` accepts 1–365. Summary returns `response_count`, distinct
`participant_count`, and for each question its answered count, not-applicable
count, mean of answered ratings, and counts for each score 1–5. An empty sample
has a null mean. The list is newest first, paginated to at most 100, and includes
the six answers, optional comment and app version, question version, and
submission timestamp. Both endpoints use `require_admin`.

If the same traveler assesses multiple trips, they contribute multiple responses
but count as one distinct participant within the selected window. Study reports
should state both denominators and the selected window. The existing Phase 14
operational metrics and Phase 12 trip reviews remain separate.

## Database and verification

Migration `2026_11_09_0900` adds only `app_assessments`; it does not alter the
existing `trips` or `trip_reviews` tables. On 9 November 2026, its upgrade and
downgrade passed against an isolated local PostgreSQL 18 database, including
constraint and authenticated API checks. The configured Neon database was
verified at `2026_11_04_0800` with no assessment table before the migration;
`alembic upgrade 2026_11_09_0900` then succeeded, and a read-only check confirmed
the table and new revision. This is not a full-chain rehearsal because local
PostgreSQL lacks PostGIS, which an older migration requires.

The opt-in PostgreSQL test is
`tests/test_app_assessments_postgres.py`. It requires a dedicated disposable
database named `lakbay_assessment_rehearsal` on `localhost` or `127.0.0.1`:

```powershell
$env:LAKBAY_ASSESSMENT_TEST_DATABASE_URL = 'postgresql+asyncpg://USER@127.0.0.1:PORT/lakbay_assessment_rehearsal'
.\.venv\Scripts\python.exe -m pytest tests/test_app_assessments_postgres.py -q
```

The test creates only the prerequisite user and trip tables, applies the
assessment migration directly, exercises the API, then runs the migration's
downgrade. Use a fresh dedicated database for each run.

Run `python -m pytest tests/test_app_assessments.py -q` in the backend virtual
environment. The tests cover completed status, membership, privacy, duplicate
protection, validation, admin authorization, and not-applicable accounting.
