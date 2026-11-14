# Place Review Publishing Checklist

Prepared: 14 November 2026
Source of place facts: team catalog research of 13 Nov 2026 and the earlier handoff. The staged records were loaded from that research; open each one in the queue and confirm before publishing. Source URLs and access evidence must come from a real page you have checked. Nothing in this file is a source link.

## 1. What publishing actually requires (from the code)

Checked in `candidate_service.py` and the admin screen `destination_candidates_screen.dart`.

| Requirement | Detail |
|---|---|
| Category, district, visitor purpose | All three must be filled, or publish fails with "Confirm the district and category, and explain the visitor purpose". |
| Visitor access policy | Choose Public, Customers or Permit required. "Unverified" blocks publishing. |
| Access source URL | A real `http://` or `https://` link. Anything else is rejected. |
| "I checked this access evidence" | Tick it, then **Save review**. Saving records the verification time. |
| Save before publish | The Publish button stays disabled while there are unsaved changes. Save first. |
| No nearby duplicate | A catalog place with the same name close by blocks publishing (HTTP 409). |

What gets copied into the catalog when you publish: name, description, district, location, category, vibes, activities, latitude, longitude, estimated cost, entrance fee, overnight fee and operating hours. The new place is created with **route_ready = false**. The access policy, source link and visitor purpose stay on the review record and are not copied to the catalog place.

Rooms and cottages are not part of publishing. Add them afterwards in the admin **Accommodation** screen (section 6).

## 2. Before you start

- [ ] Admin app running: from `apps\admin_app` in PowerShell, `flutter run -d edge`.
- [ ] Signed in with one of the three existing admin accounts. If you register your own, use the `ADMIN_REGISTRATION_CODE` from Render yourself. Do not paste a password or the code into any chat.
- [ ] Render shows the latest commit Live, so the admin app talks to the current backend.
- [ ] Open **Place review**, set the status filter to **Staged**, and use the search box to find each place by name.

## 3. Places to publish

Staged review record IDs and facts are from the research and handoff. Confirm each in the queue.

| # | Place | Review ID | Access policy to set | Hours | Admission (research) |
|---|---|---|---|---|---|
| 1 | Amador Resort (was Amador Inland Resort) | 54 | Public | Daily 8-5 | Adults ₱100-₱120, children ≤10 ₱60-₱80, toddlers often free |
| 2 | Apata Farm | 124 | Public | Daily 7-5 | Adults ₱50, children ≤10 ₱30, toddlers free |
| 3 | Apo Pantok Falls | 161 | Permit required | Daylight 6-5 | Registration ₱30-₱50, children free to ₱20; guide tip ₱200-₱300 per group |
| 4 | Banwa Kasili Falls | 162 | Permit required | Daylight 6-4 | Registration ₱50; guide ₱300-₱500 per person; not advised for small children |
| 5 | Baradi Falls | 163 | Permit required | Daylight 6-4 | Registration ₱30-₱50, children free to ₱20; guide ₱200-₱300 per group |
| 6 | Bat-Te Antaon Falls | 164 | Permit required | Daylight 6-4 | Fee ₱30-₱50, young kids free; guide ₱250-₱350 per group; in the Matigsalug ancestral domain |
| 7 | Bayna Falls | 165 | Permit required | Daylight 6-4:30 | Fee ₱30-₱50, children free to ₱20; guide ₱200-₱300 |

**Do not publish yet**

| Place | Review ID | Reason |
|---|---|---|
| Antag Falls | 160 | Temporarily closed by barangay authorities. Publish only after it reopens, and recheck the facts first. |
| Bago Aplaya Esplanade | 28 and 29 | Two staged rows for one place (`way/920131637` and `way/982238950`). See section 5. |

## 4. Per-place steps

Repeat for each place, in this order.

1. [ ] Open the record. Read the **OSM source** lines and open the OpenStreetMap link shown on the page.
2. [ ] **Check the pin** (section 4a). Fix Latitude/Longitude if the pin is wrong.
3. [ ] **Check District** matches how the rest of the catalog fills it (for example "Davao City"), and that Address or location names the area, such as Marilog or Toril.
4. [ ] Read Description, Activities, Estimated cost, Entrance fee, Operating hours. Correct anything that no longer matches your research.
5. [ ] Confirm **Visitor category** and **Visitor purpose** are filled.
6. [ ] Set **Visitor access policy** from the table above.
7. [ ] Paste the **Visitor access source URL**: a real page you have opened that supports the access policy (for example an official tourism or barangay page, or the venue's own page). If you cannot find one, do not publish that place. Leave it staged.
8. [ ] Tick **I checked this access evidence**.
9. [ ] **Save review**. Wait for "Candidate review saved."
10. [ ] **Publish destination**. Wait for "Destination published."
11. [ ] Note the new destination ID: ______
12. [ ] Add its rooms and cottages (section 6).

### 4a. Pin check

The pins came from OpenStreetMap, and five disagree with the districts your team recorded. A wrong pin puts the place on the map and in route calculations in the wrong spot, so fix it before publishing.

| Place | Your area | OSM pin says | What to do |
|---|---|---|---|
| Amador Resort | Buhangin / Indangan | Baguio District | Compare the pin with the resort's location; correct the coordinates if they are off. |
| Apata Farm | Marilog | Paquibato | Same. |
| Apo Pantok Falls | Marilog | Calinan | Same. |
| Bat-Te Antaon Falls | Marilog | Calinan | Same. |
| Bayna Falls | Toril | Calinan | Same. |
| Banwa Kasili, Baradi | Luac Bato (Toril), Marilog | Not flagged | Still glance at the pin. |

To correct a pin, edit Latitude and Longitude in the form with coordinates you have confirmed on a map. Do not guess numbers.

## 5. Bago Aplaya Esplanade (two rows)

1. [ ] Open both review records (28 and 29) and open each OpenStreetMap link.
2. [ ] Pick the row that is the actual esplanade (the walkway along the waterfront in Talomo).
3. [ ] **Reject** the other with a short reason, for example "Duplicate of review 28".
4. [ ] Fill the kept row from the research: open 24/7, free, Talomo; Sunday car-free walking 5-8 AM and 3-7 PM; bicycle rental from ₱50 per hour. Tell me the details and I can prepare the exact text to paste.
5. [ ] Then follow section 4. A free public place still needs an access source link.

Publishing both rows will fail on the second one, because of the duplicate check. Reject one first.

## 6. After publishing: rooms and cottages

Add them in the admin **Accommodation** screen. The API accepts these fields: name, room type, price, capacity, charging unit (per room per night, per room per stay, or blank), description and available. Screen labels may differ slightly; I have not opened that screen on a device.

Convention used for Bemwa Farm (#38): store the **lower price** of a range, use the **upper capacity**, leave the charging unit blank ("not stated"), and write "day use, not overnight lodging" in the description. Keep to the same convention so the planner treats these consistently.

| Place | Name | Price | Capacity |
|---|---|---|---|
| Amador Resort | Small Standard Day Room | ₱1,200 | 4 |
| Amador Resort | Medium Family/Deluxe Day Room | ₱1,800 | 8 |
| Amador Resort | Small Poolside Hut | ₱300 | 10 |
| Amador Resort | Medium Family Shed | ₱500 | 18 |
| Amador Resort | Large Function/Group Hut | ₱800 | 30 |
| Apata Farm | Small Open Picnic Shed | ₱200 | 6 |
| Apata Farm | Medium Group Shed | ₱350 | 12 |
| Apo Pantok Falls | Small Bamboo Shelter | ₱150 | 6 |
| Apo Pantok Falls | Medium Rest Hut | ₱250 | 12 |
| Bayna Falls | Small Table | ₱150 | 6 |
| Bayna Falls | Rest Hut | ₱250 | 12 |

Banwa Kasili, Baradi and Bat-Te Antaon have no rooms or cottages in the research. Skip them.

The Amador rooms are day rooms. Amador's cottages ("Large Function/Group Hut ₱800+") are open-ended; the ₱800 is a floor, not a fixed price. Say so in the description.

## 7. Verify after publishing

- [ ] **Destinations** list in the admin app shows each new place, with the right category and district.
- [ ] In the traveler app, search the place by name and open its details. Hours, fees and description match.
- [ ] Ask the planner for the place by name (for example `Add Apata Farm to my plan`). It should be added, with no unrelated cards.
- [ ] The place shows as not route-ready. That is expected, since no arrival point has been verified. Routes use the saved pin as an approximate planning point.
- [ ] Sensitive places stay honest: the five falls require a permit, so the details should not read as freely walk-in.

## 8. Tracking

| Place | Pin checked | Source link added | Saved | Published | Destination ID | Rooms/cottages added |
|---|---|---|---|---|---|---|
| Amador Resort | | | | | | |
| Apata Farm | | | | | | |
| Apo Pantok Falls | | | | | | |
| Banwa Kasili Falls | | | | | | |
| Baradi Falls | | | | | | |
| Bat-Te Antaon Falls | | | | | | |
| Bayna Falls | | | | | | |
| Bago Aplaya (kept row) | | | | | | |
| Antag Falls | on hold, reopens | | | | | |

## 9. If something goes wrong

| Message or problem | Meaning | What to do |
|---|---|---|
| "Verify visitor access and record its source and time" | Policy, source link or the checkbox is missing. | Fill all three, tick the box, Save review, then publish. |
| "Confirm the district and category, and explain the visitor purpose" | One of those fields is empty. | Fill it, save, publish. |
| Duplicate destination (409) | A nearby place with the same name is already published. | Open that place, check if it is the same one, and reject the duplicate review. |
| Publish button is greyed out | Unsaved changes. | Click Save review first. |
| The source link is rejected | It must start with http:// or https://. | Paste the full address. |
| Session expired | The admin login timed out. | Sign in again. Unsaved edits may need re-entering. |
