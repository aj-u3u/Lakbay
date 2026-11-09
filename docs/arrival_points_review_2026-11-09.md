# Arrival points and pin corrections — 9 November 2026

Proposed visitor arrival points and attraction-pin corrections for the 30 active
destinations, plus a Samal Island beach inventory. **Nothing has been written to
the database.** The values are in
[arrival_points_2026-11-09.csv](arrival_points_2026-11-09.csv); apply them only
after the user approves.

## How a place becomes route-ready

`route_ready=true` requires `arrival_lat`, `arrival_lng`, `arrival_source_url`
and `arrival_verified_at` (`app/features/destinations/schemas.py`,
`ck_destinations_route_ready_arrival`). Routing also rejects any waypoint that
OSRM snaps more than 250 m from a road (`MAX_PREVIEW_WAYPOINT_SNAP_METERS` in
`app/integrations/osrm/client.py`).

## Method

1. The user supplied 28 arrival coordinates (Mount Apo and Mainit were blank).
2. Each point was snapped with OSRM `nearest` (driving) on the public OSRM host.
3. Places whose point failed the road test or pointed at the wrong place got a
   new arrival point from OpenStreetMap (trailhead, ferry terminal, or the road
   nearest the feature), checked against web sources.
4. Every final arrival point was routed by OSRM from People's Park, Davao City.
   **All 30 returned a road route with the end snap within 250 m.** Samal
   destinations and Balut Island route over a ferry.

Limits: a road snap shows a point is reachable by road near the attraction. It
does not prove that it is the public gate. The user's points are recorded as the
user's own verification. OSM data © OpenStreetMap contributors, ODbL.

## Results

`basis`: **yours** = user's coordinate kept; **new** = replaced. `to pin` is the
distance from the arrival point to the corrected attraction pin.

| ID | Destination | Pin fix | Arrival basis | To pin | Note |
| ---: | --- | --- | --- | ---: | --- |
| 1 | People's Park | 93 m | yours | 1 m | |
| 2 | Philippine Eagle Center | 187 m | yours | 85 m | |
| 3 | Eden Nature Park | 2.2 km | yours | 425 m | Your point is the reception area. |
| 4 | Samal Island Beach Area | see below | new | 0 m | Your point was inland, 2 km from the nearest resort. Proposed: Kaputian Beach. |
| 5 | Mount Apo Trail Area | — | new | 6.2 km | Pin stays at the summit. Arrival = Mount Apo Jump-Off Santa Cruz (OSM node 5690505225). The Kapatagan jump-off (6.936047, 125.289053) is the alternative. |
| 6 | Dahican Beach | 4.0 km | yours | 63 m | |
| 7 | Panabo City Parks and Plaza | 994 m | yours | 14 m | |
| 8 | Tagbibinta Falls | 4.1 km | yours | 38 m | |
| 9 | Mainit Hot Springs | 9.7 km | new | 46 m | Assumes Bilawa Hot Waterfalls (Mainit Sulfuric Hot Spring), Brgy Mainit, Maco. **Confirm identity.** |
| 10 | Little Boracay Beach | 4.4 km | yours | 66 m | |
| 11 | Balut Island | — | new | 5.7 km | Your point was the island's centre. Arrival = Balut Island ferry terminal. Sea leg; ferry schedule not modelled. |
| 12 | Tudaya Falls | 4.8 km | new | 278 m | Your point was 487 m from a road (fails the 250 m limit). Arrival = nearest mapped road to the falls; sources describe a 30–60 min hike, so **confirm the jump-off**. |
| 13 | Aliwagwag Falls | 13.3 km | yours | 951 m | Your point is on the national highway; plausible viewing area. |
| 14 | Museo Dabawenyo | — | new | 13 m | Your point is the old Pichon St site. The museum is now on Mabini St, Marfori (WhenInManila, July 2025). |
| 15 | National Museum Davao | — | yours | 11 m | |
| 16 | Aqua Water Park | — | yours | 44 m | Ferry route. |
| 17 | Camp Sabros Mountain Resort | — | yours | 18 m | |
| 18 | Subangan Museum | — | yours | 10 m | |
| 19 | Panabo Mangrove Forest Park | — | yours | 271 m | |
| 20 | Christ the King Cathedral Parish | — | yours | 5 m | |
| 21 | Digos City Eco Park and Arboretum | — | yours | 107 m | |
| 22 | San Salvador del Mundo Church | — | yours | 0 m | |
| 23 | Rizal Park Digos | — | yours | 1 m | |
| 24 | Cape San Agustin | — | yours | 19 m | Road snap 160 m. |
| 25 | New Barili Heights and Sights | — | yours | 36 m | |
| 26 | Pyalitan Falls | — | new | 626 m | Your point was 5.9 km away on the Nabunturan–Maragusan Road. Arrival = road nearest the falls; matches a 15–20 min trail from a roadside jump-off. |
| 27 | Lake Leonard Eco-Tourism Park | — | yours | 864 m | Check it is the park entrance. |
| 28 | Christ the Redeemer, Jose Abad Santos | — | new | 24 m | Your point was in the town proper. The statue is at Joyce Paradise, Brgy Culaman (SunStar). |
| 29 | DDG Beach Resort | — | yours | 58 m | |
| 30 | Meskeen Resort (Malita Dives) | — | yours | 72 m | |

## Decisions needed before applying

1. **Destination 4.** Rename "Samal Island Beach Area" to a specific beach
   (proposed: Kaputian Beach, 6.965113, 125.723125), or add specific beaches as
   new destinations through the candidate queue.
2. **Mainit Hot Springs.** Confirm that the intended place is Bilawa Hot
   Waterfalls.
3. **Mount Apo.** Santa Cruz or Kapatagan jump-off.
4. **Tudaya Falls.** Accept the nearest-road point, or supply a known jump-off.
5. **How to write.** The admin app (one place at a time), or a reviewed script
   that calls the destination service with validation.

## Samal Island beaches

[samal_beaches_osm_2026-11-09.csv](samal_beaches_osm_2026-11-09.csv) lists 155
OSM features inside the Island Garden City of Samal boundary (112 named): public
beaches, beach resorts, resorts, hotels, attractions and ferry terminals, with
coordinates, a district and the OSM link. Districts are approximate, based on
latitude.

Named public beaches (OSM `natural=beach`):

| District | Beach | Lat, lng |
| --- | --- | --- |
| Kaputian | Kaputian Beach | 6.965113, 125.723125 |
| Kaputian | San Remigio Beach | 6.920537, 125.777155 |
| Kaputian | South Malipano Beach | 7.004798, 125.719438 |
| Talikud Island | Babu Santa Beach | 6.949571, 125.670069 |
| Talikud Island | Cogon Long Beach | 6.913461, 125.684836 |
| Talikud Island | Costafba Beach | 6.907771, 125.719466 |
| Talikud Island | Cruz Beach | 6.939625, 125.673458 |
| Talikud Island | Linosutan Beach | 6.924874, 125.682556 |
| Talikud Island | NCCC Beach | 6.943462, 125.670931 |

Talikud Island beaches need a boat from Samal (Santa Cruz / Isla Reta
terminals). Treat them as sea-access places, not road destinations.

Well-known beach resorts in the file include Paradise Island Beach Resort, Pearl
Farm Beach Resort, Canibad Cove and nearby Canibad resorts, Isla Reta Beach
Resort, Hayahay Dive Resort and Kaputian Beach Club. The file does not include
fees, hours or current operating status; enrich those through the candidate
queue before publishing.

## Sources

- [OpenStreetMap](https://www.openstreetmap.org/) via Nominatim lookup and Overpass API
- [OSRM nearest and route services](https://router.project-osrm.org/)
- [WhenInManila: Museo Dabawenyo (July 2025)](https://www.wheninmanila.com/museo-dabawenyo-what-to-see/)
- [TransitPinas: Pyalitan Falls](https://transitpinas.com/pyalitan-falls-compostela-valley/)
- [PhilAtlas: Mapawa, Maragusan](https://www.philatlas.com/mindanao/r11/davao-de-oro/maragusan/mapawa.html)
- [SunStar: Davao Occidental reopens tourism](https://www.sunstar.com.ph/davao/davao-occidental-reopens-tourism-after-78-m-earthquake)
- [SunStar: A wedding in JAS](https://www.sunstar.com.ph/davao/lifestyle/a-wedding-in-jas)
- [Mindanao Times: Bilawa Hot Waterfall](https://mindanaotimes.com.ph/?p=51104)
- [Tudaya Falls travel guide](https://phtraveldestinations.blogspot.com/2020/07/tudaya-falls.html)
