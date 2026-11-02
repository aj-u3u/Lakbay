# Developer Manual

This manual is for Lakbay backend developers who will work with Codex or another
AI coding assistant. It explains how to ask for help clearly, how to continue the
project safely, and how to avoid skipping important planning steps.

## Start Here Every Time

Before asking Codex to make changes, check these files:

- `AGENTS.md`: project rules for Codex and developers.
- `docs/core_focus.md`: current build phases.
- `docs/new_feature.md`: template for requesting new features.
- `docs/migrations.md`: database migration procedure.
- `docs/destinations.md`: Phase 2 destination API and seed data guide.
- `docs/recommendations.md`: Phase 3 recommendation API guide.
- `docs/budgets.md`: Phase 4 budget estimate API guide.
- `docs/ai_itineraries.md`: Phase 5 AI itinerary guide.
- `docs/models.md`: AI model selection notes.
- `docs/routing.md`: route optimization notes.
- `docs/trips.md`: Phase 7 trip management guide.
- `docs/group_collaboration.md`: Phase 8 group collaboration guide.
- `docs/expenses.md`: Phase 9 expenses and shared costing guide.
- `docs/memories.md`: Phase 10 memories and photo uploads guide.
- `docs/reports.md`: Phase 11 report summary and PDF download guide.
- `docs/reviews.md`: Phase 12 reviews and feedback guide.
- `docs/notifications.md`: Phase 13 in-app notifications guide.
- `docs/phase14_evaluation.md`: Phase 14 evaluation endpoint and verification gates.
- `docs/geo_analytics.md`: Phase 15 geo-analytics enhancement plan.
- `docs/itinerary_feedback.md`: Phase 15F pre-trip feedback contract and rules.
- `docs/capstone_alignment.md`: panel comment, diagram, and objective notes.

The most important rule:

```text
Do not ask Codex to implement code until the current phase and scope are clear.
```

## How To Prompt Codex Properly

Good prompts should answer four questions:

1. What phase are we working on?
2. What exact feature or task do we want?
3. Should Codex only plan, or is Codex allowed to edit files?
4. What files, docs, or existing decisions should Codex follow?

Use this format:

```text
We are working on Phase __: __.

Task:
Describe the task here.

Scope:
Tell Codex what is included and what is not included.

Permission:
Planning only. Do not edit code yet.
```

Or, when ready for implementation:

```text
We are working on Phase __: __.

Task:
Describe the task here.

Scope:
Tell Codex what files or feature modules can be changed.

Permission:
You may implement this now. Please explain the files you will edit first.
```

## Planning-Only Prompt Examples

Use planning-only prompts when you are still deciding.

```text
We are working on Phase 1: Authentication And Users.

Task:
Review the current user/auth plan and suggest the needed endpoints, schemas,
models, and services.

Permission:
Planning only. Do not edit files yet.
```

```text
We are working on Phase 2: Destination Data Foundation.

Task:
Review whether destination tags should be stored as text fields, enums, or
separate tables.

Permission:
Planning only. Do not edit files yet.
```

```text
We are working on Phase 5: AI Itinerary Generation.

Task:
Check docs/models.md and recommend which environment variables and service files
are needed for Groq integration.

Permission:
Planning only. Do not edit files yet.
```

## Implementation Prompt Examples

Use implementation prompts only after the team agrees on the scope.

```text
We are working on Phase 0: Project Foundation.

Task:
Create the minimal FastAPI app with a /health endpoint.

Scope:
You may edit app/main.py, app/api.py, and any required core config files.

Permission:
You may implement this now. Please summarize the intended edits before changing
files.
```

```text
We are working on Phase 1: Authentication And Users.

Task:
Add SQLAlchemy models and Pydantic schemas for users only.

Scope:
Do not generate the Alembic migration yet. Do not add login endpoints yet.

Permission:
You may implement this now.
```

```text
We are working on Phase 2: Destination Data Foundation.

Task:
Add destination and accommodation models based on the approved schema.

Scope:
Use feature-based folders. Do not change table names unless you explain why.

Permission:
You may implement this now.
```

## New Feature Prompt

When a new feature idea appears, use `docs/new_feature.md` first.

Prompt Codex like this:

```text
I filled out docs/new_feature.md.

We are currently working on Phase __: __.

Please review whether this feature fits the current phase. Do not edit code.
Tell me if it should be done now, deferred to another phase, split into smaller
parts, or added as a new phase in docs/core_focus.md.
```

Codex should respond with:

```text
Feature:
Current phase:
Requested phase:
Phase alignment:
Recommended phase:
Reason:
Suggested backend scope:
Possible database changes:
Testing notes:
Recommendation:
```

## Migration Prompt

Use this when database models are ready and approved.

```text
We are working on Phase __: __.

The model changes are approved.

Task:
Generate an Alembic migration for the approved model changes.

Scope:
Use docs/migrations.md. Review the generated migration before applying it.

Permission:
You may generate the migration, but ask me before running alembic upgrade head.
```

Never ask Codex to manually edit the production database.

## Code Review Prompt

Use this after code is added.

```text
Please review the current changes as a code review.

Focus on:
- Bugs
- Security risks
- Missing validation
- Migration issues
- Missing tests

Do not edit files yet. Give findings first with file and line references.
```

## Testing Prompt

Use this when a phase or feature is implemented.

```text
We finished implementing part of Phase __.

Task:
Run or recommend the relevant tests.

Focus:
Tell me what passed, what failed, and what needs to be tested next.
```

## Good Prompt Checklist

Before sending a prompt, check:

- Did I mention the current phase?
- Did I say whether this is planning-only or implementation?
- Did I mention the exact feature?
- Did I give Codex permission or not?
- Did I mention related docs?
- Did I say whether database migrations are allowed?
- Did I say whether tests should be added?

If the answer to most of these is yes, the prompt is probably clear.

## Things To Avoid

Avoid vague prompts like:

```text
Make the backend.
```

```text
Add all the models.
```

```text
Fix the project.
```

```text
Continue everything.
```

These are risky because Codex may make too many assumptions.

Better:

```text
We are working on Phase 1: Authentication And Users.

Task:
Plan the user registration and login endpoints.

Permission:
Planning only. Do not edit files yet.
```

## How To Continue A Previous Session

When returning to the project after a break, prompt Codex like this:

```text
Please inspect the project docs and summarize where we are.

Check:
- AGENTS.md
- docs/core_focus.md
- docs/manual.md
- docs/migrations.md
- docs/new_feature.md

Do not edit files yet. Tell me the current recommended next step.
```

If code work was already started, add:

```text
Also inspect the current file tree and summarize what has already been created.
```

## Phase Discipline

Every feature must belong to a phase.

If the project is in Phase 2 and someone asks for a Phase 8 feature, Codex
should say that the feature is useful but probably should wait. If the feature
has a small part that helps Phase 2, Codex can suggest a reduced version.

Example:

```text
Requested feature:
Group chat for trip members.

Current phase:
Phase 2: Destination Data Foundation.

Likely recommendation:
Defer to a later collaboration phase. Phase 2 should focus on destination data,
rates, admin CRUD, and browsing/filtering.
```

## Permission Rules For Developers

Use these exact phrases when possible:

```text
Planning only. Do not edit files yet.
```

```text
Documentation only. You may edit docs, but do not edit backend code.
```

```text
You may implement this now.
```

```text
You may create the migration, but do not apply it yet.
```

```text
You may run alembic upgrade head.
```

Clear permission makes the work safer and easier to review.

## Recommended Workflow Per Phase

For each phase:

1. Ask Codex to review the phase scope.
2. Ask Codex to propose models, endpoints, services, and tests.
3. Decide what to include.
4. Give permission to implement a small part.
5. Review the files.
6. Generate migration only after model changes are approved.
7. Review migration.
8. Apply migration.
9. Run tests.
10. Update docs if needed.

## Final Reminder

Codex is helpful, but the team still owns the project decisions.

Use Codex for:

- Planning.
- Explaining code.
- Suggesting structure.
- Writing small approved changes.
- Reviewing migrations.
- Finding risks.
- Preparing tests.

Do not use Codex to skip design decisions. Slow, clear prompts will make the
backend much easier to finish.
