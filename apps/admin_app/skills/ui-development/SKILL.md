---
name: ui-development
description: Plan, review, and, when explicitly requested, develop the Lakbay admin web interface in FINAL_ADMINLAKBAY. Use the UI_FOR_LAKBAY brand palette and task-based admin workflows for destinations, market rates, user accounts, reviews and feedback, and trip information, with integration guidance for lakbay_backend_final.
---

# Lakbay Admin UI Development

## Scope and operating mode

This skill governs the **Lakbay admin web system**, built with Flutter. The traveler application, `UI_FOR_LAKBAY`, is a separate mobile product. Share its visual identity and record meanings while designing for desktop administration.

Choose planning or implementation from the user's latest instruction. During **planning only**, produce design guidance, screen specifications, and Markdown artifacts; do not edit application code, dependencies, API services, backend code, database schemas, or deployed settings. A runnable UI prototype requires implementation authorization. Creation or invocation of this skill alone is not that authorization.

If the user later explicitly requests implementation, use that authorization within its stated scope. Reuse the existing Flutter web project and inspect applicable repository instructions. Do not introduce another frontend framework or modify sibling projects as a side effect of admin work.

This is a project-local skill artifact. It does not claim global installation or automatic skill discovery.

## Product intent

Make it easy for an administrator to maintain destination information and market rates, manage user accounts, inspect review feedback, and view trip information. Every visible control must support one of these jobs or a necessary account/system task.

Read [references/admin-ui-plan.md](references/admin-ui-plan.md) when planning navigation, screen layouts, workflows, or implementation scope. It contains the initial source audit, target information architecture, component dimensions, and backend dependencies. Its proposals are design intent, not implemented features.

## Establish the facts before designing

Resolve the project root as the directory containing `pubspec.yaml` and `lib/`. The sibling names below describe the present workspace; inspect equivalent source files if locations change.

| Source | Inspect for |
|---|---|
| Admin `lib/main.dart`, `lib/widgets/app_shell.dart` | Active routes, navigation, and the shell actually rendered |
| Admin `lib/core/theme/app_theme.dart`, affected screens | Shared tokens, component overrides, and current interaction behavior |
| Admin `lib/services/api_service.dart` | Existing API contract and integration gaps |
| Sibling `UI_FOR_LAKBAY/lib/core/theme/app_theme.dart` | Canonical shared brand colors and Outfit typography |
| Sibling `UI_FOR_LAKBAY/lib/core/config/api_config.dart` | Mobile API configuration |
| Sibling `lakbay_backend_final/app/api.py`, feature routers/schemas | Actual fields, supported operations, and permissions |

Separate **observed source behavior**, **proposed UX**, and **backend dependencies**. A source audit does not prove rendered alignment or a live connection. Recheck contracts before implementing; this plan reflects source inspected on 2026-10-02.

## Shared visual identity

The admin already shares the mobile application's core palette. Standardize its use before inventing another palette. Refer to actual color roles rather than misleading mobile variable names such as `primaryBlue` and `secondaryGreen`.

| Role | Light | Dark |
|---|---|---|
| Brand primary teal | `#20878E` | `#20878E` |
| Brand secondary orange | `#D66F29` | `#D66F29` |
| Brand accent teal | `#178A90` | `#178A90` |
| Page background | `#F5F9F9` | `#0D1F1F` |
| Card/surface | `#FFFFFF` | `#163030` |
| Primary text | `#1A2E2E` | `#F0F7F7` |
| Secondary text | `#5C7878` | `#8AADAD` |

Use teal for the principal action and navigation selection, orange sparingly for secondary emphasis, and neutrals for the workspace. Reserve success/warning/error colors for their meanings; do not use arbitrary indigo, purple, or sky-blue accents to decorate unrelated metrics. Data charts may use additional accessible series colors when their meanings and labels justify them.

Use Outfit for the principal interface, with a usable fallback. Preserve `assets/images/lakbay_logo.png`, its proportions, and its white canvas. Prefer solid, quiet surfaces for tables and forms. Use restrained borders and elevation; avoid applying blur and gradients to every information panel.

Keep exact brand swatches while checking actual foreground/background pairs. White text on the existing teal and orange fails the 4.5:1 normal-text target. Accessible semantic variants are proposed in the reference; they are not new canonical brand swatches. Test both themes, including focus rings and status badges.

## Task-based architecture

Use **Overview, Destinations, Market Rates, Users, Reviews & Feedback, and Trips** as the main navigation. Put profile, appearance, sign-out, and supported settings in account/utility locations.

Group Accommodation and Transport beneath Market Rates. Keep activities and meal information associated with their destination until a supported structured rate model is agreed. Do not maintain separate copies of one record merely because it appears in multiple screens.

Link related records: destination to its rates and feedback; rate to its destination; user to permitted related trip/review information; trip to its itinerary destinations and feedback. Preserve list filters and scroll position when returning from details.

## Web layout and interaction rules

- Use one authoritative shell and page-header pattern. Keep the top bar for global context/account utilities; keep page title, explanation, and primary action in the page header.
- Use a persistent desktop sidebar, compact navigation at intermediate widths, and a drawer at narrow widths. Preserve keyboard and pointer workflows; do not transplant mobile bottom navigation into the admin.
- Align headers, toolbars, tables, panels, and editor content to common page gutters. Use a shared spacing scale, consistent control heights, and coordinated component radii from the reference.
- Default to searchable, filterable tables for operational lists. Use dedicated detail/editor pages for complex destinations; use small dialogs for focused confirmations. Keep a map as destination location context rather than the default management surface.
- Display currency, billing units, and destination associations together. Distinguish per-person, per-room/night, and per-route prices; do not present an estimate as a verified market rate.
- Give every list loading, empty, no-results, error/retry, permission-denied, and dependency-unavailable states. An API failure is not an empty list or a zero count.
- Show Save progress, field-level errors, and confirmed success. Retain form input on failure and protect unsaved changes. Avoid live-looking placeholder metrics, notification badges, or activity feeds.
- Give icon controls accessible names and visible focus; provide text labels for important actions. Status must be understandable without color. Use legible type, sufficient contrast, keyboard operation, and an accessible dialog focus cycle.

## Integration boundary

Use `lakbay_backend_final` as the shared source of truth. The initial audit found an older unversioned admin contract; the authorized frontend enhancement now targets `/api/v1`. A matching color palette does not establish a live shared connection.

Do not assume a URL change completes integration. Account for the `/api/v1` prefix, nested authentication response, Bearer tokens, `PATCH` updates, destination-scoped rate routes, actual field schemas, and resource permissions.

Global user administration, an admin-wide review/moderation queue, and admin-wide trip viewing are **target capabilities with backend dependencies** in the inspected final backend. The admin role does not automatically grant traveler-resource access. Keep Trips read-only in the target UI unless the user requests a broader workflow. Do not add booking, payment, push-notification, or AI-regeneration controls without a product requirement and a supported contract.

Record missing fields and endpoints in the plan, including complete inactive/unavailable inventory and recovery. During planning, label dependent actions; during implementation, omit or clearly disable unsupported actions with a meaningful explanation. Never use hardcoded traveler fallback data as evidence of shared backend data. Rate delivery also requires a separately scoped mobile consumption change; the inspected mobile source does not fetch accommodation/transport lists.

## Deliver and review

For planning, provide the concrete navigation, each page's purpose/actions, list/detail/editor relationships, shared tokens, key states, and backend dependencies. State assumptions as proposals without repeatedly asking for approval of routine design choices.

When implementation is authorized, work in coherent slices: shell and tokens, one complete destination/rate workflow, then the remaining supported domains. Verify actual rendered behavior at representative desktop/tablet/narrow widths, keyboard focus, both themes, long content, and API failure states. Run relevant Flutter checks for changed behavior; do not claim visual QA from source inspection alone.

Judge success by whether an admin can find a record, understand its relationships, complete a supported action, and see an accurate result without guessing where to go next.
