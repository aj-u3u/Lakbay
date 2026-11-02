# Guidelines for AI coding agents working on Lakbay+

Lakbay+ is our Flutter capstone project. Read `knowledge.md` for its project map, then inspect the code relevant to the user's request. Use a matching project skill under `.codex/skills/` when the task involves project onboarding, UI development, or admin integration.

## Before editing

- Check `git status --short --branch` and work on the requested branch.
- Preserve existing changes. Do not overwrite or remove work unrelated to the request.
- Find the current implementation before adding a new screen, route, widget, model, or service method.

## Coding guidelines

- Keep feature screens in `lib/screens/<feature>/`, reusable UI in `lib/widgets/`, data models in `lib/models/`, and shared state in `lib/providers/`.
- Add navigation through `AppRoutes`. Reuse `AppTheme`, `AppConstants`, and existing widgets for consistent UI.
- Follow the existing Provider and `ChangeNotifier` pattern unless the user requests an architecture change.
- Keep backend requests in `ApiService`. Coordinate authentication and stored sessions with `AuthProvider` and `SessionStorage`.
- Never add API keys, passwords, or personal data to committed files.

## Before finishing

- Format changed Dart files and run relevant `flutter analyze` and `flutter test` checks when available.
- Explain what changed and report any check that could not run.
