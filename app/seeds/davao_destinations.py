import asyncio
import argparse
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


CURATED_VISITOR_DESTINATIONS = [
    {
        "name": "Museo Dabawenyo",
        "description": "City history and culture museum at its Mabini Street Event Center location.",
        "district": "Davao City",
        "location": "Barangay 10-A, Mabini Street, Davao City",
        "category": "museum",
        "vibes": "culture, history, educational",
        "activities": "museum visit, local history, exhibits",
        "lat": 7.07939,
        "lng": 125.60449,
        "estimated_cost": Decimal("0.00"),
        "entrance_fee": "Free admission listed by Davao City; confirm current access.",
        "operating_hours": "Confirm current hours before visiting.",
        "budget_class": "budget",
        "difficulty_level": "easy",
        "stay_duration_type": "short",
        "family_friendly": True,
        "group_friendly": True,
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "National Museum of the Philippines - Davao",
        "description": "Regional museum of Davao and Mindanao history, culture, and natural heritage.",
        "district": "Davao City",
        "location": "People's Park Compound, J. Palma Gil Street, Davao City",
        "category": "museum",
        "vibes": "culture, history, educational",
        "activities": "museum visit, exhibits, cultural learning",
        "lat": 7.07016,
        "lng": 125.60914,
        "estimated_cost": Decimal("0.00"),
        "entrance_fee": "Free admission listed by the National Museum; group booking rules apply.",
        "operating_hours": "Check National Museum visitor schedule before visiting.",
        "budget_class": "budget",
        "difficulty_level": "easy",
        "stay_duration_type": "short",
        "family_friendly": True,
        "group_friendly": True,
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Aqua Water Park",
        "description": "Day-tour water park within Costa Azalea on Samal Island; ferry access must be planned separately.",
        "district": "Davao del Norte",
        "location": "Limao, Island Garden City of Samal, Davao del Norte",
        "category": "water park",
        "vibes": "family, beach, leisure",
        "activities": "swimming, water slides, day tour",
        "lat": 7.08705,
        "lng": 125.66662,
        "estimated_cost": Decimal("1000.00"),
        "entrance_fee": "Date-dependent day-tour pass; confirm the current operator rate.",
        "operating_hours": "Operator schedule conflicts on Tuesday; confirm before booking.",
        "how_to_get_there": "Samal ferry or boat connection must be arranged separately.",
        "budget_class": "mid_range",
        "difficulty_level": "easy",
        "stay_duration_type": "full_day",
        "family_friendly": True,
        "group_friendly": True,
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Camp Sabros Mountain Resort",
        "description": "Kapatagan mountain resort offering day visits and outdoor activities.",
        "district": "Davao del Sur",
        "location": "Sitio Barras, Barangay Kapatagan, Digos City, Davao del Sur",
        "category": "mountain resort",
        "vibes": "nature, adventure, mountain",
        "activities": "day tour, zipline, mountain views",
        "lat": 6.90514,
        "lng": 125.34654,
        "estimated_cost": Decimal("100.00"),
        "entrance_fee": "Operator lists PHP 100 adult day-tour admission; rides cost extra.",
        "operating_hours": "Confirm arrival hours with operator before travel.",
        "how_to_get_there": "Operator describes a parking area below the camp; its exact pin is not verified.",
        "budget_class": "budget",
        "difficulty_level": "moderate",
        "stay_duration_type": "full_day",
        "family_friendly": True,
        "group_friendly": True,
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Subangan Museum",
        "description": "Provincial museum of Davao Oriental's natural and cultural heritage, reopened in January 2026.",
        "district": "Davao Oriental",
        "location": "Provincial Tourism Complex, Mati City, Davao Oriental",
        "category": "museum",
        "vibes": "culture, history, educational",
        "activities": "museum visit, provincial history, exhibits",
        "lat": 6.94423,
        "lng": 126.24834,
        "estimated_cost": Decimal("200.00"),
        "entrance_fee": "Admission fee unconfirmed; PHP 200 is a provisional planning estimate, not a listed fee.",
        "operating_hours": "Confirm current museum hours before visiting.",
        "budget_class": "budget",
        "difficulty_level": "easy",
        "stay_duration_type": "short",
        "family_friendly": True,
        "group_friendly": True,
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
]


DISCOVERY_VISITOR_DESTINATIONS = [
    {
        "name": "Panabo Mangrove Forest Park",
        "description": "Mangrove conservation and nature tourism site in Panabo City; current visitor access requires confirmation.",
        "district": "Davao del Norte",
        "location": "Panabo City, Davao del Norte",
        "category": "nature park",
        "vibes": "nature, coastal, educational",
        "activities": "mangrove viewing, nature appreciation",
        "lat": 7.26989,
        "lng": 125.68049,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm current visitor fee with Panabo City.",
        "operating_hours": "Unknown; confirm current public access.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Christ the King Cathedral Parish",
        "description": "Active cathedral parish and religious landmark in Tagum City; visits must respect worship activities.",
        "district": "Davao del Norte",
        "location": "Dr. Juan Gonzales Avenue, Tagum City, Davao del Norte",
        "category": "church",
        "vibes": "faith, heritage, culture",
        "activities": "church visit, religious heritage",
        "lat": 7.44115,
        "lng": 125.79992,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm any visitor charge with the parish.",
        "operating_hours": "Confirm parish visiting hours and services.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Digos City Eco Park and Arboretum",
        "description": "City ecopark and arboretum in Tres de Mayo; current public opening requires confirmation.",
        "district": "Davao del Sur",
        "location": "Sitio San Nicolas, Tres de Mayo, Digos City, Davao del Sur",
        "category": "nature park",
        "vibes": "nature, educational, leisure",
        "activities": "arboretum visit, nature appreciation",
        "lat": 6.77553,
        "lng": 125.34392,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm current visitor fee with Digos City.",
        "operating_hours": "Unknown; confirm current public access.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "San Salvador del Mundo Church",
        "description": "Active historic parish church in Caraga; visits must respect worship activities.",
        "district": "Davao Oriental",
        "location": "Caraga, Davao Oriental",
        "category": "church",
        "vibes": "faith, history, culture",
        "activities": "church visit, religious heritage",
        "lat": 7.32770,
        "lng": 126.56588,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm any visitor charge with the parish.",
        "operating_hours": "Confirm parish visiting hours and services.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
]


COVERAGE_COMPLETION_DESTINATIONS = [
    {
        "name": "Rizal Park Digos",
        "description": "Public city park beside Digos City Hall, listed among Digos tourism destinations.",
        "district": "Davao del Sur",
        "location": "Digos City, Davao del Sur",
        "category": "city park",
        "vibes": "leisure, urban, family",
        "activities": "park visit, walking",
        "lat": 6.74442,
        "lng": 125.35556,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm any visitor fee with Digos City.",
        "operating_hours": "Confirm current park hours.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Cape San Agustin",
        "description": "Scenic cape and historic lighthouse area in Governor Generoso; the mapped cape is not a visitor entrance.",
        "district": "Davao Oriental",
        "location": "Barangay Lavigan, Governor Generoso, Davao Oriental",
        "category": "scenic cape",
        "vibes": "coastal, history, nature",
        "activities": "coastal views, lighthouse-area sightseeing",
        "lat": 6.26932,
        "lng": 126.19297,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm ecopark access and fee with the province.",
        "operating_hours": "Unknown; confirm current public access.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "New Barili Heights and Sights",
        "description": "Mountain viewpoint and resort in New Barili, Maco, overlooking Lake Leonard.",
        "district": "Davao de Oro",
        "location": "Barangay New Barili, Maco, Davao de Oro",
        "category": "mountain resort",
        "vibes": "mountain, scenic, leisure",
        "activities": "viewpoint visit, nature appreciation",
        "lat": 7.35411,
        "lng": 126.01136,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm day-visit access and rates with the operator.",
        "operating_hours": "Unknown; confirm current operator schedule.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Pyalitan Falls",
        "description": "Multi-tier waterfall near Mapawa, Maragusan; a local trek is needed after the road approach.",
        "district": "Davao de Oro",
        "location": "Barangay Mapawa, Maragusan, Davao de Oro",
        "category": "waterfall",
        "vibes": "nature, adventure, hiking",
        "activities": "waterfall viewing, guided trekking",
        "lat": 7.29919,
        "lng": 126.17070,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm guide, permit, and admission costs locally.",
        "operating_hours": "Unknown; confirm current trekking access.",
        "travel_notes": "The waterfall point is not a road destination or trailhead.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Lake Leonard Eco-Tourism Park",
        "description": "Named visitor site by Lake Leonard in New Leyte, Maco; public opening requires confirmation.",
        "district": "Davao de Oro",
        "location": "Barangay New Leyte, Maco, Davao de Oro",
        "category": "lake park",
        "vibes": "nature, lakeside, leisure",
        "activities": "lake views, nature appreciation",
        "lat": 7.39792,
        "lng": 126.05760,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm current visitor fees with the local operator.",
        "operating_hours": "Unknown; confirm current public access.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Christ the Redeemer, Jose Abad Santos",
        "description": "Religious monument at Joyce Paradise in Barangay Culaman, Jose Abad Santos.",
        "district": "Davao Occidental",
        "location": "Joyce Paradise, Barangay Culaman, Jose Abad Santos, Davao Occidental",
        "category": "religious landmark",
        "vibes": "faith, scenic, culture",
        "activities": "monument visit, coastal views",
        "lat": 5.96223,
        "lng": 125.67773,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm current venue access and fee.",
        "operating_hours": "Unknown; confirm current venue hours.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "DDG Beach Resort",
        "description": "Seaside resort in Colagsing, Santa Maria; land and boat access require separate checking.",
        "district": "Davao Occidental",
        "location": "Sitio Colagsing, Barangay Tanglad, Santa Maria, Davao Occidental",
        "category": "beach resort",
        "vibes": "beach, leisure, coastal",
        "activities": "beach day visit, seaside views",
        "lat": 6.62303,
        "lng": 125.43369,
        "estimated_cost": None,
        "entrance_fee": "Unknown; confirm current day-visit charges with the operator.",
        "operating_hours": "Confirm date-specific access and reservations.",
        "travel_notes": "Operator describes rough-road and boat options; neither is verified for routing.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
    {
        "name": "Meskeen Resort (Malita Dives)",
        "description": "Small coastal resort and boardwalk in Tubalan, Malita, also mapped as Miskeen Beach Resort.",
        "district": "Davao Occidental",
        "location": "Tubalan, Malita, Davao Occidental",
        "category": "beach resort",
        "vibes": "coastal, leisure, nature",
        "activities": "boardwalk visit, coastal views",
        "lat": 6.49131,
        "lng": 125.57969,
        "estimated_cost": None,
        "entrance_fee": "Unknown; a 2026 visitor reported a fee, but the operator rate is unverified.",
        "operating_hours": "Unknown; confirm current public access.",
        "route_ready": False,
        "accommodations": [],
        "transportations": [],
    },
]


async def seed(destinations: list[dict] | None = None) -> None:
    sessionmaker = get_sessionmaker()
    destinations = SEED_DESTINATIONS if destinations is None else destinations

    async with sessionmaker() as session:
        for item in destinations:
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
    parser = argparse.ArgumentParser(description="Seed Davao destination data.")
    batch = parser.add_mutually_exclusive_group()
    batch.add_argument(
        "--curated-only", action="store_true",
        help="Import only the five previously reviewed visitor attractions.",
    )
    batch.add_argument(
        "--discovery-only", action="store_true",
        help="Import only the four discovery-only attractions with unknown costs.",
    )
    batch.add_argument(
        "--coverage-only", action="store_true",
        help="Import only the eight reviewed Phase 2 coverage destinations.",
    )
    arguments = parser.parse_args()
    selected = (
        CURATED_VISITOR_DESTINATIONS if arguments.curated_only else
        DISCOVERY_VISITOR_DESTINATIONS if arguments.discovery_only else
        COVERAGE_COMPLETION_DESTINATIONS if arguments.coverage_only else None
    )
    asyncio.run(seed(selected))
