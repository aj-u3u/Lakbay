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
  final String username;
  final String phone;
  final String emergencyContact;

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
    this.username = 'arjanegarcia',
    this.phone = '',
    this.emergencyContact = '',
  });

  UserProfile copyWith({
    String? uid,
    String? displayName,
    String? email,
    String? avatarUrl,
    int? completedTripsCount,
    int? sharedMemoriesCount,
    int? travelerPoints,
    int? visitedDestinationsCount,
    int? visitedProvincesCount,
    List<String>? travelPreferences,
    String? username,
    String? phone,
    String? emergencyContact,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      completedTripsCount: completedTripsCount ?? this.completedTripsCount,
      sharedMemoriesCount: sharedMemoriesCount ?? this.sharedMemoriesCount,
      travelerPoints: travelerPoints ?? this.travelerPoints,
      visitedDestinationsCount: visitedDestinationsCount ?? this.visitedDestinationsCount,
      visitedProvincesCount: visitedProvincesCount ?? this.visitedProvincesCount,
      travelPreferences: travelPreferences ?? this.travelPreferences,
      username: username ?? this.username,
      phone: phone ?? this.phone,
      emergencyContact: emergencyContact ?? this.emergencyContact,
    );
  }

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
    travelPreferences: const ['Nature', 'Beach', 'Food', 'Culture'],
    username: 'arjanegarcia',
    phone: '+639171234567',
    emergencyContact: 'Garcia Emergency • +639177654321',
  );
}
