# Provider usage implementation review — 3 November 2026

Scope: Phase 14 usage hardening for the existing OpenWeather, Groq, and
Cloudinary integrations. No database models, migrations, or credentials were
changed. The follow-up stages made four read-only live provider requests.

## Increment 1 — OpenWeather

Implemented a successful-response cache for current weather and forecasts,
plus a process-wide outbound-call limit. Both local and provider HTTP 429
responses include `Retry-After`. Uncached forecasts still make two calls.

Review: the new weather tests verify cache hits, call counting on cache misses,
and provider 429 handling. No failed response is cached. The cache and limit
reset when the worker restarts, and simultaneous cache misses may use multiple
allowed calls.

## Increment 2 — Groq

Implemented per-user AI-attempt and per-model outbound-attempt limits. A
comparison consumes one user slot per selected model. Groq HTTP 429 stops
immediately instead of triggering the configured automatic retry, and the
retry interval is sent to the API caller. Existing generation-run records
continue to capture tokens returned by Groq.

Review: new tests verify pre-call model rejection, no immediate retry after a
provider 429, and per-user rejection. Existing AI itinerary and planning-chat
tests passed. Request counts do not guarantee Groq token quotas; those still
require account-limit monitoring or a later shared token budget.

## Increment 3 — Cloudinary

Implemented atomic per-user and app-wide daily upload-attempt limits after
authorization and image validation and before Cloudinary is called.

Review: a new memory endpoint test verifies the second valid upload returns
429 with `Retry-After` and the fake storage client receives only one call.
Existing memory tests passed after the test client was made independent of the
real `.env` Cloudinary cloud name. The counters measure valid upload attempts,
not storage, transformations, or bandwidth credits.

## Verification and remaining work

- Focused guard concurrency tests passed: 2/2. The shared-process limiter
  accepted exactly five of 50 simultaneous reservations with a limit of five.
- Full suite passed: **427 tests**, with 52 pre-existing dependency/deprecation
  warnings, on 3 November 2026.
- `git diff --check` reported no whitespace errors. Existing user edits in
  route schema/tests and unrelated untracked files were left untouched.
- The initial automated tests used mocked providers and spent no live usage.

Those initial guards were process-local. The following stages add an optional
shared store and operator tools without changing the database schema.

## Follow-up stage 1 — provider visibility

Added `scripts/check_provider_usage.py --live`. Its mocked tests passed 2/2 and
confirm that status and quota output contains no API keys. A controlled live
run returned HTTP 200 for Groq's model list, both OpenWeather endpoints, and
Cloudinary usage. All four configured Groq model roles checked were listed.
Cloudinary reported 0.0 of 25.0 credits used, with its data last updated on
2 November 2026. That usage report is periodically updated, not a real-time
hard spending authorization. The command warns when a reported percentage
reaches 80%.

## Follow-up stage 2 — shared guards and rolling request budgets

Added optional Redis-backed atomic counters and a shared weather cache using
`PROVIDER_USAGE_REDIS_URL`. Redis is not configured in this workspace; local
single-worker behavior remains active. Four Redis tests using two simulated
clients verify shared limits, shared cache, atomic multi-rule rejection, and
fail-closed behavior. Local guard tests still pass. An unreachable configured
Redis store returns HTTP 503 instead of bypassing provider limits.

Added a rolling 30-day OpenWeather call budget and a rolling daily Groq
per-model request budget, with conservative defaults. Focused tests verify both
reject a call before it reaches the provider. These application windows may not
match the provider's billing reset calendar. No live Redis server was available
for an end-to-end multiworker test.

## Follow-up stage 3 — reviewed photo cleanup

Added a single-memory cleanup command. Preview mode checks a soft-deleted
record, its trip-specific Lakbay public-ID prefix, and absence of active memory
references. Purge mode requires the exact public ID and requests one Cloudinary
image deletion with CDN invalidation. Three new tests cover candidate rejection,
confirmation, and the mocked SDK call. The existing memory tests passed. No
live asset was deleted or modified.

## Final verification and limits

- Full suite passed: **438 tests**, with 52 dependency/deprecation warnings,
  on 3 November 2026.
- `git diff --check` found no whitespace errors. Existing user edits in route
  schema/tests and unrelated untracked files were left untouched.
- Groq token-per-minute/day limits are still enforced by Groq, rather than a
  local token reservation. The model-list check did not return quota headers;
  use Groq's Limits page for exact account limits. Cloudinary credits are
  monitored, not hard-capped, because its usage data can lag.
- Production use with multiple workers requires a configured Redis service and
  a live multiworker smoke test. See [the operational guide](../provider_usage.md).
