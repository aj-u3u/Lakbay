---
name: lakbay-admin-integration
description: Connect Lakbay+ Flutter data flows to an admin dashboard or backend, including shared data contracts, access rules, and end-to-end verification. Use for admin-managed records or changes that must appear in the traveler app; use lakbay-ui-development for UI-only work.
---

# Lakbay Admin Integration

Use this skill when an admin system creates, edits, publishes, removes, or reviews data consumed by Lakbay+, or when traveler actions must be visible to admins. The repository currently contains the Flutter client, not the admin application or an authoritative backend schema. Inspect the actual admin/backend code or API documentation when available; do not infer an endpoint or permission from the Flutter models alone.

## Trace the Data Flow

- Identify the record's owner and source of truth, then trace admin write -> backend storage/API -> `ApiService` -> model -> provider -> traveler screen. For traveler-originated data, trace the reverse path too.
- Record the agreed contract for each affected entity: stable ID, field names and types, required versus optional fields, status/publish rules, timestamps and timezone, media URLs, pagination, deletion behavior, and error responses. Check whether older app versions can still read the response.
- Check related IDs across destinations, trips, members, tasks, memories, and notifications. A notification or group action must retain the correct trip context.
- Distinguish backend records from demo or fallback data. `Destination.davaoDestinations` and other mock data can support preview/offline behavior, but must not imply that an admin edit or traveler action was saved.

## Follow Existing Client Boundaries

- Keep network calls in `lib/services/api_service.dart`, configuration in `lib/core/config/api_config.dart`, parsing in `lib/models/`, and shared state in `lib/providers/`. Use the existing `provider` approach and centralized routes.
- Coordinate traveler authentication with `AuthProvider`, `ApiService`, and `SessionStorage`. Do not embed admin credentials, privileged tokens, or database access in the Flutter client.
- Require the backend to enforce admin roles and traveler ownership or group membership. Hiding a control in the UI does not grant or deny access. Limit personal and group memory data to authorized users.
- Make successful writes depend on a confirmed backend response. After an admin change, define how the traveler app refreshes or invalidates affected data; handle missing, unpublished, or deleted records without showing stale content as current.
- If the admin service or contract is unavailable, complete only the client work supported by evidence and clearly identify the contract details needed for full integration.

## Verify the Connection

- Test response parsing and provider behavior with representative admin-created data, missing optional fields, rejected writes, and unavailable network responses.
- For changed user flows, check that an admin edit appears in the app after the intended refresh, and that traveler changes appear in admin views when the backend supports them.
- Verify authorization boundaries with backend or integration tests when that environment is available, especially admin-only actions and cross-group access. Never treat a client widget test as proof of server authorization.
- Run `dart format` on changed Dart files, `flutter analyze`, and focused `flutter test` cases. State which checks require a live backend or device and were not run.

For ordinary project orientation, use `lakbay-project-onboarding`. For visual or responsive screen work, use `lakbay-ui-development` alongside this skill.
