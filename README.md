# Lakbay+

Monorepo for the Lakbay+ travel-planning platform.

| Path | What | Stack |
|---|---|---|
| `apps/traveler_app` | Traveler mobile/web app | Flutter |
| `apps/admin_app` | Admin dashboard | Flutter |
| `services/api` | REST backend (`/api/v1`) | FastAPI, Postgres, Alembic |

Each project keeps its own README, dependencies and tooling; see the README inside each folder.
The backend API contract docs live in `services/api/docs/`.

## Deployment note
The backend now lives in `services/api`. Set the Render service's **Root Directory** to `services/api`.
