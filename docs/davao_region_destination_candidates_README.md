# Davao Region destination candidate data

The [full CSV](davao_region_destination_candidates.csv) records **132 named source rows** from `Lakbay+ DATASET.pdf` (118 rows) and `Lakbay+ DATASET (1).pdf` (14 named rows). The second PDF also has three empty Tagum placeholders; they are omitted. A [75-row filtered CSV](davao_region_supported_place_candidates.csv) keeps the independently supported place identities after removing cross-PDF repeats. Both files are **evidence and correction data**, not an approved list of open destinations or navigation waypoints.

Reviewed 29 October 2026 against the [118-place location audit](lakbay_dataset_location_audit.md), [118-place arrival review](lakbay_dataset_arrival_verification.md), and [14-row supplemental review](lakbay_dataset_1_verification.md). This compilation did not change backend code, database tables, or seed records.

## What the file verifies

| Field | Meaning |
|---|---|
| `place_status` | `supported` corroborates the name and stated area; `partial` needs a name/site/area decision; `contradicted_or_duplicate`, `unconfirmed`, and `duplicate` require correction or exclusion. It does not certify visitor access. |
| `source_lat`, `source_lon` | Coordinates **transcribed from the PDFs**. They are retained for audit comparisons and must not be routed to without verification. All 118 original PDF rows supplied coordinates; six named rows in the supplemental PDF did not. |
| `independent_place_lat`, `independent_place_lon`, `place_pin_evidence_url` | A separately mapped **place location** for 19 rows where an individual map record was reviewed. Blank for other rows. These points may mark an attraction center, water feature, or mountain and are **not visitor arrival coordinates**. |
| `source_pin_status` | `rejected` means the PDF point conflicts with evidence or cannot represent a usable traveler arrival; `needs_confirmation` is an unverified candidate; `missing` is blank in the PDF. |
| `arrival_review_state`, `arrival_target_to_confirm` | The kind of visitor arrival/departure point needed: venue gate, public parking/drop-off, trail registration point, or departure/landing pier. `Hold` means the place or access itself needs resolution. |
| `availability_status` | Current public access evidence level. `not_confirmed_current` is **unknown**, not open or closed. An operator visit page or a directory listing is a lead, not a guarantee for a chosen travel date. |
| `current_hours`, `current_fee_php` | Blank until a current authoritative source confirms a value. Historical PDF claims were deliberately not copied into these fields. |
| `visitor_arrival_lat`, `visitor_arrival_lon`, `route_ready` | These are deliberately empty/`no` throughout. A map's general place pin does not prove the precise public entrance or road-connected arrival point. |
| `evidence_urls` | Sources underlying the place/location finding. Empty for names that the audits could not corroborate. |
| `google_maps_lookup` | A generated Google Maps **search link**, not proof that a place listing, gate, or opening status has been checked. |
| `catalog_action`, `davao_region_eligibility` | Immediate screening decision. Out-of-region rows, the closed original Aldevinco venue, and duplicated/alias rows require exclusion or merge. |

## Results and use

- **Place identity:** 77 source rows supported, 28 partial, 13 contradicted/duplicate, 13 unconfirmed, and one explicit duplicate. These are source-row counts, not unique destinations.
- **Source pins:** 69 rejected, 57 pending confirmation, six missing. **Zero route-ready visitor arrival points.**
- **Current availability:** 116 rows have no current public-access confirmation. The remaining statuses record leads such as an operator booking page, a recent service charter, a prior rehabilitation report, or a known closure; they do not guarantee admission on a travel date. The [Philippine Eagle Center booking page](https://www.philippineeaglefoundation.org/book-online) currently lists a regular tour from ₱120; the [2026 Davao City citizen charter](https://davaocity.gov.ph/wp-content/uploads/2026/03/CGD_CC2026_VOLUMEIIE.pdf) lists public Museo Dabawenyo tours without a fee; and the [Aqua Water Park 2026 online weekday adult pass](https://onlineshopping.aquaria.landcolifestyleventures.com/?ID=413&page=product&val1=aqua-water-park-samal-islanddavao-2026-day-tour-pass-for-adults-weekdays) is listed at ₱570. Only the fixed museum and date-conditioned water-park values appear in `current_fee_php`. The eagle tour amount remains marked as “from” rather than a fixed price.
- **Outside Davao Region:** `ORIG-064` Lake Agko Hot Springs is in Kidapawan, Cotabato; `ORIG-099` Mount Magdiwata is in Agusan del Sur. Do not include these as Davao destinations. [Kidapawan City](https://kidapawancity.gov.ph/product/lake-agco/) · [Mt. Magdiwata research](https://www.nature.com/articles/s41599-026-06754-7).
- **Closed original venue:** `ORIG-021` Aldevinco Shopping Center ceased operations in 2021. The property developer reports a different attraction, Roxas Food Trucks, opened at the redevelopment site in March 2026; it would need its own new record and entrance check. [Alsons Dev](https://alsonsdev.com/alsons-dev-brings-new-energy-to-aldevinco-site-as-redevelopment-progresses/).
- **Access-sensitive venues:** The [Philippine Eagle Foundation's visitor page](https://www.philippineeaglefoundation.org/pec) offers booking but does not establish this dataset's entrance coordinate or the availability for a particular date. The [Samal engineering report](https://samalcity.gov.ph/images/pdf/CEO_Oct25.pdf) recorded rehabilitation work at Hagimit Falls Nature Park in 2025; this is a reason to reconfirm public access, not proof of present closure. A [DENR-carried 2022 report](https://denr.gov.ph/wp-content/uploads/2023/07/DENR_News_Alerts_April_13_2022_Wednesday.pdf) described permit/booking controls for Mount Hamiguitan trekking; current rules must be obtained from the protected-area office.
- **Conflicting hours:** The [Aqua Water Park operator page](https://www.landcolifestyleventures.com/day-tour/aqua-water-park/) displays both “Open Daily” and “Close every Tuesdays.” Its hours are left unconfirmed in the CSV despite an active 2026 pass listing.

## Publication rule

For a destination shown in traveler search, require an independently supported place identity and the correct city/municipality, plus evidence that the public may currently visit. For a destination used in routing, additionally require a verified, publicly reachable arrival coordinate and the source/date of the gate or pier confirmation. For time, fee, activity, or transport claims, store the source and its publication/confirmation date; leave the field unknown when there is no reliable current evidence. If these checks have not been done, keep the record in a review queue.

The browser's direct Google Maps interaction was disabled by Work settings during this compilation. Publicly indexed map records and earlier direct Google Maps checks informed the linked audits, but the CSV's generated lookup URLs were not individually opened in this pass. Google Maps place pins require separate gate/road approach checks even when browser access is available.
