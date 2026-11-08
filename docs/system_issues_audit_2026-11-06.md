# System issues audit — 6 November 2026

Scope: read-only checks of the backend checkout, the Neon database, the deployed
Render API and the Render environment screenshot supplied by the user. No
application code, database rows or deployed settings were changed during this
audit. Tick each box when the fix is done and verified.

## Healthy at time of audit

| Check | Result |
| --- | --- |
| Local test suite | 455 passed, 53 deprecation warnings (`python -m pytest -q`, 6 min 53 s) |
| Neon migration | `alembic current` = `alembic heads` = `2026_11_04_0800` |
| Committed secrets | None found; README, `alembic.ini` and `docs/migrations.md` contain placeholders only |
| Editor diagnostics | No errors in files VS Code had analyzed |
| Groq models | `qwen/qwen3.8-27b`, `openai/gpt-oss-120b` and `openai/gpt-oss-20b` exist on Groq; local key is valid |
| Deployed AI chat | Responds after `GROQ_MODEL_DEFAULT` was added on Render (the earlier 503 `ai_model_not_configured` is resolved) |

## Priority 1 — security

- [ ] **Rotate the Groq API key.** The full `GROQ_API_KEY` value was visible in a
  Render screenshot. Create a new key in the Groq console, delete the old key,
  then update Render and the local `.env`.
- [ ] **Confirm `DEBUG=false` on Render.** `app/main.py` passes `settings.debug`
  to FastAPI; with `true`, unhandled errors return stack traces. The Render
  value was hidden in the screenshot. `.env.example` has `DEBUG=true`, which is
  correct only for local use.

## Priority 2 — broken or limited features on the deployed app

- [ ] **Weather returns 503.** `OPENWEATHER_API_KEY` is absent from the Render
  environment list. Add `OPENWEATHER_API_KEY`, `OPENWEATHER_BASE_URL`,
  `OPENWEATHER_UNITS` and `OPENWEATHER_LANG`.
- [ ] **Photo uploads will fail.** No `CLOUDINARY_*` variables are on Render. Add
  `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` and
  `CLOUDINARY_UPLOAD_FOLDER`.
- [ ] **Optional AI model comparison is not configured on Render.** If used, add
  `AI_MODEL_COMPARISON_ENABLED` and `GROQ_MODEL_COMPARE_A/B/C` (without the
  leading space present in the local `.env` values).
- [ ] **Planner recommends no destinations.** Neon has 30 active destinations and
  0 with a verified arrival point (`route_ready`, arrival coordinates, source
  URL and verification time). `rank_planning_candidates` in
  `app/features/recommendations/service.py` therefore returns the message
  "No verified road candidates qualify…", and `app/features/ai/service.py`
  (lines 936–938) replaces the AI reply with it. The same gap means routes end
  at attraction pins and turn-by-turn steps are suppressed.
  - Data fix: record verified entrances using
    [lakbay_manual_arrival_checklist.md](lakbay_manual_arrival_checklist.md)
    (all items unchecked).
  - Code options awaiting a decision: recommend unverified places with an
    "approximate location" warning, or keep the AI reply and show the shortfall
    as a separate note.
  - Even with arrival points, a recommendation also needs a map-selected origin
    and a single driving or walking mode.
- [ ] **Walking routes are straight-line estimates only.** `OSRM_WALKING_BASE_URL`
  is not configured, and the public OSRM host does not serve a distinct foot
  network. Walking returns a labeled Haversine estimate until a real
  foot-profile service is configured.
- [ ] **Destination images.** 29 of 30 active destinations have no `image_url`.
  The only stored URL (destination 7, Panabo City Parks and Plaza) is
  malformed: it ends in `.../800px-Panabo_City_Hall` without `.jpg`, which
  explains the image 400 error seen in the browser.

## Priority 3 — repository and deployment hygiene

- [ ] **Local `main` is 3 commits behind `origin/main` (what Render deploys).**
  Missing locally: `e08141f` (candidate queue), `5e6a2f0` (walking service
  guard) and `f28e9c2` (fixed road route for single-destination trips).
  - Identical to GitHub but untracked locally: the candidate migration, the
    four `candidate_*` files, the staging script, candidate tests and the two
    OSM catalog review files. `git pull` will refuse to overwrite them.
  - Different from GitHub: `app/features/routes/service.py` (lacks the
    `f28e9c2` fix), `app/core/config.py`, `.env.example`,
    `tests/test_phase6_routes.py` and `docs/routing.md`. These need a careful
    merge, not a reset.
- [ ] **Uncommitted local work.** 33 modified tracked files plus new modules such
  as `app/core/provider_usage.py`, `app/integrations/groq/itinerary_schema.py`
  and provider-usage tests. None of it is deployed. Commit in small reviewed
  increments.
- [ ] **Untracked output clutter.** `outputs/` (4,477 Groq experiment files,
  about 736 KB) and `test_output.txt` are not in `.gitignore`.
- [ ] **Render cold start.** The free instance sleeps; a request on 6 November
  took about 44 s to wake it. Client requests can time out on the first call
  after idle. Options: paid instance, scheduled keep-alive, or longer client
  timeouts.
- [ ] **No build identifier.** `GET /api/v1/health` has no commit SHA, so a
  healthy response cannot confirm which revision Render is running.

## Priority 4 — low

- [ ] Replace deprecated `HTTP_422_UNPROCESSABLE_ENTITY` with
  `HTTP_422_UNPROCESSABLE_CONTENT` in `app/core/exceptions.py:88` and
  `app/features/budgets/service.py:58`.
- [ ] Add `path_separator = os` to `alembic.ini` to clear the Alembic
  deprecation warning.
- [ ] Production uses the public OSRM demo host (`router.project-osrm.org`),
  which is rate-limited and has no service guarantee.
- [ ] Documentation drift: `docs/client_integration.md` names an older migration
  head; `docs/routing.md` and `docs/ai_itineraries.md` retain older statements.
- [ ] Confirm the Render `CORS_ALLOWED_ORIGINS` value lists explicit origins
  rather than `*` (value hidden in the screenshot).

## Not checked in this audit

The traveler (`UI_FOR_LAKBAY`) and admin (`FINAL_ADMINLAKBAY`) Flutter
repositories were not inspected. Earlier notes in
[step0_readiness_audit_2026-11-05.md](step0_readiness_audit_2026-11-05.md) and
`PROJECT_CONTEXT.md` report unpushed traveler route-card edits, UI copy that
still mentions "Gemini", and offline-storage claims that overstate current
behavior.

## How the Render findings were derived

The Render environment list in the screenshot appeared alphabetical and showed
`ADMIN_REGISTRATION_CODE`, `APP_ENV`, `CORS_ALLOWED_ORIGINS`, `DATABASE_URL`,
`DEBUG`, `GROQ_API_KEY`, `JWT_SECRET_KEY` and `OSRM_BASE_URL`. Variables that
would sort between those names were treated as absent. Variables sorting after
`OSRM_BASE_URL` could not be seen. Recheck the Render page after changes.
