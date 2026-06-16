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

  // Points to local backend in debug mode, and Render cloud in release mode.
  // Note: If you are testing on an Android Emulator, change localhost (127.0.0.1) to '10.0.2.2'.
  static String baseUrl = kDebugMode
      ? 'http://127.0.0.1:8000'
      : 'https://lakbay-finalv2backend.onrender.com';

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
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);

        final String accessToken = data['access_token'];

        setToken(accessToken);

        final payload = _decodeJwtPayload(accessToken);

        final String uid =
            payload?['uid']?.toString() ?? payload?['sub']?.toString() ?? email;

        final String userEmail = data['email'] ?? email;
        final String calculatedUsername = userEmail.split('@')[0];

        return UserProfile(
          uid: uid,
          displayName: data['name'] ?? data['full_name'] ?? 'User',
          email: userEmail,
          username: calculatedUsername,
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
      // Render free-tier cold start can take up to 60 s — hint the user to retry.
      if (e.toString().contains('TimeoutException')) {
        lastError = 'Server is waking up. Please wait a moment and try again.';
      } else {
        lastError = 'Cannot connect to server. Check your internet and try again.';
      }

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
      ).timeout(const Duration(seconds: 60));

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

  // Retrieve Popular Destinations (System 1)
  Future<List<Destination>> fetchPopularDestinations({int limit = 10}) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/destinations/popular?limit=$limit'));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Destination.fromJson(json)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching popular destinations: $e');
      }
    }
    // Fallback to local davaoDestinations sorted arbitrarily
    return Destination.davaoDestinations.take(limit).toList();
  }

  // Retrieve Recommended Destinations (System 2)
  Future<List<Destination>> fetchRecommendedDestinations({
    String? category,
    String? vibe,
    double? budget,
    String? duration,
    String? location,
    List<String>? activities,
    int limit = 5,
  }) async {
    try {
      final Map<String, String> queryParams = {
        'limit': limit.toString(),
      };
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (vibe != null && vibe.isNotEmpty) queryParams['vibe'] = vibe;
      if (budget != null) queryParams['budget'] = budget.toString();
      if (duration != null && duration.isNotEmpty) queryParams['duration'] = duration;
      if (location != null && location.isNotEmpty) queryParams['location'] = location;
      if (activities != null && activities.isNotEmpty) queryParams['activities'] = activities.join(',');

      final uri = Uri.parse('$baseUrl/destinations/recommended').replace(queryParameters: queryParams);
      
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => Destination.fromJson(json)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching recommended destinations: $e');
      }
    }
    // Fallback to local davaoDestinations
    return Destination.davaoDestinations.take(limit).toList();
  }

  // Record Destination Interaction (System 1 Write Path)
  Future<bool> recordInteraction(int destinationId, String eventType, {double? rating}) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = {
        'event_type': eventType,
        'rating': ?rating,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/destinations/$destinationId/interactions'),
        headers: headers,
        body: json.encode(body),
      );

      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error recording interaction: $e');
      }
      return false;
    }
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
      ).timeout(const Duration(seconds: 60));

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

  // Fetch saved trips from PostgreSQL database
  Future<List<Trip>> fetchUserTrips() async {
    try {
      final headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse('$baseUrl/trips'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((item) {
          // Reconstruct itinerary map
          final Map<String, dynamic> itineraryJson = item['itinerary'] ?? {};
          final Map<int, List<TripActivity>> itinerary = {};
          itineraryJson.forEach((dayStr, list) {
            final day = int.tryParse(dayStr) ?? 1;
            final List<dynamic> actList = list;
            itinerary[day] = actList.map((act) => TripActivity(
              time: act['time'] ?? '',
              title: act['title'] ?? '',
              description: act['description'] ?? '',
              cost: act['cost'] ?? 'Free',
              location: act['location'] ?? '',
            )).toList();
          });

          return Trip(
            id: item['id'] ?? '',
            title: item['title'] ?? '',
            destinationName: item['destinationName'] ?? '',
            dateRange: item['dateRange'] ?? '',
            budget: (item['budget'] as num?)?.toDouble() ?? 0.0,
            imageUrl: item['imageUrl'] ?? '',
            itinerary: itinerary,
            isGroup: item['isGroup'] ?? false,
            numTravelers: item['numTravelers'] ?? 1,
            notes: item['notes'] ?? '',
            tasks: List<Map<String, dynamic>>.from(item['tasks'] ?? []),
            memories: List<Map<String, dynamic>>.from(item['memories'] ?? []),
          );
        }).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching user trips from backend: $e. Falling back to mocks.');
      }
    }
    return Trip.mockTrips;
  }

  // Save trip itinerary and metadata to PostgreSQL database
  Future<bool> createTrip(Trip newTrip) async {
    try {
      lastError = null;
      final headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      // Convert itinerary map to JSON structure expected by backend
      final Map<String, dynamic> itineraryJson = {};
      newTrip.itinerary.forEach((day, list) {
        itineraryJson[day.toString()] = list.map((act) => {
          'time': act.time,
          'title': act.title,
          'description': act.description,
          'cost': act.cost,
          'location': act.location
        }).toList();
      });

      final body = {
        'id': newTrip.id,
        'title': newTrip.title,
        'destinationName': newTrip.destinationName,
        'dateRange': newTrip.dateRange,
        'budget': newTrip.budget,
        'imageUrl': newTrip.imageUrl,
        'itinerary': itineraryJson,
        'isGroup': newTrip.isGroup,
        'numTravelers': newTrip.numTravelers,
        'notes': newTrip.notes
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trips'),
        headers: headers,
        body: json.encode(body),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Server is waking up — please wait a moment and try again.');
        },
      );

      if (response.statusCode == 201) {
        if (kDebugMode) {
          print('Trip successfully saved to database: ${newTrip.title}');
        }
        return true;
      } else {
        try {
          final errBody = json.decode(response.body);
          lastError = errBody['detail'] ?? 'Failed to save trip (Status ${response.statusCode})';
        } catch (_) {
          lastError = 'Failed to save trip (Status ${response.statusCode})';
        }
        if (kDebugMode) {
          print('Failed to save trip. status: ${response.statusCode}, body: ${response.body}');
        }
      }
    } catch (e) {
      if (e.toString().contains('timed out') || e.toString().contains('TimeoutException')) {
        lastError = 'Connection timed out. Please check your internet and try again.';
      } else if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
        lastError = 'Cannot reach the server. Make sure the backend is running.';
      } else {
        lastError = 'Failed to save trip. Please try again.';
      }
      if (kDebugMode) {
        print('Error saving trip: $e');
      }
    }
    return false;
  }

  // Fetch optimized route details including real road geometry
  Future<Map<String, dynamic>?> optimizeRoute({
    required List<Map<String, dynamic>> destinations,
    double? startLat,
    double? startLng,
    String? startName,
    bool returnToStart = false,
  }) async {
    try {
      final headers = {'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final body = {
        'destinations': destinations,
        if (startLat != null) 'start_lat': startLat,
        if (startLng != null) 'start_lng': startLng,
        if (startName != null) 'start_name': startName,
        'return_to_start': returnToStart,
      };

      final response = await http.post(
        Uri.parse('$baseUrl/trips/optimize-route'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error optimizing route: $e');
      }
    }
    return null;
  }

  // Delete trip from backend
  Future<bool> deleteTrip(String tripId) async {
    try {
      lastError = null;
      final headers = <String, String>{};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.delete(
        Uri.parse('$baseUrl/trips/$tripId'),
        headers: headers,
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Trip successfully deleted from database: $tripId');
        }
        return true;
      } else {
        try {
          final errBody = json.decode(response.body);
          lastError = errBody['detail'] ?? 'Failed to delete trip (Status ${response.statusCode})';
        } catch (_) {
          lastError = 'Failed to delete trip (Status ${response.statusCode})';
        }
      }
    } catch (e) {
      lastError = 'Failed to delete trip. Please try again.';
      if (kDebugMode) {
        print('Error deleting trip: $e');
      }
    }
    return false;
  }
}

