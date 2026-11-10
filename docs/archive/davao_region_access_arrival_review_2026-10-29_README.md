# Davao Region opening, permits, and arrival review

Reviewed 29 October 2026. The [18-row CSV](davao_region_access_arrival_review_2026-10-29.csv) extends the [Google Maps destination review](davao_region_google_maps_review_2026-10-29.csv). It checks publicly accessible tourism, government, and operator pages for opening evidence, permit or booking instructions, and visitor arrival descriptions. This is a source review, not a same-day telephone or field confirmation. `not_stated`, `unconfirmed`, and blank coordinate fields must remain unknown in the app.

## Separate location fields

- `attraction_lat`, `attraction_lng`, and `attraction_location_url` refer to the place or attraction. The few filled coordinate pairs come from independently mapped **place locations** in the prior audit. They are not parking, entrance, trailhead, or pier coordinates. A Maps search URL alone does not certify a point.
- `arrival_target` says where a traveler should arrive. `arrival_evidence_url` supports the text when a source describes it. `arrival_lat` and `arrival_lng` are **blank for all 18** because no exact public visitor arrival coordinate and final road approach were verified. `arrival_point_status` records the remaining gap. All rows remain `route_ready=no`.
- For Balut Island, a road route requires a departure pier and an island landing pier, plus a separately verified boat service. For Dahican Beach and Tubalan Cove, a specific public venue or beach access must be chosen first.

The six available attraction coordinate pairs may support a rough planning map
or provisional stop order after the road approach is checked. They must not be
used as verified arrival pins or final travel directions. AI itinerary drafts
may still include a destination whose arrival pin is pending if public access is
plausible and the draft clearly asks the traveler to confirm the entrance,
opening status, and applicable booking or permit rule. A reported closure or
unresolved non-road connection requires review before that destination is
treated as a feasible visit.

## Strongest access and arrival findings

- The [Philippine Eagle Foundation](https://www.philippineeaglefoundation.org/book-online) currently offers tour booking. Its Malagos address identifies the center, not the visitor gate.
- [Davao City Tourism](https://tourism.davaocity.gov.ph/explore-the-city/attractions/man-made-nature-parks/peoples-park/) lists People's Park as free and open daily at a Palma Gil Street address. It does not identify or pin a specific public gate.
- The [Davao City museum notice](https://davaocity.gov.ph/local-government/museo-dabawenyo-event-center-opens-exhibit-a-history-of-davao-city-in-50-objects/) places Museo Dabawenyo at the Events Center on Mabini Street, behind the high school. The [2026 citizen charter](https://davaocity.gov.ph/wp-content/uploads/2026/03/CGD_CC2026_VOLUMEIIE.pdf) lists museum tours for all visitors; prearranged groups submit a guest list and reservation. An older city department page still says Pichon Street, so it should not be used for routing.
- [Aqua Water Park's operator](https://www.landcolifestyleventures.com/day-tour/aqua-water-park/) identifies Costa Azalea in Limao and offers a map link; [2026 day passes](https://onlineshopping.aquaria.landcolifestyleventures.com/?ID=413&page=product&val1=aqua-water-park-samal-islanddavao-2026-day-tour-pass-for-adults-weekdays) require a reservation/e-voucher. Its page conflicts on Tuesday opening and the resort map does not identify the exact public water-park gate.
- [Camp Sabros' operator directions](https://www.campsabros.com/contact.php) identify an entry and parking area in Sitio Barras, about 750 m below the camp. Its [FAQ](https://www.campsabros.com/faqs.php) says day visits are walk-in and overnight stays require reservations. Operator pages disagree on arrival hours; no precise parking coordinate was published.
- [Davao de Oro tourism](https://davaodeoro.gov.ph/tagbibinta-falls/) describes vehicle parking about 250 m before Tagbibinta Falls. A [September 2026 firsthand visit](https://www.rjdexplorer.com/tagbibinta-falls-maragusan/) describes the ticket booth and public entry after a 2025 damage report. The parking coordinate and current operating notice remain unverified.
- An [October 2026 firsthand visit](https://www.rjdexplorer.com/little-boracay-davao-occidental/) describes road access and paid admission at Little Boracay in Santa Maria. The resort operator has not confirmed its exact gate or current hours.
- [PIA reported Subangan Museum's public reopening](https://pia.gov.ph/news/museums-in-davao-region-reopen/) on 12 January 2026 after earthquake repairs. Current hours and the exact entrance pin still need the museum or tourism office.
- [February 2026 reporting on Aliwagwag Falls Ecopark](https://www.sunstar.com.ph/amp/story/davao/davao-oriental-plans-aliwagwag-falls-reopening) describes a 2025 closure and reopening assessment. No later official opening notice was verified, so park access and routing remain on hold even though Google Maps shows opening hours.

## Route-ready acceptance rule

An entry can change to `route_ready=yes` only after the responsible operator or tourism office confirms current public access and any booking/permit rule; a public gate, parking area, trailhead, or pier coordinate is recorded with a source and date; and a driving or walking route is checked to end at that point on a usable public approach. Island travel additionally needs both piers and a confirmed boat leg. Keep the attraction coordinate distinct from the arrival coordinate in the review data. Any later database or route-service change needs the project approval required by `AGENTS.md`.
