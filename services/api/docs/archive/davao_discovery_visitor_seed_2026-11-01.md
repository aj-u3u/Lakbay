# Four discovery-only Davao destinations

Imported 1 November 2026 into the configured Neon database after migration
`95bb71db451f`. The import added four active destinations, bringing the live
catalog from 18 to 22. Their coordinates identify the attraction approximately,
not a visitor gate, parking point, trailhead, or pier. All four have
`route_ready=false`, null arrival coordinates, null `estimated_cost`, and no
accommodation or transportation rate rows. Coordinate attribution:
© OpenStreetMap contributors, ODbL, via the linked Mapcarta pages.

| Destination (live ID) | Public place evidence | Approximate attraction point | Visitor detail still needed |
| --- | --- | --- | --- |
| [Panabo Mangrove Forest Park](https://www.experiencedavao.com/attractions/panabo-mangrove-forest-park) (#19) | [Panabo City documented a site visit](https://panabocity.gov.ph/city-of-cabadbaran-nag-benchmark-sa-lgu-panabo/). | [OSM mapped site](https://mapcarta.com/W1436929311), 7.26989, 125.68049 | Confirm public opening, admission, and the entry point with Panabo City. |
| [Christ the King Cathedral Parish](https://www.experiencedavao.com/destinations/davao-del-norte/tagum-city/attractions/christ-the-king-cathedral-parish) (#20) | DOT Region XI lists the Tagum landmark and its Dr. Juan Gonzales Avenue address. | [OSM building](https://mapcarta.com/W828786282), 7.44115, 125.79992 | Confirm visiting hours, any tourist charge, and public compound entrance with the parish. Respect worship activity. |
| [Digos City Eco Park and Arboretum](https://digoscity.gov.ph/?page_id=491) (#21) | Digos City lists the park for tourism; [ordinance 2022-114](https://digoscity.gov.ph/site_assets/pdf/Table-of-Ordinances.pdf) established it in Sitio San Nicolas, Tres de Mayo. | [OSM park](https://mapcarta.com/W1382022448), 6.77553, 125.34392 | Confirm current public opening, fee, and entrance with Digos City. |
| [San Salvador del Mundo Church](https://www.experiencedavao.com/destinations/davao-oriental) (#22) | DOT Region XI lists the church in Caraga. | [OSM church](https://mapcarta.com/W322426196), 7.32770, 126.56588 | Confirm visiting hours, any visitor charge, and public entrance with the parish. Respect worship activity. |

The seed lives in `DISCOVERY_VISITOR_DESTINATIONS` in
`app/seeds/davao_destinations.py`. To import only this reviewed batch into an
intended database at migration `95bb71db451f` or later:

```powershell
python -m app.seeds.davao_destinations --discovery-only
```

The seed looks up each exact name and inserts only missing rows; running it
again does not replace or duplicate existing records. The command is separate
from `--curated-only`, which still targets the previous five-place batch.
Unknown costs are stored as SQL null, not PHP 0. The API returns null, a budget
estimate identifies the selected destination IDs needing costs, and a saved
maximum cost excludes unknown-cost destinations from recommendations. Group
scoring excludes unknown-cost rows and reports a warning. A planning preview
can still show the place with a null catalog cost. See
[destination API rules](../destinations.md) and
[coverage continuation](phase2_coverage_arrival_continuation_2026-11-01.md).

Read-back after import found revision `95bb71db451f`, the four IDs above, and
active district counts of 5 Davao City, 5 Davao del Norte, 4 Davao del Sur,
4 Davao Oriental, 2 Davao de Oro, and 2 Davao Occidental. At this point eight
more named, source-backed places were needed. The later
[coverage completion batch](davao_coverage_completion_seed_2026-11-01.md)
added those eight, bringing every district to five. No current record has a
verified arrival point.
