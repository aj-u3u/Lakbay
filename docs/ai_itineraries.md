# AI Itinerary API Guide

This guide covers Phase 5: AI Itinerary Generation.

Phase 5 creates itinerary drafts from selected destination data. It does not save
real trips yet. Saving a chosen option belongs to a later trip management phase.

It also includes a free-text Lakbay AI chat endpoint. The chat endpoint uses a
local vector RAG retriever over live Lakbay database records before calling the
configured Groq model.

## Endpoint

```text
POST /api/v1/ai/itineraries/generate
POST /api/v1/ai/chat
```

## Planning preview to itinerary options

The existing generation endpoint also accepts `planning_state` and
`input_revision`. For this mode, send the complete state last returned by
`POST /api/v1/planning/preview`, together with matching `destination_ids`,
`accommodation_ids`, `transportation_ids`, `traveler_count`, `day_count`, and
whole-trip `total_budget`. Catalog transportation IDs come from selected
`transportation:<id>` options; personal-vehicle and walking choices have no rate
ID. A mismatch or unavailable selection is rejected.

The backend recalculates the preview, sends its budget lines and route to the
configured AI model, and returns at least the configured number of validated
options. Each option must reference every selected destination and catalog rate
ID exactly; an omitted or substituted ID invalidates that model run. The
response includes `selected_generation_run_id` and `planning_preview`. Its
`budget.lines` distinguish verified catalog charging units, catalog prices with
assumed charging units, and traveler allowances. A catalog amount does not
verify the number of charges, a return fare, availability, or route coverage.
`estimated_total_cost` on an AI option and `estimated_cost` on an AI activity
have `cost_source=ai_draft_estimate`; the backend preview budget is the cost
projection used when saving. Missing costs remain visible as a partial preview.

To save one option, send its `option_number` and
`selected_generation_run_id` to `POST /api/v1/trips/from-ai-option`. The run
must belong to the current user. Generation stores the validated options and
preview in the run record, so the save endpoint does not accept replacement
itinerary text or different destination IDs from the client.

Authentication:

- Requires a normal user bearer token.
- Admin tokens can call it only if they are also treated as authenticated users,
  but the intended caller is the Flutter traveler account.

Purpose:

- Send selected destination, accommodation, and transportation IDs.
- Ask a configured Groq model to produce structured itinerary options.
- Validate the AI result before returning it to Flutter.
- Log each model attempt in `ai_generation_runs`.

Free-text chat purpose:

- Accept a natural-language user message and optional recent chat history.
- Resolve the target area, departure point, and interest from the message,
  user history, and recognized context fields. Explicit destination changes
  replace earlier preferences.
- Filter and rank active destinations first, then select available accommodation
  and transportation records linked to those destinations.
- Pass the retrieved context into Groq/Qwen so the answer is grounded in actual
  Lakbay data.
- Return the assistant response plus the retrieved context used for traceability.

## Environment Variables

Add these values to `.env` before using live Groq calls:

```env
GROQ_API_KEY=
GROQ_MODEL_DEFAULT=
GROQ_MODEL_FAST=
GROQ_MODEL_QUALITY=
GROQ_MODEL_FALLBACK=
GROQ_MODEL_COMPARE_A=
GROQ_MODEL_COMPARE_B=
GROQ_MODEL_COMPARE_C=
GROQ_BASE_URL=https://api.groq.com/openai/v1
GROQ_REQUEST_TIMEOUT_SECONDS=60
GROQ_MAX_RETRIES=1
GROQ_TEMPERATURE=0.30
GROQ_MAX_TOKENS=4096
AI_ITINERARY_OPTION_COUNT=5
AI_MODEL_COMPARISON_ENABLED=false
```

Recommended minimum for normal use:

```env
GROQ_API_KEY=your-groq-key
GROQ_MODEL_QUALITY=your-selected-model-id
GROQ_MODEL_FALLBACK=another-selected-model-id
```

Recommended minimum for thesis comparison:

```env
AI_MODEL_COMPARISON_ENABLED=true
GROQ_MODEL_COMPARE_A=model-a
GROQ_MODEL_COMPARE_B=model-b
GROQ_MODEL_COMPARE_C=model-c
```

Keep model IDs configurable because Groq model availability can change by
account tier and date.

## Migration

Phase 5 adds the `ai_generation_runs` table.

After pulling or receiving the Phase 5 code, run:

```bash
alembic upgrade head
alembic current
```

Expected current revision:

```text
0005_ai_generation_runs (head)
```

Do not manually create this table in Neon. Use Alembic.

## Request Body Example

Use real IDs from your database. The numbers below are examples only.

```json
{
  "total_budget": "10000.00",
  "traveler_count": 2,
  "day_count": 2,
  "destination_ids": [1],
  "accommodation_ids": [1],
  "transportation_ids": [1],
  "meal_cost_per_day": "500.00",
  "miscellaneous_cost": "300.00",
  "interests": ["beach", "food"],
  "travel_style": "relaxed",
  "special_requirements": "Prefer a slow-paced plan.",
  "model_role": "quality",
  "compare_models": false,
  "allow_fallback": true
}
```

Field notes:

- `destination_ids` must contain active destinations.
- `accommodation_ids` must be available rows that belong to the selected
  destinations.
- `transportation_ids` must be available rows that belong to the selected
  destinations.
- `model_role` can be `default`, `fast`, or `quality`.
- `compare_models=true` requires `AI_MODEL_COMPARISON_ENABLED=true` and at least
  two comparison model variables.
- `allow_fallback=true` lets the service try `GROQ_MODEL_FALLBACK` if the first
  model fails or returns invalid output.

## Free-Text Chat RAG Example

```json
{
  "message": "I want a relaxed beach stay in Mati with a room near the destination.",
  "history": [
    {
      "role": "assistant",
      "content": "Tell me what kind of Davao trip you want."
    }
  ],
  "model_role": "default",
  "allow_fallback": true,
  "use_rag": true,
  "rag_limit": 6
}
```

The response includes:

- `chat_response`: natural-language answer from the LLM.
- `mode`: `rag_chat` when retrieved context was used, otherwise `chat`.
- `retrieved_context`: ranked destination, accommodation, or transportation
  facts used in the prompt.
- model metadata and token usage when Groq returns it.

The RAG retriever is implemented without an extra deployment dependency or an
additional model call. It normalizes beach/beaches, distinguishes departure
locations from target locations, filters destinations by area and interest, and
uses hashed vectors to rank eligible destinations. Available stays and transport
records are selected through the destination ID instead of competing globally
for context slots. The default six-record limit can hold two destinations with
one stay and one transport option each; smaller limits may omit related rates.

The internal Groq payload includes `retrieval_coverage` to distinguish no matching
catalog destinations, requests needing clarification, disabled retrieval, no
available related rates, and records omitted by the context limit. Empty catalog
results do not establish that a place or transport option does not exist. Catalog
availability flags do not establish live room vacancy, and destination cost
estimates are not complete trip budgets. RAG grounding does not add public
request fields. Planning-aware chat adds the optional contract below.

## Planning-Aware Chat

To carry a preview through conversation, send the complete current planning state
and the client's current input revision to the existing authenticated chat
endpoint:

```json
{
  "message": "Make this a solo day trip.",
  "input_revision": 4,
  "planning_state": {
    "origin": {"label": "Davao City"},
    "destination_ids": [12],
    "total_budget": "6000.00",
    "traveler_count": 2,
    "day_count": 2,
    "night_count": 1,
    "interests": ["beach"]
  }
}
```

When `planning_state` is supplied, the model must return a JSON object containing
`chat_response` and partial `state_updates`. The backend validates the patch,
retains fields the traveler did not change, and returns:

- `planning.input_revision`: the echoed revision for stale-response handling.
- `planning.state_updates`: the accepted changes to origin label, destinations,
  budget, travelers, duration, return preference, or interests. Origin
  coordinates remain under Flutter's map-selection control.
- `planning.update_status`: `applied`, `no_changes`, `needs_clarification`, or
  `invalid_output`.
- `planning.preview`: the normal planning-preview response recalculated from the
  resulting state.

The model cannot change transport, activity, accommodation, route, fuel, or
pricing selections; Flutter sends those through `planning_state` or to
`POST /api/v1/planning/preview`. Newly proposed destination IDs must be grounded
in retrieved catalog context. Unsupported destination IDs or invalid structured
output leave the current state intact, and the response still includes its
preview. Flutter should retain the returned `preview.state`, increment its
revision after user edits, and ignore responses for older revisions. Omitting
`planning_state` keeps the ordinary free-text chat flow.

## Response Shape

The response includes:

- `options`: the first successful validated itinerary option set.
- `model_runs`: one entry per model attempt.

Each run records:

- AI generation run ID.
- Model role and model ID.
- Run status.
- Validation status.
- Response time.
- Token usage when Groq returns it.
- Error message when the model output fails validation.
- Options for successful runs.

## Validation Rules

The backend rejects AI output when:

- The response is not valid JSON.
- The JSON does not contain an `options` list.
- The option count is below `AI_ITINERARY_OPTION_COUNT`.
- A generated destination, accommodation, or transportation ID was not included
  in the request.
- The number of days does not match `day_count`.
- The generated total cost exceeds `total_budget`.
- The option marks itself as over budget.

This keeps AI output as a draft and prevents invented catalog data from being
treated as real backend data.

## RAG Grounding Rules

The chat prompt instructs the model to treat retrieved Lakbay rows as the
primary source for destination, accommodation, transportation, cost, route, and
accessibility facts.

Important rule:

```text
If retrieved context is missing or weak, the assistant should ask a focused
follow-up or say what information is missing instead of inventing exact facts.
```

## Planned AI Geo-Analytics Context

The current AI itinerary endpoint uses selected destinations, accommodations,
transportation options, budget, interests, travel style, and special
requirements. Phase 15 should make the AI more route-aware by passing
backend-calculated geo-analytics context into the prompt.

The backend should calculate facts first:

- top 5 recommended destinations.
- destination groups.
- route summaries.
- route warnings.
- budget projections.
- activity cost projections.
- child-aware cost notes when available.
- transportation mode context.

Then AI should organize and explain the itinerary using those facts.

Suggested prompt context shape:

```json
{
  "top_recommendations": [],
  "destination_groups": [],
  "optimized_route": {},
  "budget_projection": {},
  "travel_mode_context": {},
  "warnings": []
}
```

Important rule:

```text
AI should not invent destinations, costs, route durations, transportation
options, or child pricing rules. It should use backend-provided context and the
backend should validate the response.
```

## Testing

Run the Phase 5 tests:

```bash
python -m pytest tests/test_phase5_ai_itineraries.py -q
```

Run the full suite:

```bash
python -m pytest -q
```

The test suite mocks Groq. It does not spend API credits.

Run the Phase 4 planning-aware chat tests:

```bash
python -m pytest tests/test_planning_chat.py -q
```

## Swagger Test Steps

1. Run migrations with `alembic upgrade head`.
2. Start the API with `uvicorn app.main:app --reload`.
3. Register or log in as a normal user.
4. Authorize Swagger with the bearer access token.
5. Confirm you have real destination, accommodation, and transportation IDs.
6. Send `POST /api/v1/ai/itineraries/generate`.

If the response says a model is not configured, check `.env`.
If the response says generation failed, inspect `model_runs` in the response and
the `ai_generation_runs` table for validation or Groq errors.
