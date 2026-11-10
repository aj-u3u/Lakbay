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

## Saved catalog facts in itinerary prompts

The generation service reloads selected active catalog records for each request.
As of 10 November 2026, its prompt retains the destination description, saved
place pin, optional arrival coordinates/readiness, fees, hours, best visiting
time, access instructions, travel-time note, travel notes and packing advice.
Accommodation and transportation rows retain both `currency` and
`charging_unit` alongside their price and canonical ID. A null unit stays null;
the model must not infer a per-person, room, night or stay basis from the amount.

Pins support approximate planning. Free-text access and travel-time notes are
reference data, not live route calculations or evidence of current opening,
booking or entrance verification. Missing values remain unknown. These fields
do not bypass selected-ID, cost-arithmetic or budget validation. The prompt
versions are `phase5_itinerary_catalog_facts_v3` for direct requests and
`phase15e_calculated_route_order_v5` for planning requests.

The traveler retains the five saved travel-detail fields and displays nonempty
values in the existing Travel Notes & Tips section after catalog refresh. An
empty or cleared field does not fall back to demo advice. The admin editor
already saves these fields without requiring a separate arrival point.
`tests/test_catalog_planning_flow.py` exercises admin edits through public reads,
Top 5, pin-based planning preview and a mocked Groq generation request, including
known and unknown charging units. This is local contract verification, not a
live admin-to-phone deployment check.

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
prompt and response also include `geo_analytics_context`. It ranks up to five
interest matches **within the selected IDs** using the Phase 3 recommendation
scorer. It uses request interests when supplied, otherwise planning-state
interests. If a planning route summary exists for two or more selected destinations,
it asks the Phase 15B service for scored groups (up to three). The grouping route
covers the destinations in each group and excludes the trip origin; it is a
separate route calculation from the origin-inclusive planning preview. Group
scores, component scores, reasons, provider, estimated flag, and warnings retain
their Phase 15B meaning. A group with unknown catalog destination costs is
excluded rather than treated as free. With no eligible group, the list is empty
and `grouping_status=no_eligible_groups`; with no grouping call, a route-backed
selected set may still appear as `score_status=not_scored`.

The context also includes the planning route's provider, order, duration,
distance, estimated flag, arrival verification, and the budget's completeness,
fit, subtotal, and total estimate when known. The prompt warns that an estimated
route or unverified arrival does not establish feasibility. Grouping uses the
existing per-user Phase 15B rate limit as well as the planning route limit.
Its result is read-only and saved with the validated generation run for audit.
No unselected recommendation ID is passed to the model or allowed in its output.

When the planning route is `calculated`, the prompt and validator use the same
ordered destination IDs from its stops. The prompt calls this list
`required_destination_visit_order`. The validator reads days in numerical order
and activities in their listed order. It skips null destination IDs and counts
consecutive activities at one destination as a single visit. It rejects a model
run if any option changes the order or revisits an earlier destination. The
configured fallback can try the same order. The start and return leg remain in
the stored route, outside the itinerary's destination ID sequence. Requests
without a calculated route retain the existing destination coverage check.

The traveler confirms road access when calculating a personal-vehicle route.
When a confirmed journey changes, the route request itself is removed
(`route_preferences` becomes null), not only the confirmation. The traveler
then recalculates the route and confirms the revised journey. The chat endpoint
does this for start, destination, and return changes. Chat cannot change the
transport selection; the traveler app clears the route request itself when the
traveler changes transport, start, destinations, or return choice in its own
controls. This keeps the visit sequence consistent with the route. Daily transfer schedules and
opening hours still need their own feasibility checks.

The response includes `selected_generation_run_id`, `planning_preview`, and
`geo_analytics_context`. The preview's
`budget.lines` distinguish verified catalog charging units, catalog prices with
assumed charging units, and traveler allowances. A catalog amount does not
verify the number of charges, a return fare, availability, or route coverage.
`estimated_total_cost` on an AI option and `estimated_cost` on an AI activity
have `cost_source=ai_draft_estimate`; the backend preview budget is the cost
projection used when saving. Missing costs remain visible as a partial preview.
When Phase 15D age rules are supplied, the preview and prompt retain itemized
adult and child lines and unresolved age bands. Those rules are traveler
assumptions; AI does not decide whether a child qualifies for a discount.

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
- Pass the retrieved context into the configured Groq model (currently
  `openai/gpt-oss-120b`) so the answer is grounded in actual Lakbay data.
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
- Itinerary generation sends a strict Groq JSON schema. Configure models that
  support strict structured output; the service still checks option count, days,
  every selected destination ID (with or without a planning preview), budget,
  and whether each option total equals the sum of its activity costs after the
  model responds. The chat endpoint continues to use ordinary text responses.
- Every returned option includes `quality_warnings`. Lakbay flags current
  opening hours as unverified because the destination catalog has no hours
  verification timestamp. It also flags ferry or boat access when no selected
  catalog fare has a known charging unit, draft group costs, and route times
  when no planning preview was supplied. These warnings are shown with the
  options in the Flutter planner. They do not verify live hours, fares, or
  arrival access.
- If any option omits a selected destination or its total disagrees with its
  activity costs, that model run is invalid. The service can try a configured
  fallback; if no model passes, the endpoint returns `ai_generation_failed`
  instead of showing an incomplete itinerary.

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

```json
{
  "chat_response": "I noted your departure city.",
  "state_updates": {"origin": {"label": "Davao City"}}
}
```

`origin` must be an object with `label`; a bare string is malformed. The prompt
also tells the model not to infer overnight stays from trip days and not to
claim that unconfirmed fares or meals are covered by a budget.
The backend independently checks `night_count` and `return_to_origin` against
the current traveler message. It accepts a night count when the traveler gives
the count, clearly says day trip or no overnight stay, or answers the latest
assistant question about nights with a count. It accepts a return preference
when the traveler says round trip, one way, return or no return, or answers the
latest assistant question about returning with yes or no. A model value that
does not match that evidence is omitted; other valid fields can still apply,
and the response asks the traveler to confirm the omitted detail. Repeating a
value already present in the plan does not trigger a warning unless it
conflicts with an explicit correction. Ambiguous choices such as “one or two
nights” and “round trip or one way” do not confirm either field.

- `planning.input_revision`: the echoed revision for stale-response handling.
- `planning.state_updates`: the accepted changes to origin label, destinations,
  budget, travelers, duration, return preference, or interests. Origin
  coordinates remain under Flutter's map-selection control.
- `planning.update_status`: `applied`, `no_changes`, `needs_clarification`, or
  `invalid_output`.
- `planning.preview`: the normal planning-preview response recalculated from the
  resulting state.
- `planning.recommendations`: up to five active destinations that actually match
  the current interests and have a verified visitor arrival point, no unresolved
  non-road access hint, and a provider-confirmed route from the map-selected
  origin for the single selected driving or walking mode. Haversine and public
  transport estimates do not qualify. Candidates sort by the existing Phase 3
  preference score, then destination ID. Each item includes its catalog ID,
  score, matching reasons, destination estimate, route provider, mode, distance,
  and duration. The estimate is not a full-trip budget or a current opening,
  booking, or permit check. This lookup does not save a preference signal.
- `planning.recommendation_total_candidates` counts all verified, reachable
  preference matches, even when only the first five are returned.
  `planning.recommendation_shortfall_reason` is null when at least five qualify;
  otherwise it states why fewer qualify, including missing origin/mode, missing
  arrival verification, non-road connections, or unconfirmed routes. An empty
  preference match stays empty. With interests but fewer than five qualifying
  places, the backend uses this reason as the chat reply instead of trusting
  potentially conflicting model prose.

The model cannot change transport, activity, accommodation, route, fuel, or
pricing selections; Flutter sends those through `planning_state` or to
`POST /api/v1/planning/preview`. Newly proposed destination IDs must be grounded
in retrieved catalog context. Unsupported destination IDs leave that selection
intact. If one allowed update field has a malformed value, the backend validates
the remaining fields individually and may apply the safe ones. It replaces the
model's reply with a notice naming the rejected detail so a false confirmation
is not displayed. Unknown update fields, malformed top-level JSON, or an invalid
final combined state still leave the current state intact. The response includes
its preview in each case. Flutter should retain the returned `preview.state`,
increment its revision after user edits, and ignore responses for older revisions. Omitting
`planning_state` keeps the ordinary free-text chat flow.
When any accepted `state_updates` change the plan, Flutter clears previously
generated itinerary options even if `update_status` is `needs_clarification`
because another proposed field could not be accepted.

When a conversation changes selected destination IDs, the backend clears old
transport, activity, accommodation, and price selections before building the
next preview. The traveler confirms the new destination allowances and trip
costs before generation. Flutter displays the catalog suggestions as selectable
cards, carries the conversation and current state across turns, and sends the
exact chosen generation run and option number when saving a trip.

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

The AI itinerary endpoint uses selected destinations, accommodations,
transportation options, budget, interests, travel style, and special
requirements. Planning-enabled generation now passes the preview and selected-ID
recommendations plus Phase 15B scored groups when a route can be calculated.
Child-aware cost projections remain dependent on Phase 15D pricing rules.

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
