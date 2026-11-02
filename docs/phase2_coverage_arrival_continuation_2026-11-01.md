# Phase 2 destination coverage and arrival continuation

Reviewed 1 November 2026. This document records the initial Neon inventory,
source review, and the subsequent four-place and eight-place discovery imports. The Phase 2
target in `docs/core_focus.md` is at least five
tourist locations in each target district. `route_ready` has a separate, stricter
meaning defined in `docs/destinations.md`.

## Initial live coverage before the discovery import

An active-destination query against Neon returned:

| District | Active records | Minimum additional records to reach five | Route-ready records |
| --- | ---: | ---: | ---: |
| Davao City | 5 | 0 | 0 |
| Davao del Norte | 3 | 2 | 0 |
| Davao del Sur | 3 | 2 | 0 |
| Davao Oriental | 3 | 2 | 0 |
| Davao de Oro | 2 | 3 | 0 |
| Davao Occidental | 2 | 3 | 0 |
| **Total** | **18** | **12** | **0** |

The live Davao del Norte count includes `Panabo City Parks and Plaza`, which is
not in the current seed file. The seed file defines 17 destinations; the live
catalog has 18. Preserve that existing record when preparing any later seed.
The table is a numeric minimum. Broad records such as `Samal Island Beach Area`,
`Mount Apo Trail Area`, and `Balut Island` need a specific visitor site or travel
leg before they can be called route-feasible tourist stops. `Aliwagwag Falls`
needs a current reopening check. A count of five alone will not make a district
ready for itinerary routing.

## Initial twelve-candidate research queue

These are named places supported by a tourism or provincial source. The two
Malita shrines still need an identity and location check to establish that they
are separate visitor stops.
Christ the King Cathedral Parish and San Salvador del Mundo Church were later
imported as discovery-only records. Panabo Mangrove Forest Park and Digos City
Eco Park replaced the original Agriya and cultural-site choices for the first
batch. The other names in this table remain research candidates. This review
has not verified visitor arrival coordinates or current fees for them. A
discovery-only import can leave arrival and access details explicitly unknown
when an independent point identifies the actual attraction. Set
`route_ready=false`; do not invent fees, accommodation, or transportation rates.

| District | Candidate and place evidence | Arrival point still needed |
| --- | --- | --- |
| Davao del Norte | [Agriya Naturetainment, Panabo](https://www.experiencedavao.com/attractions/agriya-naturetainment) | Naturetainment public entrance on Garcia Street, separate from the wider township pin. |
| Davao del Norte | [Christ the King Cathedral Parish, Tagum](https://www.experiencedavao.com/destinations/davao-del-norte/tagum-city/attractions/christ-the-king-cathedral-parish) | Public compound entrance/drop-off on Dr. Juan Gonzales Avenue. |
| Davao del Sur | [Bagobo Cultural Village, Tibolo, Santa Cruz](https://www.experiencedavao.com/attractions/bagobo-cultural-village) | Community-approved meeting point, visitor rules, and road approach. |
| Davao del Sur | [Salinta Monon Weaving Center, Bitaug, Bansalan](https://www.experiencedavao.com/destinations/davao-del-sur/bansalan/attractions/salinta-monon-weaving-center) | Current public visitor entrance and booking/host confirmation. |
| Davao Oriental | [Pusan Point, Caraga](https://www.experiencedavao.com/destinations/davao-oriental) | Eco-park/Discovery Center gate or parking, not a cape or shoreline center. The [provincial service charter](https://davaooriental.gov.ph/wp-content/uploads/2022/01/0.0-Citizens-Charter-v1.3.pdf) lists Pusan Point Eco Park. |
| Davao Oriental | [San Salvador del Mundo Church, Caraga](https://www.experiencedavao.com/destinations/davao-oriental) | Active church compound entrance and safe drop-off. |
| Davao de Oro | [D'Fortees Nature Park and Inland Resort, Montevista](https://davaodeoro.gov.ph/dfortess-nature-park-and-inland-resort/) | Resort's current public gate/reception off Daang Maharlika Highway. |
| Davao de Oro | [New Barili Heights and Sights, Maco](https://davaodeoro.gov.ph/new-barili-heights-and-sights/) | Resort gate in New Barili; confirm the final road and booking rules. |
| Davao de Oro | [Pyalitan Falls, Mapawa, Maragusan](https://davaodeoro.gov.ph/pyalitan-falls/) | Authorized guide/registration point and road trailhead, not the falls coordinate. The provincial directions contain an inconsistent `Mapawa, Maco` phrase, so confirm the municipality with the tourism office before import. |
| Davao Occidental | [Christ the Redeemer, Jose Abad Santos](https://www.experiencedavao.com/attractions/christ-the-redeemer) | Joyce Paradise visitor entrance/parking in Barangay Culaman; verify access after the [June 2026 earthquake](https://pia.gov.ph/disaster-information-service/jas-mayor-assures-victims-of-food-aid-response-efforts-for-quake-hit-communities/). |
| Davao Occidental | [Divine Mercy Shrine, Malita](https://www.experiencedavao.com/destinations/davao-occidental) | Shrine entrance and exact address; confirm it is distinct from Sanctuario de Santo Rosario. |
| Davao Occidental | [Sanctuario de Santo Rosario, Malita](https://www.experiencedavao.com/destinations/davao-occidental) | Parish/shrine entrance and exact address; confirm it is distinct from Divine Mercy Shrine. |

The Department of Tourism Region XI operates Experience Davao, as identified in
its [site footer](https://www.experiencedavao.com/destinations/davao-occidental).
Its listings support candidate identity and general area only. They do not
certify opening, prices, or a navigation waypoint. The Davao de Oro provincial
pages likewise identify named sites, not verified arrival pins.

## Approximate attraction-point follow-up

The user chose to provide exact visitor arrival points later. Approximate
attraction points may be used for discovery and provisional planning with
`route_ready=false`; they do not establish a gate or usable road endpoint.
The following non-Google map records were found during the follow-up review.
Coordinates are rounded display points from the cited mapped features, not
surveyed entrances. This table does not authorize a seed or database import.

| Place | Approximate attraction point | Source and decision |
| --- | --- | --- |
| Christ the King Cathedral, Tagum | 7.44115, 125.79992 | [OpenStreetMap building via Mapcarta](https://mapcarta.com/W828786282). Suitable candidate for a discovery point after the catalog review. |
| Panabo Mangrove Forest Park | 7.26989, 125.68049 | [OpenStreetMap site via Mapcarta](https://mapcarta.com/W1436929311). Possible replacement for Agriya in the Davao del Norte coverage batch if its current public access is confirmed. |
| Digos City Eco Park and Arboretum | 6.77553, 125.34392 | [OpenStreetMap park via Mapcarta](https://mapcarta.com/W1382022448). Possible Davao del Sur coverage candidate; confirm it is distinct from existing destinations. |
| Pusan Point, Caraga | 7.29392, 126.60253 | [OpenStreetMap locality via Mapcarta](https://mapcarta.com/15730380). Suitable only as a broad discovery point; the Eco Park/Discovery Center remains unlocated. |
| San Salvador del Mundo Church, Caraga | 7.32770, 126.56588 | [OpenStreetMap church via Mapcarta](https://mapcarta.com/W322426196). Suitable candidate for a discovery point after the catalog review. |
| Pyalitan Falls, Maragusan area | 7.29919, 126.17070 | [OpenStreetMap waterfall via Mapcarta](https://mapcarta.com/N7345718185). Its `San Mariano` label is [Maragusan's former name](https://www.protectionclusterphilippines.org/wp-content/uploads/2022/12/UNHCR_MPP_Davao-de-Oro_Maragusan.pdf); the [provincial tourism page](https://davaodeoro.gov.ph/pyalitan-falls/) places the falls in Mapawa, Maragusan. |
| Christ the Redeemer, Jose Abad Santos | 5.96223, 125.67773 | [OpenStreetMap Joyce Paradise viewpoint via Mapcarta](https://mapcarta.com/W916520663). The [tourism listing](https://www.experiencedavao.com/attractions/christ-the-redeemer) and [2026 reopening report](https://www.sunstar.com.ph/amp/story/davao/davao-occidental-reopens-tourism-after-78-m-earthquake) place the monument at this venue; the exact entrance remains unverified. |

At the first follow-up, several proposed places lacked a sufficiently corroborated
non-Google point. Later mapped matches for New Barili and other places are in
the eight-place completion review. An OpenStreetMap name search returned no match
for ten of the original twelve candidates; a missing search result is not
proof that a place is absent from the map. The earlier Agriya coordinate came
from a Google Maps place pin and should not be copied into the seed under the
current [seed provenance rule](davao_curated_visitor_seed_2026-11-01.md).
Third-party coordinates for D'Fortees and Malita shrine plus codes still need
independent review. The source-backed names alone cannot be imported because
`Destination.lat` and `Destination.lng` are required.

### Imported discovery-only catalog batch

The approved batch contains four named places. It brought Davao del Norte to
five live records, Davao del Sur and Davao Oriental to four each, and the
regional total from 18 to 22. The four were imported on 1 November 2026 with
`route_ready=false` and no arrival coordinates. Their recorded costs are null.

| Candidate | Public identity evidence | Approximate attraction geometry | Remaining catalog decision |
| --- | --- | --- | --- |
| Panabo Mangrove Forest Park, Davao del Norte | [DOT Region XI listing](https://www.experiencedavao.com/attractions/panabo-mangrove-forest-park); [Panabo City account of a visit](https://panabocity.gov.ph/city-of-cabadbaran-nag-benchmark-sa-lgu-panabo/) | [OSM site](https://mapcarta.com/W1436929311), 7.26989, 125.68049 | Confirm current visitor access and fee with the city; an unofficial guide says free, but no current city fee notice was found. |
| Christ the King Cathedral Parish, Davao del Norte | [DOT Region XI listing](https://www.experiencedavao.com/destinations/davao-del-norte/tagum-city/attractions/christ-the-king-cathedral-parish) | [OSM cathedral building](https://mapcarta.com/W828786282), 7.44115, 125.79992 | Confirm visiting hours and whether any tourist activity has a charge; preserve worship use in the description. |
| Digos City Eco Park and Arboretum, Davao del Sur | [Digos City tourism page](https://digoscity.gov.ph/?page_id=491); [city ordinance index](https://digoscity.gov.ph/site_assets/pdf/Table-of-Ordinances.pdf) | [OSM park](https://mapcarta.com/W1382022448), 6.77553, 125.34392 | Confirm current public opening and fee with Digos City. |
| San Salvador del Mundo Church, Davao Oriental | [DOT Region XI listing](https://www.experiencedavao.com/destinations/davao-oriental) | [OSM church](https://mapcarta.com/W322426196), 7.32770, 126.56588 | Confirm current visitor access and any charge; respect active parish use. |

Migration `95bb71db451f` makes `Destination.estimated_cost` nullable so an
unknown cost is distinct from free admission. The API exposes null for unknown;
budget estimates reject selected destinations with an unknown cost, and
cost-capped recommendations exclude them. Arrival coordinates remain empty and
`route_ready=false`. The [discovery seed review](davao_discovery_visitor_seed_2026-11-01.md)
records the import and source trail.

### Coverage after the first import

| District | Active records | More needed for five |
| --- | ---: | ---: |
| Davao City | 5 | 0 |
| Davao del Norte | 5 | 0 |
| Davao del Sur | 4 | 1 |
| Davao Oriental | 4 | 1 |
| Davao de Oro | 2 | 3 |
| Davao Occidental | 2 | 3 |
| **Total** | **22** | **8** |

### Current live coverage after the second import

The [eight-place completion batch](davao_coverage_completion_seed_2026-11-01.md)
added Rizal Park Digos, Cape San Agustin, New Barili Heights and Sights,
Pyalitan Falls, Lake Leonard Eco-Tourism Park, Christ the Redeemer in Jose Abad
Santos, DDG Beach Resort, and Meskeen Resort (Malita Dives). Neon read-back
confirmed the eight rows and these active counts:

| District | Active records | More needed for five |
| --- | ---: | ---: |
| Davao City | 5 | 0 |
| Davao del Norte | 5 | 0 |
| Davao del Sur | 5 | 0 |
| Davao Oriental | 5 | 0 |
| Davao de Oro | 5 | 0 |
| Davao Occidental | 5 | 0 |
| **Total** | **30** | **0** |

The numeric Phase 2 coverage target is met. All 30 active records still have
`route_ready=false`; an attraction count does not certify current opening,
admission, booking, road approach, or a verified arrival point. The newer
records' specific follow-up items are in their two seed reviews.

## Arrival work for the initial 18 live records

All 30 now have empty `arrival_lat` and `arrival_lng` and `route_ready=false` in
Neon. The table below covers the initial 18; the twelve newer records have
arrival work listed in their seed reviews. Keep these fields separate from
attraction `lat` and `lng`. The earlier
[access review](davao_region_access_arrival_review_2026-10-29_README.md) and
[manual checklist](lakbay_manual_arrival_checklist.md) contain source leads.

| District | Existing destination | Next arrival decision |
| --- | --- | --- |
| Davao City | People's Park | Identify the active J. Palma Gil Street pedestrian gate and legal vehicle drop-off. |
| Davao City | Philippine Eagle Center | Confirm the foundation's visitor gate, not the general Malagos center pin. |
| Davao City | Eden Nature Park | Confirm the main resort gate/reception and final road approach. |
| Davao City | Museo Dabawenyo | Pin the Mabini Street Events Center lobby/entrance; the [city notice](https://davaocity.gov.ph/local-government/museo-dabawenyo-event-center-opens-exhibit-a-history-of-davao-city-in-50-objects/) supersedes the older Pichon Street address. |
| Davao City | National Museum of the Philippines - Davao | Pin the museum's public entrance within People's Park; the [museum's page](https://www.nationalmuseum.gov.ph/nmp-davao/) gives the compound address, not a gate coordinate. |
| Davao del Norte | Samal Island Beach Area | Replace the broad area with a named public beach or venue, then identify ferry terminals and the final local arrival point. |
| Davao del Norte | Panabo City Parks and Plaza | Confirm the chosen active park gate and safe drop-off; distinguish it from Museo Panabo. |
| Davao del Norte | Aqua Water Park | Confirm the Costa Azalea water-park gate and ferry/boat connection separately. |
| Davao del Sur | Mount Apo Trail Area | Choose an authorized climb route, permit/registration office, and road trailhead. |
| Davao del Sur | Tudaya Falls | Confirm local guide/registration point and parking/trailhead. |
| Davao del Sur | Camp Sabros Mountain Resort | Pin the Sitio Barras entry/parking area, about 750 m below the camp, described by the [operator](https://www.campsabros.com/contact.php). The operator page supplies directions but no exact parking coordinate. |
| Davao Oriental | Dahican Beach | Select a named public beach access or venue reception. |
| Davao Oriental | Aliwagwag Falls | Obtain an official reopening/access notice before selecting the eco-park ticket/parking gate. |
| Davao Oriental | Subangan Museum | Confirm the public entrance at Mati's Provincial Tourism Complex after its [January 2026 reopening](https://pia.gov.ph/news/museums-in-davao-region-reopen/). |
| Davao de Oro | Mainit Hot Springs | Identify the exact visitor facility and entrance; do not equate a broad spring area with a specific resort. |
| Davao de Oro | Tagbibinta Falls | Pin Barangay Coronobe visitor parking about 250 m before the falls, as described by the [provincial government](https://davaodeoro.gov.ph/tagbibinta-falls/). Its plus code labels the falls, not the parking point. |
| Davao Occidental | Little Boracay Beach | Confirm the resort/public beach gate and parking in Santa Maria. |
| Davao Occidental | Balut Island | Confirm departure and landing piers, service, and the island arrival point as separate legs. |

## Evidence needed to mark a record route-ready

For each record, capture the exact arrival latitude/longitude, arrival type
(gate, parking, trailhead, or pier), source URL or direct operator/office
confirmation, verification date, and a checked driving/walking approach that
ends at that point. Confirm current admission and booking/permit rules separately.
For island trips, capture both piers and the boat service. Only then should an
admin set `route_ready=true`. The current sources do not satisfy this acceptance
rule for any of the 30 live records or the remaining candidates.

Before any catalog import, reconcile the 18 live names with the seed file,
confirm each candidate's identity and approximate attraction coordinate, review
any seed-code change under `AGENTS.md`, and keep unverified arrival fields
blank. Unknown access and cost data must remain clearly labeled as unknown.
