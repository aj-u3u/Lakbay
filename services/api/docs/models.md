# AI Model Guide

This document defines how Lakbay should choose and manage AI models for
itinerary generation and model comparison.

Last checked against Groq documentation: September 16, 2026.

## Why This Exists

The proposal mentions these Groq model IDs:

- `llama-3.1-8b-instant`
- `llama-3.3-70b-versatile`
- `qwen/qwen3.6-27b`

Groq's deprecation page currently lists `llama-3.1-8b-instant` and
`llama-3.3-70b-versatile` as deprecated with an August 16, 2026 shutdown date
for free and developer-tier usage. Enterprise customers with committed-spend
contracts may be different.

Because of that, Lakbay should not hard-code model IDs in the backend. Model IDs
should live in environment variables so the project can update models without
changing application code.

Sources:

- [Groq model deprecations](https://console.groq.com/docs/deprecations)
- [Groq supported models](https://console.groq.com/docs/models)
- [Groq model permissions](https://console.groq.com/docs/model-permissions)

## Environment Variables

Use these variables in `.env`:

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

Suggested meaning:

- `GROQ_MODEL_DEFAULT`: the normal model used for itinerary generation.
- `GROQ_MODEL_FAST`: a lower-cost or faster model for drafts, retries, and
  lightweight chatbot responses.
- `GROQ_MODEL_QUALITY`: a stronger model for final itinerary generation.
- `GROQ_MODEL_FALLBACK`: a backup model if the default model fails.
- `GROQ_MODEL_COMPARE_A`: first model for thesis comparison.
- `GROQ_MODEL_COMPARE_B`: second model for thesis comparison.
- `GROQ_MODEL_COMPARE_C`: third model for thesis comparison.
- `GROQ_BASE_URL`: Groq OpenAI-compatible base URL.
- `GROQ_REQUEST_TIMEOUT_SECONDS`: request timeout for live AI calls.
- `GROQ_MAX_RETRIES`: retry count for temporary Groq request failures.
- `GROQ_TEMPERATURE`: generation randomness. Keep this low for structured JSON.
- `GROQ_MAX_TOKENS`: maximum response tokens for generated itinerary JSON.
- `AI_ITINERARY_OPTION_COUNT`: minimum number of itinerary options to request and
  validate.
- `AI_MODEL_COMPARISON_ENABLED`: enables comparison mode for configured compare
  models.

Do not put API keys in documentation, commits, screenshots, or shared messages.

## Recommended Current Direction

For implementation planning, prefer a flexible model selection service:

```text
request purpose -> model role -> environment variable -> Groq model ID
```

Example:

```text
itinerary draft -> fast -> GROQ_MODEL_FAST
final itinerary -> quality -> GROQ_MODEL_QUALITY
normal chatbot request -> default -> GROQ_MODEL_DEFAULT
model comparison -> compare_a/compare_b/compare_c -> comparison variables
```

This keeps the backend stable even if Groq changes model availability.

## Deprecated Model Handling

Before coding AI integration, confirm the exact model IDs in the Groq console or
through Groq's models endpoint.

If a configured model is unavailable:

1. Log the failed model ID.
2. Return a clear internal error to the service layer.
3. Retry once using `GROQ_MODEL_FALLBACK` if configured.
4. Save the failure in the AI generation run table once that table exists.
5. Do not silently switch models during thesis comparison runs unless the run is
   explicitly marked as a fallback run.

## Thesis Comparison Notes

The original objective compares Llama 3.3 70B, Llama 3.1 8B, and Qwen 3.6 27B.
Because two of those IDs may no longer be available on free/developer tiers, the
research write-up should make the model availability clear.

Possible approaches:

- Use the original model names only if the account can still access them.
- Use Groq's recommended replacement models and document the substitution.
- Compare three currently available models through `GROQ_MODEL_COMPARE_A`,
  `GROQ_MODEL_COMPARE_B`, and `GROQ_MODEL_COMPARE_C`.

For fairness, each comparison run should store:

- Model ID.
- Prompt version.
- Input preferences.
- Selected destinations.
- Response time.
- Token usage if available.
- Validation result.
- Budget adherence.
- Route feasibility.
- Geo-analytics context used by the prompt.
- Recommendation relevance score.
- Itinerary feedback score.
- User or evaluator relevance score.

## Output Validation Rule

AI-generated itineraries should be treated as drafts until validated.

The backend should check:

- The response is valid JSON or can be parsed into a known schema.
- Destinations exist in the database.
- Days and times are valid.
- Costs are numeric after parsing.
- Total cost fits the requested budget.
- Route order can be optimized or at least estimated.
- The response does not invent unavailable accommodations, transport options, or
  prices unless clearly marked as estimated.

Only validated itinerary data should be saved to permanent trip tables.
