import 'dart:convert';
import 'package:flutter/material.dart';

class Destination {
  final int id;
  final String name;
  final String description;
  final double rating;
  final double? estimatedCost;
  final String district; // Province or general city area
  final String location; // Detailed address
  final String category;
  final String imageUrl;
  final String entranceFee;
  final String overnightFee;
  final String operatingHours;
  final List<String> activities;
  final bool isKidFriendly;
  final bool isWheelchairAccessible;
  final bool isPetFriendly;
  final bool isElderlyFriendly;
  final double latitude;
  final double longitude;
  final double? arrivalLatitude;
  final double? arrivalLongitude;
  final bool routeReady;
  final double popularityScore;
  final String trendingStatus;
  final Map<String, String> matchReasons;
  final bool isCatalogRecord;

  Destination({
    required this.id,
    required this.name,
    required this.description,
    required this.rating,
    required this.estimatedCost,
    required this.district,
    required this.location,
    required this.category,
    required this.imageUrl,
    required this.entranceFee,
    this.overnightFee = '',
    required this.operatingHours,
    required this.activities,
    this.isKidFriendly = true,
    this.isWheelchairAccessible = false,
    this.isPetFriendly = false,
    this.isElderlyFriendly = true,
    required this.latitude,
    required this.longitude,
    this.arrivalLatitude,
    this.arrivalLongitude,
    this.routeReady = false,
    this.popularityScore = 0.0,
    this.trendingStatus = 'stable',
    this.matchReasons = const {},
    this.isCatalogRecord = false,
  });

  // Mock Database of geographically accurate destinations in Davao Region
  static final List<Destination> davaoDestinations = [
    Destination(
      id: 1,
      name: 'Eden Nature Park & Resort',
      description:
          'Lush mountain resort at the foot of Mount Apo featuring pine forests, organic vegetable gardens, adventure sky-rides, and clear gulf vistas.',
      rating: 4.8,
      estimatedCost: 1200.0,
      district: 'Davao City',
      location: 'Toril, Davao City',
      category: 'Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
      entranceFee: '₱150 per person',
      operatingHours: '8:00 AM - 5:00 PM (Approximate Mock Operating Hours)',
      activities: [
        'Hiking',
        'Ziplining',
        'Bird Watching',
        'Photography',
        'Fishing',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: false,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.0094,
      longitude: 125.4338,
    ),
    Destination(
      id: 2,
      name: 'Philippine Eagle Center',
      description:
          'Crucial breeding and conservation facility nestled in a rainforest biome dedicated to the endangered Philippine Eagle.',
      rating: 4.6,
      estimatedCost: 600.0,
      district: 'Davao City',
      location: 'Malagos, Calinan, Davao City',
      category: 'Nature/Wildlife',
      imageUrl:
          'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=800&q=80',
      entranceFee: '₱100 per person',
      operatingHours: '8:00 AM - 4:00 PM (Approximate Mock Operating Hours)',
      activities: [
        'Bird Watching',
        'Educational Tours',
        'Photography',
        'Nature Walks',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: true,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.1554,
      longitude: 125.4452,
    ),
    Destination(
      id: 3,
      name: 'Malagos Garden Resort',
      description:
          'An interactive 12-hectare agricultural eco-resort hosting the country\'s first interactive chocolate museum, butterfly dome, and bird feeds.',
      rating: 4.7,
      estimatedCost: 1200.0,
      district: 'Davao City',
      location: 'Calinan, Davao City',
      category: 'Culture/Nature',
      imageUrl: 'assets/destinations/malagos_garden.jpg',
      entranceFee: '₱350 - ₱550',
      operatingHours: '8:00 AM - 5:00 PM (Approximate Mock Operating Hours)',
      activities: [
        'Butterfly Watching',
        'Bird Feeding',
        'Chocolate Making',
        'Swimming',
        'Horseback Riding',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: true,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.1593,
      longitude: 125.4414,
    ),
    Destination(
      id: 4,
      name: 'Jack\'s Ridge Resort & Restaurant',
      description:
          'Hilltop leisure development situated on a historic WWII Japanese fortress offering panoramic evening views of the city skyline.',
      rating: 4.5,
      estimatedCost: 800.0,
      district: 'Davao City',
      location: 'Shrine Hills, Matina, Davao City',
      category: 'Urban/Culture',
      imageUrl: 'assets/destinations/jacks_ridge.jpg',
      entranceFee: 'Free admission',
      operatingHours: '10:00 AM - 11:00 PM (Approximate Mock Operating Hours)',
      activities: ['Sightseeing', 'Swimming Pool Use', 'Dining', 'Photography'],
      isKidFriendly: true,
      isWheelchairAccessible: true,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.0674,
      longitude: 125.5841,
    ),
    Destination(
      id: 5,
      name: 'People\'s Park',
      description:
          'A vibrant public park in downtown showcasing detailed, giant heritage sculptures by artist Kublai Millan amidst tropical flora.',
      rating: 4.5,
      estimatedCost: 100.0,
      district: 'Davao City',
      location: 'Downtown, Davao City',
      category: 'Urban/Nature',
      imageUrl: 'assets/destinations/peoples_park.jpg',
      entranceFee: 'Free',
      operatingHours: '5:00 AM - 9:00 PM (Approximate Mock Operating Hours)',
      activities: [
        'Jogging',
        'Strolling',
        'Photography',
        'Children\'s Playground',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: true,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.0706,
      longitude: 125.6092,
    ),
    Destination(
      id: 6,
      name: 'Roxas Night Market',
      description:
          'A bustling nocturnal culinary and shopping strip in the city core featuring affordable local street food, dynamic vendors, and open massage stalls.',
      rating: 4.6,
      estimatedCost: 300.0,
      district: 'Davao City',
      location: 'Roxas Avenue, Davao City',
      category: 'Urban/Food',
      imageUrl: 'assets/destinations/roxas_night_market.jpg',
      entranceFee: 'Free',
      operatingHours: '6:00 PM - 12:00 AM (Approximate Mock Operating Hours)',
      activities: [
        'Street Food Tasting',
        'Massage Services',
        'Thrift Shopping',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: true,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.0733,
      longitude: 125.6124,
    ),
    Destination(
      id: 8,
      name: 'Pearl Farm Beach Resort',
      description:
          'Premium world-class private island hideaway featuring iconic over-water stilt bungalows, infinity pools, and marine sanctuaries.',
      rating: 4.9,
      estimatedCost: 12000.0,
      district: 'Davao del Norte',
      location: 'Samal Island, Davao del Norte',
      category: 'Beach/Luxury',
      imageUrl: 'assets/destinations/pearl_farm.png',
      entranceFee: '₱3,500 Day Tour',
      operatingHours: '24 Hours (Approximate Mock Operating Hours)',
      activities: [
        'Diving',
        'Spa Sessions',
        'Snorkeling',
        'Kayaking',
        'Jet Skiing',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: false,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.0194,
      longitude: 125.7194,
    ),
    Destination(
      id: 9,
      name: 'Hagimit Falls',
      description:
          'Multi-layered woodland cascade flowing into wide natural limestone wading pools shaded by pristine jungle vegetation.',
      rating: 4.6,
      estimatedCost: 500.0,
      district: 'Davao del Norte',
      location: 'Babak District, Samal Island, Davao del Norte',
      category: 'Nature/Waterfalls',
      imageUrl: 'assets/destinations/hagimit_falls.jpg',
      entranceFee: '₱40 per person',
      operatingHours: '6:00 AM - 6:00 PM (Approximate Mock Operating Hours)',
      activities: ['Swimming', 'Waterfall Wading', 'Camping', 'Picnicking'],
      isKidFriendly: true,
      isWheelchairAccessible: false,
      isPetFriendly: false,
      isElderlyFriendly: false,
      latitude: 7.0942,
      longitude: 125.7725,
    ),
    Destination(
      id: 15,
      name: 'Dahican Beach',
      description:
          'Stunning 7-kilometer crescent of open white sand facing Pacific swells, famous for world-class skimboarding and turtle nesting.',
      rating: 4.8,
      estimatedCost: 1500.0,
      district: 'Davao Oriental',
      location: 'Mati, Davao Oriental',
      category: 'Beach/Surfing',
      imageUrl: 'assets/destinations/dahican_beach.png',
      entranceFee: '₱20 per person',
      operatingHours: '24 Hours (Approximate Mock Operating Hours)',
      activities: [
        'Surfing',
        'Skimboarding',
        'Sea Turtle Spotting',
        'Camping',
        'Swimming',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: false,
      isPetFriendly: true,
      isElderlyFriendly: false,
      latitude: 6.9205,
      longitude: 126.2944,
    ),
    Destination(
      id: 12,
      name: 'Mount Apo National Park',
      description:
          'High-altitude wilderness reserve guarding the highest peak in the Philippines, marked by volcanic rocks and mossy cloud forests.',
      rating: 4.9,
      estimatedCost: 5000.0,
      district: 'Davao del Sur',
      location: 'Kapatagan, Digos City, Davao del Sur',
      category: 'Nature/Mountain',
      imageUrl: 'assets/destinations/mount_apo.png',
      entranceFee: '₱2,000 Permit Fee',
      operatingHours: '24 Hours (Approximate Mock Operating Hours)',
      activities: [
        'Highland Mountain Trekking',
        'Alpine Camping',
        'Wildlife Sightseeing',
      ],
      isKidFriendly: false,
      isWheelchairAccessible: false,
      isPetFriendly: false,
      isElderlyFriendly: false,
      latitude: 6.9875,
      longitude: 125.2708,
    ),
    Destination(
      id: 16,
      name: 'Toyozu Hot Spring',
      description:
          'A natural hot spring resort famous for its therapeutic, volcanic sulfur water pools and Japanese-style soaking tubs.',
      rating: 4.5,
      estimatedCost: 400.0,
      district: 'Davao de Oro',
      location: 'Maco, Davao de Oro',
      category: 'Nature/Relaxation',
      imageUrl:
          'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800&q=80',
      entranceFee: '₱80 per person',
      operatingHours: '8:00 AM - 8:00 PM',
      activities: ['Thermal Bathing', 'Spa Treatments', 'Picnicking'],
      isKidFriendly: true,
      isWheelchairAccessible: true,
      isPetFriendly: false,
      isElderlyFriendly: true,
      latitude: 7.3718,
      longitude: 125.8239,
    ),
    Destination(
      id: 17,
      name: 'Kopiat Island',
      description:
          'An uninhabited 87-hectare island ringed with pristine white sands, serving as a sanctuary for sea turtles and diverse marine life.',
      rating: 4.7,
      estimatedCost: 1800.0,
      district: 'Davao de Oro',
      location: 'Mabini, Davao de Oro',
      category: 'Beach/Nature',
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      entranceFee: 'Free (Boat rental extra)',
      operatingHours: '6:00 AM - 5:00 PM',
      activities: [
        'Snorkeling',
        'Island Hopping',
        'Beach Volleyball',
        'Turtle Watching',
      ],
      isKidFriendly: true,
      isWheelchairAccessible: false,
      isPetFriendly: true,
      isElderlyFriendly: false,
      latitude: 7.2889,
      longitude: 125.8654,
    ),
    Destination(
      id: 18,
      name: 'Olanivan Island',
      description:
          'A remote, flat islet famous for its historic circular lighthouse, clear turquoise waters, and unique shell-strewn shores.',
      rating: 4.6,
      estimatedCost: 2500.0,
      district: 'Davao Occidental',
      location: 'Sarangani, Davao Occidental',
      category: 'Beach/Adventure',
      imageUrl:
          'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
      entranceFee: 'Free (Boat charter needed)',
      operatingHours: '24 Hours',
      activities: ['Sightseeing', 'Swimming', 'Camping', 'Photography'],
      isKidFriendly: true,
      isWheelchairAccessible: false,
      isPetFriendly: true,
      isElderlyFriendly: false,
      latitude: 5.6150,
      longitude: 125.5398,
    ),
    Destination(
      id: 19,
      name: 'Balut Island Hot Springs',
      description:
          'An active volcanic island featuring natural thermal springs, dramatic coastal cliffs, and sweeping views of the Celebes Sea.',
      rating: 4.5,
      estimatedCost: 3000.0,
      district: 'Davao Occidental',
      location: 'Sarangani, Davao Occidental',
      category: 'Nature/Adventure',
      imageUrl:
          'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
      entranceFee: '₱50 entry fee',
      operatingHours: '6:00 AM - 6:00 PM',
      activities: [
        'Hot Spring Soaking',
        'Trekking',
        'Snorkeling',
        'Local Interaction',
      ],
      isKidFriendly: false,
      isWheelchairAccessible: false,
      isPetFriendly: false,
      isElderlyFriendly: false,
      latitude: 5.4022,
      longitude: 125.3789,
    ),
  ];

  factory Destination.fromJson(Map<String, dynamic> json) {
    String categoryStr = '';
    if (json['category'] is List) {
      categoryStr = (json['category'] as List).join(', ');
    } else if (json['category'] is String) {
      categoryStr = json['category'];
    }

    final accessibility = json['accessibility'] as Map<String, dynamic>? ?? {};

    List<String> parseStringList(dynamic value) {
      if (value == null) return const [];
      if (value is List) {
        return value.map((item) => item.toString()).toList();
      }
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty) return const [];
        if (trimmed.startsWith('[')) {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is List) {
              return decoded.map((item) => item.toString()).toList();
            }
          } catch (_) {}
        }
        return trimmed
            .split(RegExp(r'[,/]'))
            .map((item) => item.trim())
            .where((item) => item.isNotEmpty)
            .toList();
      }
      return const [];
    }

    double parseDouble(dynamic value, {double fallback = 0.0}) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    int parseInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    // Safely parse match reasons
    final Map<String, String> matchReasonsMap = {};
    if (json['match_reasons'] is Map) {
      (json['match_reasons'] as Map).forEach((key, val) {
        matchReasonsMap[key.toString()] = val.toString();
      });
    } else if (json['matched_reasons'] is List) {
      final List list = json['matched_reasons'] as List;
      for (int i = 0; i < list.length; i++) {
        matchReasonsMap['reason_$i'] = list[i].toString();
      }
    } else if (json['match_reasons'] is List) {
      final List list = json['match_reasons'] as List;
      for (int i = 0; i < list.length; i++) {
        matchReasonsMap['reason_$i'] = list[i].toString();
      }
    }

    final id = parseInt(json['destination_id'] ?? json['id']);
    if (id <= 0) throw const FormatException('Destination ID is missing.');
    final catalogCost = json.containsKey('estimated_cost')
        ? json['estimated_cost']
        : json['cost'];
    return Destination(
      id: id,
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      rating: parseDouble(json['rating']),
      estimatedCost: double.tryParse(catalogCost?.toString() ?? ''),
      district: json['district'] ?? '',
      location: json['location'] ?? '',
      category: categoryStr,
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? json['image'] ?? '')
          .toString(),
      entranceFee: (json['entrance_fee'] ?? json['entranceFee'] ?? 'Not listed')
          .toString(),
      overnightFee: (json['overnight_fee'] ?? '').toString(),
      operatingHours:
          (json['operating_hours'] ?? json['operatingHours'] ?? 'Not listed')
              .toString(),
      activities: parseStringList(json['activities']),
      isKidFriendly:
          accessibility['isKidFriendly'] ?? json['is_kid_friendly'] ?? true,
      isWheelchairAccessible:
          accessibility['isWheelchairAccessible'] ??
          json['is_wheelchair_accessible'] ??
          false,
      isPetFriendly:
          accessibility['isPetFriendly'] ?? json['is_pet_friendly'] ?? false,
      isElderlyFriendly:
          accessibility['isElderlyFriendly'] ??
          json['is_elderly_friendly'] ??
          true,
      latitude: parseDouble(json['latitude'] ?? json['lat']),
      longitude: parseDouble(json['longitude'] ?? json['lng']),
      arrivalLatitude: json['arrival_lat'] == null
          ? null
          : parseDouble(json['arrival_lat']),
      arrivalLongitude: json['arrival_lng'] == null
          ? null
          : parseDouble(json['arrival_lng']),
      routeReady: json['route_ready'] == true,
      popularityScore: parseDouble(json['popularity_score']),
      trendingStatus: json['trending_status'] ?? 'stable',
      matchReasons: matchReasonsMap,
      isCatalogRecord: json.containsKey('destination_id'),
    );
  }

  DestinationExtra get extra {
    if (isCatalogRecord) {
      return DestinationExtra(
        activityPrices: const {},
        environmentalFee: 'Not listed',
        overnightFee: overnightFee.isEmpty ? 'Not listed' : overnightFee,
        accommodationTypes: const [],
        travelNotes: const [],
        mealInclusions: const [],
        transportOptions: const [],
      );
    }
    switch (id) {
      case 1:
        return DestinationExtra(
          activityPrices: {
            'Ziplining': '₱150',
            'Skycycle': '₱200',
            'Skyrider': '₱150',
            'Guided Shuttle': '₱120',
          },
          environmentalFee: '₱50 per vehicle',
          overnightFee: '₱3,500 - ₱8,000 / night',
          accommodationTypes: [
            {'type': 'Vista Cottage', 'price': '₱3,500 / night'},
            {'type': 'Log Cabin', 'price': '₱6,000 / night'},
            {'type': 'Mountain Villa', 'price': '₱8,500 / night'},
          ],
          travelNotes: [
            'Best visited early in the morning to enjoy cool mountain mist.',
            'Bring a light jacket as temperature can drop in the afternoon.',
            'Strictly no outside food allowed inside the resort.',
          ],
          mealInclusions: [
            'Day Tour: Buffet Lunch included',
            'Overnight: Complimentary Breakfast included',
          ],
          transportOptions: [
            {
              'vehicle': 'Private Taxi / Grab',
              'from': 'Panabo',
              'to': 'Toril (Eden)',
              'price': '₱1,200 - ₱1,500',
              'duration': '1.5 hours',
            },
            {
              'vehicle': 'Jeepney + Habal-Habal',
              'from': 'Davao City Center',
              'to': 'Toril (Eden)',
              'price': '₱150',
              'duration': '1 hour',
            },
            {
              'vehicle': 'Public Bus + Habal-Habal',
              'from': 'Panabo',
              'to': 'Toril (Eden)',
              'price': '₱250',
              'duration': '2 hours',
            },
          ],
        );
      case 8:
        return DestinationExtra(
          activityPrices: {
            'Scuba Diving': '₱2,500 per dive',
            'Jet Skiing': '₱3,000 / hr',
            'Snorkeling Gear': '₱300 rental',
            'Mandaya Spa': '₱1,500 - ₱4,000',
          },
          environmentalFee: '₱100 per guest',
          overnightFee: '₱12,000 - ₱35,000 / night',
          accommodationTypes: [
            {'type': 'Hilltop Room', 'price': '₱12,000 / night'},
            {'type': 'Samal House (Overwater)', 'price': '₱18,500 / night'},
            {'type': 'Mandaya Villa', 'price': '₱28,000 / night'},
          ],
          travelNotes: [
            'Includes private roundtrip boat transfers from Lanang Marina.',
            'Prior reservation is required for day tours.',
            'Ideal place for coral conservation and marine view.',
          ],
          mealInclusions: [
            'Welcome drinks on arrival',
            'Complimentary premium buffet breakfast',
            'Overwater Dinner sets available',
          ],
          transportOptions: [
            {
              'vehicle': 'Taxi / Grab',
              'from': 'Davao City Center',
              'to': 'Lanang Marina',
              'price': '₱250 - ₱350',
              'duration': '30 mins',
            },
            {
              'vehicle': 'Resort Ferry / Boat',
              'from': 'Lanang Marina',
              'to': 'Samal Island Resort',
              'price': 'Included in Tour',
              'duration': '45 mins',
            },
            {
              'vehicle': 'Public Bus / Jeepney',
              'from': 'Panabo',
              'to': 'Lanang Marina',
              'price': '₱80 - ₱120',
              'duration': '1.2 hours',
            },
          ],
        );
      case 15:
        return DestinationExtra(
          activityPrices: {
            'Surfboard Rental': '₱400 / hr (with instructor)',
            'Skimboard Rental': '₱100 / hr',
            'Tent Pitching': '₱250',
          },
          environmentalFee: '₱50 environmental fee',
          overnightFee: '₱250 (Camping) - ₱2,500 (Resort)',
          accommodationTypes: [
            {'type': 'Campsite Space', 'price': '₱250 / night'},
            {'type': 'Standard Beach Room', 'price': '₱1,800 / night'},
            {'type': 'Beachfront Cottage', 'price': '₱2,500 / night'},
          ],
          travelNotes: [
            'Best skimboarding months are from October to March.',
            'Turtle nesting sites are restricted; do not touch the turtles.',
            'Bring sunscreen and rashguards for surfing.',
          ],
          mealInclusions: [
            'Meals not included; local beachfront grill houses available nearby.',
          ],
          transportOptions: [
            {
              'vehicle': 'Public Bus (Non-Stop)',
              'from': 'Davao City Center',
              'to': 'Mati Terminal',
              'price': '₱350 - ₱450',
              'duration': '4 - 5 hours',
            },
            {
              'vehicle': 'Local Tricycle',
              'from': 'Mati Terminal',
              'to': 'Dahican Beach',
              'price': '₱50 - ₱100',
              'duration': '15 mins',
            },
            {
              'vehicle': 'Shared Passenger Van',
              'from': 'Panabo',
              'to': 'Mati Town',
              'price': '₱400',
              'duration': '4.5 hours',
            },
          ],
        );
      default:
        return DestinationExtra(
          activityPrices: {
            'General Guide': '₱300 - ₱500',
            'Equipment Rental': '₱150',
          },
          environmentalFee: '₱30 local fee',
          overnightFee: 'Not applicable (Day Tour focus)',
          accommodationTypes: [
            {'type': 'Standard Guesthouse', 'price': '₱1,200 / night'},
            {'type': 'Camping Site Rental', 'price': '₱300 / night'},
          ],
          travelNotes: [
            'Respect the local environment and leave no trace.',
            'Bring cash as digital payment options might be limited.',
          ],
          mealInclusions: [
            'Meals not included (local food stalls available nearby).',
          ],
          transportOptions: [
            {
              'vehicle': 'Taxi / Grab',
              'from': 'Davao City',
              'to': 'Destination',
              'price': '₱200 - ₱400',
              'duration': '30 - 45 mins',
            },
            {
              'vehicle': 'Public Jeepney',
              'from': 'Panabo',
              'to': 'Destination',
              'price': '₱50 - ₱100',
              'duration': '1 - 1.5 hours',
            },
            {
              'vehicle': 'Local Tricycle / Habal-Habal',
              'from': 'Local Terminal',
              'to': 'Destination',
              'price': '₱20 - ₱50',
              'duration': '15 mins',
            },
          ],
        );
    }
  }

  static Widget loadImage(
    String url, {
    BoxFit fit = BoxFit.cover,
    Widget Function(BuildContext, Object, StackTrace?)? errorBuilder,
  }) {
    if (url.startsWith('assets/')) {
      return Image.asset(url, fit: fit, errorBuilder: errorBuilder);
    }
    return Image.network(url, fit: fit, errorBuilder: errorBuilder);
  }
}

class DestinationExtra {
  final Map<String, String> activityPrices;
  final String environmentalFee;
  final String overnightFee;
  final List<Map<String, String>> accommodationTypes;
  final List<String> travelNotes;
  final List<String> mealInclusions;
  final List<Map<String, String>> transportOptions;

  DestinationExtra({
    required this.activityPrices,
    required this.environmentalFee,
    required this.overnightFee,
    required this.accommodationTypes,
    required this.travelNotes,
    required this.mealInclusions,
    required this.transportOptions,
  });
}
