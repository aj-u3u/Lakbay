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
- Build a vector query from the message, recent user history, and optional
  context.
- Retrieve the most relevant active destinations, available accommodations, and
  available transportation rows from the Lakbay database.
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

The RAG retriever is implemented without an extra deployment dependency. It
creates hashed numeric vectors from live database rows at request time, compares
them to the user's message with cosine similarity, and sends only the highest
scoring records to the LLM. This is a working vector RAG baseline and can later
be swapped for persistent embeddings or `pgvector` if the project needs larger
semantic search scale.

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
