# Active destination coordinate audit — 3 November 2026

Read-only comparison of the 30 active destination `lat`/`lng` values in the connected Lakbay database with current OpenStreetMap (OSM) features. No destination or arrival coordinate was changed.

## Method and limits

- OSM features were identified by name and location, then checked by object ID through [Nominatim's OSM object lookup](https://nominatim.org/release-docs/latest/api/Lookup/). Distances below are rounded great-circle distances between the saved point and the OSM point or representative point for a way/relation. © OpenStreetMap contributors, ODbL.
- A point on a park, beach, resort, church, or island may differ from an OSM representative point while still being inside the feature. Conversely, close coordinates do not prove a safe, public arrival point.
- `Likely displaced` means the candidate named OSM feature is over 500 m away; it is a review finding, not permission to replace a coordinate automatically. `Review` is 50–500 m. `Aligned` is within 50 m of the identified feature. Ambiguous places have their own status.
- The Google coordinate supplied by the user was used only as a cross-check for the Philippine Eagle Center; OSM is the comparison source for this audit.

## Results

| ID | Saved destination | Lakbay lat, lng | Compared OSM feature; lat, lng | Offset | Finding |
| ---: | --- | --- | --- | ---: | --- |
| 1 | People's Park | 7.07070, 125.60960 | [People's Park way](https://www.openstreetmap.org/way/28993492); 7.0709328, 125.6087877 | 93 m | Review park point and public gate. |
| 2 | Philippine Eagle Center | 7.18540, 125.41690 | [Philippine Eagle Center node](https://www.openstreetmap.org/node/747886405); 7.1848752, 125.4152870 | 187 m | Review; saved pin is visibly displaced. User's 7.18498, 125.41528 is about 12 m from the OSM node. Entrance remains unverified. |
| 3 | Eden Nature Park | 7.00880, 125.39920 | [Eden Nature Park and Resort way](https://www.openstreetmap.org/way/1135430452); 7.0282403, 125.4017550 | 2,180 m | Likely displaced; [reception area](https://www.openstreetmap.org/way/538858577) is a distinct mapped feature. |
| 4 | Samal Island Beach Area | 7.07440, 125.70870 | No unique OSM feature for this generic beach-area name | — | Cannot verify until a specific public beach or venue is chosen. |
| 5 | Mount Apo Trail Area | 6.98750, 125.27080 | [Mount Apo peak node](https://www.openstreetmap.org/node/416326155); 6.9873416, 125.2709954 | 28 m | Near the summit, but this does **not** verify a trailhead or visitor arrival. |
| 6 | Dahican Beach | 6.94870, 126.25420 | [Dahican Beach way](https://www.openstreetmap.org/way/651370443); 6.9243488, 126.2808986 | 4,002 m | Likely displaced relative to this OSM beach; choose a named public access point. |
| 7 | Panabo City Parks and Plaza | 7.30810, 125.68420 | [Panabo City Park way](https://www.openstreetmap.org/way/614154998); 7.2996292, 125.6813143 | 994 m | Likely displaced if this is the intended park; confirm name equivalence. |
| 8 | Tagbibinta Falls | 7.34760, 126.15140 | [Tagbibinta Falls node](https://www.openstreetmap.org/node/7076360886); 7.3163971, 126.1718680 | 4,139 m | Likely displaced; the falls and road/trail arrival are separate points. |
| 9 | Mainit Hot Springs | 7.36360, 125.94940 | Possible [Mainit Sulfuric Hot Spring way](https://www.openstreetmap.org/way/1000619479); 7.4013531, 126.0288832 | 9,718 m | **Ambiguous identity**; cannot call this the same place. Identify the intended spring before changing anything. |
| 10 | Little Boracay Beach | 6.53610, 125.46930 | [Little Boracay Beach Resort way](https://www.openstreetmap.org/way/1104821790); 6.5651682, 125.4968126 | 4,437 m | Likely displaced if this resort is intended; confirm exact beach/venue. |
| 11 | Balut Island | 5.40470, 125.37650 | [Balut Island relation](https://www.openstreetmap.org/relation/7129791); 5.4017256, 125.3852859 | 1,027 m | **Island-wide feature**; offset from a representative point does not establish an error. Choose a landing pier for routing. |
| 12 | Tudaya Falls | 6.98420, 125.39120 | [Tudaya Falls node](https://www.openstreetmap.org/node/5062921518); 6.9590797, 125.3554587 | 4,834 m | Likely displaced; waterfall and approved trailhead are separate points. |
| 13 | Aliwagwag Falls | 7.74310, 126.42180 | [Aliwagwag Falls node](https://www.openstreetmap.org/node/5799152058); 7.7404501, 126.3014983 | 13,258 m | Likely displaced; verify the attraction versus ecopark entrance separately. |
| 14 | Museo Dabawenyo | 7.07939, 125.60449 | [Museo Dabawenyo node](https://www.openstreetmap.org/node/13179862776); 7.0793875, 125.6044903 | <1 m | Aligned; public door unverified. |
| 15 | National Museum of the Philippines - Davao | 7.07016, 125.60914 | [Museum way](https://www.openstreetmap.org/way/1153418558); 7.0702233, 125.6091628 | 7 m | Aligned; public door unverified. |
| 16 | Aqua Water Park | 7.08705, 125.66662 | [Aqua Water Park node](https://www.openstreetmap.org/node/9211408403); 7.0870452, 125.6666218 | 1 m | Aligned; pier and entrance unverified. |
| 17 | Camp Sabros Mountain Resort | 6.90514, 125.34654 | [Camp Sabros way](https://www.openstreetmap.org/way/1454653112); 6.9054365, 125.3470619 | 66 m | Review; operator-described parking area is separate from camp. |
| 18 | Subangan Museum | 6.94423, 126.24834 | [Subangan way](https://www.openstreetmap.org/way/1328605333); 6.9442424, 126.2483375 | 1 m | Aligned; entrance unverified. |
| 19 | Panabo Mangrove Forest Park | 7.26989, 125.68049 | [Panabo Mangroves Forest Park way](https://www.openstreetmap.org/way/1436929311); 7.2698402, 125.6803912 | 12 m | Aligned; boardwalk entrance unverified. |
| 20 | Christ the King Cathedral Parish | 7.44115, 125.79992 | [Christ the King Cathedral way](https://www.openstreetmap.org/way/828786282); 7.4412082, 125.7999089 | 7 m | Aligned; public entrance unverified. |
| 21 | Digos City Eco Park and Arboretum | 6.77553, 125.34392 | [Eco Park way](https://www.openstreetmap.org/way/1382022448); 6.7755018, 125.3439083 | 3 m | Aligned; entrance unverified. |
| 22 | San Salvador del Mundo Church | 7.32770, 126.56588 | [El Salvador del Mundo Parish way](https://www.openstreetmap.org/way/322426196); 7.3277005, 126.5658774 | <1 m | Aligned; parish name variant, entrance unverified. |
| 23 | Rizal Park Digos | 6.74442, 125.35556 | [Rizal Park way](https://www.openstreetmap.org/way/97188461); 6.7444181, 125.3555565 | <1 m | Aligned; entrance unverified. |
| 24 | Cape San Agustin | 6.26932, 126.19297 | [Cape San Agustin node](https://www.openstreetmap.org/node/4385211700); 6.2693185, 126.1929652 | 1 m | Aligned; cape point is not the ecopark gate. |
| 25 | New Barili Heights and Sights | 7.35411, 126.01136 | [New Barili Heights & Sights node](https://www.openstreetmap.org/node/9671315617); 7.3541053, 126.0113611 | 1 m | Aligned; visitor approach unverified. |
| 26 | Pyalitan Falls | 7.29919, 126.17070 | [Pyalitan Falls node](https://www.openstreetmap.org/node/7345718185); 7.2991848, 126.1706967 | 1 m | Aligned; road/trail arrival unverified. |
| 27 | Lake Leonard Eco-Tourism Park | 7.39792, 126.05760 | [Lake Leonard Eco-Tourism Park node](https://www.openstreetmap.org/node/7170393085); 7.3979217, 126.0575963 | <1 m | Aligned; entrance unverified. |
| 28 | Christ the Redeemer, Jose Abad Santos | 5.96223, 125.67773 | [Joyce Paradise viewpoint way](https://www.openstreetmap.org/way/916520663); 5.9622850, 125.6777536 | 7 m | Near the venue, but no separate OSM statue point was verified. |
| 29 | DDG Beach Resort | 6.62303, 125.43369 | [DDG Beach Resort node](https://www.openstreetmap.org/node/10111274417); 6.6230303, 125.4336855 | <1 m | Aligned; entrance unverified. |
| 30 | Meskeen Resort (Malita Dives) | 6.49131, 125.57969 | [Miskeen Beach Resort node](https://www.openstreetmap.org/node/12452684186); 6.4913065, 125.5796917 | <1 m | Aligned to probable spelling variant; verify the operator/entrance. |

## Actionable conclusion

Fifteen saved points are within 50 m of a plausible named OSM feature. Seven have likely displaced pins: Eden Nature Park, Dahican Beach, Panabo City Parks and Plaza, Tagbibinta Falls, Little Boracay Beach, Tudaya Falls, and Aliwagwag Falls. People's Park, Philippine Eagle Center, and Camp Sabros need closer coordinate review. Balut Island, Mainit Hot Springs, Samal Island Beach Area, Mount Apo Trail Area, and Christ the Redeemer require a specific feature/arrival interpretation before claiming coordinate agreement. **None of these OSM comparisons verifies a public arrival point.**

For Philippine Eagle Center, the current OSM node is `7.1848752, 125.4152870`. It is about 187 m from Lakbay's saved pin and about 12 m from the coordinate supplied by the user. The attraction pin and public entrance should be stored and verified separately; this audit does not set `route_ready`.
