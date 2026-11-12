# Lakbay+ Admin

Flutter web workspace for maintaining the information used by Lakbay. The interface shares the mobile application's teal/orange palette, Outfit typography, and Lakbay identity, with desktop tables and responsive editing flows.

## Run

Use an existing Flutter installation and the final backend:

```powershell
flutter pub get
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Sign in using an administrator account provisioned in `lakbay_backend_final`. Access tokens, refresh tokens, and the server-returned identity are retained locally; protected requests refresh an expired access token once. Sign out clears the local session even when server revocation fails.

`API_BASE_URL` is a compile-time setting. Its default is `http://127.0.0.1:8000/api/v1`. Configure the backend's allowed browser origins for the actual admin URL. For a hosted build, provide a reachable HTTPS API URL:

```powershell
flutter build web --dart-define=API_BASE_URL=https://your-api.example/api/v1
```

Deploy the generated `build/web` directory. Localhost refers to the computer running the browser; it is only suitable for local development.

## Implemented workflows

- **Overview:** live active-destination count and direct links to the five admin jobs.
- **Destinations:** search, category filter, sorting, pagination, full details, add/edit, and confirmed deactivation. The editor validates coordinates and decimal amounts, sends only changed fields on update, retains failed edits, and protects unsaved work.
- **Market Rates:** destination-scoped accommodation/transport tabs, responsive tables/cards, add/edit, and confirmed deactivation. Route/lodging details remain attached to the correct destination.
- **My profile:** live own-account information; supported full-name and avatar-URL editing.
- **Appearance:** saved Light, Dark, and System modes.
- **Navigation:** one shared shell, compact desktop navigation, and a narrow-screen drawer.

The final API supplies active destinations and available rate options only. Deactivated records cannot currently be browsed or restored through this API. Rate `price` has no dedicated currency/unit field; describe the actual unit in the description or notes.

## Remaining backend capabilities

User Accounts clearly distinguishes the signed-in administrator's own profile from a global account directory. Global user management, administrative review access/moderation, and trip inspection are shown as unavailable because the inspected final backend provides no corresponding admin directory/access policy. These screens do not invent records or call obsolete endpoints.

The admin targets `lakbay_backend_final` versioned routes, replacing the old unversioned admin contract. The mobile `ui_for_lakbay` project must point to the same running backend/database to see shared destination changes. Its consumption of accommodation/transport rates and the complete system integration still require a live end-to-end check. This frontend enhancement does not modify either sibling project.

## Validation and UI guidance

```powershell
flutter analyze --no-pub
flutter test --no-pub
flutter build web --no-pub
```

API tests cover nested authentication, token refresh, pagination, scoped rate writes, permission/network failures, and late refresh after sign-out. Widget tests cover validation, changed-only destination updates, discard/save guards, catalog/rate refresh, account retry, rate saving, compact/narrow navigation, and admin session eligibility. Browser layout/workflow checks use a temporary synthetic API fixture, separate from real records.

UI development guidance is in [skills/ui-development/SKILL.md](skills/ui-development/SKILL.md); the design audit and target plan are in [admin-ui-plan.md](skills/ui-development/references/admin-ui-plan.md).

