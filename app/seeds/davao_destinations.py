import asyncio
from decimal import Decimal

from geoalchemy2.elements import WKTElement
from sqlalchemy import select

from app.db.session import get_sessionmaker
from app.features.accommodations.models import Accommodation
from app.features.destinations.models import Destination
from app.features.transportations.models import Transportation


SEED_DESTINATIONS = [
    {
        "name": "People's Park",
        "description": "Urban public park in Davao City for relaxed sightseeing.",
        "district": "Davao City",
        "location": "Poblacion District, Davao City",
        "category": "park",
        "vibes": "relaxed, family-friendly, city walk",
        "activities": "walking, photography, sightseeing",
        "lat": 7.0707,
        "lng": 125.6096,
        "estimated_cost": Decimal("150.00"),
        "entrance_fee": "Free",
        "operating_hours": "Open daily",
        "best_time_to_visit": "Late afternoon or early evening",
        "budget_class": "budget",
        "crowd_level": "moderate",
        "difficulty_level": "easy",
        "stay_duration_type": "short",
        "transport_accessibility": "high",
        "family_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "is_elderly_friendly": True,
        "accommodations": [
            {
                "name": "City Budget Inn",
                "room_type": "Standard Room",
                "price": Decimal("1200.00"),
                "capacity": 2,
                "description": "Simple city accommodation near downtown.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Taxi",
                "transport_mode": "public_transport",
                "route_from": "Davao City Airport",
                "route_to": "People's Park",
                "price": Decimal("350.00"),
                "duration_minutes": 35,
                "duration_text": "30-40 minutes",
            }
        ],
    },
    {
        "name": "Philippine Eagle Center",
        "description": "Conservation site for the Philippine eagle and other wildlife.",
        "district": "Davao City",
        "location": "Malagos, Baguio District, Davao City",
        "category": "wildlife",
        "vibes": "educational, nature, family-friendly",
        "activities": "wildlife viewing, guided visit, photography",
        "lat": 7.1854,
        "lng": 125.4169,
        "estimated_cost": Decimal("600.00"),
        "entrance_fee": "Paid entrance",
        "operating_hours": "Daytime visits",
        "best_time_to_visit": "Morning",
        "budget_class": "budget",
        "crowd_level": "moderate",
        "difficulty_level": "easy",
        "stay_duration_type": "half_day",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "is_elderly_friendly": True,
        "accommodations": [
            {
                "name": "Malagos Garden Stay",
                "room_type": "Garden Room",
                "price": Decimal("3500.00"),
                "capacity": 2,
                "description": "Nature-oriented stay near Malagos attractions.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Van",
                "transport_mode": "public_transport",
                "route_from": "Davao City Proper",
                "route_to": "Malagos",
                "price": Decimal("250.00"),
                "duration_minutes": 75,
                "duration_text": "1-1.5 hours",
            }
        ],
    },
    {
        "name": "Eden Nature Park",
        "description": "Mountain resort destination with gardens and outdoor activities.",
        "district": "Davao City",
        "location": "Toril, Davao City",
        "category": "nature resort",
        "vibes": "cool weather, nature, adventure",
        "activities": "garden tour, outdoor activities, dining",
        "lat": 7.0088,
        "lng": 125.3992,
        "estimated_cost": Decimal("1500.00"),
        "entrance_fee": "Package-based rates",
        "operating_hours": "Daytime visits",
        "best_time_to_visit": "Morning to afternoon",
        "budget_class": "mid_range",
        "crowd_level": "moderate",
        "difficulty_level": "easy",
        "stay_duration_type": "half_day",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "couple_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "accommodations": [
            {
                "name": "Eden Mountain Room",
                "room_type": "Standard Room",
                "price": Decimal("4200.00"),
                "capacity": 2,
                "description": "Mountain resort room for overnight stays.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Private Car",
                "transport_mode": "private_vehicle",
                "route_from": "Davao City Proper",
                "route_to": "Eden Nature Park",
                "price": Decimal("1200.00"),
                "duration_minutes": 80,
                "duration_text": "1-1.5 hours",
            }
        ],
    },
    {
        "name": "Samal Island Beach Area",
        "description": "Beach destination accessible from Davao City by ferry.",
        "district": "Davao del Norte",
        "location": "Island Garden City of Samal",
        "category": "beach",
        "vibes": "beach, island, relaxation",
        "activities": "swimming, beach picnic, island hopping",
        "lat": 7.0744,
        "lng": 125.7087,
        "estimated_cost": Decimal("1800.00"),
        "entrance_fee": "Varies by resort",
        "operating_hours": "Varies by resort",
        "best_time_to_visit": "Dry season and sunny weekends",
        "budget_class": "mid_range",
        "crowd_level": "high",
        "difficulty_level": "easy",
        "stay_duration_type": "full_day",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "couple_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "accommodations": [
            {
                "name": "Samal Beach Cottage",
                "room_type": "Cottage Room",
                "price": Decimal("3000.00"),
                "capacity": 4,
                "description": "Beach-side stay for small groups.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Ferry",
                "transport_mode": "public_transport",
                "route_from": "Davao City Wharf",
                "route_to": "Samal Island",
                "price": Decimal("150.00"),
                "duration_minutes": 30,
                "duration_text": "20-40 minutes",
            }
        ],
    },
    {
        "name": "Mount Apo Trail Area",
        "description": "Major hiking destination associated with the Philippines' highest peak.",
        "district": "Davao del Sur",
        "location": "Sta. Cruz / Kapatagan area",
        "category": "mountain",
        "vibes": "adventure, hiking, nature",
        "activities": "trekking, camping, nature viewing",
        "lat": 6.9875,
        "lng": 125.2708,
        "estimated_cost": Decimal("5000.00"),
        "entrance_fee": "Permit and guide fees required",
        "operating_hours": "Permit-based schedule",
        "best_time_to_visit": "Dry season with a registered guide",
        "budget_class": "premium",
        "crowd_level": "low",
        "difficulty_level": "hard",
        "stay_duration_type": "multi_day",
        "transport_accessibility": "low",
        "group_friendly": True,
        "accommodations": [
            {
                "name": "Kapatagan Homestay",
                "room_type": "Shared Room",
                "price": Decimal("1000.00"),
                "capacity": 4,
                "description": "Basic homestay before or after trekking.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Van",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Kapatagan",
                "price": Decimal("500.00"),
                "duration_minutes": 180,
                "duration_text": "3-4 hours",
            }
        ],
    },
    {
        "name": "Dahican Beach",
        "description": "Long beach destination popular for skimboarding and surfing.",
        "district": "Davao Oriental",
        "location": "Mati City, Davao Oriental",
        "category": "beach",
        "vibes": "beach, surfing, youthful",
        "activities": "swimming, surfing, skimboarding, sunrise viewing",
        "lat": 6.9487,
        "lng": 126.2542,
        "estimated_cost": Decimal("2500.00"),
        "entrance_fee": "Varies by access point",
        "operating_hours": "Open beach access varies",
        "best_time_to_visit": "Morning and dry season",
        "budget_class": "mid_range",
        "crowd_level": "high",
        "difficulty_level": "easy",
        "stay_duration_type": "overnight",
        "transport_accessibility": "moderate",
        "couple_friendly": True,
        "group_friendly": True,
        "accommodations": [
            {
                "name": "Dahican Surf Stay",
                "room_type": "Fan Room",
                "price": Decimal("1800.00"),
                "capacity": 2,
                "description": "Simple stay near the beach.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Bus",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Mati City",
                "price": Decimal("600.00"),
                "duration_minutes": 240,
                "duration_text": "4-5 hours",
            }
        ],
    },
    {
        "name": "Tagbibinta Falls",
        "description": "Multi-tiered waterfall destination in Maragusan surrounded by forest scenery.",
        "district": "Davao de Oro",
        "location": "Maragusan, Davao de Oro",
        "category": "waterfall",
        "vibes": "nature, refreshing, adventure",
        "activities": "waterfall viewing, swimming, photography, picnic",
        "lat": 7.3476,
        "lng": 126.1514,
        "estimated_cost": Decimal("1200.00"),
        "entrance_fee": "Local entrance or environmental fees may apply",
        "operating_hours": "Daytime visits",
        "best_time_to_visit": "Morning during fair weather",
        "how_to_get_there": "Travel from Davao City to Maragusan by bus or van, then hire local transport to the falls.",
        "estimated_travel_time": "About 4-6 hours from Davao City depending on road and weather conditions.",
        "travel_notes": "Road conditions can vary. Check local advisories and avoid visiting during heavy rain.",
        "what_to_bring": "Water shoes, dry bag, extra clothes, water, snacks, and rain protection.",
        "budget_class": "mid_range",
        "crowd_level": "moderate",
        "difficulty_level": "moderate",
        "stay_duration_type": "full_day",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "accommodations": [
            {
                "name": "Maragusan Nature Homestay",
                "room_type": "Family Room",
                "price": Decimal("1800.00"),
                "capacity": 4,
                "description": "Simple local stay for waterfall and nature trips in Maragusan.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Van",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Maragusan",
                "price": Decimal("650.00"),
                "duration_minutes": 300,
                "duration_text": "5-6 hours",
                "notes": "Local motorcycle or habal-habal may be needed for the final road segment.",
            }
        ],
    },
    {
        "name": "Mainit Hot Springs",
        "description": "Natural hot spring area in Maco known for warm pools and mountain surroundings.",
        "district": "Davao de Oro",
        "location": "Maco, Davao de Oro",
        "category": "hot spring",
        "vibes": "relaxation, nature, wellness",
        "activities": "hot spring bathing, nature viewing, picnic",
        "lat": 7.3636,
        "lng": 125.9494,
        "estimated_cost": Decimal("1000.00"),
        "entrance_fee": "Local entrance fees may apply",
        "operating_hours": "Daytime visits",
        "best_time_to_visit": "Morning or late afternoon",
        "how_to_get_there": "Travel from Davao City to Maco, then arrange local transport to Mainit.",
        "estimated_travel_time": "About 3-4 hours from Davao City.",
        "travel_notes": "Bring cash and confirm road conditions before visiting.",
        "what_to_bring": "Swimwear, towel, water, slippers, and extra clothes.",
        "budget_class": "budget",
        "crowd_level": "moderate",
        "difficulty_level": "easy",
        "stay_duration_type": "half_day",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "couple_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "is_elderly_friendly": True,
        "accommodations": [
            {
                "name": "Maco Traveller Lodge",
                "room_type": "Standard Room",
                "price": Decimal("1600.00"),
                "capacity": 2,
                "description": "Budget-friendly lodge option for Davao de Oro visitors.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Bus",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Maco",
                "price": Decimal("350.00"),
                "duration_minutes": 210,
                "duration_text": "3-4 hours",
                "notes": "Take local transport from Maco town proper to the hot spring area.",
            }
        ],
    },
    {
        "name": "Little Boracay Beach",
        "description": "White-sand beach area in Davao Occidental suited for swimming and relaxed seaside trips.",
        "district": "Davao Occidental",
        "location": "Santa Maria, Davao Occidental",
        "category": "beach",
        "vibes": "beach, family-friendly, relaxation",
        "activities": "swimming, beach picnic, sunset viewing, photography",
        "lat": 6.5361,
        "lng": 125.4693,
        "estimated_cost": Decimal("1800.00"),
        "entrance_fee": "Local resort or cottage fees may apply",
        "operating_hours": "Daytime beach access varies",
        "best_time_to_visit": "Sunny mornings and dry season weekends",
        "how_to_get_there": "Travel from Davao City to Digos or Malita, then continue by local transport toward Santa Maria.",
        "estimated_travel_time": "About 4-5 hours from Davao City.",
        "travel_notes": "Confirm beach access and cottage availability before departure.",
        "what_to_bring": "Sunblock, water, beachwear, snacks, and cash for cottages.",
        "budget_class": "mid_range",
        "crowd_level": "moderate",
        "difficulty_level": "easy",
        "stay_duration_type": "full_day",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "couple_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "accommodations": [
            {
                "name": "Santa Maria Beach Pension",
                "room_type": "Standard Room",
                "price": Decimal("1800.00"),
                "capacity": 2,
                "description": "Simple coastal stay for beach visitors in Davao Occidental.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Van",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Santa Maria",
                "price": Decimal("550.00"),
                "duration_minutes": 270,
                "duration_text": "4-5 hours",
                "notes": "Routes may require transfer through Digos or Malita.",
            }
        ],
    },
    {
        "name": "Balut Island",
        "description": "Remote island destination in Davao Occidental known for beaches, marine scenery, and volcanic landscapes.",
        "district": "Davao Occidental",
        "location": "Sarangani, Davao Occidental",
        "category": "island",
        "vibes": "remote, adventure, beach, island",
        "activities": "island hopping, swimming, snorkeling, coastal sightseeing",
        "lat": 5.4047,
        "lng": 125.3765,
        "estimated_cost": Decimal("6500.00"),
        "entrance_fee": "Boat and local fees vary",
        "operating_hours": "Boat schedules and weather dependent",
        "best_time_to_visit": "Dry season with calm sea conditions",
        "how_to_get_there": "Travel to General Santos or Davao Occidental access points, then arrange sea transport to Sarangani islands.",
        "estimated_travel_time": "Multi-leg trip; usually requires overnight planning.",
        "travel_notes": "Plan with local operators, check sea conditions, and prepare for limited services.",
        "what_to_bring": "Dry bag, power bank, reef-safe sunblock, water, medicine, and cash.",
        "budget_class": "premium",
        "crowd_level": "low",
        "difficulty_level": "hard",
        "stay_duration_type": "multi_day",
        "transport_accessibility": "low",
        "couple_friendly": True,
        "group_friendly": True,
        "accommodations": [
            {
                "name": "Balut Island Guesthouse",
                "room_type": "Basic Room",
                "price": Decimal("1500.00"),
                "capacity": 2,
                "description": "Basic island stay for travelers with advance local arrangements.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Boat",
                "transport_mode": "sea_transport",
                "route_from": "Mainland Davao Occidental",
                "route_to": "Balut Island",
                "price": Decimal("2500.00"),
                "duration_minutes": 240,
                "duration_text": "Weather dependent",
                "notes": "Coordinate with local boat operators and avoid rough sea conditions.",
            }
        ],
    },
    {
        "name": "Tudaya Falls",
        "description": "Tall waterfall destination near Mount Apo foothills with cool mountain surroundings.",
        "district": "Davao del Sur",
        "location": "Sta. Cruz, Davao del Sur",
        "category": "waterfall",
        "vibes": "nature, adventure, cool weather",
        "activities": "waterfall viewing, trekking, photography",
        "lat": 6.9842,
        "lng": 125.3912,
        "estimated_cost": Decimal("1800.00"),
        "entrance_fee": "Local fees and guide arrangements may apply",
        "operating_hours": "Daytime visits",
        "best_time_to_visit": "Dry season mornings",
        "how_to_get_there": "Travel from Davao City to Sta. Cruz or Kapatagan, then arrange local guide and transport.",
        "estimated_travel_time": "About 3-4 hours from Davao City plus trail time.",
        "travel_notes": "Trail conditions may be slippery. Visit with local guidance.",
        "what_to_bring": "Trekking shoes, water, extra clothes, snacks, and rain protection.",
        "budget_class": "mid_range",
        "crowd_level": "low",
        "difficulty_level": "moderate",
        "stay_duration_type": "full_day",
        "transport_accessibility": "low",
        "group_friendly": True,
        "accommodations": [
            {
                "name": "Sta. Cruz Traveller Homestay",
                "room_type": "Shared Room",
                "price": Decimal("1200.00"),
                "capacity": 4,
                "description": "Basic homestay for waterfall and mountain trips.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Van",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Sta. Cruz",
                "price": Decimal("350.00"),
                "duration_minutes": 150,
                "duration_text": "2-3 hours",
                "notes": "Local guide and motorcycle transfer may be required near the trail.",
            }
        ],
    },
    {
        "name": "Aliwagwag Falls",
        "description": "Scenic multi-tiered waterfall system and nature park in Davao Oriental.",
        "district": "Davao Oriental",
        "location": "Cateel, Davao Oriental",
        "category": "waterfall",
        "vibes": "nature, adventure, photography",
        "activities": "waterfall viewing, swimming, bridge walk, photography",
        "lat": 7.7431,
        "lng": 126.4218,
        "estimated_cost": Decimal("3000.00"),
        "entrance_fee": "Local park fees may apply",
        "operating_hours": "Daytime visits",
        "best_time_to_visit": "Morning during fair weather",
        "how_to_get_there": "Travel from Davao City toward Cateel via Davao Oriental routes, then proceed to Aliwagwag area.",
        "estimated_travel_time": "About 6-8 hours from Davao City depending on route and stops.",
        "travel_notes": "Best planned as an overnight or multi-stop Davao Oriental trip.",
        "what_to_bring": "Water shoes, dry bag, extra clothes, water, snacks, and sun protection.",
        "budget_class": "mid_range",
        "crowd_level": "moderate",
        "difficulty_level": "moderate",
        "stay_duration_type": "overnight",
        "transport_accessibility": "moderate",
        "family_friendly": True,
        "group_friendly": True,
        "is_kid_friendly": True,
        "accommodations": [
            {
                "name": "Cateel Traveller Inn",
                "room_type": "Standard Room",
                "price": Decimal("1800.00"),
                "capacity": 2,
                "description": "Simple town stay for waterfall visitors.",
            }
        ],
        "transportations": [
            {
                "vehicle_type": "Bus",
                "transport_mode": "public_transport",
                "route_from": "Davao City",
                "route_to": "Cateel",
                "price": Decimal("750.00"),
                "duration_minutes": 420,
                "duration_text": "6-8 hours",
                "notes": "Consider an overnight itinerary because travel time is long.",
            }
        ],
    },
]


async def seed() -> None:
    sessionmaker = get_sessionmaker()

    async with sessionmaker() as session:
        for item in SEED_DESTINATIONS:
            destination_data = {
                key: value
                for key, value in item.items()
                if key not in {"accommodations", "transportations"}
            }
            accommodations = item["accommodations"]
            transportations = item["transportations"]

            existing = await session.execute(
                select(Destination).where(Destination.name == item["name"])
            )
            destination = existing.scalar_one_or_none()

            if destination is None:
                destination = Destination(
                    **destination_data,
                    geom=WKTElement(
                        f"POINT({destination_data['lng']} {destination_data['lat']})",
                        srid=4326,
                    ),
                )
                session.add(destination)
                await session.flush()

            await _seed_accommodations(
                session=session,
                destination_id=destination.destination_id,
                accommodations=accommodations,
            )
            await _seed_transportations(
                session=session,
                destination_id=destination.destination_id,
                transportations=transportations,
            )

        await session.commit()


async def _seed_accommodations(
    *,
    session,
    destination_id: int,
    accommodations: list[dict],
) -> None:
    for accommodation in accommodations:
        existing = await session.execute(
            select(Accommodation).where(
                Accommodation.destination_id == destination_id,
                Accommodation.name == accommodation["name"],
                Accommodation.room_type == accommodation["room_type"],
            )
        )

        if existing.scalar_one_or_none() is not None:
            continue

        session.add(
            Accommodation(
                destination_id=destination_id,
                **accommodation,
            )
        )


async def _seed_transportations(
    *,
    session,
    destination_id: int,
    transportations: list[dict],
) -> None:
    for transportation in transportations:
        existing = await session.execute(
            select(Transportation).where(
                Transportation.destination_id == destination_id,
                Transportation.vehicle_type == transportation["vehicle_type"],
                Transportation.transport_mode == transportation["transport_mode"],
                Transportation.route_from == transportation["route_from"],
                Transportation.route_to == transportation["route_to"],
            )
        )

        if existing.scalar_one_or_none() is not None:
            continue

        session.add(
            Transportation(
                destination_id=destination_id,
                **transportation,
            )
        )


if __name__ == "__main__":
    asyncio.run(seed())
