# Demo Rehearsal Kit

Prepared: 14 November 2026
Status: Rehearsal plan. Nothing here has been run end to end yet; every "Expected" line is something to confirm and record, not a claim that it passes.

Covers PF-11 (group sharing) and PF-13 (prepared prompts and evidence) from the [panel feedback guide](PANEL_FEEDBACK_IMPROVEMENT_GUIDE.md), and shows the improvements made since: field-level error messages, discovery cards that stay after adding a stop, and suggested budget amounts.

## 1. Facts checked against the live catalog (14 Nov 2026)

The public catalog at `https://lakbay-api-sg.onrender.com/api/v1/destinations` returned 41 published places.

| Place | ID | District | Use in demo |
|---|---|---|---|
| People's Park | 1 | Davao City | Scenario 3 |
| National Museum of the Philippines - Davao | 15 | Davao City | Scenario 3 |
| Samal Island Beach Area | 4 | Davao del Norte | Scenario 2 (replaces "Kaputian") |
| Eden Nature Park | 3 | Davao City | Scenario 1 follow-up |
| Bemwa Farm | 38 | Davao City | Updated catalog data, day-use options |

**There is no "Kaputian" place in the published catalog.** The older prompt "Help me plan a Kaputian trip..." will not match a catalog entry. Use Samal Island Beach Area, or publish a Kaputian place first.

The eight researched places (Amador, Apata, Apo Pantok, Banwa Kasili, Baradi, Bat-Te Antaon, Bayna, Antag) are still staged, not published, so they cannot appear in the app yet. Do not demo them until Place review publishes them.

## 2. Before the demo (do the day before, repeat one hour before)

- [ ] Render service shows the latest commit **Live** (Deploys tab). Note the commit: ______
- [ ] `https://lakbay-api-sg.onrender.com/api/v1/health` answers quickly. UptimeRobot should keep it awake; if the first call is slow, warm it with two calls.
- [ ] Latest debug APK installed on the demo phone (`adb install -r`). Note the build time: ______
- [ ] Two test accounts exist and can sign in: **Owner** and **Member**. Use real registered emails; sharing works by registered email. Credentials stay with you, never in this file.
- [ ] Phone has stable data or Wi-Fi, and battery above 50%.
- [ ] Sign out and in once on the owner phone so the session is fresh.
- [ ] Open the admin app (`flutter run -d edge`) and confirm the places in section 1 are listed as published.
- [ ] Screen recording tool ready (fallback, section 6).

## 3. What the improvements let you show

| Improvement | How to show it | What to say |
|---|---|---|
| Discovery cards stay after adding a stop | Scenario 1, steps 3 to 5 | Browsing and planning are one flow; you can keep adding places. |
| Suggested budget amounts | Scenario 2, review sheet | The whole-trip budget is a ceiling. Amounts are labelled system estimates, editable, never catalog prices. |
| Clear error messages | Scenario 2 optional step: enter 5 nights on a 2-day trip | The app names the field to fix instead of a generic failure. |
| Honest route and cost labels | Scenario 3 | Estimates are marked as estimates; unresolved crossings are not drawn as confirmed. |

## 4. Scenarios

Record the actual result of each run in section 7. If something fails, write down what happened; do not change the expected result to match.

### Scenario 1: Discovery to cards

1. Planner tab, fresh plan. Send: `Can you provide me a list of tourist spots in Davao City?`
2. **Expected:** catalog-backed cards with Add buttons, or a clear message if no interest was recognised. If none appear, follow with `Show me waterfalls in Davao` (recognised interests: beach, mountain, waterfall, food; "nature" is not recognised yet).
3. Tap **Add** on one card.
4. Send: `Show me more waterfalls`.
5. **Expected:** new cards, none already in the plan. Add a second one.
6. Open the review sheet.
7. **Expected:** both places appear once each.

### Scenario 2: Overnight plan and budget

Prompt (uses a place that exists):
`Help me plan a Samal Island Beach Area trip for 3 days and 2 nights for 2 adults, with a PHP 10,000 whole-trip budget. Show the costs and assumptions.`

1. Send the prompt. Add the place if a card is offered.
2. Open the review sheet. Confirm days 3, nights 2, travelers 2, budget 10,000.
3. Tap **Suggest amounts from my budget**.
4. **Expected:** transport, food and lodging fill with system estimates (₱2,000 / ₱2,500 / ₱3,000 for ₱10,000 with nights). The note says they are estimates.
5. Edit one amount by hand, then tap the button again. **Expected:** your edited amount stays.
6. Confirm amounts, then generate the itinerary.
7. **Expected:** comparison cards labelled "AI draft estimate", no star ratings. Totals stay inside the budget or the sheet warns about the shortfall.
8. Optional: change nights to 5 with days 3 and confirm. **Expected:** a message naming the field, not a generic failure.

Say plainly: crossings to Samal are advisory; the app does not know a ferry schedule or fare.

### Scenario 3: Multiple stops and group sharing

Prompt:
`Starting in Tagum City, help us plan a day trip to People's Park and the National Museum in Davao City for 2 adults using a private vehicle, within a PHP 5,000 whole-trip budget.`

1. Send the prompt. Make sure both places end up in the plan (People's Park #1, National Museum #15).
2. Review sheet: 1 day, 0 nights. Tap **Suggest amounts**. **Expected:** no lodging suggestion.
3. Generate. Pick one option and save it to **My Trips** after the feedback screen.
4. **Expected:** the saved trip opens from My Trips with both stops and one map.
5. Group sharing (section 5), then continue.

Known limit to state if asked: the route starts from the typed place name, not a verified Davao arrival point. Local-start logic is a planned improvement.

## 5. Two-account group sharing check (PF-11)

Both accounts must be on the same backend.

1. **Owner** saves the Scenario 3 itinerary.
2. Owner opens the trip, goes to the group dashboard, adds the Member by registered email.
3. **Member** signs in on a second phone or after signing out, opens **My Trips**, and pulls to refresh if needed.
4. **Expected:** the Member sees the same trip.
5. Perform one shared action (for example add a task or expense as the Member) and refresh as the Owner. **Expected:** the Owner sees it.
6. Negative check: sign in as a third account that is not a member. **Expected:** the trip is not visible.

Say plainly: "Invite" adds an existing registered account. It does not send an email, and there are no public share links.

## 6. Fallback plan

| Problem | Do this |
|---|---|
| First request is slow | Wait up to 15 seconds; the login screen shows a "waking server" note. Warm the server beforehand. |
| AI provider rate limit or error | Wait 10 to 30 seconds and retry once. The app keeps your draft. Do not retry repeatedly: the per-user cap is 60 AI requests a day. |
| Generation fails twice | Switch to the screen recording, labelled clearly as a recording. Show the review sheet and budget suggestions live, which do not need the AI. |
| No network | Use the screen recording and the admin app screenshots. State that it is a recording. |
| A place is missing from the catalog | Say so and use a place from section 1. Do not invent catalog data. |

Record the fallback videos in advance from a successful run of each scenario.

## 7. Evidence log

Fill one row per run. Keep screenshots with the date in the file name.

| Date | Scenario | App build | Backend commit | Expected | Actual | Pass / Fail | Notes or limitation |
|---|---|---|---|---|---|---|---|
| | 1 | | | | | | |
| | 2 | | | | | | |
| | 3 | | | | | | |
| | Sharing | | | | | | |

## 8. Things to avoid claiming

- Do not call suggested amounts verified prices. They are system estimates that start at fixed shares of the budget.
- Do not call generated itineraries ranked by rating; destination ratings are sample data.
- Do not say ferry or barge schedules and fares are known.
- Do not say "Invite" sends an email.
- Do not present the staged places as available until they are published.
- Do not claim speed numbers without a measurement. Chats were about 1 to 3 seconds after the move to Singapore; measure again before quoting.

## 9. Gaps this kit exposed (for later work)

- No Kaputian place in the catalog.
- "Nature" is not a recognised interest, so a plain "nature spots" request may not return cards.
- The suggest button is on the conversational review sheet only, not on the detailed planner.
- The "other" budget share is returned by the backend but has no box in the sheet.
- Local Davao start point and route consistency checks are still planned (PF-01, PF-02).
