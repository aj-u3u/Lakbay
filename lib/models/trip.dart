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
  final String dateRange;
  final double budget;
  final String imageUrl;
  final Map<int, List<TripActivity>> itinerary; // Day number mapped to activities list

  Trip({
    required this.id,
    required this.title,
    required this.destinationName,
    required this.dateRange,
    required this.budget,
    required this.imageUrl,
    required this.itinerary,
  });

  // Mock database of trips
  static final List<Trip> mockTrips = [
    Trip(
      id: 'trip-1',
      title: 'Ultimate Samal Getaway',
      destinationName: 'Samal Island, Davao del Norte',
      dateRange: 'June 10 - June 12, 2026',
      budget: 15000.0,
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      itinerary: {
        1: [
          TripActivity(
            time: '08:00 AM',
            title: 'Marina Wharf Departure',
            description: 'Board the private ferry from Lanang Marina Wharf to Samal.',
            cost: 'Included',
            location: 'Lanang, Davao City',
          ),
          TripActivity(
            time: '10:00 AM',
            title: 'Pearl Farm Check-in',
            description: 'Welcome drinks and settlement in over-water stilt bungalows.',
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
            description: 'Trek down the limestone steps to wade in the multi-tiered natural pools.',
            cost: '₱40 Entrance',
            location: 'Babak District, Samal',
          ),
          TripActivity(
            time: '01:00 PM',
            title: 'Monfort Bat Sanctuary Tour',
            description: 'Visit the world\'s largest colony of Rousette fruit bats.',
            cost: '₱120 Entrance',
            location: 'Babak, Samal',
          ),
        ],
        3: [
          TripActivity(
            time: '07:00 AM',
            title: 'Sunrise Yoga & Infinity Pool',
            description: 'Relaxing workout session by the poolside overlooking the Gulf.',
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
      imageUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
      itinerary: {
        1: [
          TripActivity(
            time: '08:00 AM',
            title: 'Philippine Eagle Center',
            description: 'Learn about bird conservation and see the legendary national eagles.',
            cost: '₱100 Entrance',
            location: 'Malagos, Calinan',
          ),
          TripActivity(
            time: '12:00 PM',
            title: 'Malagos Garden Buffet Lunch',
            description: 'Enjoy fresh farm-to-table lunch buffet and make your own chocolate.',
            cost: '₱550 Lunch Pack',
            location: 'Calinan, Davao City',
          ),
          TripActivity(
            time: '06:00 PM',
            title: 'Roxas Night Market Street Food',
            description: 'Try the authentic charcoal grilled tuna, chicken barbecue, and local durian ice cream.',
            cost: '₱200 Budget',
            location: 'Roxas Ave, Davao City',
          ),
        ],
        2: [
          TripActivity(
            time: '09:00 AM',
            title: 'Eden Nature Park Guided Shuttle',
            description: 'Ride around the mountain resort, explore the pine forest and organic gardens.',
            cost: '₱150 Entrance',
            location: 'Toril, Davao City',
          ),
          TripActivity(
            time: '02:00 PM',
            title: 'People\'s Park Stroll',
            description: 'Relax under the trees and photograph the giant sculptures.',
            cost: 'Free',
            location: 'Downtown Davao',
          ),
        ],
      },
    ),
  ];
}
