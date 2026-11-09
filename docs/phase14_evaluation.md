# Phase 14 Evaluation Summary

Phase 14 adds a read-only, admin-only summary of measures already stored by the
backend. It does not add tables or change the AI, recommendation, or trip
contracts.

## Endpoint

`GET /api/v1/evaluation/summary?window_days=30` requires an active admin access
token. `window_days` defaults to 30 and accepts 1 through 365. The response is
JSON, so an authorized administrator can save it as an evaluation snapshot.
The endpoint returns aggregates only; it does not expose user IDs, emails,
prompts, trip details, or raw provider errors.

The `window_start` and `generated_at` fields are UTC. AI and recommendation
measures count rows created in that inclusive interval. Catalog measures are a
snapshot of currently active destinations at `generated_at`.

| Response section | Meaning |
| --- | --- |
| `ai.attempts`, `succeeded`, `failed` | Model attempts recorded in `ai_generation_runs`; a still-running attempt contributes only to `attempts`. |
| `ai.valid`, `invalid` | Recorded output validation outcomes, including failed attempts when validation ran. |
| `ai.fallback_used` | Attempts marked as fallback runs. |
| `ai.average_response_time_ms` and `by_model` | Mean of recorded non-null attempt latencies, overall and by model role/ID. Null means no latency was recorded. |
| `recommendations.preference_submissions` | Saved recommendation requests, not the number of destinations shown. |
| `recommendations.catalog_*` | Destination view, save, rating, and itinerary-add interactions across the catalog. These actions are not linked to a specific recommendation impression. |
| `recommendations.average_catalog_rating` | Mean of rating interactions in the window; null means no ratings. |
| `catalog.*` | Active destinations, route-ready destinations, and active destinations with unknown estimated cost. |

Do not report the interaction counts or average catalog rating as recommendation
accuracy or conversion. The present schema does not link a recommendation
result to subsequent interactions. Measuring relevance or accuracy requires an
agreed human-labelled sample or an approved exposure/outcome design.

The review ratings in `GET /api/v1/trips/{trip_id}/reviews/summary` can support
a separate post-trip assessment. They are not mixed into this catalog summary.
ISO/IEC 25010 evaluation still requires a study protocol and participant data;
this endpoint supplies operational evidence only.

The separate [mobile app assessment](app_assessments.md) collects six
traveler-reported quality ratings after completed trips. Its admin-only summary
has its own response and participant counts; those survey results are not part
of `GET /api/v1/evaluation/summary`.

## Verification gates

1. Run `python -m pytest -q` for backend regression coverage. The Phase 14
   endpoint tests check anonymous and traveler denial, window validation,
   empty values, admin/traveler catalog flow, and AI attempt aggregation.
2. Run the Alembic offline SQL smoke test in
   `tests/test_phase14_migrations.py`. It checks one migration head and upgrade
   and downgrade SQL generation without connecting to Neon. Apply and reverse
   migrations on disposable Postgres/PostGIS before treating them as live-ready.
3. Confirm the admin and traveler apps use the same API environment. Test an
   admin-created unknown-cost and known-zero destination through traveler
   refresh, filtering, and detail display on a device or emulator.
4. Review provider-dependent scenarios with controlled credentials: Groq
   success/invalid output/fallback, routing provider failure, Cloudinary upload,
   and PDF download. Mark results as simulated or live.
5. Record the evaluation sample and denominator before making percentage claims.
   For example, validation success is `valid / (valid + invalid)` when that
   denominator is nonzero, not `valid / all HTTP 200 responses`.

The aggregate endpoint reads existing tables without a new index. The
`created_at` columns used for time-window filtering do not have dedicated
indexes. Review query plans and latency when the run/interaction
tables grow; any index change requires a reviewed Alembic migration. No live
provider, device, or Postgres migration check is implied by the automated tests.
