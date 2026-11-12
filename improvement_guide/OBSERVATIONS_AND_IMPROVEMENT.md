# Planner Observations and Improvement Guide

Recorded: 12 November 2026  
Status: Initial observations and proposed improvements; application changes are not implemented.

## 1. Purpose and scope

This guide records the user's first observations while trying the Lakbay+ planner, relates them to the inspected source code, and describes a proposed improvement approach.

These observations do **not** yet include comments from the capstone panel or judges. Add that feedback separately when available, preserving its source and date.

The authorized work for this update is documentation only. Creating this guide does not authorize changes to application code, API contracts, database tables, migrations, or deployed services.

The findings below come from source inspection. The reported validation failure has not been reproduced against the installed app or hosted API. Distinguish the following throughout this guide:

- **Reported observation:** behavior described by the user.
- **Verified code finding:** behavior visible in the inspected implementation.
- **Hypothesis:** a possible explanation that still needs reproduction.
- **Proposed improvement:** intended future behavior, not an existing capability.

## 2. Existing planning flow

The conversational planning flow currently supports:

1. Ask for destination recommendations.
2. Select **Add to Plan** for a destination.
3. Supply trip details through conversation, such as days, nights, budget, and traveler count.
4. Open the review sheet to confirm trip details, selected activities, transport, and cost assumptions.
5. Generate validated itinerary options once the current planning preview satisfies the generation requirements.
6. Choose an itinerary option and review its planning feedback.
7. Save the selected option to **My Trips** after a successful backend response.

Generating an itinerary does not itself save a permanent trip. Option selection, feedback review, and successful saving are separate steps.

The default Planner tab uses `ConversationalPlannerScreen`. A separate detailed `PlannerScreen` remains accessible through its tune action. Both use shared planning state, but have separate review sheets, so improvements need to account for both paths.

## 3. OBS-001: Manual budget distribution and repeated confirmation

### Reported observation

After the traveler adds a destination and supplies days, nights, budget, and party details in chat, a bottom sheet asks for those details again. It also asks the traveler to enter expense allowances.

Selecting an activity such as **Photography** can reveal another required amount field. The traveler has to decide how to divide the overall budget among food, lodging, transport, activities, and other expenses.

The concern is that the overall budget should guide an automatic proposed distribution instead of making the traveler construct the budget breakdown manually.

### Verified code findings

- Both review sheets initialize available trip fields from the shared planning state. They are prefilled when those values are present, but still expose an editable confirmation form.
- The review sheets require several valid cost amounts before submitting a complete review.
- `ActivitySelectionFields` defaults selected activities to a separate cost amount unless an existing inclusion or allowance says otherwise. A separate amount must be valid before confirmation.
- Activities can instead be explicitly included in a destination or food allowance, with checks intended to avoid counting the same cost twice.
- The backend planning cost engine totals catalog choices and explicit allowances. It does not currently allocate the overall budget automatically.
- Some catalog cost descriptions have unknown charging bases or inclusions. Activity prices are not structured reliable fees in the current planning catalog. The cost engine deliberately keeps such costs unresolved rather than assuming they are free.
- The conversational review sheet currently clears selected accommodation IDs and accommodation pricing assumptions when submitting and uses a whole-trip lodging allowance. Supporting catalog-based lodging in that path requires an intentional change.

The manual allowance behavior therefore reflects the current budgeting design. Automatic distribution is a proposed enhancement, separate from fixing a request validation defect.

### Agreed direction

The user selected these preferences during planning:

| Decision | Selected behavior |
|---|---|
| Budget interaction | Automatically suggest a breakdown; allow optional traveler edits. |
| Missing catalog prices | Use clearly labeled, editable spending estimates that the traveler can accept. |
| Overall budget meaning | Use it as the spending ceiling; do not force spending the full amount. |

### Proposed budgeting behavior

The backend should calculate the proposed breakdown, and Flutter should display it and submit any traveler adjustments. The language model should use that controlled budget context when composing itineraries.

1. Reuse the trip details already collected in chat. Ask for a missing detail or correction only when needed.
2. Apply suitable catalog rates first, using their stated charging units, selected options, traveler counts, room capacities, rooms, and nights. Do not treat an unclear price description as a verified per-person fee.
3. Suggest allowances for unresolved food, transport, lodging, destination, activity, and incidental spending. Explain the assumptions behind those estimates.
4. Identify each amount as a catalog-based calculation, system estimate, or traveler override. An allocation is money set aside, not proof of a supplier's price or availability.
5. Show estimated spending, optional reserve, and unallocated money separately. Money left over does not need to be assigned to an expense.
6. Keep traveler overrides when recalculating other suggestions. If an override or changed trip detail makes the plan unaffordable, show the conflict instead of silently replacing the override.
7. Recalculate affected suggestions when budget, dates, party, destinations, activities, or transport change. Show changed assumptions before the traveler confirms the revised plan.
8. For day trips with zero nights, omit overnight lodging. For overnight stays, use the stated night count rather than silently deriving it from days.
9. Do not assume children receive a discount or are free. Distinguish known child-pricing rules from provisional whole-party estimates.
10. If essential costs exceed the ceiling, show the shortfall and suggest changes to the budget, duration, destinations, activities, lodging, or transport. Do not reduce known prices merely to make the plan fit.

Selecting **Photography** should select the activity without forcing immediate cost entry. Its proposed coverage should appear in the budget review. Only use a zero extra charge or inclusion when supported; otherwise use a disclosed allowance. Do not invent a separate fee merely because an activity was selected.

Accepting labeled estimates should be possible in one budget review. Travelers should not have to type every amount to confirm it. Acceptance must remain explicit, and unresolved nonfinancial requirements or invalid selections must still be addressed.

### Illustrative budget review

Example inputs: **PHP 10,000 for the whole party, two adults, two days, one night**.

These numbers illustrate the proposed presentation only. They are not verified destination prices, local market rates, or an approved allocation formula.

| Budget item | Illustrative amount | How it should be explained |
|---|---:|---|
| Transportation | PHP 1,200 | Selected fare calculation or labeled journey estimate. |
| Destination fees | PHP 600 | Applicable known fees or a disclosed destination allowance. |
| Accommodation | PHP 2,200 | One-night room calculation or a labeled lodging allowance. |
| Food | PHP 1,800 | Suggested allowance for the whole party and trip. |
| Activities | PHP 400 | Suggested additional spending, excluding included costs. |
| Other expenses | PHP 500 | Editable incidental allowance. |
| **Estimated spending** | **PHP 6,700** | Sum of the expense lines. |
| Reserve | PHP 1,000 | Money held aside, separate from estimated spending. |
| **Unallocated money** | **PHP 2,300** | Budget minus estimated spending and reserve. |

The budget review must distinguish an affordable allocation from a fully verified cost estimate. A low allowance does not establish that the proposed trip can actually be purchased at that price.

### Allocation policy still to define before implementation

The interaction model is agreed, but the estimation policy is not yet specified. A later implementation plan must define the source of default allowances, how suggestions scale with party size and duration, reserve defaults, and how lodging or transport alternatives are suggested.

Do not treat the example above as fixed percentages or implement arbitrary market prices from it. Improvements to structured catalog pricing can be planned separately from the initial allowance-based experience.

## 4. OBS-002: Planner chip interactions lead to validation failures

### Reported observation

On the screen titled **Lakbay Planner**, chips above the message input reportedly open bottom dialogs for changing duration, party details, vibe, and similar preferences. After using these controls and trying to generate a trip or continue planning, the app shows **Request Validation Failed**.

### Verified code findings

- The backend converts request-schema validation failures into HTTP 422 responses with `error.code`, `error.message`, and `error.details`.
- Its generic message is `Request validation failed.` Detailed validation entries contain locations and reasons for rejected values.
- The traveler API error parser selects the generic message but does not translate `error.details` into useful field-level corrections.
- Planning schemas validate related values together. Examples include adult count plus child ages matching traveler count, and nights not exceeding days.
- The current `ChatPlanningSession.edit` merges changes into existing state. Related old values can remain unless an editing path updates or clears them deliberately.
- Revision checks already prevent stale previews from replacing newer edits; preserve that behavior.

There is also a source/build discrepancy to resolve: the inspected default conversational planner renders its summary chips without tap handlers. The reported interactive controls may belong to a different installed revision. This does not invalidate the user's observation, but the installed build and request must be identified before attributing the defect to a particular control.

### Hypotheses to investigate

These are investigation cases, not confirmed causes of the reported failure:

- A traveler-count edit leaves an incompatible existing adult count or child-age list.
- A day-count edit leaves a previous night count greater than the new duration.
- A control submits an invalid type, out-of-range value, empty interest, malformed monetary value, duplicate identifier, or unsupported field.
- Previously selected options or pricing assumptions remain after the associated selection changes.
- The installed frontend and deployed backend use different request contracts.

An unavailable catalog selection can also produce a planning selection problem rather than a schema-level HTTP 422. Investigate these outcomes separately.

### Proposed investigation and correction

1. Identify the installed build, active planner entry point, and backend URL used during reproduction.
2. Start a fresh plan and reproduce each reported chip interaction, including successive edits and the final generation action.
3. Identify the failing endpoint: chat, planning preview, planning feedback, or itinerary generation. Capture a sanitized request and the structured validation locations and messages.
4. Compare that request with the actual backend schema. Confirm a cause before changing validation rules.
5. Make related edits atomic. For example, party editing should submit compatible traveler/adult/child values together. A duration edit that conflicts with nights should prompt a correction rather than silently change the intended stay.
6. Show field-specific corrections in the relevant dialog and preserve entered values. Provide a useful general message when an error cannot be associated with one control.
7. Preserve incomplete but valid planning drafts. Missing trip details should guide the next step; malformed or contradictory values should be corrected before submission.
8. Keep generation and saving tied to the current validated planning revision. Do not bypass generation requirements to hide an error.
9. Add a focused regression test using the reproduced failing case before considering the defect fixed.

## 5. Recommended future user flow

1. **Discover:** ask for recommendations and add destinations to the plan.
2. **Describe:** provide days, nights, party details, budget, and interests in conversation or consistent editing controls.
3. **Calculate:** receive a backend-generated breakdown with known costs and labeled suggested allowances.
4. **Review:** see a prefilled trip summary and editable budget breakdown. Resolve only missing details, conflicts, or unsupported selections.
5. **Generate:** accept the current assumptions and generate itinerary options from the reviewed planning context.
6. **Choose:** select an option and review its advisory feedback.
7. **Save:** save the chosen current option, then show success only after backend confirmation.

Editing material trip details after generation should invalidate outdated options and require regeneration. The accepted cost assumptions should remain associated with the plan used to generate and save the selected itinerary.

## 6. Recommended sequence and architecture

| Priority | Work | Expected result |
|---|---|---|
| P0 | Reproduce the validation failure and improve error presentation. | The failing field is known, valid edits succeed, and rejected edits explain what to correct. |
| P1 | Define and implement automatic editable budget suggestions. | Travelers can review a useful breakdown without entering every expense manually. |
| P1 | Simplify confirmation across both planner paths. | Existing conversation details are retained and the review focuses on corrections and acceptance. |
| P2 | Improve structured destination, activity, lodging, and transport pricing. | More suggestions can rely on reviewed data instead of provisional allowances. |

Keep budget calculations and provenance in the backend planning layer. Flutter should manage input, presentation, and optional overrides through the existing Provider and API service boundaries. AI should compose itinerary options using backend-controlled context rather than independently invent the authoritative cost breakdown.

The existing preview, feedback, itinerary-generation, and selected-option-save endpoints are the starting points. Any request or response additions for allocation controls, estimate provenance, acceptance, or override handling are proposals that require a later implementation contract. Check compatibility with the existing generation-run and saved-trip snapshots before deciding whether persistence changes are necessary.

This work aligns with Phase 4 budgeting and the existing Phase 15C activity-cost, Phase 15D child-cost, and Phase 15E AI planning-context work. It does not require inventing an unrelated feature phase. The proposed estimation policy changes the current explicit-allowance behavior and must be documented as such when implemented.

No new API, dependency, external provider, database change, or migration is introduced by this guide.

## 7. Acceptance checklist for future implementation

### Budget and confirmation

- [ ] Chat-provided days, nights, party details, budget, and interests appear correctly in review and survive reopening it.
- [ ] Travelers receive automatic suggestions without entering every expense amount.
- [ ] Catalog calculations, system estimates, traveler overrides, reserve, and unallocated money are distinguishable.
- [ ] Suggested amounts can be accepted together or edited individually.
- [ ] A selected activity does not force immediate manual cost entry.
- [ ] Included activities are counted once; uncertain costs are not silently made free.
- [ ] Zero-night trips omit lodging; overnight calculations use the stated nights and charging units.
- [ ] Party and duration changes recalculate affected suggestions while preserving deliberate overrides.
- [ ] Child fees are supported by known rules or labeled assumptions, rather than an automatic discount.
- [ ] Known costs are not reduced to hide a shortfall; insufficient budgets show actionable alternatives.
- [ ] Rounding preserves consistent totals, and the full budget need not be spent.

### Validation and state

- [ ] The reported failure is reproduced against an identified build and endpoint, or remains explicitly unresolved.
- [ ] Valid partial drafts can be previewed without a generic validation failure.
- [ ] Duration, party, budget, and interest edits send schema-compatible values.
- [ ] Invalid party totals and conflicting days/nights show specific corrections and preserve input.
- [ ] Unavailable selections are distinguished from malformed requests.
- [ ] Rapid edits cannot let an older response overwrite the current draft or its relevant error state.
- [ ] Corrections allow the traveler to continue without restarting the conversation.

### Generation and saving

- [ ] The current accepted budget context reaches itinerary generation.
- [ ] Material edits invalidate outdated generated options.
- [ ] Both planner entry points use consistent budget and validation behavior.
- [ ] Feedback cancellation or save failure does not falsely report a saved trip.
- [ ] The chosen current generation option is saved successfully and appears in My Trips.

Use focused backend costing/schema tests, Flutter provider/API contract tests, review-sheet widget tests, and a final live end-to-end check. Existing tests provide starting points; passing a mocked client test alone does not prove compatibility with the deployed backend.

## 8. Code and documentation references

| Area | References |
|---|---|
| Main planner and option flow | [Conversational planner](../apps/traveler_app/lib/screens/planner/conversational_planner_screen.dart), [main navigation](../apps/traveler_app/lib/screens/navigation/main_navigation.dart) |
| Review sheets | [Conversational review](../apps/traveler_app/lib/screens/planner/conversational_review_sheet.dart), [detailed planner review](../apps/traveler_app/lib/screens/planner/chat_plan_review_sheet.dart) |
| Activity and party controls | [Activity selection](../apps/traveler_app/lib/widgets/inputs/activity_selection_fields.dart), [party details](../apps/traveler_app/lib/widgets/inputs/party_details_fields.dart) |
| Shared state and generation requirements | [Planning session](../apps/traveler_app/lib/models/chat_planning_session.dart), [TripProvider](../apps/traveler_app/lib/providers/trip_provider.dart) |
| Client requests and error handling | [Traveler ApiService](../apps/traveler_app/lib/services/api_service.dart) |
| Backend preview and costing | [Planning service](../services/api/app/features/planning/service.py), [cost engine](../services/api/app/features/planning/costs.py), [planning schemas](../services/api/app/features/planning/schemas.py) |
| Backend validation error envelope | [Exception handlers](../services/api/app/core/exceptions.py) |
| AI generation contract | [AI schemas](../services/api/app/features/ai/schemas.py) |
| Existing verification | [Client planning contract tests](../apps/traveler_app/test/chat_planning_contract_test.dart), [activity field tests](../apps/traveler_app/test/activity_selection_fields_test.dart), [backend preview tests](../services/api/tests/test_planning_preview.py), [backend cost tests](../services/api/tests/test_planning_costs.py) |
| Phase alignment | [Core focus](../services/api/docs/core_focus.md), [new feature review](../services/api/docs/new_feature.md) |

## 9. Verification limits and follow-up notes

- No application code or deployed behavior was changed for this document.
- No live request, device interaction, or hosted-data check was performed during this analysis.
- A local Python schema check could not run because the available interpreter did not have `pydantic` installed. The validation scenarios above are source-based investigation cases, not runtime reproductions.
- The exact chip behavior, request payload, and rejected field remain pending reproduction.
- The source of automatic estimate defaults and their allocation policy remain decisions for the later feature implementation plan.
- Future panel and judge comments should be added with their own dated attribution, without rewriting these initial observations as panel findings.
