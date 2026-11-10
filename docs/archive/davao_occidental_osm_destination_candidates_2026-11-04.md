# Davao Occidental OSM destination candidates — 4 November 2026

[Open the full 116-row CSV](davao_occidental_osm_destination_candidates_2026-11-04.csv).

This is a **complete extraction for the named OSM tag set below inside Davao Occidental's OSM boundary**, including its mapped islands. It is a list of *candidate places*, not an approved Lakbay tourist catalog. It supports Phase 2 destination-data research in `core_focus.md`. No live destination, fee, activity, database schema, or routing field was changed.

## Source and boundary

- Source: [Davao Region OSM PBF extract](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region-latest.osm.pbf) from the [regional extract index](https://download.openstreetmap.fr/extracts/asia/philippines/). Its replication state at download was `2026-11-03T00:12:04Z` (sequence `7356061`). The downloaded file's MD5 was `cee2272b08d86fd5160b51b3472fcad4`, matching the published [checksum](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region.osm.pbf.md5).
- Boundary: [OSM Davao Occidental relation 3304098](https://www.openstreetmap.org/relation/3304098), resolved to its polygon through [Nominatim's object lookup](https://nominatim.org/release-docs/latest/api/Lookup/). A feature was included when its mapped or representative point fell inside or on that polygon.
- Named nodes and ways were read from the regional PBF locally. Region-wide named relation features matching the tag set were checked; four had representative points inside Occidental: Basiawan Beach, Kisulad Beach, Balut Island, and Sarangani island. [Pyosmium's handler documentation](https://docs.osmcode.org/pyosmium/latest/reference/Handler-Processing/) describes the streaming read.
- Data attribution: © OpenStreetMap contributors, ODbL. See the [OSM attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines).

Using the regional file avoids dependence on the public Overpass bulk query service, which returned errors or timed out during the earlier audit.

## Inclusion rule

An object needed a `name` or `name:en` tag, a point in the province polygon, and at least one of these tags. Where several matched, the CSV records one primary matching tag. This applies the same tag set as the [Davao de Oro inventory](davao_de_oro_osm_destination_candidates_2026-11-04.md).

| OSM key | Included values or rule | Rows |
| --- | --- | ---: |
| `natural` | `beach`, `waterfall`, `peak`, `volcano`, `cave_entrance`, `hot_spring` | 74 |
| `amenity` | `place_of_worship`, `arts_centre`, `theatre` | 15 |
| `leisure` | `park`, `garden`, `nature_reserve`, `water_park`, `beach_resort`, `resort` | 9 |
| `place` | `island`, `islet` | 7 |
| `man_made` | `lighthouse`, `observation_tower` | 6 |
| `historic` | `monument`, `memorial`, `ruins`, `archaeological_site`, `wayside_shrine`, `fort`, `castle`, `heritage` | 3 |
| `tourism` | `attraction`, `museum`, `artwork`, `viewpoint`, `zoo`, `aquarium`, `theme_park`, `yes`, `picnic_site`, `camp_site`, `gallery` | 2 |
| `waterway` | `waterfall` | 0 |
| `landuse` | `recreation_ground` | 0 |
| `attraction` | any nonempty value, if none of the preceding rules matched | 0 |
| **Total** | | **116** |

The CSV has **96 nodes, 16 ways, and 4 relations**. Validation found 116 unique OSM IDs, no missing coordinate or link fields, and no coordinate outside the Davao Occidental polygon. All five Occidental features from the earlier regional starter list appear: Balut Island, DDG Beach Resort, Joyce Paradise, Little Boracay Beach Resort, and Miskeen Beach Resort.

## Reading the coordinates

`coordinate_basis` distinguishes mapped nodes from representative points computed on ways or returned for relations. A `polygon_interior`, `line_representative`, or `nominatim_representative` coordinate identifies a mapped feature; it is **not a verified public entrance**. Balut Island and Sarangani need a confirmed receiving pier for routing. Joyce Paradise is a mapped venue near the Christ the Redeemer monument; it does not verify the statue's own location or entrance. `arrival_verified` is `no` for every row.

Of the 116 rows, **69 are tagged `natural=peak` and 15 are places of worship**. They are retained as OSM place candidates, but many may not be public tourist destinations. Two names occur on more than one OSM object; those objects were retained separately. Fees, public access, tourist suitability, and operating status still need confirmation.

This is exhaustive only for the **named objects and selected tags in the dated OSM extract**. OSM may omit places, use other tags, contain duplicate or stale objects, or place a feature across a provincial border while its representative point lies outside. Unnamed objects are intentionally excluded. Any broader definition of destination needs a new tag set and another offline extraction. Do not copy these coordinates into `arrival_lat`/`arrival_lng` or set `route_ready=true` without verifying the visitor arrival point.
