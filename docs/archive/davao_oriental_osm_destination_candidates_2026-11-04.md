# Davao Oriental OSM destination candidates — 4 November 2026

[Open the full 223-row CSV](davao_oriental_osm_destination_candidates_2026-11-04.csv).

This is a **complete extraction for the named OSM tag set below inside Davao Oriental's OSM boundary**, including Mati and mapped islands. It is a list of *candidate places*, not an approved Lakbay tourist catalog. It supports Phase 2 destination-data research. No live destination, fee, activity, database schema, or routing field was changed.

## Source and boundary

- Source: [Davao Region OSM PBF extract](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region-latest.osm.pbf) from the [regional extract index](https://download.openstreetmap.fr/extracts/asia/philippines/). Its replication state at download was `2026-11-03T00:12:04Z` (sequence `7356061`). The downloaded file's MD5 was `cee2272b08d86fd5160b51b3472fcad4`, matching the published [checksum](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region.osm.pbf.md5).
- Boundary: [OSM Davao Oriental relation 1507095](https://www.openstreetmap.org/relation/1507095), resolved to its polygon through [Nominatim's object lookup](https://nominatim.org/release-docs/latest/api/Lookup/). A feature was included when its mapped or representative point fell inside or on that polygon.
- Named nodes and ways were read from the regional PBF locally. Region-wide named relation features matching the tag set were checked; two had representative points inside Oriental: Culanag Beach Resort and Sigaboy Island. [Pyosmium's handler documentation](https://docs.osmcode.org/pyosmium/latest/reference/Handler-Processing/) describes the streaming read.
- Data attribution: © OpenStreetMap contributors, ODbL. See the [OSM attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines).

Using the regional file avoids dependence on the public Overpass bulk query service, which returned errors or timed out during the earlier audit.

## Inclusion rule

An object needed a `name` or `name:en` tag, a point in the province polygon, and at least one of these tags. Where several matched, the CSV records one primary matching tag. This uses the same rules as the [Davao Occidental inventory](davao_occidental_osm_destination_candidates_2026-11-04.md), **plus `natural=cape`** so Cape San Agustin and other named capes are included.

| OSM key | Included values or rule | Rows |
| --- | --- | ---: |
| `tourism` | `attraction`, `museum`, `artwork`, `viewpoint`, `zoo`, `aquarium`, `theme_park`, `yes`, `picnic_site`, `camp_site`, `gallery` | 38 |
| `leisure` | `park`, `garden`, `nature_reserve`, `water_park`, `beach_resort`, `resort` | 64 |
| `natural` | `beach`, `waterfall`, `peak`, `volcano`, `cape`, `cave_entrance`, `hot_spring` | 35 |
| `historic` | `monument`, `memorial`, `ruins`, `archaeological_site`, `wayside_shrine`, `fort`, `castle`, `heritage` | 4 |
| `amenity` | `place_of_worship`, `arts_centre`, `theatre` | 58 |
| `man_made` | `lighthouse`, `observation_tower` | 7 |
| `waterway` | `waterfall` | 7 |
| `landuse` | `recreation_ground` | 1 |
| `place` | `island`, `islet` | 9 |
| `attraction` | any nonempty value, if none of the preceding rules matched | 0 |
| **Total** | | **223** |

The CSV has **129 nodes, 92 ways, and 2 relations**. Validation found 223 unique OSM type/ID pairs, no missing coordinate or link fields, and no coordinate outside the Davao Oriental polygon. All five Oriental features from the earlier regional starter list appear: Aliwagwag Falls, Cape San Agustin, Dahican Beach, El Salvador del Mundo Parish, and Subangan.

## Reading the coordinates

`coordinate_basis` distinguishes mapped nodes from representative points computed on ways or returned for relations. A `polygon_interior`, `line_representative`, or `nominatim_representative` coordinate identifies a mapped feature; it is **not a verified public entrance**. `arrival_verified` is `no` for every row. An island may need a verified receiving pier, and a park or resort may need a gate, before routing can show a useful last segment.

The 223 rows include **57 places of worship, 37 beach resorts, and 21 peaks**. These are retained as OSM place candidates, but their tourist suitability and public access need review. Four names occur on more than one OSM object; separate objects were retained rather than merged by name. Fees, activities, operating status, and safe arrival points still need confirmation.

This is exhaustive only for the **named objects and selected tags in the dated OSM extract**. OSM may omit places, use other tags, contain duplicate or stale objects, or place a feature across a provincial border while its representative point lies outside. Unnamed objects are intentionally excluded. A broader definition of destination needs a new tag set and another offline extraction. Do not copy these coordinates into `arrival_lat`/`arrival_lng` or set `route_ready=true` without verifying the visitor arrival point.
