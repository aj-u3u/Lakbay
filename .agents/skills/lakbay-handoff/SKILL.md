---
name: lakbay-handoff
description: Load the Lakbay+ project handoff, inspect the current repository state, and orient work across the traveler app, backend, and admin dashboard. Use when taking over this project or reviewing a proposed Lakbay task.
argument-hint: "[task]"
disable-model-invocation: true
---

# Lakbay+ handoff

The user's task, if any, is: $ARGUMENTS

## Read before acting

1. Work from the `lakbay_backend_final` repository root. Read `PROJECT_CONTEXT.md`, `AGENTS.md`, `docs/core_focus.md`, and `docs/new_feature.md`. For a specific task, read the relevant feature guide, router, schemas, service, models, migrations, and tests.
2. Check `git status --short` and the relevant diff. Preserve existing modified and untracked work. Treat dated deployment and Neon counts in the handoff as historical until checked again.
3. Check whether the sibling traveler repository `UI_FOR_LAKBAY` and admin repository `FINAL_ADMINLAKBAY` are available. Inspect their current files before making client-specific claims. They are separate checkouts and may not accompany a backend-only handoff.
4. Use the current code, migration files, generated OpenAPI, and live environment checks when available to resolve documentation drift. Do not expose `.env` values, tokens, database URLs, or provider keys.

## If invoked without a task

Give a concise takeover brief: architecture, current phase, what is implemented in each component, highest-priority unfinished work, the state of the working tree, and facts requiring live verification. Point to `PROJECT_CONTEXT.md` for the full detail. Do not edit code.

## If invoked with a task

1. Compare the task with `docs/core_focus.md` and the new-feature review rule in `AGENTS.md`. State whether it is current-phase work, a later-phase proposal, or a correction to existing behavior.
2. Explain the smallest reviewable scope, affected API contracts, models/migrations, client screens, environment settings, and tests. Keep Groq as the implemented AI provider; Gemini is only a possible future provider unless the code now proves otherwise.
3. Follow `AGENTS.md`: ask the user for permission **before implementing code changes**. For changes to existing database tables, columns, relationships, or model names, explain the reason and get specific approval first. A directly requested documentation-only change may proceed.
4. After approval, make the scoped change, use Alembic for approved schema changes, run focused meaningful checks, and report touched files, verified behavior, and remaining limits. Do not reset files, delete migrations, overwrite user work, or bulk-publish staged destinations.

## System facts to preserve

- Both Flutter clients call the FastAPI `/api/v1` API; only the backend connects to Neon PostgreSQL/PostGIS and external providers.
- Planning previews and feedback are stateless. AI itinerary attempts are audited, validated, and saved to trips only through a selected generation run and option.
- OSRM supplies driving routes and suggested stop order. Walking requires a distinct verified foot-profile service; public transport and Haversine fallbacks are estimates. An attraction pin is not a verified visitor arrival point.
- The admin candidate queue is separate from the public destination catalog. Publication is an explicit per-place action; published candidates are not automatically route-ready.
- Multi-day time-window scheduling, continuous live detour recalculation, a Gemini backend integration, a traveler offline trip database, and an admin heatmap are not established implementations in the handoff.
