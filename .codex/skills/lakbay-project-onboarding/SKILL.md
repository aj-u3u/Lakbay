---
name: lakbay-project-onboarding
description: Quickly understand the Lakbay+ Flutter project before making changes, including key files, setup, build/test commands, conventions, and where to inspect first.
metadata:
  short-description: Lakbay+ project orientation
---

# Lakbay Project Onboarding

Use this skill when first entering the Lakbay+ project, preparing to change unfamiliar code, reviewing project structure, or explaining where a feature lives. The goal is to build enough context to edit safely without rereading the whole repository.

## Fast Orientation

- This is a Flutter app named `lakbay_plus`.
- The product is a Davao travel planning app with auth, destination discovery, AI itinerary planning, trips, group collaboration, memories, notifications, and profile flows.
- Main app startup is in `lib/main.dart`.
- App navigation is centralized in `lib/core/routes/app_routes.dart`.
- App-wide state is registered with `MultiProvider` in `lib/main.dart`.
- The project uses `provider`, `http`, `flutter_secure_storage`, `google_fonts`, `flutter_map`, `latlong2`, `geolocator`, `image_picker`, and `flutter_spinkit`.
- The UI is mobile-first and Flutter Material 3 based.

## Important Files

- `pubspec.yaml`: package metadata, dependencies, SDK constraint, and registered asset folders.
- `analysis_options.yaml`: lint setup via `package:flutter_lints/flutter.yaml`.
- `lib/main.dart`: root `LakbayPlusApp`, app theme wiring, route setup, and Provider registration.
- `lib/core/theme/app_theme.dart`: light/dark theme, brand palette, typography, input, chip, button, app bar, and navigation styling.
- `lib/core/constants/app_constants.dart`: spacing, radii, shadows, animation durations, and static config placeholders.
- `lib/core/routes/app_routes.dart`: route names, route creation, and typed route arguments.
- `lib/core/config/api_config.dart`: backend base URL from `--dart-define=API_BASE_URL`, defaulting to `http://127.0.0.1:8000/api/v1`.
- `lib/services/api_service.dart`: singleton HTTP/API layer, auth tokens, backend fallbacks, trips, AI, recommendations, weather, collaboration, memories, notifications, and route optimization.
- `lib/services/session_storage.dart`: secure session persistence.
- `lib/providers/`: app state controllers for auth, navigation, trips, theme, and language.
- `lib/models/`: domain models for destinations, trips, user profile, notifications, planner drafts, grouped destinations, session preferences, and app errors.
- `lib/screens/`: feature screens grouped by domain.
- `lib/widgets/`: reusable UI grouped as buttons, cards, inputs, loaders, and shared components.
- `assets/images/`, `assets/icons/`, `assets/destinations/`, `assets/animations/`: asset folders declared in `pubspec.yaml`.
- `test/widget_test.dart`: current smoke test that pumps `LakbayPlusApp`.
- `Lakbay_UI_UX_Feature_Enhancement_Plan_v2.md`: product and UX requirements; read relevant sections before implementing planned UI/feature changes.
- `logcat_full.txt`: large diagnostic log; do not read unless debugging a specific Android/runtime issue.

## Setup

For a normal local setup:

```bash
flutter pub get
```

Run the app with the default local API:

```bash
flutter run
```

Run with a custom backend:

```bash
flutter run --dart-define=API_BASE_URL=http://<host>:<port>/api/v1
```

Use platform-specific Flutter targets only when needed, for example `flutter run -d chrome`, `flutter run -d windows`, or a connected mobile device.

## Build And Test Commands

Use the narrowest useful verification for the change:

```bash
dart format lib test
flutter analyze
flutter test
```

Additional useful commands:

```bash
flutter pub get
flutter build apk
flutter build web
```

- Run `flutter pub get` after dependency or asset manifest changes.
- Run `dart format lib test` after Dart edits.
- Run `flutter analyze` for code and UI changes.
- Run `flutter test` for changes touching app startup, widgets, providers, models, routing, or test files.
- Run platform builds only when the change affects platform configuration or release output.
- If Flutter is unavailable in the environment, still inspect affected files and report that verification could not be run.

## Known Conventions

- Keep feature screens under `lib/screens/<feature>/`.
- Put shared UI in `lib/widgets/<category>/` instead of duplicating repeated controls inside screens.
- Keep routes in `AppRoutes`; avoid new raw route strings scattered in widgets.
- Use `ChangeNotifier` providers and `context.watch`, `context.read`, or `Consumer` consistently. Do not introduce another state-management approach.
- Use `ApiService` for backend calls rather than calling `http` directly from screens or providers.
- Preserve the fallback behavior in `ApiService` and models, especially `Destination.davaoDestinations` and `Destination.loadImage`.
- Keep token/session behavior coordinated through `AuthProvider`, `ApiService`, and `SessionStorage`.
- Use `AppTheme` and `AppConstants` for design tokens.
- Prefer existing widgets such as `CustomButton`, `CustomInputField`, `DestinationCard`, `PromoCard`, `SectionHeader`, loader widgets, empty/error states, dialogs, and toast utilities.
- Keep UI changes aligned with the companion skill `lakbay-ui-development` when the task is specifically frontend-focused.
- Avoid broad rewrites of large screens such as `home_screen.dart`, `planner_screen.dart`, `destination_details_screen.dart`, and `group_dashboard_screen.dart` unless the request clearly requires it.

## Where To Look First

- App startup, global providers, theme mode: `lib/main.dart`, `lib/providers/theme_provider.dart`.
- Routing or screen arguments: `lib/core/routes/app_routes.dart`.
- Brand styling, colors, text, spacing, radii, shadows: `lib/core/theme/app_theme.dart`, `lib/core/constants/app_constants.dart`.
- Auth, login, signup, session restore, logout: `lib/providers/auth_provider.dart`, `lib/services/api_service.dart`, `lib/services/session_storage.dart`, `lib/screens/auth/`.
- Destination discovery, cards, details, district pages: `lib/models/destination.dart`, `lib/screens/home/home_screen.dart`, `lib/screens/destinations/`, `lib/widgets/cards/destination_card.dart`.
- AI planner and itinerary generation: `lib/screens/planner/`, `lib/providers/trip_provider.dart`, `lib/services/api_service.dart`, `lib/models/trip.dart`, `lib/models/session_preferences.dart`.
- Trips list and trip editing: `lib/screens/trips/trips_screen.dart`, `lib/providers/trip_provider.dart`, `lib/models/trip.dart`.
- Group collaboration, tasks, members, shared memories: `lib/screens/collaboration/`, `TripProvider` collaboration methods, and the trip collaboration methods in `ApiService`.
- Memories and image upload flows: `lib/screens/memories/`, `lib/screens/collaboration/shared_memories_screen.dart`, `ApiService` memory methods, and `image_picker` usage.
- Notifications: `lib/screens/notifications/notifications_screen.dart`, `lib/models/app_notification.dart`, `TripProvider` notification state, `ApiService` notification methods.
- Profile, theme/language preferences, saved profile edits: `lib/screens/profile/`, `lib/providers/theme_provider.dart`, `lib/providers/language_provider.dart`, `AuthProvider`.
- API URL or backend integration issues: `lib/core/config/api_config.dart`, `lib/services/api_service.dart`.
- Product requirements or expected UX behavior: `Lakbay_UI_UX_Feature_Enhancement_Plan_v2.md`.

## Before Making Changes

- Check `git status --short --branch` so existing user changes are not overwritten.
- Read the smallest relevant set of files from the sections above before editing.
- Search with `rg` for existing components, routes, provider methods, and model fields before adding new ones.
- Confirm whether the task is UI-only, state/provider logic, backend API mapping, model parsing, platform config, or test-only.
- If adding a user-facing flow, identify its loading, empty, error, disabled, and success states before coding.
- If adding an asset, verify it is in a registered asset folder or update `pubspec.yaml` intentionally.

## Before Finishing

- Format changed Dart files.
- Run `flutter analyze` and the relevant tests when available.
- Mention any commands that could not be run.
- Summarize the main files changed and why.
