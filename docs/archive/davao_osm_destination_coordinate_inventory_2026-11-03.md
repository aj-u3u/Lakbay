# Davao OSM destination coordinate inventory — 3 November 2026

[Download the CSV](davao_osm_destination_coordinate_inventory_2026-11-03.csv).

This is a **41-place, source-linked starting inventory**, covering Davao City and all five Davao provinces. It is Phase 2 destination-data research under `core_focus.md`. It does not change Lakbay's live database, seed code, destination classifications, fees, activities, or routing state.

| Area | OSM features |
| --- | ---: |
| Davao City | 10 |
| Davao del Norte | 8 |
| Davao del Sur | 5 |
| Davao Oriental | 5 |
| Davao de Oro | 8 |
| Davao Occidental | 5 |
| **Total** | **41** |

The CSV lists each OSM object's current name, latitude, longitude, object ID and link. Coordinates were checked through [Nominatim's OSM object lookup](https://nominatim.org/release-docs/latest/api/Lookup/) or, for Agriya, the [OSM node API](https://api.openstreetmap.org/api/0.6/nodes.json?nodes=9205138314,14282996052). The inventory includes places from the existing 30-destination catalog and separately documented candidates. © OpenStreetMap contributors, ODbL; see the [OSM attribution guidance](https://osmfoundation.org/wiki/Attribution_Guidelines).

## What the coordinates mean

An OSM `node` has a mapped point. For a `way` or `relation`, Nominatim returns a representative point for the mapped feature. Neither kind of coordinate is automatically a visitor gate, road arrival, pier, trailhead, or confirmation that public entry is allowed. Every row remains an **unverified arrival** until separately checked.

The list also includes physical landmarks such as Mount Apo and Mount Candalaga, and broad features such as Balut Island. They are geographic points for identifying the place, not direct driving destinations. The `review_note` column calls out these cases. Agriya's park node is distinct from its township node. Joyce Paradise is a mapped venue near the Christ the Redeemer monument; this does not prove the statue's own coordinate. Mainit Sulfuric Hot Spring is a specific mapped feature and should not be automatically merged with Lakbay's ambiguous `Mainit Hot Springs` record.

## Coverage boundary

“All available OSM destinations” has no fixed meaning: OSM contains many tagged tourism, leisure, historic, natural, religious, accommodation, and food features, including unnamed objects and places with no confirmed public access. This file is **not an exhaustive extract** of those features. It contains the places we could trace to a specific OSM object and check in this review. The public Overpass endpoints tried for a broader regional extraction returned errors or timeouts, so no claim of complete regional coverage is made. A true exhaustive inventory needs an agreed tag set and a full regional OSM extract, followed by name deduplication, boundary checks, and manual visitor-access review.

The coordinates should not be copied into `arrival_lat`/`arrival_lng` or used to set `route_ready=true` until the public arrival point is verified. The [coordinate audit](destination_osm_coordinate_audit_2026-11-03.md) compares the 30 saved Lakbay points with OSM.
