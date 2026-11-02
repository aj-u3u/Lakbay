class TripActivity {
  final String time;
  final String title;
  final String description;
  final String cost;
  final String location;

  TripActivity({
    required this.time,
    required this.title,
    required this.description,
    required this.cost,
    required this.location,
  });
}

class Trip {
  final String id;
  final String title;
  final String destinationName;
  final List<int> destinationIds;
  final String dateRange;
  final double budget;
  final String imageUrl;
  final Map<int, List<TripActivity>>
  itinerary; // Day number mapped to activities list
  final bool isGroup;
  final int numTravelers;
  final String notes;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> memories;

  /// For group trips: list of {name, role, avatar} maps.
  /// Seeded from numTravelers on trip creation; names can be updated later.
  final List<Map<String, String>> members;

  Trip({
    required this.id,
    required this.title,
    required this.destinationName,
    this.destinationIds = const [],
    required this.dateRange,
    required this.budget,
    required this.imageUrl,
    required this.itinerary,
    this.isGroup = false,
    this.numTravelers = 1,
    this.notes = '',
    this.tasks = const [],
    this.memories = const [],
    this.members = const [],
  });

  Trip copyWith({
    String? id,
    String? title,
    String? destinationName,
    List<int>? destinationIds,
    String? dateRange,
    double? budget,
    String? imageUrl,
    Map<int, List<TripActivity>>? itinerary,
    bool? isGroup,
    int? numTravelers,
    String? notes,
    List<Map<String, dynamic>>? tasks,
    List<Map<String, dynamic>>? memories,
    List<Map<String, String>>? members,
  }) {
    return Trip(
      id: id ?? this.id,
      title: title ?? this.title,
      destinationName: destinationName ?? this.destinationName,
      destinationIds: destinationIds ?? this.destinationIds,
      dateRange: dateRange ?? this.dateRange,
      budget: budget ?? this.budget,
      imageUrl: imageUrl ?? this.imageUrl,
      itinerary: itinerary ?? this.itinerary,
      isGroup: isGroup ?? this.isGroup,
      numTravelers: numTravelers ?? this.numTravelers,
      notes: notes ?? this.notes,
      tasks: tasks ?? this.tasks,
      memories: memories ?? this.memories,
      members: members ?? this.members,
    );
  }

  /// Generates seeded placeholder members from [count].
  /// The first slot is always 'Organizer', the rest are 'Member'.
  static List<Map<String, String>> seedMembers(int count) {
    return List.generate(
      count,
      (i) => {
        'name': i == 0 ? 'You (Organizer)' : 'Traveler ${i + 1}',
        'role': i == 0 ? 'Organizer' : 'Member',
        'avatar': '',
      },
    );
  }

  // Mock database of trips
  static final List<Trip> mockTrips = [
    Trip(
      id: 'trip-1',
      title: 'Ultimate Samal Getaway',
      destinationName: 'Samal Island, Davao del Norte',
      dateRange: 'June 10 - June 12, 2026',
      budget: 15000.0,
      imageUrl:
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      isGroup: true,
      numTravelers: 4,
      notes:
          'Don\'t forget to pack swimming clothes, sunscreen, and cash! Carlo to coordinate habal-habal transport.',
      tasks: [
        {
          'task': 'Book Pearl Farm ferry tickets',
          'assignee': 'Arjane',
          'done': true,
          'category': 'Booking',
        },
        {
          'task': 'Reserve 2 Samal House cabins',
          'assignee': 'Bea',
          'done': true,
          'category': 'Booking',
        },
        {
          'task': 'Buy snorkeling gear for 4 people',
          'assignee': 'Carlo',
          'done': false,
          'category': 'Packing',
        },
        {
          'task': 'Pack emergency first aid kit',
          'assignee': 'Dana',
          'done': false,
          'category': 'Packing',
        },
        {
          'task': 'Confirm Hagimit Falls entry fees',
          'assignee': 'Arjane',
          'done': false,
          'category': 'Research',
        },
        {
          'task': 'Book a habal-habal to Monfort Bats',
          'assignee': 'Bea',
          'done': false,
          'category': 'Transport',
        },
        {
          'task': 'Prepare ₱3,000 cash emergency fund',
          'assignee': 'Carlo',
          'done': true,
          'category': 'Finance',
        },
      ],
      memories: [
        {
          'id': 'mem-1',
          'user': 'Arjane',
          'avatar':
              'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
          'time': '2 hours ago',
          'caption':
              'Pearl Farm morning vibes 🌊✨ The stilt bungalows are absolutely dreamy!',
          'image':
              'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
          'likes': '18',
          'comments': '4',
          'location': 'Pearl Farm Resort',
        },
        {
          'id': 'mem-2',
          'user': 'Bea',
          'avatar':
              'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&q=80',
          'time': '5 hours ago',
          'caption':
              'Hagimit Falls was COLD and refreshing! The tiered pools were a surprise.',
          'image':
              'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
          'likes': '24',
          'comments': '7',
          'location': 'Hagimit Falls',
        },
        {
          'id': 'mem-3',
          'user': 'Carlo',
          'avatar':
              'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&q=80',
          'time': 'Yesterday',
          'caption':
              'Spotted a million bats flying out at sunset from Monfort Sanctuary! 🦇',
          'image':
              'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
          'likes': '31',
          'comments': '9',
          'location': 'Monfort Sanctuary',
        },
      ],
      itinerary: {
        1: [
          TripActivity(
            time: '08:00 AM',
            title: 'Marina Wharf Departure',
            description:
                'Board the private ferry from Lanang Marina Wharf to Samal.',
            cost: 'Included',
            location: 'Lanang, Davao City',
          ),
          TripActivity(
            time: '10:00 AM',
            title: 'Pearl Farm Check-in',
            description:
                'Welcome drinks and settlement in over-water stilt bungalows.',
            cost: '₱14,500/night',
            location: 'Samal Island',
          ),
          TripActivity(
            time: '02:00 PM',
            title: 'Coral Garden Snorkeling',
            description: 'Explore the marine sanctuary and view giant clams.',
            cost: 'Free',
            location: 'Pearl Farm Beach Reef',
          ),
        ],
        2: [
          TripActivity(
            time: '09:00 AM',
            title: 'Hagimit Falls Exploration',
            description:
                'Trek down the limestone steps to wade in the multi-tiered natural pools.',
            cost: '₱40 Entrance',
            location: 'Babak District, Samal',
          ),
          TripActivity(
            time: '01:00 PM',
            title: 'Monfort Bat Sanctuary Tour',
            description:
                'Visit the world\'s largest colony of Rousette fruit bats.',
            cost: '₱120 Entrance',
            location: 'Babak, Samal',
          ),
        ],
        3: [
          TripActivity(
            time: '07:00 AM',
            title: 'Sunrise Yoga & Infinity Pool',
            description:
                'Relaxing workout session by the poolside overlooking the Gulf.',
            cost: 'Free',
            location: 'Pearl Farm Resort',
          ),
          TripActivity(
            time: '12:00 PM',
            title: 'Check Out & Return Boat',
            description: 'Return boat trip back to Davao City proper.',
            cost: 'Included',
            location: 'Marina Wharf',
          ),
        ],
      },
    ),
    Trip(
      id: 'trip-2',
      title: 'Davao City Nature & Culture Tour',
      destinationName: 'Davao City Proper',
      dateRange: 'July 15 - July 16, 2026',
      budget: 3500.0,
      imageUrl:
          'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
      notes:
          'Pack comfortable walking shoes for Eden park and People\'s park, and prepare change for night market vendors.',
      tasks: [],
      memories: [],
      itinerary: {
        1: [
          TripActivity(
            time: '08:00 AM',
            title: 'Philippine Eagle Center',
            description:
                'Learn about bird conservation and see the legendary national eagles.',
            cost: '₱100 Entrance',
            location: 'Malagos, Calinan',
          ),
          TripActivity(
            time: '12:00 PM',
            title: 'Malagos Garden Buffet Lunch',
            description:
                'Enjoy fresh farm-to-table lunch buffet and make your own chocolate.',
            cost: '₱550 Lunch Pack',
            location: 'Calinan, Davao City',
          ),
          TripActivity(
            time: '06:00 PM',
            title: 'Roxas Night Market Street Food',
            description:
                'Try the authentic charcoal grilled tuna, chicken barbecue, and local durian ice cream.',
            cost: '₱200 Budget',
            location: 'Roxas Ave, Davao City',
          ),
        ],
        2: [
          TripActivity(
            time: '09:00 AM',
            title: 'Eden Nature Park Guided Shuttle',
            description:
                'Ride around the mountain resort, explore the pine forest and organic gardens.',
            cost: '₱150 Entrance',
            location: 'Toril, Davao City',
          ),
          TripActivity(
            time: '02:00 PM',
            title: 'People\'s Park Stroll',
            description:
                'Relax under the trees and photograph the giant sculptures.',
            cost: 'Free',
            location: 'Downtown Davao',
          ),
        ],
      },
    ),
  ];
}
