class UserProfile {
  final String uid;
  final String displayName;
  final String email;
  final String avatarUrl;
  final int completedTripsCount;
  final int sharedMemoriesCount;
  final int travelerPoints;
  final int visitedDestinationsCount;
  final int visitedProvincesCount;
  final List<String> travelPreferences;

  UserProfile({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.completedTripsCount,
    required this.sharedMemoriesCount,
    required this.travelerPoints,
    required this.visitedDestinationsCount,
    required this.visitedProvincesCount,
    required this.travelPreferences,
  });

  // Mock profile data
  static final UserProfile defaultProfile = UserProfile(
    uid: 'user-001',
    displayName: 'Arjane Garcia',
    email: 'arjane.garcia@gmail.com',
    avatarUrl: 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&q=80',
    completedTripsCount: 12,
    sharedMemoriesCount: 28,
    travelerPoints: 2450,
    visitedDestinationsCount: 8,
    visitedProvincesCount: 3,
    travelPreferences: ['Nature', 'Beach', 'Food', 'Culture'],
  );
}
