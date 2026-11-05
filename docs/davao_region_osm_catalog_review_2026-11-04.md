# Davao Region OSM catalog review — 4 November 2026

[Open the row-by-row review](davao_region_osm_catalog_triage_2026-11-04.jsonl). Each JSON line retains the source area, OSM identity, coordinates, source tag, suggested category, decision, and the limited access evidence in the 3 November 2026 OSM extract. This is a **tag-based first pass**, not a field or operator verification.

## Phase alignment and decision

Reviewing and preloading destination records fits **Phase 2: Destination Data Foundation** in [core_focus.md](core_focus.md). The existing model and admin create endpoint can hold a place name and attraction coordinate without fees or arrival coordinates. New destinations default to `route_ready=false`. A new schema is not required just to store an initial place pin. Publishing unreviewed records as active destinations would affect traveler browse, recommendations, AI itinerary selection, and routing previews, so the full OSM extract should not be inserted wholesale.

No backend code, seed, live catalog, database table, or arrival point was changed in this review. `catalog_added=false` and `arrival_verified=false` in every review line.

## Six-source audit

| Source area | Source rows | Visitor candidates needing review |
| --- | ---: | ---: |
| Davao City | 792 | 191 |
| Davao del Norte | 421 | 184 |
| Davao del Sur | 243 | 78 |
| Davao de Oro | 129 | 53 |
| Davao Occidental | 116 | 20 |
| Davao Oriental | 223 | 123 |
| **Total** | **1,924** | **649** |

The six files contain **1,920 unique OSM type/ID pairs**. Four objects occur in two area files because their points lie on OSM administrative boundaries: Mount Apo, Tumari Falls, Caputian Hill, and Kabakungan Hill. These must become at most one catalog record each after area assignment. All 1,920 OSM objects were found in the local regional PBF. Exact name comparison with the repository's 29 seed destinations found 17 source rows that may already be represented; name alone is not a reliable duplicate key, and the live catalog may differ from that seed.

| First-pass decision | Source rows | Meaning |
| --- | ---: | --- |
| `visitor_candidate_review` | 649 | The OSM type suggests a visitable attraction, park, beach, resort, museum, viewpoint, waterfall, and similar place. Identity, current access, and the arrival point still need checking. |
| `special_case_review` | 1,261 | The tag by itself does not establish a tourist spot. This includes 914 places of worship, 201 peaks, artwork, memorials, malls, islands, and other context-dependent places. |
| `hold_restricted_or_closed` | 14 | OSM says `access=private` or `access=emergency`, or `opening_hours=closed`. Do not publish without newer contrary evidence. |

The OSM metadata is sparse: **1,888 of 1,920 unique objects lack an `access` tag**, 1,852 lack `opening_hours`, and 1,899 lack a `fee` tag. Missing tags mean **unknown**, not public or free. Some tagged sites permit customers or require permits; those conditions also need checking.

## When Lakbay may call a place a tourist spot

A place qualifies for the public tourist catalog when all of these are established:

1. **Visitor purpose:** a traveler can reasonably visit it for recreation, nature, heritage, culture, learning, sightseeing, or a comparable experience. An OSM name or broad tag alone is only a lead.
2. **Current identity:** the place still exists and the OSM feature represents the intended site, not an obsolete name, duplicate object, or a large regional feature used in place of a specific venue.
3. **Lawful visitor access:** visitors are allowed under stated conditions. Private, emergency-only, closed, unsafe, or permit-only places need explicit handling; access is never inferred from a map pin.
4. **Location evidence:** the attraction pin is credible and belongs to the correct city or province. For ways and relations, the exported point is representative, not necessarily a gate.
5. **Catalog uniqueness and category:** the same place is not already active under another name or OSM object. Its category describes the visit accurately; for example a mall is a shopping destination, and a generic church or peak is not automatically a tourist attraction.
6. **Honest unknowns:** fees, hours, activities, amenities, accessibility, and transport should remain unknown until checked. Do not turn missing data into “Free,” “Open,” or accessibility `true`.

A verified **visitor arrival point** is a separate routing requirement. A tourist spot may have an attraction pin before its public gate is known, but it must stay `route_ready=false`; route output is only a planning preview. A dotted map connector must not assert that an unmapped gap is safe or walkable.

## Proposed catalog sequence

1. Review the 649 visitor candidates first. Check the 14 restricted/closed records against current operator or local evidence before reconsidering them. Review special cases when there is specific cultural, recreational, or visitor evidence.
2. Match each proposed addition to the **current live catalog**, using OSM ID where available, normalized name, nearby coordinates, and operator identity. The seed-name flag in the review file is only a prompt for this check.
3. Verify current public access and attraction location. Record an OSM URL and any independent source in the curation record. Keep fees, hours, and activities blank until supplied or verified.
4. Import only approved records as active destinations, with `route_ready=false` and no invented arrival point. Review the Flutter map and route preview with a small pilot batch before a wider import.
5. Add a verified gate or receiving point later, with its source and verification time, before enabling turn-by-turn directions.

The current destination table has no stable OSM type/ID or publication-review field. A bulk import into that table would need a deliberate duplicate/provenance plan, preferably before repeated updates from OSM. This is a design choice for the implementation review, not a change made here.

OSM data attribution is required when the data is published in Lakbay. See the [OpenStreetMap Foundation attribution guidelines](https://osmfoundation.org/wiki/Attribution_Guidelines). The source coordinate inventories and this review derive from the local Davao Region OSM PBF snapshot, not Google Maps.
