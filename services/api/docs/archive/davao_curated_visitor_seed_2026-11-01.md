# Curated Davao visitor seed review

Reviewed 1 November 2026. This batch adds five named tourist attractions to the
existing Davao destination seed. It is a small, evidence-backed addition to the
[75 supported place candidates](../davao_region_destination_candidates_README.md),
not a claim to contain every tourist listing on Google Maps. Google Maps searches
were used to discover or cross-check names in the earlier
[18-place review](davao_region_google_maps_review_2026-10-29_README.md). Persisted
coordinates below come from OpenStreetMap-derived place features, not Google
Places content. Coordinate attribution: © OpenStreetMap contributors, ODbL.

| Seed name | Public visitor evidence | Attraction coordinate source | Unresolved before routing |
| --- | --- | --- | --- |
| Museo Dabawenyo | [Davao City reports the Mabini Street Event Center opened to the public](https://davaocity.gov.ph/local-government/museo-dabawenyo-event-center-opens-exhibit-a-history-of-davao-city-in-50-objects/) and lists free admission. The [2026 city charter](https://davaocity.gov.ph/wp-content/uploads/2026/03/CGD_CC2026_VOLUMEIIE.pdf) includes museum tours. | [OSM node 13179862776](https://mapcarta.com/N13179862776), 7.07939, 125.60449 | Confirm the current public door and any group booking rule. Do not use the older Pichon Street address. |
| National Museum of the Philippines - Davao | The [museum's Davao page](https://www.nationalmuseum.gov.ph/nmp-davao/) identifies the People's Park site. Its [visitor booking page](https://reservation.nationalmuseum.gov.ph/reservation/book/region-museum) lists Davao, free admission, walk-ins, and advance booking for groups of 20 or more. A [January 2026 government report](https://pia.gov.ph/news/museums-in-davao-region-reopen/) documents reopening after the earthquakes. | [OSM way 1153418558](https://mapcarta.com/W1153418558), 7.07016, 125.60914 | Confirm the active entrance and visit-day availability. This is a separate museum from Museo Dabawenyo and People's Park. |
| Aqua Water Park | The [operator's day-tour page](https://www.landcolifestyleventures.com/day-tour/aqua-water-park/) advertises visits, and its [2026 pass listing](https://onlineshopping.aquaria.landcolifestyleventures.com/?ID=413&page=product&val1=aqua-water-park-samal-islanddavao-2026-day-tour-pass-for-adults-weekdays) offers reservations. | [OSM node 9211408403](https://mapcarta.com/N9211408403), 7.08705, 125.66662 | The operator page conflicts on Tuesday opening. Confirm the gate, date-specific pass, departure pier, receiving pier, and ferry/boat connection. PHP 1,000 is a planning estimate, not a universal admission price. |
| Camp Sabros Mountain Resort | The [operator FAQ](https://www.campsabros.com/faqs.php) offers walk-in day visits and lists PHP 100 adult admission; the [operator directions](https://www.campsabros.com/contact.php) identify a parking area below the camp. | [OSM way 1454653112](https://mapcarta.com/W1454653112), 6.90514, 125.34654 | Confirm the exact public parking/arrival coordinate and current hours. Rides and transport cost extra. |
| Subangan Museum | The [Philippine Information Agency reported public reopening on 12 January 2026](https://pia.gov.ph/news/museums-in-davao-region-reopen/) at the provincial tourism complex in Mati. | [OSM way 1328605333](https://mapcarta.com/W1328605333), 6.94423, 126.24834 | Confirm current hours, admission fee, and visitor entrance. PHP 200 is a provisional planning estimate because no current fee was verified. |

All five rows are **discovery-only**: `route_ready=false`, no visitor arrival
coordinate, and no fabricated accommodation or transportation rates. The
attraction coordinate is for a rough place map only. Current public information
supports a possible visit, but no source guarantees admission on an arbitrary
future date. The seed does not establish road, ferry, opening, permit, or booking
feasibility for a selected trip.

Other candidates remain in review. In particular, the earlier Maps review has
only a parent-venue match for Agriya Naturetainment; D'Fortees lacks current
operator admission evidence; and Aliwagwag Falls Ecopark needs an official
reopening confirmation. The existing broad starter rows are unchanged by this
batch. They have not all passed this visitor-evidence standard.

## Import

After the destination migration is applied, run only the reviewed batch:

```powershell
python -m app.seeds.davao_destinations --curated-only
```

The command inserts missing rows by exact name and skips rows already present.
It does not modify existing destination records. It adds no accommodation or
transportation rows for this batch. Run it against the intended database only
after checking `DATABASE_URL` and its migration state. The normal seed command
still loads the older starter set.

The reviewed command was applied to the configured Neon database on 1 November
2026 after confirming Alembic was at `2026_10_29_0600 (head)`. A read-back
confirmed all five new records (IDs 14–18), bringing the live destination count
from 13 to 18. None has a visitor arrival coordinate or `route_ready=true`.

For future expansion, verify each candidate's public visitor identity and area
using its operator or responsible tourism office; use a non-Google coordinate
source for stored attraction geometry; check current access; and document its
cost basis. Verify the actual gate, parking area, trailhead, or pier separately
before setting `route_ready=true`. Google's [Places API policy](https://developers.google.com/maps/documentation/places/web-service/policies)
restricts storing Places content, while allowing stored Place IDs under its
specified exception. No Place IDs or copied Places content are in this seed.
