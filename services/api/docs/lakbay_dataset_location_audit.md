# Lakbay+ location dataset audit

Source: `C:\Users\Arjane\Downloads\Lakbay+ DATASET.pdf` (56 pages). Reviewed 26 October 2026; arrival-point review updated 29 October 2026. This is a **location audit**, not a verification of prices, opening hours, activities, or current access. The first 49 pages contain 118 numbered destination rows; the final seven pages repeat eight Davao Oriental rows in another format and are not additional destinations. See [arrival-point review](lakbay_dataset_arrival_verification.md) before routing.

## How to read the audit

- **V**: independent government, operator, or other reasonably direct source supports the named place and its stated city/municipality.
- **P**: the wider area or a closely related place is supported, but the exact name, facility, or municipality remains uncertain.
- **X**: independent evidence contradicts the PDF location/name or shows two entries are the same venue.
- **U**: no sufficiently reliable independent evidence for that exact named place was found. This does **not** prove that it does not exist.
- **Pin `reject`**: the PDF coordinate conflicts with a documented location or is plainly reused for a different venue. **Pin `check`**: an individual visitor waypoint has not been verified; it must not be used for routing yet. Even a V place can have a bad pin.

The PDF gives many coordinates to only two decimal places. At Davao's latitude, 0.01° is roughly 1.1 km, so four displayed decimals do not imply a precise surveyed entrance. This audit compares named locations with published government/operator information and, for some coordinates, OpenStreetMap-derived map records. Neither the PDF nor this audit supplies an approved final navigation point for all 118 places. Municipal labels in the PDF's `District` column are inconsistent with the backend's province/city `district` field.

**Audit result:** 66 places have independent support for their name and administrative area (V); 27 are partial matches (P); 13 have a contradicted location/name or duplicate identity (X); and 12 exact names remain uncorroborated (U). **67 PDF pins are rejected** on the evidence or because they do not identify a usable visitor access point. The other 51 pins still require individual confirmation. None of the 118 PDF pins is certified here as a final routing waypoint.

## High-priority corrections before any import

1. **Remove or relocate entries outside their stated province:** Lake Agko is in **Ilomavis, Kidapawan City, Cotabato** [S5]; Mount Magdiwata is in **Agusan del Sur**, not Nabunturan [D6]; Canibad Beach is on **Samal**, not in Mati [N10]; Sarangani Island is associated with the separate **Sarangani municipality**, not Jose Abad Santos [W1].
2. **Correct municipality and identity:** Lake Leonard is in **New Leyte, Maco**, not Maragusan; Salvosa Falls and Pyalitan Falls are **different waterfalls** in Pantukan and Maragusan respectively [D1]. The Mt. Apo Agri-Ecotourism Park is in **Kapatagan, Digos**, not Bansalan [S3]. Provincial records describe Bagobo-Tagabawa cultural villages in **Binaton, Digos** and **Tibolo, Santa Cruz**, so the PDF's Bansalan entry needs a specific identity [S4][S10].
3. **Reject demonstrably displaced pins:** the PDF's Mount Candalaga and Tagbibinta Falls coordinates are each over 50 km north of mapped sites [D3][D4]. The Monfort Bat Cave, Talikud Island, Vanishing Island, Kaputian Beach, People's Park, Energy Park, Kopiat Island, Bilawa Mainit Falls, Awao Falls, D'Fortees Nature Park, and Mount Kibusao coordinates also conflict with independent location records [N3][N4][N5][C9][N7][D17][D18][D19][D20][W4].
4. **Resolve possible duplicate/ambiguous records:** Davao Crocodile Park and Davao Riverfront Crocodile Park refer to the Riverfront venue in Ma-a [C6]. “World's Largest Rosary” is at Christ the King Cathedral [N11]. “Lola's Garden (Eden)” may be an area within Eden Nature Park, not a separate destination [C10]. “Davao Baywalk” and “Mati Baywalk” describe broad promenades; choose an entrance or designated viewpoint.
5. **Hold all `U` rows and all `check` pins** for direct confirmation from the municipality, operator, or a reviewed map waypoint before showing them in route optimization or destination search.

## Every PDF row

Rows are numbered within each PDF province/city section. `PDF area` reproduces the table's District field; a correction in `Finding` takes precedence. Source keys link to the evidence below. A row marked V validates **place and administrative area only**, not its coordinate or present operating status.

### Davao City — 23 rows

| # | PDF place | PDF area | Place | Pin | Finding / evidence |
|---:|---|---|:---:|:---:|---|
| 1 | Malagos Garden Resort | Malagos/Baguio | V | reject | Operator confirms Malagos, Baguio District; mapped resort center ~7.1910, 125.4274 versus PDF 7.1700, 125.3500 [C5][C20]. Neither point establishes the gate. |
| 2 | Philippine Eagle Center | Malagos/Baguio | V | reject | Foundation confirms Malagos, Baguio District; OpenStreetMap-derived attraction ~7.1849, 125.4153 versus PDF 7.1800, 125.3400 [C5][C21]. Neither point establishes the gate. |
| 3 | Davao Crocodile Park | Ma-a | V | reject | Riverfront Corporate City, Ma-a; mapped ~7.0972, 125.5990 versus PDF 7.0778, 125.5948 [C6][C13]. |
| 4 | Davao Riverfront Crocodile Park | Ma-a | X | reject | Alternate name for row 3's Riverfront venue; merge after checking operator [C6]. |
| 5 | People's Park | Poblacion | V | reject | Park exists, but mapped center ~7.0709, 125.6087 versus PDF 7.0644, 125.6070 [C9]. |
| 6 | Roxas Night Market | Poblacion | V | check | Roxas Avenue night market [C1]. |
| 7 | Davao Chinatown | Poblacion | V | check | A district along Ramon Magsaysay Avenue, not a single-point venue [C2]. |
| 8 | San Pedro Cathedral | Poblacion | V | check | Cathedral's own address is San Pedro Street, Barangay 38-D [C7]. |
| 9 | Museo Dabawenyo | Poblacion | V | reject | Moved to Mabini Street beside Davao City National High School; PDF point requires replacement [C3]. |
| 10 | Davao Museum of History | Poblacion | P | reject | Likely Davao Museum of History and Ethnography, which moved to Ateneo de Davao's Jacinto campus; confirm exact institution and visitor entrance [C4]. |
| 11 | Rizal Park | Poblacion | V | check | City center landmark [C11]. |
| 12 | Davao City Hall | Poblacion | V | check | San Pedro Street civic landmark [C11]. |
| 13 | Eden Nature Park | Toril | V | check | Operator places it in Toril [C10]. |
| 14 | Lola's Garden (Eden) | Toril | P | reject | Subsite/name within Eden; exact separate attraction unclear; PDF reuses row 13 pin [C10]. |
| 15 | Jack's Ridge | Talomo | V | check | Operator/city tourism places it at Shrine Hills, Matina Crossing [C19]. |
| 16 | Lon Wa Buddhist Temple | Talomo | X | reject | Temple is on Cabaguio Avenue, not Talomo; mapped ~7.0955, 125.6203 versus PDF 7.0900, 125.5600 [C14]. |
| 17 | SM Lanang Premier | Lanang | V | reject | Mall in Lanang; mapped ~7.0990, 125.6309 versus PDF 7.1100, 125.6400 [C8][C15]. |
| 18 | Abreeza Mall | Poblacion | V | reject | Mall on J. P. Laurel Avenue; mapped ~7.0912, 125.6113 versus PDF 7.0700, 125.6100 [C8][C16]. |
| 19 | Tamayong Prayer Mountain | Calinan | P | check | Tamayong/Calinan area is supported; access and exact facility need confirmation [C1]. |
| 20 | Bankerohan Public Market | Poblacion | V | check | City market [C1]. |
| 21 | Aldevinco Shopping Center | Poblacion | X | reject | The original shopping center closed in 2021 and the site is being redeveloped; former tenants moved to Poblacion Market Central [C17]. |
| 22 | Mount Apo (via Davao City side) | Hillside | P | reject | Mount Apo is real, but a summit coordinate is not a Davao City-side trailhead; select a named approved access point [C5]. |
| 23 | Davao Baywalk | Poblacion | P | reject | This name commonly points to the Matina Aplaya/Queensland Baywalk, not Poblacion; define the intended segment and entrance [C18]. |

### Davao del Norte — 26 rows

| # | PDF place | PDF area | Place | Pin | Finding / evidence |
|---:|---|---|:---:|:---:|---|
| 1 | Samal Island (General) | Samal Island | V | reject | Island-wide area, not a visitor waypoint. Use a port or specific attraction [N1]. |
| 2 | Kaputian Beach Park | Samal Island | V | reject | DENR published Kaputian beach near 6.9647, 125.7227; PDF 7.0700, 125.7100 is ~12 km north [N4]. |
| 3 | Alorro Crystal Beach Resort | Samal Island | P | check | Alorro-branded Samal resort appears in city tourism listings; exact name and pin need operator confirmation [N2]. |
| 4 | Monfort Bat Cave | Samal Island | V | reject | Barangay Tambo, Babak; mapped ~7.1654, 125.6927 versus PDF 7.0700, 125.7100 [N1][N5]. |
| 5 | Hagimit Falls | Samal Island | V | reject | Barangay Cawag; mapped ~7.0666, 125.7230 versus PDF 7.1000, 125.7200 [N1][N6]. Check current access separately. |
| 6 | Talikud Island | Samal Island | V | reject | CAAP landmark ~6.9225, 125.7031 versus PDF 7.0000, 125.8000; use a landing point for routes [N3]. |
| 7 | Pearl Farm Beach Resort | Samal Island | V | check | Samal resort [C5]. |
| 8 | Discovery Samal | Samal Island | V | reject | Separate resort from Alorro; PDF reuses row 3 coordinate, so at least one pin is wrong [N2]. |
| 9 | Aqua Water Park | Samal | V | check | Operator identifies Barangay Limao, Samal [N12]. |
| 10 | Vanishing Island | Samal Island | V | reject | CAAP landmark ~7.1589, 125.6822 versus PDF 7.0900, 125.6800 [N3]. |
| 11 | Tagum City Freedom Park | Tagum City | V | check | City records identify Freedom Park; confirm entrance coordinate [N13]. |
| 12 | World's Largest Rosary | Tagum City | V | check | On Christ the King Cathedral grounds; map as a subsite if retained separately [N11]. |
| 13 | Christ the King Cathedral | Tagum City | V | check | Cathedral in Tagum [N11]. |
| 14 | Energy Park | Tagum City | V | reject | Government locates Energy Park in Barangay Apokon, not at the PDF downtown cluster [N7]. |
| 15 | Nabintad Riverside | Tagum City | P | check | Nabintad Riverside Road exists in Barangay Madaum; specific visitor site not established [N9]. |
| 16 | Panabo Mariculture Park | Panabo City | V | check | BFAR identifies the mariculture park; public tourist access is not established [N8]. |
| 17 | TADECO Farm Tour | Panabo City | P | check | TADECO plantation is real; a public farm-tour product/booking point is unconfirmed [N14]. |
| 18 | Panabo City Mangroves | Panabo City | P | reject | Generic habitat label; identify a named mangrove park, trail, or access point [N14]. |
| 19 | Suaon Nature Park | Kapalong | P | check | Named in secondary Kapalong coverage; seek municipal confirmation [N15]. |
| 20 | Kapalong Caves | Kapalong | P | reject | Generic group of caves; identify a specific cave and access point [N1]. |
| 21 | Okbot Cave | Kapalong | V | reject | Cave is in Kapalong, but PDF reuses row 20 pin without an independently checked entrance [N1]. |
| 22 | Asuncion River Cruise | Asuncion | U | check | Exact operating tour/boarding point not corroborated. |
| 23 | Ising Peace Memorial | Carmen | V | check | Memorial is listed on the Davao del Norte tourism circuit [N1]. |
| 24 | Carmen Rice Terraces View | Carmen | U | check | Named lookout/visitor site not corroborated. |
| 25 | Talaingod View Deck | Talaingod | P | check | Named view deck appears in local hiking coverage; no official entrance pin found [N16]. |
| 26 | Banana Beach (Hijo Resorts) | Tagum City | V | reject | Government/DepEd identifies Hijo Banana Beach in Barangay Madaum, not the PDF's downtown Tagum point [N17]. |

### Davao del Sur — 15 rows

| # | PDF place | PDF area | Place | Pin | Finding / evidence |
|---:|---|---|:---:|:---:|---|
| 1 | Mount Apo (via Digos/Kapatagan) | Digos | P | reject | Kapatagan is a Digos access area; PDF repeats the summit point from Davao City row 22, not a trailhead [S1]. |
| 2 | Kapatagan Valley | Digos | V | reject | Broad valley/landscape; choose a specific visitor waypoint [S1]. |
| 3 | Camp Sabros | Kapatagan | V | check | Sitio Barras, Kapatagan, Digos [S2]. |
| 4 | Jardin de Senorita | Kapatagan | P | check | Kapatagan attraction appears in travel coverage; confirm operator name and entrance [S1]. |
| 5 | Twin Mountain View Resort | Bansalan | V | check | Provincial record places Twin Mountain Resort in Barangay Managa, Bansalan [S8]. |
| 6 | Bagobo-Tagabawa Cultural Village | Bansalan | X | reject | Province cites villages in Binaton, Digos and Tibolo, Santa Cruz; identify which one was intended [S4][S10]. |
| 7 | Salinta Monon Weaving Center | Bansalan | V | reject | Provincial brochure names the center; visitor listing places it in Bitaug, Bansalan, far from the PDF point [S1][S11]. |
| 8 | Sir Ped's Coffee | Bansalan | V | check | A 2026 profile identifies the business with coffee growers in Balutakay, Bansalan; exact visitor entrance remains unchecked [S12]. |
| 9 | Mt. Apo Agri-Ecotourism Park | Bansalan | X | reject | Province places park in Barangay Kapatagan, Digos [S3]. |
| 10 | Lao Integrated Farm | Bansalan | V | reject | Operator and province place farm in Barangay Eman, Bansalan; PDF point is far from Eman [S13]. |
| 11 | Tudaya Falls | Santa Cruz | V | check | Santa Cruz waterfall [S7]. |
| 12 | Lake Venado | Santa Cruz | P | reject | Lake is in Mt. Apo landscape; DENR inventory associates it with Davao City/Magpet rather than a Santa Cruz town waypoint [S6]. |
| 13 | Sibulan River | Santa Cruz | V | reject | River/corridor, not a single tourist entrance [S1]. |
| 14 | Bamboo Peak (Buntod Ta Laya) | Santa Cruz | P | check | Hike reported in Barangay Jose Rizal, Santa Cruz; verify trailhead locally [S9]. |
| 15 | Lake Agko Hot Springs | Santa Cruz | X | reject | Lake Agco is in Ilomavis, Kidapawan City, Cotabato [S5]. |

### Davao Oriental — 20 rows

| # | PDF place | PDF area | Place | Pin | Finding / evidence |
|---:|---|---|:---:|:---:|---|
| 1 | Dahican Beach | Mati | V | check | Mati beach [O1]. |
| 2 | Pujada Bay | Mati | V | reject | Broad bay, not a single arrival point [O1]. |
| 3 | Sleeping Dinosaur Viewpoint | Mati | V | check | Mati roadside viewpoint [O2]. |
| 4 | Subangan Provincial Museum | Mati | V | check | Provincial museum in Mati [O1]. |
| 5 | Mount Hamiguitan World Heritage Park | San Isidro | V | reject | San Isidro protected landscape; a mountain coordinate is not necessarily the visitor interpretation center/entrance [O1]. |
| 6 | Aliwagwag Falls Eco Park | Cateel | V | check | Cateel waterfall site [O1]. |
| 7 | Pusan Point & Discovery Center | Caraga | V | check | Pusan Point is in Caraga; verify Discovery Center visitor entrance [O1]. |
| 8 | Cape San Agustin & Parola | Governor Generoso | V | check | Cape/lighthouse in Governor Generoso [O1]. |
| 9 | Lake Carolina | Baganga | V | check | Baganga attraction [O2]. |
| 10 | San Victor Island | Baganga | V | check | Baganga island [O2]. |
| 11 | San Salvador del Mundo Church | Caraga | V | check | Historic church in Caraga [O8]. |
| 12 | Tag-ayo Falls | Baganga | P | check | Waterfall name appears in secondary Baganga listings; exact site/pin unconfirmed [O9]. |
| 13 | Poo Kinablangan Sandbar | Baganga | P | reject | Poo Island at Kinablangan is documented, but exact sandbar and current public access need local confirmation [O10]. |
| 14 | Mandaya Village | Caraga | U | check | Generic cultural-village label; no named operating visitor facility corroborated. |
| 15 | Waniban Island | Mati | V | reject | Island near Mati is documented; PDF shares row 3's viewpoint coordinate, so island pin is wrong [O5]. |
| 16 | Oakwood Island | Mati | X | reject | Coastal directory names **Oak Island**, not Oakwood Island; confirm whether this is the intended destination [O3]. |
| 17 | Canibad Beach | Mati | X | reject | Canibad is in Aundanao, Samal, Davao del Norte [N10]. |
| 18 | Guang Guang Mangrove Park | Mati | V | check | Mati mangrove park [O4]. |
| 19 | Seaside Empanada | Mati | U | check | Business name/operating address not independently established. |
| 20 | Mati Baywalk | Mati | V | reject | Baywalk is in Mati, but a promenade needs a specified entrance/segment; PDF shares Pujada Bay point [O7]. |

### Davao de Oro — 22 rows

| # | PDF place | PDF area | Place | Pin | Finding / evidence |
|---:|---|---|:---:|:---:|---|
| 1 | Mount Candalaga | Maragusan | V | reject | Maragusan peak; mapped ~7.2955, 126.1961 versus PDF 7.8000, 126.1000 [D3]. |
| 2 | Mount Kampalili | Maragusan | P | reject | On/near the Maragusan–Manay border; PDF 7.8500, 126.1500 is far north of documented mountain area [D8]. |
| 3 | Mount Kalumotan | Maragusan | U | reject | Exact Maragusan mountain not corroborated; shares row 4/5 point in a displaced coordinate cluster. |
| 4 | Tagbibinta Falls | Maragusan | V | reject | Barangay Coronobe; mapped ~7.3164, 126.1719 versus PDF 7.8200, 126.1200 [D1][D4]. |
| 5 | Calamba Farm Sea of Clouds | Maragusan | V | reject | Operator confirms Maragusan; PDF reuses the incorrect Tagbibinta point [D5]. |
| 6 | Haven's Peak Highland Resort | Maragusan | V | reject | Maragusan resort; PDF in same far-north cluster [D9]. |
| 7 | Cleo Heights | Maragusan | P | reject | Maragusan listing appears in map data; PDF in same far-north cluster [D10]. |
| 8 | Mount Pinan-panan | Maragusan | P | reject | Maragusan hike described in independent trail coverage; PDF in same far-north cluster [D11]. |
| 9 | Mount Maitum | Maragusan | P | reject | Geographic mountain name appears near Maragusan; PDF in same far-north cluster [D12]. |
| 10 | Posto Pierro | Maragusan | P | reject | Maragusan business/place listing exists; PDF in same far-north cluster [D13]. |
| 11 | Marangig Falls | Maragusan | V | reject | Government tourism list places falls in Maragusan; PDF in same far-north cluster [D2]. |
| 12 | Salvosa Falls / Pyalitan Falls | Maragusan | X | reject | Conflates Salvosa Falls (Araibo, Pantukan) with Pyalitan Falls (Mapawa, Maragusan) [D1]. |
| 13 | Aguacan Cold Spring Resort | Maragusan | P | reject | Maragusan cold spring is supported by local tourism listings; PDF in same far-north cluster [D5]. |
| 14 | Awao Falls | Monkayo | V | reject | Monkayo waterfall mapped near 7.9465, 125.9816 versus PDF 7.7000, 126.0800 [D2][D19]. |
| 15 | Mount Magdiwata | Nabunturan | X | reject | Mt. Magdiwata is in Agusan del Sur, outside Davao Region [D6]. |
| 16 | Nabunturan Eco-Adventure Park | Nabunturan | U | reject | Exact named venue not corroborated; reuses false Mt. Magdiwata pin. |
| 17 | Kopiat Island | Mabini | V | reject | Mabini island mapped near 7.2774, 125.8319 versus PDF 7.4500, 125.8500; select a landing point [D17]. |
| 18 | Bilawa Mainit Falls | Maco | V | reject | Barangay Mainit, Maco; mapped waterfall ~7.4012, 126.0292 versus PDF 7.4600, 125.8600 [D1][D18]. |
| 19 | Lake Leonard | Maragusan | X | reject | Province places lake in Barangay New Leyte, **Maco**, not Maragusan [D1]. |
| 20 | Mainit Hot Springs | Maragusan | P | reject | Name is ambiguous: regional planning page lists a Maragusan spring, while protected landscape/Mainit sites are also in Nabunturan/Maco; identify exact facility [D15][D16]. |
| 21 | La Tonyo's Lakeview | Nabunturan | P | reject | Described in trail coverage but no official site or waypoint confirmed; PDF reuses false Mt. Magdiwata pin [D11]. |
| 22 | D'Fortees Nature Park | Montevista | V | reject | Province identifies resort in Montevista; independent venue listing places it near 7.7104, 125.9911 versus PDF 7.5000, 125.9000 [D7][D20]. |

### Davao Occidental — 12 rows

| # | PDF place | PDF area | Place | Pin | Finding / evidence |
|---:|---|---|:---:|:---:|---|
| 1 | Davao Occidental Provincial Capitol | Malita | V | check | Provincial office is in Barangay Lais, Malita; PDF coordinate needs on-site check [W2]. |
| 2 | Malita Dives (“Little Maldives”) | Malita/Tubalan | P | check | Local first-hand report associates name with Meskeen Resort in Tubalan; confirm operator/site [W6]. |
| 3 | Tubalan Cove | Malita | V | check | Tubalan Cove in Malita is named in DPWH record [W3]. |
| 4 | Balut Fish Port | Malita | U | reject | No exact Malita port corroboration; “Balut” refers to the separate island municipality, so name/location may be mixed [W1]. |
| 5 | Little Boracay | Sta Maria | V | check | Santa Maria beach appears in national Tourism Promotions Board list [O2]. |
| 6 | Sta. Maria Viewdeck | Sta Maria | U | check | Exact public named view deck not corroborated independently. |
| 7 | Mount Kibusao | Sta Maria | X | reject | GeoNames puts Mount Kibusao near 6.2653, 125.6108 in Malita; PDF is 6.5500, 125.4500 [W4]. |
| 8 | Bulata White Beach | Don Marcelino | U | check | Exact named beach not corroborated. |
| 9 | Tuwang White Beach | Don Marcelino | U | check | Exact named beach not corroborated. |
| 10 | Lawayon Beach | Don Marcelino | U | check | Exact named beach not corroborated. |
| 11 | Tagakaulo Cultural Village | Don Marcelino | U | check | Exact visitor village not corroborated; Tagakaulo cultural presence alone is insufficient. |
| 12 | Sarangani Island | Jose Abad Santos | X | reject | Sarangani is a distinct island municipality (Balut/Sarangani islands), not Jose Abad Santos; PDF point is on the mainland [W1]. |

## Evidence consulted

These sources support the specific statements referenced above; they do not certify every PDF coordinate or current opening status. Government records and operators take priority over travel blogs. OpenStreetMap-derived coordinates are useful contradiction checks, but a final routing pin should be inspected on a map and confirmed with the venue or local authority.

### Davao City

- [C1] [Davao City Tourism attractions](https://tourism.davaocity.gov.ph/explore-the-city/attractions/).
- [C2] [Davao City Chinatown walk](https://davaocity.gov.ph/tourism/bound-to-the-friendship-arch-davao-city-chinatown-walk-boosts-tourism-and-cultural-heritage/).
- [C3] [PIA: Museo Dabawenyo moved to Mabini Street](https://pia.gov.ph/news/museo-dabawenyo-reopens-in-new-location/).
- [C4] [PIA: Davao Museum of History and Ethnography moved](https://pia.gov.ph/news/davao-museum-gets-new-home-at-ateneo-de-davao/).
- [C5] [Tourism Promotions Board Davao itinerary](https://tpb.gov.ph/wp-content/uploads/2022/03/TPB-RFQ-2022-03-073-Descriptive-Itinerary-Davao.pdf).
- [C6] [City Tourism: Davao Crocodile Park at Riverfront](https://tourism.davaocity.gov.ph/explore-the-city/attractions/man-made-nature-parks/davao-crocodile-park-wild-water-rafting-zip-city/).
- [C7] [San Pedro Cathedral official site](https://www.sanpedrocathedral.com/).
- [C8] [City Tourism mall directory](https://tourism.davaocity.gov.ph/explore-the-city/shopping/malls/).
- [C9] [OpenStreetMap-derived People's Park record](https://mapcarta.com/32802286).
- [C10] [Eden Nature Park operator map](https://edennaturepark.com.ph/eden_map/getting_to_eden.pdf).
- [C11] [PIA: San Pedro civic landmarks](https://pia.gov.ph/news/davao-citys-calle-san-pedro-historical-exhibit-opens/).
- [C13] [OpenStreetMap-derived Davao Crocodile Park location](https://mapcarta.com/W81347693); [independent visitor guide with a suggested gate point (explicitly unaffiliated with the park)](https://davaocrocodilepark.com/getting-here).
- [C14] [OpenStreetMap-derived Long Hua/Lon Wa Temple location](https://mapcarta.com/W139555365).
- [C15] [OpenStreetMap-derived SM Lanang location](https://mapcarta.com/W1200041101).
- [C16] [OpenStreetMap-derived Abreeza location](https://mapcarta.com/W117593466).
- [C17] [Aldevinco developer on the former site](https://alsonsdev.com/alsons-dev-brings-new-energy-to-aldevinco-site-as-redevelopment-progresses/); [report on former tenants moving to Poblacion Market Central](https://edgedavao.net/latest-news/2022/08/maya-on-the-block-poblacion-that-good-old-aldevincos-reincarnation/).
- [C18] [Davao Baywalk visitor description in Matina Aplaya](https://www.localphilippines.com/attractions/baywalk/).
- [C19] [City Tourism listing for Jack's Ridge](https://tourism.davaocity.gov.ph/explore-the-city/nightlife/resorts/jacks-ridge-resort-and-restaurant-corp/); [operator site](https://www.jacksridgedavao.com/).
- [C20] [Malagos Garden Resort operator address](https://www.malagos.com/contact); [OpenStreetMap-derived resort center](https://mapcarta.com/W976238615).
- [C21] [Philippine Eagle Foundation address](https://www.philippineeaglefoundation.org/); [OpenStreetMap-derived attraction point](https://mapcarta.com/N747886405).

### Davao del Norte

- [N1] [PIA: Davao del Norte tourism circuits](https://mirror.pia.gov.ph/news/2022/06/03/colors-of-mindanao-banners-5-davnor-tourism-circuits).
- [N2] [Samal City tourism pass / establishments](https://turismo.samalcity.gov.ph/tour_pass).
- [N3] [CAAP Philippine AIP RPMD visual landmarks, mirrored PDF, page AD 2-17](https://vatphil.com/viewchart.php?id=484).
- [N4] [DENR EMB Kaputian Beach coordinate](https://r11.emb.gov.ph/wp-content/uploads/2022/02/2019-Regional-State-of-Brown-Environmental-Report.pdf).
- [N5] [OpenStreetMap-derived Monfort Bat Sanctuary record](https://mapcarta.com/W666853611).
- [N6] [OpenStreetMap-derived Hagimit Falls record](https://mapcarta.com/N1223930550).
- [N7] [Proclamation reserving Tagum Energy Park in Apokon](https://issuances-library.senate.gov.ph/executive-issuance/proclamation-no-1748-s-2009).
- [N8] [BFAR Panabo Mariculture Park document](https://www.bfar.da.gov.ph/wp-content/uploads/2024/04/CC_PANABO.pdf).
- [N9] [Tagum city record for Nabintad Riverside Road](https://tagumcity.gov.ph/wp-content/uploads/2024/09/CITY-GOVERNMENT-OF-TAGUM-ANNUAL-PROCUREMENT-PLAN-APP-for-FY-2024.pdf).
- [N10] [DPWH record placing Canibad in Aundanao, Samal](https://www.dpwh.gov.ph/dpwh/sites/default/files/gaa/23238/ddn-deo-pmr-2021-1st-sem-civil-works.pdf).
- [N11] [Tagum cathedral and rosary, local site visit](https://greegadventure.blogspot.com/2016/03/holy-rosary-garden.html).
- [N12] [Aqua Water Park operator](https://www.landcolifestyleventures.com/day-tour/aqua-water-park/).
- [N13] [Tagum City ordinance naming Freedom Park](https://sp.tagumcity.gov.ph/wp-content/uploads/2022/10/CO-848-18.pdf).
- [N14] [Panabo destination context from regional tourism planning](https://dro11.depdev.gov.ph/davao-region/davao-del-norte/).
- [N15] [Kapalong/Suaon local coverage](https://www.policefilestonite.net/2026/02/16/kapalong-along-da-pba/).
- [N16] [Talaingod viewpoint local trail coverage](https://manakaayugbukid.com/).
- [N17] [DepEd record: Hijo Banana Beach in Madaum](https://depeddavnor.ph/records/officememo/DM-OSDS-2025-0199%20-%20LAND%20TITLING%20ISSUES%20AND%20SOLUTIONS%20A%20MULTI-PERSPECTIVE%20APPROACH.pdf).

### Davao del Sur

- [S1] [Davao del Sur provincial tourism brochure](https://davaodelsur.gov.ph/wp-content/uploads/MERGED-PDF-NOV.-7-2023_compressed.pdf).
- [S2] [Province: Camp Sabros in Kapatagan, Digos](https://davaodelsur.gov.ph/tourism/camp-sabros/).
- [S3] [Province: Mt. Apo Agri-Ecotourism Park in Kapatagan](https://davaodelsur.gov.ph/tourism-news/regional-director-of-the-department-of-tourism-visited-the-mt-apo-agri-eco-tourism-park-in-barangay-kapatagan/).
- [S4] [Province procurement listings: Bagobo-Tagabawa and Salinta B. Monon centers](https://davaodelsur.gov.ph/itb-civil-works-invitation-to-bid-2024/).
- [S5] [Kidapawan City: Lake Agco in Ilomavis](https://kidapawancity.gov.ph/product/lake-agco/).
- [S6] [DENR Lake Venado inventory](https://www.philchm.ph/wp-content/uploads/2019/03/inland-wetlands-as-of-1st-qtr-2019.pdf).
- [S7] [Philippine Cultural Education: Tudaya Falls](https://philippineculturaleducation.com.ph/talong-tudaya/).
- [S8] [Provincial procurement document naming Twin Mountain Resort in Managa](https://davaodelsur.gov.ph/wp-content/uploads/Purchase-Order-March_compressed_11zon.pdf).
- [S9] [Bamboo Peak first-hand trail report](https://logsac.blogspot.com/2021/06/hiking-barangay-jose-rizals-bamboo-peak.html).
- [S10] [Province: Bagobo-Tagabawa Cultural Village in Tibolo, Santa Cruz](https://davaodelsur.gov.ph/pgo-ptdpo/).
- [S11] [Provincial tourism brochure naming Salinta Monon Weaving Center](https://davaodelsur.gov.ph/wp-content/uploads/MERGED-PDF-NOV.-7-2023_compressed.pdf); [visitor listing in Bitaug](https://www.experiencedavao.com/destinations/davao-del-sur/bansalan/attractions/salinta-monon-weaving-center).
- [S12] [2026 profile of Sir Ped's Coffee](https://edgedavao.net/entrepreneurs/2026/02/game-changer-atty-elmer-g-pedregosa-when-coffee-and-tourism-converge/).
- [S13] [Lao Integrated Farms operator address](https://laointegratedfarms.com/); [province report on the farm in Eman](https://davaodelsur.gov.ph/socialwelfare/first-day-of-community-culinary-training-was-held-at-lao-integrated-farm/); [Eman map record](https://mapcarta.com/N9009708872).

### Davao Oriental

- [O1] [PPP Center: Davao Oriental sites and municipalities](https://ppp.gov.ph/in_the_news/boosting-world-class-hospitality-in-davors-tourism-sites/).
- [O2] [Tourism Promotions Board Region XI attraction list](https://tpb.gov.ph/wp-content/uploads/2022/08/ANNEX-A_Terms-of-Reference_360-VR-Experiential-Tours.pdf).
- [O3] [DENR coastal destination directory: Oak Island](https://www.coast.ph/oneocean.org/download/db_files/directory_of_crm_destinations2Ed.pdf).
- [O4] [MGB Region XI: Guang Guang Mangrove Park](https://region11.mgb.gov.ph/%F0%9D%90%83%F0%9D%90%84%F0%9D%90%8D%F0%9D%90%91-%F0%9D%90%8C%F0%9D%90%86%F0%9D%90%81-%F0%9D%90%97%F0%9D%90%88-%F0%9D%90%89%F0%9D%90%A8%F0%9D%90%A2%F0%9D%90%A7%F0%9D%90%AC-%F0%9D%90%8D%F0%9D%90%83/).
- [O5] [Senate bill reference to Waniban Island, Mati](https://legacy.senate.gov.ph/lisdata/1260011287%21.pdf).
- [O7] [Mati Baywalk commercial address in Mati](https://www.7-eleven.com.ph/products/stores-with-city-cafe-christmas-blind-cups/).
- [O8] [Provincial destination information](https://davaooriental.gov.ph/wp-content/uploads/2022/01/0.0-Citizens-Charter-v1.3.pdf).
- [O9] [Baganga tourism context](https://tpb.gov.ph/wp-content/uploads/2022/08/ANNEX-A_Terms-of-Reference_360-VR-Experiential-Tours.pdf).
- [O10] [MindaNews: Poo Island in Kinablangan](https://mindanews.com/top-stories/2020/06/baganga-mayor-orders-temporary-prohibition-of-tourism-activities-in-poo-island/).

### Davao de Oro

- [D1] [Province wellness tourism circuit: waterfalls and Lake Leonard](https://davaodeoro.gov.ph/tourist-circuit-wellness-loop/).
- [D2] [Tourism Promotions Board Region XI attraction list](https://tpb.gov.ph/wp-content/uploads/2022/08/ANNEX-A_Terms-of-Reference_360-VR-Experiential-Tours.pdf).
- [D3] [OpenStreetMap-derived Mount Candalaga record](https://mapcarta.com/N8148289068).
- [D4] [OpenStreetMap-derived Tagbibinta Falls record](https://mapcarta.com/N7076360886).
- [D5] [Calamba Farm operator's Maragusan guide](https://calambafarm.com/).
- [D6] [Mount Magdiwata map record in Agusan del Sur](https://mapcarta.com/N6324600942); [research on Mt. Magdiwata, Agusan del Sur](https://www.nature.com/articles/s41599-026-06754-7).
- [D7] [Province: D'Fortees Nature Park in Montevista](https://davaodeoro.gov.ph/dfortess-nature-park-and-inland-resort/).
- [D8] [Research on Mount Kampalili and Maragusan–Manay area](https://threatenedtaxa.org/index.php/JoTT/article/download/10046/10483/70189?inline=1).
- [D9] [DOT accredited establishments list, Haven's Peak](https://philippines.travel/data/AEs_with_CAO_as_of_25Jan21.pdf).
- [D10] [OpenStreetMap-derived Cleo Heights record](https://mapcarta.com/N8177610100).
- [D11] [Local hiking and lakeview accounts](https://manakaayugbukid.com/).
- [D12] [Davao de Oro geographic context](https://www.philatlas.com/mindanao/r11/davao-de-oro/maragusan.html).
- [D13] [Maragusan place directory naming Posto Pierro](https://www.lookph.com/province-of-davao-de-oro/parks/).
- [D14] [National tourism list: Kopiat Island](https://tpb.gov.ph/wp-content/uploads/2022/08/ANNEX-A_Terms-of-Reference_360-VR-Experiential-Tours.pdf).
- [D15] [Regional planning page listing Mainit Hot Springs under Maragusan](https://dro11.depdev.gov.ph/davao-region/davao-de-oro/).
- [D16] [DENR report on Mainit Hot Springs Protected Landscape in Nabunturan](https://faspselib.denr.gov.ph/uploads/materials/be324071-f5c8-4281-aa7e-490d563a5970/6dcc143f-6a4a-4072-ae73-c317f4bc8b92.pdf).
- [D17] [OpenStreetMap-derived Kopiat Island record](https://mapcarta.com/W4243814).
- [D18] [Province: Bilawa Mainit Hot Waterfalls in Maco](https://davaodeoro.gov.ph/bilawa-mainit-hot-waterfalls/); [OpenStreetMap-derived waterfall location](https://mapcarta.com/N6035786485).
- [D19] [Awao Falls coordinate compilation](https://www.discoverthephilippines.com/waterfalls-of-the-philippines/).
- [D20] [Independent D'Fortees venue coordinates](https://philippines.worldplaces.me/view-place/65157761-d-fortees-nature-park-and-inland-resort.html).

### Davao Occidental

- [W1] [Province: municipalities including Sarangani](https://davaooccidental.gov.ph/government-municipalities/).
- [W2] [Province citizens' charter: capitol in Barangay Lais](https://davaooccidental.gov.ph/wp-content/uploads/2024/05/PTCAO-Citizens-Charter.pdf).
- [W3] [DPWH record naming Tubalan Cove, Malita](https://www.dbm.gov.ph/wp-content/uploads/GAA/GAA2015/GAA%202015%20Volume%201%20with%20UACS/DPWH.pdf).
- [W4] [GeoNames: Mount Kibusao location](https://www.geonames.org/search.html?country=PH&q=Davao+Region&startRow=1400).
- [W6] [First-hand account of Malita Dives and Meskeen Resort](https://www.rjdexplorer.com/malita-dives-davao-occidental/).

## Recommended use in Lakbay

Keep this PDF as a **candidate list**. Import only a row whose name, municipality, and route entrance have been checked against independent evidence. Store a province/city field separately from municipality/barangay if the existing schema is later revised with approval. Treat broad geography (islands, bays, rivers, mountains) as areas or select a specific access point rather than routing to a centroid. The existing seed data and database were **not changed** during this review.
