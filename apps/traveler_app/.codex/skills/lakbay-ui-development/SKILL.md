---
name: lakbay-ui-development
description: Build or edit the Lakbay+ Flutter frontend while preserving its component patterns, theme, responsive behavior, assets, and verification workflow.
metadata:
  short-description: Lakbay+ Flutter UI conventions
---

# Lakbay UI Development

Use this skill when creating, editing, or reviewing frontend UI in the Lakbay+ Flutter app. Keep the work aligned with the existing mobile-first travel product rather than introducing a new design system.

## Project Shape

- This is a Flutter app named `lakbay_plus`.
- Main UI code lives under `lib/`.
- Screens live in `lib/screens/<feature>/`.
- Reusable UI belongs in `lib/widgets/`, grouped by purpose:
  - `buttons/` for button components.
  - `cards/` for destination, promo, and other repeated cards.
  - `inputs/` for form and preference controls.
  - `loaders/` for loading and skeleton states.
  - `shared/` for section headers, empty/error states, dialogs, and toasts.
- App-wide design tokens live in `lib/core/theme/app_theme.dart` and `lib/core/constants/app_constants.dart`.
- Route names and argument handling live in `lib/core/routes/app_routes.dart`.
- Shared state uses `provider` with `ChangeNotifier` classes in `lib/providers/`.
- Domain objects live in `lib/models/`, especially `Destination`, `Trip`, and planner models.

## Component Patterns

- Prefer small `StatelessWidget` or `StatefulWidget` classes over large inline builders when UI will be reused or repeated.
- Reuse existing shared widgets before creating new ones:
  - `CustomButton` for primary, secondary, outlined, ghost, loading, and icon button states.
  - `CustomInputField` for labeled form fields.
  - `DestinationCard` and `PromoCard` for travel cards.
  - `SectionHeader` for titled content blocks with optional actions.
  - Existing empty, error, loading, skeleton, dialog, and toast widgets for those states.
- Keep screen-specific helper widgets private in the same screen file only when they are tightly coupled to that screen. Promote repeated patterns into `lib/widgets/`.
- Follow the existing constructor style: `const` constructors where possible, `super.key`, required model/callback parameters, and nullable callbacks for optional actions.
- Use `Consumer<T>`, `context.watch<T>()`, and `context.read<T>()` consistently with the existing Provider approach. Do not introduce another state-management library.
- Add new app routes through `AppRoutes` instead of scattering route strings through widgets.

## Styling Approach

- Use `Theme.of(context)`, `theme.colorScheme`, and `theme.textTheme` for normal styling.
- Use `AppTheme` only for established brand colors or dark/light text colors that are already defined there.
- Use `AppConstants` for spacing, radii, shadows, and animation durations instead of hard-coded duplicates.
- Keep the Lakbay visual identity: teal primary, warm orange secondary, white/off-white surfaces, rounded travel cards, soft shadows, and image-led destination content.
- Respect dark mode. When setting explicit colors, check `Theme.of(context).brightness` or use color scheme values that already adapt.
- Prefer Material icons and existing image icons. Use asset icons only when the asset is already available or is intentionally added to `assets/icons/`.
- Avoid one-off typography with `GoogleFonts.outfit` unless a screen already uses it heavily. Prefer the theme text styles for new reusable components.
- Keep UI copy concise and travel-focused. Do not add explanatory text that describes how the UI works unless the product flow genuinely needs it.

## Responsive Rules

- Design mobile-first. The existing app relies on `CustomScrollView`, slivers, horizontal lists, `Wrap`, `Expanded`, `Flexible`, and `MediaQuery` for adaptation.
- Use `SafeArea` or `MediaQuery.of(context).padding` for status bars, bottom navigation, sheets, and overlays.
- Prevent text overflow with `maxLines`, `overflow: TextOverflow.ellipsis`, `Expanded`, or `Flexible` in rows.
- Use `Wrap` for chips, filters, moods, and option groups that may exceed one line.
- Give image cards and fixed controls stable dimensions so loading, labels, ratings, and icons do not resize the layout.
- For bottom sheets and keyboard-aware forms, account for `MediaQuery.of(context).viewInsets.bottom`.
- Keep touch targets comfortable. Existing primary buttons are about 52 px tall; match that rhythm unless the component context is compact.
- Avoid desktop-only assumptions. If adding larger-screen support, preserve the existing mobile layout and progressively widen grids or max content widths.

## Assets

- Registered asset folders are declared in `pubspec.yaml`:
  - `assets/images/`
  - `assets/icons/`
  - `assets/destinations/`
  - `assets/animations/`
- Use existing destination assets before adding new ones.
- For destination images, prefer `Destination.loadImage(...)` so local asset paths and network URLs both work with consistent error handling.
- When adding new assets, place them in the correct existing folder and update `pubspec.yaml` only if a new folder is introduced.
- Provide fallback UI for image failures, usually a tinted container with a relevant Material icon, matching existing destination-card patterns.
- Keep asset references exact and relative to the project root, such as `assets/images/lakbay_logo.png`.

## Verification Commands

Run the checks that match the scope of the change:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
```

- Run `flutter pub get` after dependency or asset manifest changes.
- Run `dart format lib test` after Dart edits.
- Run `flutter analyze` for all UI changes.
- Run `flutter test` when changing widgets, routing, providers, models, or app startup.
- If a command cannot run in the current environment, report that clearly and still perform the static review that is possible.

## Before Finishing

- Confirm new UI reuses existing theme tokens and shared widgets where appropriate.
- Check both light and dark color choices for readable contrast.
- Check narrow mobile layouts for overflow, especially rows with text plus trailing buttons/icons.
- Make sure loading, empty, error, and disabled states are handled for user-facing flows.
- Keep changes scoped to the requested feature and avoid broad visual rewrites unless explicitly requested.
