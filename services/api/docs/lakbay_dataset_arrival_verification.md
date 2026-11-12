# Lakbay+ traveler arrival-point review

Reviewed 29 October 2026 against the 118 numbered entries in `Lakbay+ DATASET.pdf`. Read with the [place and coordinate audit](lakbay_dataset_location_audit.md), which records the evidence and the PDF pin verdict for every row. The names in this report are **arrival targets to verify**, not certified GPS waypoints. No PDF coordinate has been approved for routing. This review did not verify today's opening hours, permissions, road conditions, or transport schedules.

## Decision for routing

**Do not feed the PDF coordinates directly to OSRM.** The place audit rejects 67 of the 118 PDF points; 51 remain unverified. Even a supported venue name can be paired with a wrong pin. An island, river, bay, mountain peak, or waterfall center is usually not where the traveler should arrive. A road route should end at an accessible entrance, parking area, trail registration point, or departure pier. An island trip additionally needs a confirmed landing pier and boat leg.

The table uses these arrival states:

- **Venue**: a specific, supported facility or address is identifiable. Confirm its active public gate and exact road-connected point before routing.
- **Access**: the place is supported, but the trailhead, parking place, access road, or shore landing still needs selection.
- **Choose**: the PDF names a broad area or multiple possible access points; choose a specific traveler destination.
- **Hold**: the place identity, public access, or operating venue remains uncertain or contradicted. Do not expose as a routable destination yet.

**Route-ready with a verified arrival coordinate: 0 of 118.** The tables identify what to verify next; they do not imply that every candidate is safe, open, or legally accessible.

Arrival triage: **36 Venue**, **24 Access**, **15 Choose**, **43 Hold**. These are work queues, not counts of certified entrances.

### Google Maps spot check (29 October 2026)

Google Maps is accessible in the browser and is useful for finding a place listing, road approach, photos, and candidate coordinates. Its main place pin is not automatically a gate or parking pin.

- [Malagos Garden Resort on Google Maps](https://www.google.com/maps/search/?api=1&query=Malagos+Garden+Resort+Davao) lists the resort on Calinan–Baguio–Cadalian Road. The displayed main pin is near that road, but the view did not identify a separately marked visitor gate. The resort operator's address and directions support the venue, not a precise gate coordinate [C20].
- [Philippine Eagle Center on Google Maps](https://www.google.com/maps/search/?api=1&query=Philippine+Eagle+Center+Malagos+Davao) lists Purok 5, Malagos–Baguio District. Its place pin appears inside the center grounds; searching for “Philippine Eagle Center entrance” returned the same place listing, not a distinct entrance. Ask the foundation for the vehicle drop-off pin [C21].
- [Tagbibinta Falls on Google Maps](https://www.google.com/maps/search/?api=1&query=Tagbibinta+Falls+Maragusan) displays the falls north of the mapped Tagbibinta Road. A search including “parking area” resolved to the falls listing, without a separate parking marker. The provincial directions specifically say to park about 250 m before the falls [D21].

For a final waypoint, compare the Google Maps place pin, satellite/Street View or recent visitor photos if available, and the operator or local tourism office's directions. Ask: **“Please send the pin for the public entrance or parking area where a car should stop, not the attraction itself. Is that access open and suitable for a traveler arriving by car?”** For islands, ask for both the departure pier and the receiving landing. Save the answer, confirmation date, and the road-connected coordinate before enabling routes.

## Traveler arrival target for each PDF row

### Davao City (23)

| # | PDF place | State | Traveler should arrive at / action needed |
|---:|---|:---:|---|
| 1 | Malagos Garden Resort | Venue | Resort reception/main gate in Malagos, Baguio District. Use the operator's route via Calinan; obtain the gate pin. PDF pin is displaced [C20]. |
| 2 | Philippine Eagle Center | Venue | Center's visitor entrance in Malagos, Baguio District; verify it separately from Malagos Garden Resort. PDF pin is displaced [C21]. |
| 3 | Davao Crocodile Park | Venue | Park visitor gate at Riverfront Corporate City, Ma-a. A third-party guide proposes a gate point, but the operator has not confirmed it [C6][C13]. |
| 4 | Davao Riverfront Crocodile Park | Hold | Same Riverfront venue as row 3; merge identity and use one confirmed park gate. |
| 5 | People's Park | Venue | Public pedestrian entrance on Palma Gil Street, not the park center; confirm the active gate [C22]. |
| 6 | Roxas Night Market | Access | Choose a legal pedestrian approach at the Roxas Avenue market boundary, not a point inside the vehicle-closed market stretch [C23]. |
| 7 | Davao Chinatown | Choose | Select a specific arch or starting corner on Ramon Magsaysay Avenue for a walking visit [C2]. |
| 8 | San Pedro Cathedral | Venue | Cathedral public entrance on San Pedro Street; verify road-side drop-off [C7]. |
| 9 | Museo Dabawenyo | Venue | Museum/event-center visitor entrance on Mabini Street beside Davao City National High School; do not route to the old Pichon Street site [C3]. |
| 10 | Davao Museum of History | Hold | Confirm that the intended venue is Davao Museum of History and Ethnography and that it is open at Rodriguez Hall, Ateneo de Davao Jacinto campus, Roxas Avenue side [C4]. |
| 11 | Rizal Park | Venue | Pick an active pedestrian entrance on the San Pedro civic plaza side, then check its location on a current map [C11]. |
| 12 | Davao City Hall | Venue | Public City Hall entrance on San Pedro Street, with legal drop-off [C11]. |
| 13 | Eden Nature Park | Venue | Eden Nature Park & Resort main entrance in Barangay Eden, Toril. The operator describes the approach from Toril/Mercury Drugstore crossing, then the left fork toward Barangay Eden [C10]. |
| 14 | Lola's Garden (Eden) | Hold | Confirm this is a separately bookable public site; otherwise route to Eden's main entrance as an internal attraction, not a second destination. |
| 15 | Jack's Ridge | Venue | Resort/restaurant gate at Shrine Hills, Matina Crossing; obtain the exact vehicle entrance [C19]. |
| 16 | Lon Wa Buddhist Temple | Venue | Temple visitor entrance on Cabaguio Avenue; correct the PDF's Talomo label and pin [C14]. |
| 17 | SM Lanang Premier | Venue | Choose the mall entrance or transport drop-off relevant to the visit on J. P. Laurel Avenue, Lanang; PDF pin is displaced [C8][C15]. |
| 18 | Abreeza Mall | Venue | Choose a public mall entrance/drop-off on J. P. Laurel Avenue; PDF pin is displaced [C8][C16]. |
| 19 | Tamayong Prayer Mountain | Hold | Confirm visitor eligibility, booking, exact facility, and controlled entry point in Tamayong/Calinan before listing. |
| 20 | Bankerohan Public Market | Venue | Select the market's active public gate and legal vehicle drop-off; do not use an internal stall/centroid [C1]. |
| 21 | Aldevinco Shopping Center | Hold | Original center closed. If the user means former tenants, create a distinct Poblacion Market Central listing and confirm its gate [C17]. |
| 22 | Mount Apo (via Davao City side) | Hold | Specify an authorized Davao City-side climb route, registration office, and trailhead; a summit pin is unusable as a road arrival. |
| 23 | Davao Baywalk | Choose | Specify the intended baywalk segment, likely Matina Aplaya/Queensland, and a public promenade entrance; correct the Poblacion label [C18]. |

### Davao del Norte (26)

| # | PDF place | State | Traveler should arrive at / action needed |
|---:|---|:---:|---|
| 1 | Samal Island (General) | Choose | Choose the departure ferry terminal and Samal arrival terminal for the selected crossing; an island center cannot be a routing endpoint. |
| 2 | Kaputian Beach Park | Access | Confirm public park gate/shore access in Kaputian and the actual ferry/road approach; PDF point lies far north of the beach [N4]. |
| 3 | Alorro Crystal Beach Resort | Hold | Confirm the exact resort name, booking, gate, and Samal barangay with the operator [N2]. |
| 4 | Monfort Bat Cave | Venue | Monfort Bat Sanctuary visitor entrance in Barangay Tambo, Babak; PDF point is displaced [N1][N5]. |
| 5 | Hagimit Falls | Access | Confirm present opening status and use its current ticket/parking area in Barangay Cawag; do not route to the falls water feature [N1][N6]. |
| 6 | Talikud Island | Choose | Choose a booked boat's departure port and the landing pier/beach for the specific Talikud destination [N3]. |
| 7 | Pearl Farm Beach Resort | Venue | Confirm operator-designated boat departure point and private resort landing/reception; do not assume a road route to the island resort. |
| 8 | Discovery Samal | Venue | Resort's actual main gate/arrival reception; verify independently of Alorro, whose PDF pin is reused [N2]. |
| 9 | Aqua Water Park | Venue | Operator's public Aqua Water Park gate in Barangay Limao, Samal [N12]. |
| 10 | Vanishing Island | Choose | Confirm licensed boat departure and weather/tide-dependent landing point; not routable by car [N3]. |
| 11 | Tagum City Freedom Park | Venue | Choose the active public park gate in Tagum [N13]. |
| 12 | World's Largest Rosary | Venue | Christ the King Cathedral compound entrance; treat the rosary garden as an internal point [N11]. |
| 13 | Christ the King Cathedral | Venue | Cathedral compound/public entrance in Tagum; confirm street-side drop-off [N11]. |
| 14 | Energy Park | Access | Public park entrance in Barangay Apokon, Tagum, not the PDF downtown cluster [N7]. |
| 15 | Nabintad Riverside | Hold | Define an actual publicly accessible riverside destination/entrance on Nabintad Riverside Road, Madaum [N9]. |
| 16 | Panabo Mariculture Park | Hold | Confirm whether BFAR permits tourist visits and specify an authorized embarkation/visitor point [N8]. |
| 17 | TADECO Farm Tour | Hold | Confirm that a public tour exists, its booking process, and the plantation's authorized visitor gate. |
| 18 | Panabo City Mangroves | Hold | Replace this generic habitat name with a named public boardwalk, park, or barangay access point. |
| 19 | Suaon Nature Park | Hold | Seek Kapalong municipal/operator confirmation of the venue and its public gate [N15]. |
| 20 | Kapalong Caves | Choose | Name one cave, check its DENR/local access rules, and identify guide registration and trailhead. |
| 21 | Okbot Cave | Access | Identify Okbot Cave's permitted guide/registration point and trailhead; PDF shares another cave's unverified coordinate [N1]. |
| 22 | Asuncion River Cruise | Hold | Verify that this specific cruise operates and get the boarding pier, operator, and landing plan. |
| 23 | Ising Peace Memorial | Venue | Memorial's public entrance in Carmen/Ising area; exact road access remains to be confirmed [N1]. |
| 24 | Carmen Rice Terraces View | Hold | Verify a named legal lookout or tour product and its approach road. |
| 25 | Talaingod View Deck | Hold | Identify the exact viewpoint and accessible roadside stop with the municipality [N16]. |
| 26 | Banana Beach (Hijo Resorts) | Venue | Hijo Banana Beach resort gate/booking check-in in Barangay Madaum, Tagum, not downtown [N17]. |

### Davao del Sur (15)

| # | PDF place | State | Traveler should arrive at / action needed |
|---:|---|:---:|---|
| 1 | Mount Apo (via Digos/Kapatagan) | Access | Confirm an authorized Kapatagan climb route, permit/registration point, and road trailhead; never use the summit pin [S1]. |
| 2 | Kapatagan Valley | Choose | Choose a named resort, viewpoint, or trail registration site in Kapatagan, Digos [S1]. |
| 3 | Camp Sabros | Venue | Camp Sabros reception/main gate in Sitio Barras, Barangay Kapatagan, Digos [S2]. |
| 4 | Jardin de Senorita | Hold | Verify operator spelling, active entrance, and precise Kapatagan site. |
| 5 | Twin Mountain View Resort | Venue | Resort reception/gate in Barangay Managa, Bansalan [S8]. |
| 6 | Bagobo-Tagabawa Cultural Village | Hold | Choose the specific cultural village: Binaton, Digos or Tibolo, Santa Cruz; confirm community-led visitor access [S4][S10]. |
| 7 | Salinta Monon Weaving Center | Venue | Weaving center visitor entrance in Bitaug, Bansalan; correct PDF point after direct confirmation [S11]. |
| 8 | Sir Ped's Coffee | Hold | Confirm there is a public farm/cafe visit, then its Balutakay, Bansalan gate [S12]. |
| 9 | Mt. Apo Agri-Ecotourism Park | Venue | Park public entrance in Barangay Kapatagan, Digos, not Bansalan [S3]. |
| 10 | Lao Integrated Farm | Venue | Farm visitor gate/reception in Barangay Eman, Bansalan [S13]. |
| 11 | Tudaya Falls | Access | Confirm the approved Santa Cruz access route, local guide/parking point, and waterfall trailhead [S7]. |
| 12 | Lake Venado | Access | Confirm permitted Mt. Apo climbing route and official trailhead; the lake itself is a trekking waypoint [S6]. |
| 13 | Sibulan River | Choose | Name the specific rafting, viewpoint, or river access site and legal drop-off; a river has no single entrance [S1]. |
| 14 | Bamboo Peak (Buntod Ta Laya) | Access | Confirm a local guide and hike trailhead in Barangay Jose Rizal, Santa Cruz [S9]. |
| 15 | Lake Agko Hot Springs | Hold | Correct to Lake Agco, Ilomavis, Kidapawan City, Cotabato; decide whether this out-of-region place belongs in Lakbay [S5]. |

### Davao Oriental (20)

| # | PDF place | State | Traveler should arrive at / action needed |
|---:|---|:---:|---|
| 1 | Dahican Beach | Choose | Select a named public beach access, resort, or surf school entrance in Mati; the shoreline has multiple approaches [O1]. |
| 2 | Pujada Bay | Choose | Choose a specific shore viewpoint or booked island-tour departure pier in Mati [O1]. |
| 3 | Sleeping Dinosaur Viewpoint | Access | Confirm the designated roadside lookout and safe vehicle pull-off on the approach to Mati [O2]. |
| 4 | Subangan Provincial Museum | Venue | Museum's public entrance in Mati; confirm road-connected drop-off [O1]. |
| 5 | Mount Hamiguitan World Heritage Park | Access | Separate a museum/interpretation-center visit from a permitted mountain trek; for trekking, confirm booking, registration and trailhead with the protected-area office [O1][O11]. |
| 6 | Aliwagwag Falls Eco Park | Access | Confirm the current eco-park gate/ticket and parking area at Aliwagwag Falls, Cateel; do not use a waterfall centroid [O1]. |
| 7 | Pusan Point & Discovery Center | Venue | Discovery Center's visitor entrance at Pusan Point, Caraga; verify exact road gate [O1]. |
| 8 | Cape San Agustin & Parola | Access | Confirm the public lighthouse/cape approach, parking, and whether the lighthouse compound is open in Governor Generoso [O1]. |
| 9 | Lake Carolina | Access | Confirm designated public lake entrance/parking in Baganga [O2]. |
| 10 | San Victor Island | Choose | Confirm a legal boat departure point and the island's receiving beach/pier in Baganga [O2]. |
| 11 | San Salvador del Mundo Church | Venue | Church's public entrance in Caraga town center [O8]. |
| 12 | Tag-ayo Falls | Hold | Confirm the exact falls, barangay, and local guide/trailhead in Baganga [O9]. |
| 13 | Poo Kinablangan Sandbar | Hold | Confirm the exact sandbar, current access permission, boat launch, and landing; a past mayoral order restricted tourism at Poo Island [O10]. |
| 14 | Mandaya Village | Hold | Identify a specific community-run village visit and obtain community consent/arrival instructions. |
| 15 | Waniban Island | Choose | Confirm boat departure and Waniban landing in Mati; PDF uses a viewpoint point on the mainland [O5]. |
| 16 | Oakwood Island | Hold | Confirm whether the intended site is Oak Island and identify its boat arrival [O3]. |
| 17 | Canibad Beach | Hold | Correct the location to Aundanao, Samal, Davao del Norte, then confirm the beach access road/gate [N10]. |
| 18 | Guang Guang Mangrove Park | Venue | Park's public boardwalk/visitor entrance in Mati; confirm access point [O4]. |
| 19 | Seaside Empanada | Hold | Verify the business's operating address and public entrance; exact establishment was not corroborated. |
| 20 | Mati Baywalk | Choose | Choose the intended promenade segment and pedestrian entrance in Mati [O7]. |

### Davao de Oro (22)

| # | PDF place | State | Traveler should arrive at / action needed |
|---:|---|:---:|---|
| 1 | Mount Candalaga | Access | Confirm Maragusan climbing permit/guide registration and road trailhead; the PDF pin is far north of the mountain [D3]. |
| 2 | Mount Kampalili | Access | Confirm the approved approach and trailhead on the Maragusan/Manay side; do not route to a peak coordinate [D8]. |
| 3 | Mount Kalumotan | Hold | Verify the exact mountain identity and legal access before selecting a trailhead. |
| 4 | Tagbibinta Falls | Access | **Best documented arrival instruction:** drive to the Barangay Coronobe approach and park about **250 m before the falls**, then walk. Provincial page says vehicles can reach that parking area; its precise parking coordinate still needs checking [D21]. |
| 5 | Calamba Farm Sea of Clouds | Venue | Calamba Farm operator's visitor gate/reception in Maragusan; request current access and gate pin [D5]. |
| 6 | Haven's Peak Highland Resort | Venue | Resort gate/reception in Maragusan; obtain operator's gate pin [D9]. |
| 7 | Cleo Heights | Hold | Confirm operating venue identity and actual entrance in Maragusan [D10]. |
| 8 | Mount Pinan-panan | Access | Confirm guided route, registration, and trailhead in Maragusan [D11]. |
| 9 | Mount Maitum | Access | Confirm which mountain/route is intended and its authorized trailhead near Maragusan [D12]. |
| 10 | Posto Pierro | Hold | Confirm operating business/attraction identity and gate in Maragusan [D13]. |
| 11 | Marangig Falls | Access | Confirm local guide, parking area, and trailhead in Maragusan [D2]. |
| 12 | Salvosa Falls / Pyalitan Falls | Hold | Split into Salvosa Falls in Araibo, Pantukan and Pyalitan Falls in Mapawa, Maragusan; each needs a separate local arrival point [D1]. |
| 13 | Aguacan Cold Spring Resort | Hold | Confirm exact resort name and reception/gate in Maragusan [D5]. |
| 14 | Awao Falls | Access | Confirm road end, local guide, and trailhead in Barangay Awao, Monkayo; PDF point is displaced [D2][D19]. |
| 15 | Mount Magdiwata | Hold | Located in Agusan del Sur, outside the PDF's Nabunturan area; decide whether to remove [D6]. |
| 16 | Nabunturan Eco-Adventure Park | Hold | Exact operating park and public gate were not corroborated. |
| 17 | Kopiat Island | Choose | Confirm boat departure in Mabini and island landing; PDF point is on the wrong site [D14][D17]. |
| 18 | Bilawa Mainit Falls | Access | Barangay Mainit, Maco by way of Mawab; confirm the barangay-managed visitor parking/trail start before routing [D18][D22]. |
| 19 | Lake Leonard | Access | Confirm public lake access in Barangay New Leyte, Maco, not Maragusan [D1]. |
| 20 | Mainit Hot Springs | Hold | Select and verify the exact spring or resort: the Maragusan name conflicts with other Mainit sites in Nabunturan/Maco [D15][D16]. |
| 21 | La Tonyo's Lakeview | Hold | Confirm exact operating venue and gate; PDF pin is reused from the false Magdiwata location [D11]. |
| 22 | D'Fortees Nature Park | Venue | Park/resort gate in Montevista; verify current access and replace the displaced PDF pin [D7][D20]. |

### Davao Occidental (12)

| # | PDF place | State | Traveler should arrive at / action needed |
|---:|---|:---:|---|
| 1 | Davao Occidental Provincial Capitol | Venue | Public capitol entrance in Barangay Lais, Malita [W2]. |
| 2 | Malita Dives (“Little Maldives”) | Hold | Verify whether this is Meskeen Resort in Tubalan, then its booking/gate/boat instructions [W6]. |
| 3 | Tubalan Cove | Choose | Select a named public shore access, resort, or viewpoint in Tubalan, Malita [W3]. |
| 4 | Balut Fish Port | Hold | Resolve whether the intended port is on Balut Island, in Sarangani municipality, or a distinct Malita facility [W1]. |
| 5 | Little Boracay | Access | Confirm beach's public access/parking in Santa Maria, Davao Occidental [O2]. |
| 6 | Sta. Maria Viewdeck | Hold | Confirm that a named public view deck operates and identify its safe road pull-off. |
| 7 | Mount Kibusao | Hold | PDF has the wrong municipality/pin; confirm whether the Malita mountain and an authorized trail are intended [W4]. |
| 8 | Bulata White Beach | Hold | Verify exact beach name, barangay, public access, and parking in Don Marcelino. |
| 9 | Tuwang White Beach | Hold | Verify exact beach name, barangay, public access, and parking in Don Marcelino. |
| 10 | Lawayon Beach | Hold | Verify exact beach name, barangay, public access, and parking in Don Marcelino. |
| 11 | Tagakaulo Cultural Village | Hold | Identify a specific community-run destination, obtain consent and arrival instructions. |
| 12 | Sarangani Island | Hold | Correct the municipality to Sarangani, Davao Occidental; identify departure port and island landing, not a Jose Abad Santos mainland point [W1]. |

## What counts as confirmed before import

For each retained destination, record **(1)** exact venue name and barangay/municipality/province, **(2)** who confirmed access and when, **(3)** arrival type (gate, parking, trail registration, pier, pedestrian entrance), **(4)** reviewed latitude/longitude of that arrival point, **(5)** travel mode and whether a ferry/boat or hike starts there, and **(6)** current access restrictions or booking requirement. Inspect the proposed point against a road/path map and satellite imagery, then check that a test route ends on the correct approach side of the entrance. For remote nature sites, island landings, and controlled facilities, get the local operator, barangay tourism office, or protected-area office to confirm the waypoint before activation. Recheck after relocations, closures, or access changes.

This review is documentation only. No destination records, seeds, database schema, or routing code were changed.

## Additional sources for arrival instructions

The evidence codes below supplement the citations in the [place audit](lakbay_dataset_location_audit.md). They establish address or approach descriptions, not final gate coordinates.

- [C20] [Malagos Garden Resort operator address](https://www.malagos.com/contact), [operator-hosted approach description](https://www.malagos.com/highlights/2021/1/18/service-hospitality-nature-an-all-in-one-experience-at-malagos-garden-resort), [OpenStreetMap-derived resort center](https://mapcarta.com/W976238615).
- [C21] [Philippine Eagle Foundation address](https://www.philippineeaglefoundation.org/), [OpenStreetMap-derived attraction point](https://mapcarta.com/N747886405).
- [C22] [Davao City Tourism: People's Park](https://tourism.davaocity.gov.ph/explore-the-city/attractions/man-made-nature-parks/peoples-park/).
- [C23] [Davao City ordinance defining the Roxas Night Market street segment](https://lissp2.davaocity.gov.ph/uploads/items/11722/Ordinance%20No.%200111-22%20%28Night%20Market%29.pdf), [City Tourism market listing](https://tourism.davaocity.gov.ph/explore-the-city/restaurants/night-market/roxas-night-market/).
- [O11] [DENR report on protected-area trek bookings and access control](https://denr.gov.ph/wp-content/uploads/2023/07/DENR_News_Alerts_16_April_2022_Saturday.pdf).
- [D21] [Davao de Oro provincial Tagbibinta Falls directions and parking instruction](https://davaodeoro.gov.ph/tagbibinta-falls/).
- [D22] [Davao de Oro provincial Bilawa Mainit Hot Waterfalls directions and barangay management](https://davaodeoro.gov.ph/bilawa-mainit-hot-waterfalls/).
