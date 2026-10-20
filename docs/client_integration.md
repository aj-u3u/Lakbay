# Local admin and Android integration

The admin and traveler apps use the same FastAPI service. Only the backend has
`DATABASE_URL`; neither Flutter client connects to Postgres directly.

## Backend

From `lakbay_backend_final`, keep the configured Neon `DATABASE_URL` in the
untracked `.env` file. Confirm that `alembic current` matches `alembic heads`
before starting the API. The current migration head is `dfc235ae4bed`.

For the local admin browser on port 5173, set:

```env
CORS_ALLOWED_ORIGINS=http://localhost:5173,http://127.0.0.1:5173
```

Then run:

```powershell
.\.venv\Scripts\uvicorn.exe app.main:app --host 0.0.0.0 --port 8000
```

The bind address makes port 8000 available to an Android emulator or a phone on
the same network, subject to the host firewall. Browser CORS applies to the admin
web client; Android native HTTP requests do not send browser CORS preflights.

## Admin web client

From `FINAL_ADMINLAKBAY`, run:

```powershell
flutter run -d edge --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Open the reported local URL and sign in with an admin account. The browser URL
must match one of `CORS_ALLOWED_ORIGINS`. A production browser deployment needs a
reachable HTTPS API URL and its exact browser origin in the backend setting.

## Android traveler client

From `UI_FOR_LAKBAY`, Android emulator builds default to
`http://10.0.2.2:8000/api/v1`, which reaches port 8000 on the development host.
An explicit build setting overrides that default:

```powershell
flutter run -d <android-device-id> --dart-define=API_BASE_URL=http://10.0.2.2:8000/api/v1
```

For a physical Android phone, replace `10.0.2.2` with the development host's
current LAN IPv4 address. Keep the phone and host on the same network, allow
inbound TCP port 8000, and use that address in `API_BASE_URL`. `127.0.0.1` on a
phone points to the phone itself.

## Shared-data check

1. Sign in to the admin web app and the Android app with their respective test
   accounts.
2. In the admin destination catalog, find a current active destination and note
   its name and ID.
3. Refresh the traveler destination list and open the same destination. Confirm
   its ID and name against `GET /api/v1/destinations/{destination_id}`.
4. If the traveler app is offline, distinguish its local sample destinations
   from a successful API response before treating the check as passed.

The current Neon database returned destination ID 13, **Aliwagwag Falls**, for
the October 18, 2026 integration check. Its records can change later.

## Catalog refresh and rates

The Android catalog now requests all active destination pages with
`limit=100&offset=0,100,...`. It uses `destination_id` as the model ID,
maps the backend's snake-case fields (including `image_url`, `entrance_fee`,
and `overnight_fee`), and keeps bundled preview destinations out of the live
catalog. A failed request shows an offline or error state with Retry rather
than substituting sample data.

Open a destination to fetch that ID again plus its available accommodation
and transportation rows. Pull to refresh the destination list or detail page
after an admin save or deactivation. An edited row retains the same
`accommodation_id` or `transportation_id`; a deactivated row disappears from
the corresponding public list. Rate prices are displayed with `currency` and
`charging_unit`. Legacy rows whose unit has not been reviewed display
`basis unverified`.
