# New Feature Request Template

Use this document when proposing a new Lakbay backend feature. The purpose is to
make sure every new feature fits the current build phase in `docs/core_focus.md`
before any code is written.

## Current Project Phase

Before filling out this request, check `docs/core_focus.md` and write the phase
the project is currently working on.

```text
Current phase:
Phase title:
Date proposed:
Requested by:
```

Reminder:

```text
If the project is currently in Phase 2, a new feature should normally support
Phase 2 goals. If it belongs to Phase 6, Phase 9, or another later phase, Codex
should recommend deferring it instead of implementing it immediately.
```

## User Input Template

The user can edit this section directly.

### Feature Name

```text
Write the short name of the feature here.
```

### Feature Description

```text
Describe what the feature should do in plain language.
```

### Problem It Solves

```text
Explain why this feature is needed.
```

### Target User

```text
Who will use this feature?

Examples:
- Traveler
- Group member
- Trip owner
- Admin
```

### Expected User Flow

```text
Describe how the user will interact with the feature from start to finish.
```

### Requested Phase

```text
Which phase do you think this belongs to?

Example:
Phase 2: Destination Data Foundation
```

### Why It Belongs In That Phase

```text
Explain why this feature should be built during the requested phase.
```

### Related Existing Phase

```text
List any phase from docs/core_focus.md that seems related.
```

### Expected API Endpoints

```text
Write suggested endpoints if you already have them.

Example:
GET /api/v1/destinations
POST /api/v1/destinations
```

### Data Or Model Changes

```text
List any tables, columns, or relationships you think are needed.

If unsure, write "Codex should suggest this."
```

### Environment Variables

```text
List any new API keys, service URLs, or configuration variables.

If none, write "None."
```

### Dependencies Or External Services

```text
List any external service this feature might need.

Examples:
- Groq
- OSRM
- Object storage
- Email provider
```

### Security Or Permission Rules

```text
Describe who can create, view, update, or delete this feature's data.
```

### Acceptance Criteria

```text
Write what must be true for this feature to be considered complete.
```

### Notes

```text
Add any extra context, edge cases, or questions.
```

## Codex Review Checklist

Codex must review this request before implementation.

1. Read `docs/core_focus.md`.
2. Identify the current project phase.
3. Compare the requested feature against the current phase goal.
4. Decide whether the feature fits the current phase.
5. If it does not fit, recommend the correct existing phase.
6. If no phase fits, recommend adding or modifying a phase in
   `docs/core_focus.md`.
7. Identify likely models, endpoints, services, migrations, tests, and
   environment variables.
8. Ask the user for permission before making any code changes.

## Codex Review Response Format

When reviewing a submitted feature, Codex should answer using this structure:

```text
Feature:
Current phase:
Requested phase:
Phase alignment:
Recommended phase:

Reason:

Suggested backend scope:

Likely files or modules:

Possible database changes:

Possible environment variables:

Testing notes:

Recommendation:
```

## Phase Alignment Labels

Use one of these labels:

```text
Fits current phase
Fits current phase if reduced
Better for existing later phase
Requires new phase
Needs clarification
```

## Review Rules

- If the feature directly supports the current phase, Codex may recommend adding
  it to the current phase.
- If the feature is useful but not needed yet, Codex should recommend deferring
  it to the correct later phase.
- If the feature is too large, Codex should suggest splitting it into a small
  current-phase version and a later enhancement.
- If the feature requires new database tables or columns, Codex must explain the
  migration impact before asking for permission.
- If the feature needs a new external API or paid service, Codex must list the
  required environment variables before implementation.
- If the feature affects authentication, authorization, payments, private user
  data, uploaded files, or AI-generated content, Codex must include security
  notes.
- No feature should move from proposal to code without explicit user approval.

## Example

```text
Feature Name:
Destination tags filter

Current phase:
Phase 2: Destination Data Foundation

Feature Description:
Allow users to filter destinations by category, vibe, district, and
accessibility flags.

Requested Phase:
Phase 2

Why It Belongs In That Phase:
Phase 2 is where destination data and browsing are created. Filtering helps
Flutter use the preloaded destination data before AI recommendations are added.
```

Expected Codex review:

```text
Phase alignment:
Fits current phase

Recommended phase:
Phase 2: Destination Data Foundation

Reason:
The feature depends only on destination data and improves destination browsing.
It does not require AI, route optimization, or group planning.
```
