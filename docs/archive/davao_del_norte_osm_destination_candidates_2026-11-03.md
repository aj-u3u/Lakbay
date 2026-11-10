# Davao del Norte OSM destination candidates — 3 November 2026

[Open the full 421-row CSV](davao_del_norte_osm_destination_candidates_2026-11-03.csv).

This is a **complete extraction for the named OSM tag set below within the Davao del Norte OSM boundary**, including the Island Garden City of Samal. It is a list of *candidate places*, not an approved Lakbay tourist catalog. It supports the Phase 2 destination-data work in `core_focus.md`. No live destination, fee, activity, database schema, or routing field was changed.

## Source and boundary

- Source: [Davao Region OSM PBF extract](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region-latest.osm.pbf) from the [regional extract index](https://download.openstreetmap.fr/extracts/asia/philippines/). Its replication state at download was `2026-11-03T00:12:04Z` (sequence `7356061`). The downloaded file's MD5 was `cee2272b08d86fd5160b51b3472fcad4`, matching the published [checksum](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region.osm.pbf.md5).
- Boundary: [OSM Davao del Norte relation 1507313](https://www.openstreetmap.org/relation/1507313), resolved to its polygon through [Nominatim's object lookup](https://nominatim.org/release-docs/latest/api/Lookup/). Features were included when their mapped or representative point fell inside the polygon.
- Named nodes and ways were read from the regional PBF locally. The 15 named region-wide relations matching the tag set were checked in one Nominatim lookup; 10 had representative points inside the province.
- Data attribution: © OpenStreetMap contributors, ODbL. See the [OSM attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines).

Using the regional file avoids dependence on the public Overpass bulk query service, which returned errors or timed out during the earlier audit. [Pyosmium's handler documentation](https://docs.osmcode.org/pyosmium/latest/reference/Handler-Processing/) describes the local streaming read used for nodes and ways.

## Inclusion rule

An object needed a `name` or `name:en` tag, a point inside the province polygon, and at least one of these tags. Where several matched, the CSV records one primary matching tag.

| OSM key | Included values or rule | Rows |
| --- | --- | ---: |
| `amenity` | `place_of_worship`, `arts_centre`, `theatre` | 199 |
| `leisure` | `park`, `garden`, `nature_reserve`, `water_park`, `beach_resort`, `resort` | 131 |
| `natural` | `beach`, `waterfall`, `peak`, `cave_entrance`, `hot_spring` | 42 |
| `tourism` | `attraction`, `museum`, `artwork`, `viewpoint`, `zoo`, `aquarium`, `theme_park`, `yes`, `picnic_site`, `camp_site`, `gallery` | 32 |
| `waterway` | `waterfall` | 7 |
| `historic` | `monument`, `memorial`, `ruins`, `archaeological_site`, `wayside_shrine`, `fort`, `castle`, `heritage` | 5 |
| `landuse` | `recreation_ground` | 2 |
| `man_made` | `lighthouse`, `observation_tower` | 2 |
| `attraction` | any nonempty value, if none of the preceding rules matched | 1 |
| **Total** | | **421** |

The CSV has **229 nodes, 182 ways, and 10 relations**. There are 421 unique OSM object IDs, no missing coordinate or link fields, and no point outside the province bounding box. All 764 named, matching ways in the wider regional extract had complete node locations. The inventory includes all eight Davao del Norte examples from the earlier regional starter list, including Agriya, Aqua Water Park, Hagimit Falls, Monfort Bat Sanctuary, and the Panabo parks.

## Reading the coordinates

`coordinate_basis` distinguishes mapped nodes from points computed on ways and points returned for relations. A `polygon_interior` or `line_representative` coordinate identifies the mapped feature; it is **not a verified public entrance**. Island beaches, waterfalls, peaks, parks, resorts, and churches need an access review before routing. `arrival_verified` is `no` on every row.

Of the 421 rows, **199 are places of worship**. They are retained because some churches are visitor destinations, but many may be ordinary local congregations. The 15 repeated-name groups were not collapsed: distinct OSM objects can have the same name. Fees, public access, suitability as a tourist destination, and operating status still need confirmation.

This is exhaustive only for the **named objects and selected tags in the dated OSM extract**. OSM may omit places, use other tags, contain duplicate or stale objects, or place a feature across the provincial border while its representative point lies outside. Unnamed objects are intentionally excluded. Any broader definition of destination requires a new tag set and another offline extraction. Do not copy these coordinates into `arrival_lat`/`arrival_lng` or set `route_ready=true` without verifying the visitor arrival point.
