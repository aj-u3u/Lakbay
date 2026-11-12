# Phase 2 eight-place coverage batch

Reviewed 1 November 2026. This batch supplies one additional named attraction
in Davao del Sur, one in Davao Oriental, three in Davao de Oro, and three in
Davao Occidental. It is a **discovery-only** catalog batch: the mapped points
identify attractions approximately, not usable arrival points. Each seed row
has `estimated_cost=null`, empty arrival fields, `route_ready=false`, and no
accommodation or transportation rates. A null fee is unknown, not free.
Coordinate attribution: © OpenStreetMap contributors, ODbL, through Mapcarta.

| Seed name | Visitor and place evidence | Approximate attraction point | Unresolved before a trip |
| --- | --- | --- | --- |
| Rizal Park Digos | [Digos City tourism page](https://digoscity.gov.ph/?page_id=491) lists Rizal Park. | [OSM park way 97188461](https://mapcarta.com/W97188461), 6.74442, 125.35556 | Current park hours, any fee, and vehicle drop-off. |
| Cape San Agustin | [DOT Region XI listing](https://www.experiencedavao.com/attractions/cape-san-agustin) identifies the Lavigan cape and lighthouse area; the [provincial charter](https://davaooriental.gov.ph/wp-content/uploads/2022/01/0.0-Citizens-Charter-v1.3.pdf) lists its ecopark. | [OSM cape node 4385211700](https://mapcarta.com/15726614), 6.26932, 126.19297 | Ecopark opening, entry, fee, and safe road approach; the cape point is not a gate or coast guard lighthouse entrance. |
| New Barili Heights and Sights | [Davao de Oro provincial listing](https://davaodeoro.gov.ph/new-barili-heights-and-sights/) and [wellness loop](https://davaodeoro.gov.ph/tourist-circuit-wellness-loop/) identify the New Barili venue. | [OSM attraction node 9671315617](https://mapcarta.com/N9671315617), 7.35411, 126.01136 | Current day visits, fee, booking, and final road approach. |
| Pyalitan Falls | [Davao de Oro provincial listing](https://davaodeoro.gov.ph/pyalitan-falls/) identifies Mapawa, Maragusan and an hour-long trek. | [OSM waterfall node 7345718185](https://mapcarta.com/N7345718185), 7.29919, 126.17070 | Current guide/permit rules, registration, and road trailhead. The provincial directions include a `Mapawa, Maco` typo. The OSM page uses `San Mariano`, [Maragusan's former name](https://www.protectionclusterphilippines.org/wp-content/uploads/2022/12/UNHCR_MPP_Davao-de-Oro_Maragusan.pdf); the falls and existing Tagbibinta Falls are separate mapped features. |
| Lake Leonard Eco-Tourism Park | [Davao de Oro provincial tourism inspection](https://davaodeoro.gov.ph/2022/08/08/ddos-tourism-wellness-loop-revisited/) names the Danao Aqua Eco Park in New Leyte, Maco; [DOT Region XI](https://www.experiencedavao.com/attractions/lake-leonard) lists Lake Leonard. | [OSM park node 7170393085](https://mapcarta.com/N7170393085), 7.39792, 126.05760 | Confirm the park's current operation, fee, and entry. The mapped park is distinct from the lake water-body coordinate and the existing `Mainit Hot Springs` row. |
| Christ the Redeemer, Jose Abad Santos | [DOT Region XI listing](https://www.experiencedavao.com/attractions/christ-the-redeemer) identifies Barangay Culaman; a [2026 tourism reopening report](https://www.sunstar.com.ph/amp/story/davao/davao-occidental-reopens-tourism-after-78-m-earthquake) places the monument at Joyce Paradise and says provincial tourism resumed after the earthquake. | [OSM Joyce Paradise viewpoint way 916520663](https://mapcarta.com/W916520663), 5.96223, 125.67773 | Confirm monument access, venue hours and fees; the viewpoint geometry is a venue point, not the statue's entrance. |
| DDG Beach Resort | A [2026 operator-post mirror](https://www.findglocal.com/PH/Santa-Maria/702784866553165/DDG-BEACH-Resort) identifies the Colagsing venue and reservations. | [OSM resort node 10111274417](https://mapcarta.com/N10111274417), 6.62303, 125.43369 | Confirm current day-visit charge and booking with the operator. The mirror describes rough-road and boat options, neither verified for routing. |
| Meskeen Resort (Malita Dives) | An [October 2026 first-person visit](https://www.rjdexplorer.com/malita-dives-davao-occidental/) reports that the Tubalan entrance sign reads `Meskeen Resort` and that `Malita Dives` is another name. | [OSM Miskeen Beach Resort node 12452684186](https://mapcarta.com/N12452684186), 6.49131, 125.57969 | Confirm the operator spelling, entrance, fee, and return transport. The map's `Miskeen` and visitor's `Meskeen` spellings are treated as a probable alias, not two destinations. |

Pusan Point Eco Park was held out of this batch: an [October 2026 restoration
inspection report](https://mindanao.politiko.com.ph/gov-nelson-l-dayanghirang-requests-tieza-inspection-of-aliwagwag-falls-pusan-point-for-restoration/)
raises a current opening question. Cape San Agustin supplies the Oriental
coverage place instead. The two Malita shrines also remain unimported because
their independently mapped attraction points have not been corroborated.

After confirming the intended database and migration `95bb71db451f` or later,
the separate idempotent batch command is:

```powershell
python -m app.seeds.davao_destinations --coverage-only
```

The reviewed command was applied to the configured Neon database on 1 November
2026. Read-back found IDs 23–30 in the order listed above, all with null costs,
null arrival fields, and `route_ready=false`. Each of the six target districts
now has five active records, 30 total; the live route-ready count is zero.

This command inserts missing names and does not update existing records. Keep
the eight records out of route-ready recommendations and exact budget promises
until their arrival and cost evidence is reviewed. The broader
[coverage review](phase2_coverage_arrival_continuation_2026-11-01.md) tracks the
arrival work for the initial 18 and the first four discovery records.
