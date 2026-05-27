import 'package:flutter/foundation.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';

class ApiService {
  // Simulated base URL for future FastAPI integration
  static const String baseUrl = 'http://localhost:8000/api';

  // Future-based stubs for Authentication
  Future<UserProfile?> authenticateUser(String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 800)); // Simulate network latency
    if (email.contains('@') && password.length >= 6) {
      return UserProfile.defaultProfile;
    }
    return null;
  }

  Future<UserProfile?> registerUser(String name, String email, String password) async {
    await Future.delayed(const Duration(milliseconds: 1000));
    return UserProfile(
      uid: 'user-new',
      displayName: name,
      email: email,
      avatarUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&q=80',
      completedTripsCount: 0,
      sharedMemoriesCount: 0,
      travelerPoints: 100,
      visitedDestinationsCount: 0,
      visitedProvincesCount: 0,
      travelPreferences: [],
    );
  }

  // Future-based stubs for Destination data
  Future<List<Destination>> fetchDestinations() async {
    await Future.delayed(const Duration(milliseconds: 600));
    return Destination.davaoDestinations;
  }

  // Future-based stubs for Trip records
  Future<List<Trip>> fetchUserTrips() async {
    await Future.delayed(const Duration(milliseconds: 700));
    return Trip.mockTrips;
  }

  Future<bool> createTrip(Trip newTrip) async {
    await Future.delayed(const Duration(milliseconds: 950));
    if (kDebugMode) {
      print('Trip created in mock DB: ${newTrip.title}');
    }
    return true;
  }
}
