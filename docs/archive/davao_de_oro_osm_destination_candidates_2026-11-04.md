# Davao de Oro OSM destination candidates — 4 November 2026

[Open the full 129-row CSV](davao_de_oro_osm_destination_candidates_2026-11-04.csv).

This is a **complete extraction for the named OSM tag set below inside Davao de Oro's OSM boundary**. It is a list of *candidate places*, not an approved Lakbay tourist catalog. It supports Phase 2 destination-data research in `core_focus.md`. No live destination, fee, activity, database schema, or routing field was changed.

## Source and boundary

- Source: [Davao Region OSM PBF extract](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region-latest.osm.pbf) from the [regional extract index](https://download.openstreetmap.fr/extracts/asia/philippines/). Its replication state at download was `2026-11-03T00:12:04Z` (sequence `7356061`). The downloaded file's MD5 was `cee2272b08d86fd5160b51b3472fcad4`, matching the published [checksum](https://download.openstreetmap.fr/extracts/asia/philippines/davao_region.osm.pbf.md5).
- Boundary: [OSM Davao de Oro relation 1507283](https://www.openstreetmap.org/relation/1507283), resolved to its polygon through [Nominatim's object lookup](https://nominatim.org/release-docs/latest/api/Lookup/). A feature was included when its mapped or representative point fell inside or on that polygon.
- Named nodes and ways were read from the regional PBF locally. Named region-wide relation features matching the selected tags were checked; none had a representative point inside Davao de Oro. [Pyosmium's handler documentation](https://docs.osmcode.org/pyosmium/latest/reference/Handler-Processing/) describes the streaming read.
- Data attribution: © OpenStreetMap contributors, ODbL. See the [OSM attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines).

Using the regional file avoids dependence on the public Overpass bulk query service, which returned errors or timed out during the earlier audit.

## Inclusion rule

An object needed a `name` or `name:en` tag, a point in the province polygon, and at least one of these tags. Where several matched, the CSV records one primary matching tag. This uses the [Davao del Sur inventory's](davao_del_sur_osm_destination_candidates_2026-11-04.md) visitor-relevant filter, plus `place=island` and `place=islet` so that Kopiat Island and other named islands are not missed. The extra island tag means counts should not be compared directly with the earlier provincial inventories without applying the same filter to them.

| OSM key | Included values or rule | Rows |
| --- | --- | ---: |
| `amenity` | `place_of_worship`, `arts_centre`, `theatre` | 59 |
| `leisure` | `park`, `garden`, `nature_reserve`, `water_park`, `beach_resort`, `resort` | 34 |
| `tourism` | `attraction`, `museum`, `artwork`, `viewpoint`, `zoo`, `aquarium`, `theme_park`, `yes`, `picnic_site`, `camp_site`, `gallery` | 13 |
| `natural` | `beach`, `waterfall`, `peak`, `volcano`, `cave_entrance`, `hot_spring` | 12 |
| `waterway` | `waterfall` | 8 |
| `place` | `island`, `islet` | 2 |
| `historic` | `monument`, `memorial`, `ruins`, `archaeological_site`, `wayside_shrine`, `fort`, `castle`, `heritage` | 1 |
| `man_made` | `lighthouse`, `observation_tower` | 0 |
| `landuse` | `recreation_ground` | 0 |
| `attraction` | any nonempty value, if none of the preceding rules matched | 0 |
| **Total** | | **129** |

The CSV has **83 nodes and 46 ways**. Validation found 129 unique OSM IDs, no missing coordinate or link fields, and no coordinate outside the Davao de Oro polygon. All eight Davao de Oro features from the earlier regional starter list appear: Bilawa Falls, Kopiat Island, Lake Leonard Eco-Tourism Park, Mainit Sulfuric Hot Spring, Mount Candalaga, New Barili Heights & Sights, Pyalitan Falls, and Tagbibinta Falls.

## Reading the coordinates

`coordinate_basis` distinguishes mapped nodes from representative points computed on ways. A `polygon_interior` or `line_representative` point identifies a mapped feature; it is **not a verified public entrance**. Falls, peaks, islands, parks, and resorts need separate visitor-access checks before routing. `arrival_verified` is `no` for every row. Kopiat Island's coordinate is an islet point, not a boat landing. Mainit Sulfuric Hot Spring is a specific mapped feature and should not automatically be merged with Lakbay's ambiguous `Mainit Hot Springs` record.

Of the 129 rows, **59 are tagged `amenity=place_of_worship`**. Some may be visitor destinations, while many may be ordinary local congregations. Two names occur on more than one OSM object; those objects were retained separately. Fees, public access, tourist suitability, and operating status still need confirmation.

This is exhaustive only for the **named objects and selected tags in the dated OSM extract**. OSM may omit places, use other tags, contain duplicate or stale objects, or place a feature across a provincial border while its representative point lies outside. Unnamed objects are intentionally excluded. Any broader definition of destination needs a new tag set and another offline extraction. Do not copy these coordinates into `arrival_lat`/`arrival_lng` or set `route_ready=true` without verifying the visitor arrival point.
