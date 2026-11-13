# Lakbay+ project knowledge

Lakbay+ is a Flutter travel app focused on Davao destinations. Its current code includes destination discovery, trip planning, authentication, group collaboration, memories, notifications, and profile screens.

## Project map

- `lib/main.dart` starts the app and registers the `ChangeNotifier` providers.
- `lib/core/routes/app_routes.dart` defines navigation.
- `lib/core/theme/app_theme.dart` and `lib/core/constants/app_constants.dart` define shared styling.
- `lib/models/` holds app data models; `lib/providers/` holds shared state.
- `lib/screens/` contains feature screens; `lib/widgets/` contains reusable UI.
- `lib/services/api_service.dart` is the main backend API layer.
- `lib/services/session_storage.dart` stores session data securely.
- `Lakbay_UI_UX_Feature_Enhancement_Plan_v2.md` contains planned product and UI work.

## Development setup

The API URL comes from `API_BASE_URL` in `lib/core/config/api_config.dart`. Its default is `https://lakbay-api-sg.onrender.com/api/v1`; running a backend locally may require a different host address on a device or emulator.

From the repository root, use `flutter pub get` to install dependencies, `flutter run` to launch the app, `flutter analyze` for static checks, and `flutter test` for tests. Pass a different API URL with `flutter run --dart-define=API_BASE_URL=<url>` when needed.

## Repository conventions

The app uses Provider and `ChangeNotifier` for shared state, Material 3 for UI, and the route and theme files above for consistent navigation and styling. Review the relevant project skill under `.codex/skills/` when working on onboarding, UI, or admin integration.

This file records the current project structure. Update it when architecture or setup changes; keep temporary task notes and secrets out of it.
