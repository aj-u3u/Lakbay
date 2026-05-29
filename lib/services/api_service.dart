import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/destination.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';

/// Decodes a JWT token and returns the payload as a Map.
/// Returns null if the token is malformed.
Map<String, dynamic>? _decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;

    var payload = parts[1];

    while (payload.length % 4 != 0) {
      payload += '=';
    }

    final decoded = utf8.decode(base64Url.decode(payload));
    return json.decode(decoded) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

class ApiService {
  // Singleton pattern
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  // RENDER BACKEND URL
  static String baseUrl = 'https://lakbay-finalv2backend.onrender.com';

  String? token;
  String? lastError;

  void setToken(String? newToken) {
    token = newToken;
  }

  // Authentication: Login
  Future<UserProfile?> authenticateUser(String email, String password) async {
    try {
      lastError = null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final String accessToken = data['access_token'];

        setToken(accessToken);

        final payload = _decodeJwtPayload(accessToken);

        final String uid =
            payload?['uid']?.toString() ?? payload?['sub']?.toString() ?? email;

        return UserProfile(
          uid: uid,
          displayName: data['name'] ?? data['full_name'] ?? 'User',
          email: data['email'] ?? email,
          avatarUrl:
              'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150&q=80',
          completedTripsCount: 0,
          sharedMemoriesCount: 0,
          travelerPoints: 100,
          visitedDestinationsCount: 0,
          visitedProvincesCount: 0,
          travelPreferences: ['Nature', 'Beach', 'Food'],
        );
      } else {
        if (kDebugMode) {
          print('Login failed: ${response.statusCode} — ${response.body}');
        }

        try {
          final body = json.decode(response.body);

          lastError = body['detail'] ?? 'Invalid email or password.';
        } catch (_) {
          lastError = 'Invalid email or password.';
        }
      }
    } catch (e) {
      lastError = 'Cannot connect to server.';

      if (kDebugMode) {
        print('Login request error: $e');
      }
    }

    return null;
  }

  // Authentication: Register
  Future<bool> registerUser(
    String name,
    String email,
    String password,
  ) async {
    try {
      lastError = null;

      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'full_name': name,
          'email': email,
          'password': password,
          'confirm_password': password,
        }),
      );

      if (response.statusCode == 201) {
        return true;
      } else {
        if (kDebugMode) {
          print('Register failed: ${response.statusCode} — ${response.body}');
        }

        try {
          final body = json.decode(response.body);

          lastError = body['detail'] ?? 'Registration failed.';
        } catch (_) {
          lastError = 'Registration failed.';
        }
      }
    } catch (e) {
      lastError = 'Cannot connect to server.';

      if (kDebugMode) {
        print('Registration request error: $e');
      }
    }

    return false;
  }

  // Retrieve Destinations
  Future<List<Destination>> fetchDestinations() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/destinations'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        return data.map((json) => Destination.fromJson(json)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching destinations: $e');
      }
    }

    return Destination.davaoDestinations;
  }

  // AI Chat
  Future<Map<String, dynamic>?> chatWithAI(String prompt) async {
    try {
      final headers = {'Content-Type': 'application/json'};

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.post(
        Uri.parse('$baseUrl/ai/chat'),
        headers: headers,
        body: json.encode({'prompt': prompt}),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      } else {
        if (kDebugMode) {
          print(
            'AI chat failed with status ${response.statusCode}: ${response.body}',
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error calling AI chat endpoint: $e');
      }
    }

    return null;
  }

  // Mock trips
  Future<List<Trip>> fetchUserTrips() async {
    await Future.delayed(const Duration(milliseconds: 300));

    return Trip.mockTrips;
  }

  Future<bool> createTrip(Trip newTrip) async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (kDebugMode) {
      print('Trip created locally: ${newTrip.title}');
    }

    return true;
  }
}
