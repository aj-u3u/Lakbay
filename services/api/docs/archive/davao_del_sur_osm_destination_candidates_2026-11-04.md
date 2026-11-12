# Davao del Sur OSM destination candidates — 4 November 2026

[Open the full 243-row CSV](davao_del_sur_osm_destination_candidates_2026-11-04.csv).

This is a **complete extraction for the named OSM tag set below inside Davao del Sur's OSM boundary**. It includes Digos and excludes Davao City. It is a list of *candidate places*, not an approved Lakbay tourist catalog. It supports the Phase 2 destination-data work in `core_focus.md`. No live destination, fee, activity, database schema, or routing field was changed.

## Source and boundary

- Source: [Davao Region OSM PBF extract](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region-latest.osm.pbf) from the [regional extract index](https://download.openstreetmap.fr/extracts/asia/philippines/). Its replication state at download was `2026-11-03T00:12:04Z` (sequence `7356061`). The downloaded file's MD5 was `cee2272b08d86fd5160b51b3472fcad4`, matching the published [checksum](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region.osm.pbf.md5).
- Boundary: [OSM Davao del Sur relation 1513050](https://www.openstreetmap.org/relation/1513050), resolved to its polygon through [Nominatim's object lookup](https://nominatim.org/release-docs/latest/api/Lookup/). A feature was included when its mapped or representative point fell inside or on that polygon. Mount Apo's summit point lies on the boundary and is included.
- Named nodes and ways were read from the regional PBF locally. The 15 named relation features in the wider Davao Region matching the tag set were checked; none had a representative point inside Davao del Sur. [Pyosmium's handler documentation](https://docs.osmcode.org/pyosmium/latest/reference/Handler-Processing/) describes the local streaming read.
- Data attribution: © OpenStreetMap contributors, ODbL. See the [OSM attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines).

Using the regional file avoids dependence on the public Overpass bulk query service, which returned errors or timed out during the earlier audit.

## Inclusion rule

An object needed a `name` or `name:en` tag, a point in the province polygon, and at least one of these tags. Where several matched, the CSV records one primary matching tag. This uses the same core filter as the [Davao del Norte inventory](davao_del_norte_osm_destination_candidates_2026-11-03.md), with `natural=volcano` added because OSM maps Mount Apo that way. A check found no named volcano point inside Davao del Norte, so that addition does not change its count.

| OSM key | Included values or rule | Rows |
| --- | --- | ---: |
| `amenity` | `place_of_worship`, `arts_centre`, `theatre` | 101 |
| `natural` | `beach`, `waterfall`, `peak`, `volcano`, `cave_entrance`, `hot_spring` | 57 |
| `tourism` | `attraction`, `museum`, `artwork`, `viewpoint`, `zoo`, `aquarium`, `theme_park`, `yes`, `picnic_site`, `camp_site`, `gallery` | 36 |
| `leisure` | `park`, `garden`, `nature_reserve`, `water_park`, `beach_resort`, `resort` | 35 |
| `waterway` | `waterfall` | 8 |
| `historic` | `monument`, `memorial`, `ruins`, `archaeological_site`, `wayside_shrine`, `fort`, `castle`, `heritage` | 2 |
| `man_made` | `lighthouse`, `observation_tower` | 2 |
| `attraction` | any nonempty value, if none of the preceding rules matched | 2 |
| `landuse` | `recreation_ground` | 0 |
| **Total** | | **243** |

The CSV has **158 nodes and 85 ways**. Validation found 243 unique OSM IDs, no missing coordinate or link fields, and no point outside the Davao del Sur polygon. All five Davao del Sur examples from the earlier regional starter list appear: Camp Sabros Mountain Resort, Digos City Eco Park and Arboretum, Mount Apo, Rizal Park, and Tudaya Falls.

## Reading the coordinates

`coordinate_basis` distinguishes mapped nodes from representative points computed on ways. A `polygon_interior` or `line_representative` point identifies a mapped feature; it is **not a verified public entrance**. Falls, peaks, volcanoes, parks, resorts, and churches need separate visitor-access checks before routing. `arrival_verified` is `no` for every row. In particular, Mount Apo's summit coordinate is not a trailhead or road arrival.

Of the 243 rows, **100 are tagged `amenity=place_of_worship`**. Some may be visitor destinations, while many may be ordinary local congregations. Nine names occur on more than one OSM object; those objects were retained separately. Fees, public access, tourist suitability, and operating status still need confirmation.

This is exhaustive only for the **named objects and selected tags in the dated OSM extract**. OSM may omit places, use other tags, contain duplicate or stale objects, or place a feature across a provincial border while its representative point lies outside. Unnamed objects are intentionally excluded. Any broader definition of destination needs a new tag set and another offline extraction. Do not copy these coordinates into `arrival_lat`/`arrival_lng` or set `route_ready=true` without verifying the visitor arrival point.
