import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/destination.dart';
import '../models/catalog_rate.dart';
import '../models/grouped_destinations.dart';
import '../models/route_geometry.dart';
import '../models/planning_feedback.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';
import '../core/config/api_config.dart';
import 'validation_message.dart';

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

Future<MediaType?> _memoryImageContentType(String filePath) async {
  final file = await File(filePath).open();
  try {
    final header = await file.read(12);
    if (header.length >= 3 &&
        header[0] == 0xFF &&
        header[1] == 0xD8 &&
        header[2] == 0xFF) {
      return MediaType('image', 'jpeg');
    }
    if (header.length >= 8 &&
        header[0] == 0x89 &&
        header[1] == 0x50 &&
        header[2] == 0x4E &&
        header[3] == 0x47 &&
        header[4] == 0x0D &&
        header[5] == 0x0A &&
        header[6] == 0x1A &&
        header[7] == 0x0A) {
      return MediaType('image', 'png');
    }
    if (header.length >= 12 &&
        header[0] == 0x52 &&
        header[1] == 0x49 &&
        header[2] == 0x46 &&
        header[3] == 0x46 &&
        header[8] == 0x57 &&
        header[9] == 0x45 &&
        header[10] == 0x42 &&
        header[11] == 0x50) {
      return MediaType('image', 'webp');
    }
    return null;
  } finally {
    await file.close();
  }
}

class CatalogException implements Exception {
  final String message;
  final bool isOffline;
  const CatalogException(this.message, {this.isOffline = false});
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  ApiService._internal();

  @visibleForTesting
  ApiService.testing();

  static String baseUrl = ApiConfig.baseUrl;

  String? token;
  String? refreshToken;
  String? lastError;
  void Function(String? accessToken, String? refreshToken)? onSessionChanged;

  void setToken(String? newToken) {
    token = newToken;
  }

  void setSessionTokens({
    required String? accessToken,
    required String? newRefreshToken,
  }) {
    token = accessToken;
    refreshToken = newRefreshToken;
    onSessionChanged?.call(token, refreshToken);
  }

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  Map<String, String> _headers({bool jsonBody = true}) {
    return {
      if (jsonBody) 'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  List<Map<String, dynamic>> _collaborationListFromBody(String body) {
    final decoded = json.decode(body);
    if (decoded is! List ||
        decoded.any((item) => item is! Map<String, dynamic>)) {
      throw const FormatException('The server returned an invalid list.');
    }
    return decoded.cast<Map<String, dynamic>>();
  }

  String? _errorCode(http.Response response) {
    try {
      final body = json.decode(response.body);
      final error = body is Map ? body['error'] : null;
      final code = error is Map ? error['code'] : null;
      return code?.toString();
    } catch (_) {
      return null;
    }
  }

  int _retryAfterSeconds(http.Response response) {
    var seconds = int.tryParse(response.headers['retry-after'] ?? '');
    try {
      final body = json.decode(response.body);
      final error = body is Map ? body['error'] : null;
      final details = error is Map ? error['details'] : null;
      final fromBody = details is Map ? details['retry_after_seconds'] : null;
      if (fromBody is num) seconds = fromBody.toInt();
    } catch (_) {}
    return (seconds ?? 30).clamp(1, 120);
  }

  String _errorFromResponse(http.Response response, String fallback) {
    try {
      final body = json.decode(response.body);
      final error = body is Map ? body['error'] : null;
      final errorDetails = error is Map ? error['details'] : null;
      if (errorDetails is List) {
        final fieldMessage = validationMessage(errorDetails);
        if (fieldMessage != null) return fieldMessage;
      }
      final detail = body is Map
          ? body['detail'] ??
                body['message'] ??
                (error is Map ? error['message'] : null)
          : null;
      if (detail is String && detail.isNotEmpty) return detail;
      if (detail != null) return detail.toString();
    } catch (_) {}
    return fallback;
  }

  void _storeTokens(Map<String, dynamic> data) {
    final tokens = (data['tokens'] as Map?)?.cast<String, dynamic>() ?? data;
    final accessToken = tokens['access_token']?.toString();
    if (accessToken == null || accessToken.isEmpty) {
      throw StateError('No access token was returned.');
    }

    setSessionTokens(
      accessToken: accessToken,
      newRefreshToken: tokens['refresh_token']?.toString(),
    );
  }

  UserProfile _userProfileFromJson(
    Map<String, dynamic> user, {
    String? fallbackEmail,
  }) {
    final userEmail = user['email']?.toString() ?? fallbackEmail ?? '';
    final displayName =
        user['full_name']?.toString() ?? user['name']?.toString() ?? 'User';
    final payload = token == null ? null : _decodeJwtPayload(token!);

    return UserProfile(
      uid:
          (user['user_id'] ??
                  user['id'] ??
                  payload?['uid'] ??
                  payload?['sub'] ??
                  userEmail)
              .toString(),
      displayName: displayName,
      email: userEmail,
      username: userEmail.contains('@')
          ? (user['username']?.toString() ?? userEmail.split('@').first)
          : (user['username']?.toString() ?? userEmail),
      phone: user['phone']?.toString() ?? '',
      emergencyContact:
          user['emergency_contact']?.toString() ??
          user['emergencyContact']?.toString() ??
          '',
      avatarUrl: user['avatar_url']?.toString() ?? '',
      completedTripsCount: 0,
      sharedMemoriesCount: 0,
      travelerPoints: 100,
      visitedDestinationsCount: 0,
      visitedProvincesCount: 0,
      travelPreferences: const ['Nature', 'Beach', 'Food'],
    );
  }

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  double _doubleValue(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double _parseMoney(String text) {
    final matches = RegExp(r'\d+(?:[,.]\d{3})*(?:\.\d+)?').allMatches(text);
    if (matches.isEmpty) return 0.0;
    final raw = matches.first.group(0)!.replaceAll(',', '');
    return double.tryParse(raw) ?? 0.0;
  }

  String _formatCurrency(num value) {
    return '₱${value.toStringAsFixed(0)}';
  }

  String _dateRangeFrom(dynamic start, dynamic end) {
    final startText = start?.toString() ?? '';
    final endText = end?.toString() ?? '';
    if (startText.isEmpty && endText.isEmpty) return 'Flexible Dates';
    if (startText.isNotEmpty && endText.isNotEmpty) {
      return '$startText - $endText';
    }
    return startText.isNotEmpty ? startText : endText;
  }

  String? _isoDateFromRange(String dateRange, {required bool end}) {
    final matches = RegExp(r'\d{4}-\d{2}-\d{2}').allMatches(dateRange).toList();
    if (matches.isEmpty) return null;
    if (end && matches.length > 1) return matches[1].group(0);
    return matches.first.group(0);
  }

  List<String> _splitTextPrefs(String? value) {
    if (value == null || value.trim().isEmpty) return const [];
    return value
        .split(RegExp(r'[,/]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  String _budgetClassFromAmount(double? budget) {
    if (budget == null) return 'mid_range';
    if (budget <= 1500) return 'budget';
    if (budget <= 6000) return 'mid_range';
    return 'premium';
  }

  String _notificationTypeFromEvent(String eventType) {
    final normalized = eventType.toLowerCase();
    if (normalized.contains('task')) return 'taskComplete';
    if (normalized.contains('member')) return 'memberJoin';
    if (normalized.contains('memory') || normalized.contains('photo')) {
      return 'memoryUpload';
    }
    if (normalized.contains('ai') || normalized.contains('plan')) {
      return 'aiPlan';
    }
    if (normalized.contains('route') || normalized.contains('trip')) {
      return 'tripUpdate';
    }
    if (normalized.contains('expense')) return 'tripUpdate';
    return 'tripUpdate';
  }

  String _iconFromNotificationType(String type) {
    switch (type) {
      case 'memberJoin':
        return '👥';
      case 'taskComplete':
        return '✅';
      case 'memoryUpload':
        return '📸';
      case 'aiPlan':
        return '⚡';
      default:
        return '🏖️';
    }
  }

  String _relativeTime(dynamic isoDate) {
    final parsed = DateTime.tryParse(isoDate?.toString() ?? '');
    if (parsed == null) return 'Just now';

    final diff = DateTime.now().difference(parsed.toLocal());
    if (diff.inDays > 1) return '${diff.inDays} days ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inHours > 1) return '${diff.inHours} hours ago';
    if (diff.inHours == 1) return '1 hour ago';
    if (diff.inMinutes > 1) return '${diff.inMinutes} mins ago';
    if (diff.inMinutes == 1) return '1 min ago';
    return 'Just now';
  }

  Future<UserProfile?> authenticateUser(String email, String password) async {
    try {
      lastError = null;

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/login'),
            headers: _headers(),
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? data;
        _storeTokens(data);
        return _userProfileFromJson(user, fallbackEmail: email);
      }

      lastError = _errorFromResponse(response, 'Invalid email or password.');
    } catch (e) {
      lastError = e.toString().contains('TimeoutException')
          ? 'Server is waking up. Please wait a moment and try again.'
          : 'Cannot connect to server. Check your internet and try again.';
      if (kDebugMode) {
        print('Login request error: $e');
      }
    }

    return null;
  }

  Future<bool> registerUser(String name, String email, String password) async {
    try {
      lastError = null;

      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/register'),
            headers: _headers(),
            body: json.encode({
              'full_name': name,
              'email': email,
              'password': password,
              'confirm_password': password,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 201) {
        return true;
      }

      lastError = _errorFromResponse(response, 'Registration failed.');
    } catch (e) {
      lastError = 'Cannot connect to server.';
      if (kDebugMode) {
        print('Registration request error: $e');
      }
    }

    return false;
  }

  Future<UserProfile?> fetchCurrentUser() async {
    if (token == null) return null;

    try {
      lastError = null;
      final response = await http
          .get(
            Uri.parse('$baseUrl/users/me'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final user = json.decode(response.body) as Map<String, dynamic>;
        return _userProfileFromJson(user);
      }

      if (response.statusCode == 401 && await refreshSession()) {
        return fetchCurrentUser();
      }

      lastError = _errorFromResponse(response, 'Failed to restore session.');
    } catch (e) {
      lastError = 'Cannot restore session.';
      if (kDebugMode) {
        print('Current user request error: $e');
      }
    }

    return null;
  }

  Future<UserProfile?> updateCurrentUser(UserProfile profile) async {
    if (token == null) return null;

    try {
      lastError = null;
      final response = await http
          .patch(
            Uri.parse('$baseUrl/users/me'),
            headers: _headers(),
            body: json.encode({
              'full_name': profile.displayName,
              'avatar_url': profile.avatarUrl,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final user = json.decode(response.body) as Map<String, dynamic>;
        return _userProfileFromJson(user);
      }

      if (response.statusCode == 401 && await refreshSession()) {
        return updateCurrentUser(profile);
      }

      lastError = _errorFromResponse(response, 'Failed to update profile.');
    } catch (e) {
      lastError = 'Cannot update profile.';
      if (kDebugMode) {
        print('Profile update request error: $e');
      }
    }

    return null;
  }

  Future<bool> refreshSession() async {
    final currentRefreshToken = refreshToken;
    if (currentRefreshToken == null || currentRefreshToken.isEmpty) {
      return false;
    }

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/auth/refresh'),
            headers: _headers(),
            body: json.encode({'refresh_token': currentRefreshToken}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        _storeTokens(data);
        return true;
      }

      lastError = _errorFromResponse(response, 'Session expired.');
    } catch (e) {
      lastError = 'Cannot refresh session.';
      if (kDebugMode) {
        print('Refresh token request error: $e');
      }
    }

    setSessionTokens(accessToken: null, newRefreshToken: null);
    return false;
  }

  Future<void> logoutSession() async {
    final currentRefreshToken = refreshToken;

    try {
      if (currentRefreshToken != null && currentRefreshToken.isNotEmpty) {
        await http
            .post(
              Uri.parse('$baseUrl/auth/logout'),
              headers: _headers(),
              body: json.encode({'refresh_token': currentRefreshToken}),
            )
            .timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      if (kDebugMode) {
        print('Logout request error: $e');
      }
    } finally {
      setSessionTokens(accessToken: null, newRefreshToken: null);
    }
  }

  Future<List<Destination>> fetchDestinations() async {
    const pageSize = 100;
    final byId = <int, Destination>{};
    for (var offset = 0; ; offset += pageSize) {
      final page = await _catalogList(
        '/destinations?limit=$pageSize&offset=$offset',
      );
      for (final row in page) {
        if (row['is_active'] == false) continue;
        final destination = Destination.fromJson(row);
        byId[destination.id] = destination;
      }
      if (page.length < pageSize) return byId.values.toList();
    }
  }

  Future<Destination> fetchDestination(int id) async {
    final row = await _catalogObject('/destinations/$id');
    if (row['is_active'] == false) {
      throw const CatalogException('This destination is no longer available.');
    }
    return Destination.fromJson(row);
  }

  Future<List<CatalogRate>> fetchAccommodationRates(int destinationId) async {
    final rows = await _catalogList(
      '/destinations/$destinationId/accommodations',
    );
    return rows
        .where((row) => row['is_available'] != false)
        .map(CatalogRate.accommodation)
        .where((rate) => rate.destinationId == destinationId)
        .toList();
  }

  Future<List<CatalogRate>> fetchTransportationRates(int destinationId) async {
    final rows = await _catalogList(
      '/destinations/$destinationId/transportations',
    );
    return rows
        .where((row) => row['is_available'] != false)
        .map(CatalogRate.transportation)
        .where((rate) => rate.destinationId == destinationId)
        .toList();
  }

  Future<List<Map<String, dynamic>>> _catalogList(String path) async {
    final decoded = await _catalogRequest(path);
    if (decoded is! List) {
      throw const CatalogException('The catalog returned an invalid list.');
    }
    return decoded.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const CatalogException('The catalog returned an invalid record.');
      }
      return item;
    }).toList();
  }

  Future<Map<String, dynamic>> _catalogObject(String path) async {
    final decoded = await _catalogRequest(path);
    if (decoded is! Map<String, dynamic>) {
      throw const CatalogException('The catalog returned an invalid record.');
    }
    return decoded;
  }

  Future<dynamic> _catalogRequest(String path) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl$path'))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 404) {
        throw const CatalogException(
          'This destination is no longer available.',
        );
      }
      if (response.statusCode != 200) {
        throw CatalogException(
          'The catalog could not be loaded (HTTP ${response.statusCode}).',
        );
      }
      return json.decode(response.body);
    } on SocketException {
      throw const CatalogException(
        'You are offline. Connect to refresh the catalog.',
        isOffline: true,
      );
    } on http.ClientException {
      throw const CatalogException(
        'Lakbay could not be reached. Check your connection and retry.',
        isOffline: true,
      );
    } on TimeoutException {
      throw const CatalogException('The catalog request timed out. Try again.');
    } on FormatException {
      throw const CatalogException('The catalog returned unreadable data.');
    }
  }

  Future<List<Destination>> fetchPopularDestinations({int limit = 10}) async {
    final destinations = await fetchDestinations();
    final sorted = List<Destination>.from(destinations)
      ..sort((a, b) {
        final ratingCompare = b.rating.compareTo(a.rating);
        if (ratingCompare != 0) return ratingCompare;
        final aCost = a.estimatedCost;
        final bCost = b.estimatedCost;
        if (aCost == null) return bCost == null ? 0 : 1;
        if (bCost == null) return -1;
        return aCost.compareTo(bCost);
      });
    return sorted.take(limit).toList();
  }

  Future<List<Destination>> fetchRecommendedDestinations({
    String? category,
    String? vibe,
    double? budget,
    String? duration,
    String? location,
    List<String>? activities,
    int limit = 5,
  }) async {
    final destinations = await fetchDestinations();

    final hasCriteria = [
      category,
      vibe,
      duration,
      location,
      ...(activities ?? const <String>[]),
    ].any((value) => value != null && value.toString().trim().isNotEmpty);

    if (token != null && hasCriteria) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/recommendations'),
              headers: _headers(),
              body: json.encode({
                'preferred_categories': _splitTextPrefs(category),
                'preferred_vibes': _splitTextPrefs(vibe),
                'preferred_activities': activities ?? const <String>[],
                'preferred_districts': _splitTextPrefs(location),
                'budget_class': _budgetClassFromAmount(budget),
                'stay_duration_type': duration,
                'max_estimated_cost': budget,
                'limit': limit,
              }),
            )
            .timeout(const Duration(seconds: 30));

        if (response.statusCode == 200 || response.statusCode == 201) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;
          final recs = decoded['recommendations'];
          if (recs is List && recs.isNotEmpty) {
            final byId = {for (final dest in destinations) dest.id: dest};
            final hydrated = recs
                .whereType<Map>()
                .map((item) => _intValue(item['destination_id']))
                .whereType<int>()
                .map((id) => byId[id])
                .whereType<Destination>()
                .toList();
            if (hydrated.isNotEmpty) return hydrated.take(limit).toList();
          }
        } else if (response.statusCode == 401 && await refreshSession()) {
          return fetchRecommendedDestinations(
            category: category,
            vibe: vibe,
            budget: budget,
            duration: duration,
            location: location,
            activities: activities,
            limit: limit,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('Error fetching recommendations: $e');
        }
      }
    }

    var filtered = List<Destination>.from(destinations);
    if (category != null && category.isNotEmpty) {
      filtered = filtered
          .where(
            (d) => d.category.toLowerCase().contains(category.toLowerCase()),
          )
          .toList();
    }
    if (vibe != null && vibe.isNotEmpty) {
      filtered = filtered
          .where(
            (d) =>
                d.category.toLowerCase().contains(vibe.toLowerCase()) ||
                d.activities.any(
                  (activity) =>
                      activity.toLowerCase().contains(vibe.toLowerCase()),
                ),
          )
          .toList();
    }
    if (location != null && location.isNotEmpty) {
      filtered = filtered
          .where(
            (d) =>
                d.district.toLowerCase().contains(location.toLowerCase()) ||
                d.location.toLowerCase().contains(location.toLowerCase()),
          )
          .toList();
    }
    if (budget != null) {
      filtered = filtered
          .where((d) => d.estimatedCost != null && d.estimatedCost! <= budget)
          .toList();
    }

    if (filtered.isEmpty && budget == null) filtered = destinations;
    return filtered.take(limit).toList();
  }

  Future<List<GroupedDestinations>> fetchGroupedDestinations({
    List<Destination>? source,
  }) async {
    final destinations = source ?? await fetchDestinations();
    final groups = <String, List<Destination>>{};
    for (final dest in destinations) {
      groups
          .putIfAbsent(
            dest.district.isEmpty ? 'Unknown' : dest.district,
            () => [],
          )
          .add(dest);
    }

    return groups.entries.map((entry) {
      final list = entry.value;
      final knownCosts = list
          .map((item) => item.estimatedCost)
          .whereType<double>()
          .toList();
      final double? averageCost = knownCosts.isEmpty
          ? null
          : knownCosts.reduce((a, b) => a + b) / knownCosts.length;
      final averageRating = list.isEmpty
          ? 0.0
          : list.fold<double>(0, (sum, item) => sum + item.rating) /
                list.length;
      return GroupedDestinations(
        district: entry.key,
        count: list.length,
        averageCost: averageCost,
        averageRating: averageRating,
        destinations: list,
      );
    }).toList();
  }

  Future<bool> recordInteraction(
    int destinationId,
    String eventType, {
    double? rating,
  }) async {
    if (token == null) return false;

    final mappedType = eventType == 'itinerary_add'
        ? 'add_to_itinerary'
        : eventType == 'rate'
        ? 'rate'
        : eventType;

    try {
      final body = {
        'interaction_type': mappedType,
        if (mappedType == 'rate' && rating != null) 'rating': rating.round(),
      };

      final response = await http
          .post(
            Uri.parse('$baseUrl/destinations/$destinationId/interactions'),
            headers: _headers(),
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 401 && await refreshSession()) {
        return recordInteraction(destinationId, eventType, rating: rating);
      }

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      if (kDebugMode) {
        print('Error recording interaction: $e');
      }
      return false;
    }
  }

  Future<Map<String, dynamic>?> chatWithAI(
    String prompt, {
    List<Map<String, String>>? history,
    Map<String, dynamic>? planningState,
    int inputRevision = 0,
    bool rateLimitRetried = false,
  }) async {
    if (token == null) {
      lastError = 'Please sign in to use Lakbay AI.';
      return null;
    }

    try {
      lastError = null;
      final normalizedHistory = (history ?? const <Map<String, String>>[])
          .where(
            (item) =>
                (item['role'] == 'user' || item['role'] == 'assistant') &&
                (item['content']?.trim().isNotEmpty ?? false),
          )
          .map(
            (item) => {
              'role': item['role']!,
              'content': item['content']!.trim(),
            },
          )
          .toList();
      if (normalizedHistory.isNotEmpty &&
          normalizedHistory.last['role'] == 'user' &&
          normalizedHistory.last['content'] == prompt.trim()) {
        normalizedHistory.removeLast();
      }
      final recentHistory = normalizedHistory.length > 12
          ? normalizedHistory.sublist(normalizedHistory.length - 12)
          : normalizedHistory;

      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/chat'),
            headers: _headers(),
            body: json.encode({
              'message': prompt,
              if (recentHistory.isNotEmpty) 'history': recentHistory,
              'model_role': 'default',
              'allow_fallback': true,
              'use_rag': true,
              'rag_limit': 6,
              ...?(planningState == null
                  ? null
                  : {
                      'planning_state': planningState,
                      'input_revision': inputRevision,
                    }),
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }

      if (response.statusCode == 401 && await refreshSession()) {
        return chatWithAI(
          prompt,
          history: history,
          planningState: planningState,
          inputRevision: inputRevision,
        );
      }

      if (response.statusCode == 429) {
        if (_errorCode(response) == 'ai_user_daily_limit_exceeded') {
          // Waiting a few seconds will not help; show the server's message.
          lastError = _errorFromResponse(
            response,
            "You have reached today's AI limit. Please try again tomorrow.",
          );
          return null;
        }
        final retryAfter = _retryAfterSeconds(response);
        if (!rateLimitRetried && retryAfter <= 5) {
          await Future<void>.delayed(Duration(seconds: retryAfter));
          return chatWithAI(
            prompt,
            history: history,
            planningState: planningState,
            inputRevision: inputRevision,
            rateLimitRetried: true,
          );
        }
        lastError =
            'The AI planner is busy right now. Please try again in about '
            '$retryAfter seconds.';
        return null;
      }

      lastError = _errorFromResponse(
        response,
        'Failed to chat with Lakbay AI.',
      );
      if (kDebugMode) {
        print('AI chat failed: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      lastError = e.toString().contains('TimeoutException')
          ? 'AI is taking too long to respond. Please try again.'
          : 'Failed to chat with Lakbay AI.';
      if (kDebugMode) {
        print('Error chatting with AI: $e');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> previewPlanningState({
    required Map<String, dynamic> state,
    required int inputRevision,
  }) async {
    if (token == null) {
      lastError = 'Please sign in to plan a trip.';
      return null;
    }
    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/planning/preview'),
            headers: _headers(),
            body: json.encode({
              'state': state,
              'input_revision': inputRevision,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return previewPlanningState(state: state, inputRevision: inputRevision);
      }
      lastError = _errorFromResponse(response, 'Could not review this plan.');
    } catch (_) {
      lastError = 'Could not review this plan. Please try again.';
    }
    return null;
  }

  Future<PlanningFeedback?> fetchPlanningFeedback({
    required Map<String, dynamic> state,
    required int inputRevision,
    bool? travelingWithChildren,
  }) async {
    if (token == null) {
      lastError = 'Please sign in to review this plan.';
      return null;
    }
    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/planning/feedback'),
            headers: _headers(),
            body: json.encode({
              'state': state,
              'input_revision': inputRevision,
              'traveling_with_children': travelingWithChildren,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return PlanningFeedback.fromJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchPlanningFeedback(
          state: state,
          inputRevision: inputRevision,
          travelingWithChildren: travelingWithChildren,
        );
      }
      lastError = _errorFromResponse(response, 'Could not check this plan.');
    } catch (_) {
      lastError = 'Could not check this plan. Please try again.';
    }
    return null;
  }

  Future<Map<String, dynamic>?> generatePlanningItinerary({
    required Map<String, dynamic> state,
    required int inputRevision,
  }) async {
    if (token == null) {
      lastError = 'Please sign in to generate an itinerary.';
      return null;
    }
    final destinationIds = (state['destination_ids'] as List? ?? const [])
        .whereType<int>()
        .toList();
    final transportationIds =
        (state['selected_transport_option_ids'] as List? ?? const [])
            .map((id) => id.toString())
            .where((id) => id.startsWith('transportation:'))
            .map((id) => int.tryParse(id.split(':').last))
            .whereType<int>()
            .toList();
    if (destinationIds.isEmpty ||
        state['total_budget'] == null ||
        state['traveler_count'] == null ||
        state['day_count'] == null) {
      lastError = 'Choose a destination and complete the trip details first.';
      return null;
    }
    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/ai/itineraries/generate'),
            headers: _headers(),
            body: json.encode({
              'total_budget': state['total_budget'],
              'traveler_count': state['traveler_count'],
              'day_count': state['day_count'],
              'destination_ids': destinationIds,
              'accommodation_ids':
                  state['selected_accommodation_ids'] ?? const <int>[],
              'transportation_ids': transportationIds,
              'interests': state['interests'] ?? const <String>[],
              'model_role': 'quality',
              'compare_models': false,
              'allow_fallback': true,
              'planning_state': state,
              'input_revision': inputRevision,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return generatePlanningItinerary(
          state: state,
          inputRevision: inputRevision,
        );
      }
      lastError = _errorFromResponse(
        response,
        'AI itinerary generation failed. Review your plan and retry.',
      );
    } catch (_) {
      lastError = 'AI itinerary generation timed out. Please try again.';
    }
    return null;
  }

  Future<Trip?> savePlanningAIOption({
    required int generationRunId,
    required int optionNumber,
  }) async {
    if (token == null) {
      lastError = 'Please sign in to save your trip.';
      return null;
    }
    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/trips/from-ai-option'),
            headers: _headers(),
            body: json.encode({
              'generation_run_id': generationRunId,
              'option_number': optionNumber,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 201) {
        return _tripFromFinalJson(
          json.decode(response.body) as Map<String, dynamic>,
        );
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return savePlanningAIOption(
          generationRunId: generationRunId,
          optionNumber: optionNumber,
        );
      }
      lastError = _errorFromResponse(
        response,
        'Could not save this itinerary.',
      );
    } catch (_) {
      lastError = 'Could not save this itinerary. Please try again.';
    }
    return null;
  }

  Future<Map<String, dynamic>?> generateAIItinerary({
    required String destinationName,
    required int numDays,
    required double budget,
    required int numAdults,
    required int numChildren,
    required String childAges,
    required List<String> interests,
  }) async {
    try {
      final selected = await _selectDestinationsForPlan(
        destinationName: destinationName,
        interests: interests,
      );
      if (selected.isEmpty) {
        lastError = 'Choose an available catalog destination.';
        return null;
      }
      final weatherSummary = await _weatherSummaryForPlanning(selected.first);

      if (token != null) {
        final response = await http
            .post(
              Uri.parse('$baseUrl/ai/itineraries/generate'),
              headers: _headers(),
              body: json.encode({
                'total_budget': budget.toStringAsFixed(2),
                'traveler_count': (numAdults + numChildren).clamp(1, 100),
                'day_count': numDays,
                'destination_ids': selected.map((d) => d.id).take(10).toList(),
                'accommodation_ids': const <int>[],
                'transportation_ids': const <int>[],
                'meal_cost_per_day': '500.00',
                'miscellaneous_cost': '300.00',
                'interests': interests,
                'travel_style': interests.isNotEmpty ? interests.first : null,
                'special_requirements':
                    [
                      if (childAges.isNotEmpty) 'Children ages: $childAges',
                      ?weatherSummary,
                    ].join('\n').trim().isEmpty
                    ? null
                    : [
                        if (childAges.isNotEmpty) 'Children ages: $childAges',
                        ?weatherSummary,
                      ].join('\n'),
                'model_role': 'quality',
                'compare_models': false,
                'allow_fallback': true,
              }),
            )
            .timeout(const Duration(seconds: 60));

        if (response.statusCode == 200) {
          final decoded = json.decode(response.body) as Map<String, dynamic>;
          final options = decoded['options'];
          if (options is List && options.isNotEmpty && options.first is Map) {
            return _legacyItineraryFromFinalOption(
              (options.first as Map).cast<String, dynamic>(),
              destinationName,
              selected,
              budget,
            );
          }
        } else if (response.statusCode == 401 && await refreshSession()) {
          return generateAIItinerary(
            destinationName: destinationName,
            numDays: numDays,
            budget: budget,
            numAdults: numAdults,
            numChildren: numChildren,
            childAges: childAges,
            interests: interests,
          );
        } else if (kDebugMode) {
          print('AI itinerary failed: ${response.statusCode} ${response.body}');
        }
      }

      lastError = 'AI itinerary generation failed. Please retry.';
      return null;
    } catch (e) {
      if (kDebugMode) {
        print('Error generating itinerary: $e');
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> fetchWeatherForecast({
    required double lat,
    required double lng,
    int days = 5,
  }) async {
    if (token == null) return null;

    try {
      lastError = null;
      final uri = Uri.parse('$baseUrl/weather/forecast').replace(
        queryParameters: {
          'lat': lat.toStringAsFixed(6),
          'lng': lng.toStringAsFixed(6),
          'days': days.clamp(1, 5).toString(),
        },
      );
      final response = await http
          .get(uri, headers: _headers(jsonBody: false))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchWeatherForecast(lat: lat, lng: lng, days: days);
      }
      lastError = _errorFromResponse(response, 'Failed to load weather.');
    } catch (e) {
      lastError = 'Failed to load weather.';
      if (kDebugMode) print('Error fetching weather forecast: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchDestinationWeather(
    int destinationId, {
    int days = 5,
  }) async {
    if (token == null) return null;

    try {
      lastError = null;
      final uri = Uri.parse(
        '$baseUrl/destinations/$destinationId/weather',
      ).replace(queryParameters: {'days': days.clamp(1, 5).toString()});
      final response = await http
          .get(uri, headers: _headers(jsonBody: false))
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchDestinationWeather(destinationId, days: days);
      }
      lastError = _errorFromResponse(
        response,
        'Failed to load destination weather.',
      );
    } catch (e) {
      lastError = 'Failed to load destination weather.';
      if (kDebugMode) print('Error fetching destination weather: $e');
    }
    return null;
  }

  Future<String?> _weatherSummaryForPlanning(Destination destination) async {
    final forecast = await fetchWeatherForecast(
      lat: destination.latitude,
      lng: destination.longitude,
      days: 3,
    );
    if (forecast == null) return null;

    final days = forecast['days'];
    if (days is! List || days.isEmpty) return null;

    final summary = StringBuffer('Weather context for ${destination.name}:');
    for (final raw in days.take(3)) {
      if (raw is! Map) continue;
      final condition = raw['condition'];
      final conditionText = condition is Map
          ? (condition['description'] ?? condition['main'] ?? 'weather')
                .toString()
          : 'weather';
      summary.write(
        '\n- ${raw['date']}: $conditionText, '
        '${raw['temp_min_c'] ?? '?'}-${raw['temp_max_c'] ?? '?'} C, '
        '${raw['rain_chance_percent'] ?? 0}% rain chance. '
        '${raw['advisory'] ?? ''}',
      );
    }
    return summary.toString();
  }

  Future<List<Trip>> fetchUserTrips() async {
    if (token == null) {
      lastError = 'Sign in to load your trips.';
      return [];
    }

    lastError = null;
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/trips'), headers: _headers(jsonBody: false))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final list = _collaborationListFromBody(response.body);
        final trips = <Trip>[];
        for (final item in list.whereType<Map>()) {
          final summary = item.cast<String, dynamic>();
          final tripId = _intValue(summary['trip_id']);
          if (tripId == null) {
            throw const FormatException(
              'The server returned an invalid trip ID.',
            );
          }
          final details = await _fetchTripDetails(tripId);
          if (details == null) {
            lastError = 'Failed to load trip details.';
            return [];
          }
          final trip = _tripFromFinalJson(details);
          final memories = await fetchTripMemories(trip.id);
          if (lastError != null) return [];
          trips.add(trip.copyWith(memories: memories));
        }
        return trips;
      }

      if (response.statusCode == 401 && await refreshSession()) {
        return fetchUserTrips();
      }
      lastError = _errorFromResponse(response, 'Failed to load trips.');
    } catch (e) {
      lastError = 'Failed to load trips.';
      if (kDebugMode) print('Error fetching user trips: $e');
    }

    return [];
  }

  Future<Map<String, dynamic>?> _fetchTripDetails(int tripId) async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$tripId'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return _fetchTripDetails(tripId);
      }
    } catch (_) {}
    return null;
  }

  Trip _tripFromFinalJson(Map<String, dynamic> item) {
    final itinerary = <int, List<TripActivity>>{};
    final days = item['itinerary_days'];
    if (days is List) {
      for (final dayRaw in days.whereType<Map>()) {
        final day = dayRaw.cast<String, dynamic>();
        final dayNumber = _intValue(day['day_number']) ?? 1;
        final activities = <TripActivity>[];
        final rawActivities = day['activities'];
        if (rawActivities is List) {
          for (final actRaw in rawActivities.whereType<Map>()) {
            final act = actRaw.cast<String, dynamic>();
            activities.add(
              TripActivity(
                time: act['time']?.toString() ?? '',
                title: act['title']?.toString() ?? '',
                description:
                    act['description']?.toString() ??
                    act['notes']?.toString() ??
                    '',
                cost: _formatCurrency(_doubleValue(act['estimated_cost'])),
                location: act['location']?.toString() ?? '',
              ),
            );
          }
        }
        itinerary[dayNumber] = activities;
      }
    }

    final destinations = item['destinations'];
    Map<String, dynamic>? firstDestination;
    if (destinations is List &&
        destinations.isNotEmpty &&
        destinations.first is Map) {
      firstDestination = (destinations.first as Map).cast<String, dynamic>();
    }

    final members = _membersFromFinalJson(item['members']);

    return Trip(
      id: (item['trip_id'] ?? item['id'] ?? '').toString(),
      title: item['title']?.toString() ?? 'Untitled Trip',
      destinationName:
          firstDestination?['name']?.toString() ??
          item['description']?.toString() ??
          '',
      destinationIds: destinations is List
          ? destinations
                .whereType<Map>()
                .map((entry) => _intValue(entry['destination_id']))
                .whereType<int>()
                .toList()
          : const [],
      dateRange: _dateRangeFrom(item['start_date'], item['end_date']),
      budget: _doubleValue(item['total_budget']),
      imageUrl: '',
      itinerary: itinerary,
      isGroup: (_intValue(item['traveler_count']) ?? 1) > 1,
      numTravelers: _intValue(item['traveler_count']) ?? 1,
      notes: item['notes']?.toString() ?? '',
      tasks: _tasksFromFinalJson(item['tasks'], members: members),
      members: members,
    );
  }

  List<Map<String, dynamic>> _tasksFromFinalJson(
    dynamic raw, {
    List<Map<String, String>> members = const [],
  }) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      return _taskFromFinalJson(item.cast<String, dynamic>(), members: members);
    }).toList();
  }

  List<Map<String, String>> _membersFromFinalJson(dynamic raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((item) {
      final member = item.cast<String, dynamic>();
      final role = member['role']?.toString() ?? 'member';
      final id = (member['trip_member_id'] ?? member['id'] ?? '').toString();
      return {
        'id': id,
        'trip_member_id': id,
        'user_id': (member['user_id'] ?? '').toString(),
        'name': member['full_name']?.toString() ?? 'Traveler',
        'email': member['email']?.toString() ?? '',
        'role': _memberRoleLabel(role),
        'status': member['status']?.toString() ?? 'active',
        'avatar':
            'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&q=80',
      };
    }).toList();
  }

  int? _backendTripId(String tripId) {
    final id = _intValue(tripId);
    if (id == null || id < 1) {
      lastError = 'This trip is not saved in the backend yet.';
      return null;
    }
    return id;
  }

  int? _backendRecordId(dynamic id) {
    final parsed = _intValue(id);
    return parsed != null && parsed > 0 ? parsed : null;
  }

  String _memberRoleLabel(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
      case 'organizer':
        return 'Organizer';
      case 'member':
        return 'Member';
      default:
        return role.isEmpty
            ? 'Member'
            : '${role[0].toUpperCase()}${role.substring(1).toLowerCase()}';
    }
  }

  String _memberRolePayload(String role) {
    final lower = role.toLowerCase();
    if (lower == 'owner' || lower == 'organizer') return 'organizer';
    return 'member';
  }

  String _memberNameForId(int? memberId, List<Map<String, String>> members) {
    if (memberId == null) return 'Unassigned';
    for (final member in members) {
      if (_intValue(member['trip_member_id'] ?? member['id']) == memberId) {
        return member['name']?.isNotEmpty == true
            ? member['name']!
            : 'Traveler';
      }
    }
    return 'Member #$memberId';
  }

  Map<String, dynamic> _taskFromFinalJson(
    Map<String, dynamic> task, {
    List<Map<String, String>> members = const [],
  }) {
    final taskId = (task['trip_task_id'] ?? task['id'] ?? '').toString();
    final assignedId = _intValue(task['assigned_trip_member_id']);
    final status = task['status']?.toString() ?? 'pending';
    return {
      'id': taskId,
      'trip_task_id': taskId,
      'task': task['title']?.toString() ?? '',
      'description': task['description']?.toString() ?? '',
      'assignee': _memberNameForId(assignedId, members),
      'assigned_trip_member_id': assignedId?.toString() ?? '',
      'done': status == 'completed',
      'status': status,
      'due_date': task['due_date']?.toString() ?? '',
      'category': 'General',
    };
  }

  String _expenseUiCategory(dynamic value) {
    switch (value?.toString().toLowerCase()) {
      case 'meals':
        return 'Food';
      case 'transportation':
        return 'Transport';
      case 'accommodation':
        return 'Accommodation';
      case 'activities':
        return 'Activities';
      default:
        return 'Others';
    }
  }

  String _expenseApiCategory(String value) {
    switch (value.toLowerCase()) {
      case 'food':
      case 'meals':
        return 'meals';
      case 'transport':
      case 'transportation':
        return 'transportation';
      case 'accommodation':
        return 'accommodation';
      case 'activities':
        return 'activities';
      default:
        return 'other';
    }
  }

  Map<String, dynamic> _expenseFromFinalJson(Map<String, dynamic> expense) {
    final id = (expense['trip_expense_id'] ?? expense['expense_id'] ?? '')
        .toString();
    final title = expense['title']?.toString() ?? 'Trip expense';
    final notes = expense['notes']?.toString();
    final description = expense['description']?.toString();
    return {
      'id': id,
      'trip_expense_id': id,
      'amount': _doubleValue(expense['amount']),
      'category': _expenseUiCategory(expense['category']),
      'note': (notes?.isNotEmpty == true)
          ? notes
          : (description?.isNotEmpty == true ? description : title),
      'title': title,
      'description': description ?? '',
      'paid_by_trip_member_id': (expense['paid_by_trip_member_id'] ?? '')
          .toString(),
      'paid_by_full_name': expense['paid_by_full_name']?.toString() ?? '',
      'status': expense['status']?.toString() ?? 'active',
      'expense_date': expense['expense_date']?.toString() ?? '',
    };
  }

  Map<String, dynamic> _memoryFromFinalJson(Map<String, dynamic> memory) {
    final id = (memory['trip_memory_id'] ?? memory['memory_id'] ?? '')
        .toString();
    return {
      'id': id,
      'memory_id': id,
      'user': memory['uploaded_by_full_name']?.toString() ?? 'Traveler',
      'avatar':
          'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=100&q=80',
      'time': _relativeTime(memory['created_at'] ?? memory['taken_at']),
      'caption': memory['caption']?.toString() ?? '',
      'image': memory['image_url']?.toString() ?? '',
      'likes': (_intValue(memory['like_count']) ?? 0).toString(),
      'comments': (_intValue(memory['comment_count']) ?? 0).toString(),
      'location':
          memory['location_tag']?.toString() ??
          memory['destination_name']?.toString() ??
          '',
      'cloudinary_public_id': memory['cloudinary_public_id']?.toString() ?? '',
      'destination_id': (memory['destination_id'] ?? '').toString(),
      'status': memory['status']?.toString() ?? 'active',
    };
  }

  Future<List<Map<String, String>>> fetchTripMembers(String tripId) async {
    final id = _backendTripId(tripId);
    if (id == null) return const [];
    if (token == null) {
      lastError = 'Sign in to load trip data.';
      return const [];
    }

    try {
      lastError = null;
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$id/members'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _membersFromFinalJson(_collaborationListFromBody(response.body));
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchTripMembers(tripId);
      }
      lastError = _errorFromResponse(response, 'Failed to load trip members.');
    } catch (e) {
      lastError = 'Failed to load trip members.';
      if (kDebugMode) print('Error fetching trip members: $e');
    }
    return const [];
  }

  Future<Map<String, String>?> addTripMember(
    String tripId, {
    required String email,
    String role = 'member',
  }) async {
    final id = _backendTripId(tripId);
    if (id == null || token == null) return null;

    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/trips/$id/members'),
            headers: _headers(),
            body: json.encode({
              'email': email,
              'role': _memberRolePayload(role),
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final members = _membersFromFinalJson([data]);
        return members.isNotEmpty ? members.first : null;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return addTripMember(tripId, email: email, role: role);
      }
      lastError = _errorFromResponse(response, 'Failed to invite member.');
    } catch (e) {
      lastError = 'Failed to invite member.';
      if (kDebugMode) print('Error inviting trip member: $e');
    }
    return null;
  }

  Future<Map<String, String>?> updateTripMember(
    String tripId,
    String memberId, {
    required String role,
  }) async {
    final tripBackendId = _backendTripId(tripId);
    final memberBackendId = _backendRecordId(memberId);
    if (tripBackendId == null || memberBackendId == null || token == null) {
      return null;
    }

    try {
      lastError = null;
      final response = await http
          .patch(
            Uri.parse('$baseUrl/trips/$tripBackendId/members/$memberBackendId'),
            headers: _headers(),
            body: json.encode({'role': _memberRolePayload(role)}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final members = _membersFromFinalJson([data]);
        return members.isNotEmpty ? members.first : null;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return updateTripMember(tripId, memberId, role: role);
      }
      lastError = _errorFromResponse(response, 'Failed to update member.');
    } catch (e) {
      lastError = 'Failed to update member.';
      if (kDebugMode) print('Error updating trip member: $e');
    }
    return null;
  }

  Future<bool> removeTripMember(String tripId, String memberId) async {
    final tripBackendId = _backendTripId(tripId);
    final memberBackendId = _backendRecordId(memberId);
    if (tripBackendId == null || memberBackendId == null || token == null) {
      return false;
    }

    try {
      lastError = null;
      final response = await http
          .delete(
            Uri.parse('$baseUrl/trips/$tripBackendId/members/$memberBackendId'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 401 && await refreshSession()) {
        return removeTripMember(tripId, memberId);
      }
      lastError = _errorFromResponse(response, 'Failed to remove member.');
    } catch (e) {
      lastError = 'Failed to remove member.';
      if (kDebugMode) print('Error removing trip member: $e');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchTripTasks(
    String tripId, {
    List<Map<String, String>> members = const [],
  }) async {
    final id = _backendTripId(tripId);
    if (id == null) return const [];
    if (token == null) {
      lastError = 'Sign in to load trip data.';
      return const [];
    }

    try {
      lastError = null;
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$id/tasks'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _tasksFromFinalJson(
          _collaborationListFromBody(response.body),
          members: members,
        );
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchTripTasks(tripId, members: members);
      }
      lastError = _errorFromResponse(response, 'Failed to load trip tasks.');
    } catch (e) {
      lastError = 'Failed to load trip tasks.';
      if (kDebugMode) print('Error fetching trip tasks: $e');
    }
    return const [];
  }

  Future<Map<String, dynamic>?> createTripTask(
    String tripId, {
    required String title,
    String? description,
    String? assignedTripMemberId,
    String status = 'pending',
    List<Map<String, String>> members = const [],
  }) async {
    final id = _backendTripId(tripId);
    if (id == null || token == null) return null;

    try {
      lastError = null;
      final assignedId = _backendRecordId(assignedTripMemberId);
      final response = await http
          .post(
            Uri.parse('$baseUrl/trips/$id/tasks'),
            headers: _headers(),
            body: json.encode({
              'title': title,
              if (description != null && description.isNotEmpty)
                'description': description,
              'assigned_trip_member_id': assignedId,
              'status': status,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _taskFromFinalJson(data, members: members);
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return createTripTask(
          tripId,
          title: title,
          description: description,
          assignedTripMemberId: assignedTripMemberId,
          status: status,
          members: members,
        );
      }
      lastError = _errorFromResponse(response, 'Failed to create task.');
    } catch (e) {
      lastError = 'Failed to create task.';
      if (kDebugMode) print('Error creating trip task: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateTripTask(
    String tripId,
    String taskId, {
    String? title,
    String? description,
    String? assignedTripMemberId,
    String? status,
    List<Map<String, String>> members = const [],
  }) async {
    final tripBackendId = _backendTripId(tripId);
    final taskBackendId = _backendRecordId(taskId);
    if (tripBackendId == null || taskBackendId == null || token == null) {
      return null;
    }

    try {
      lastError = null;
      final response = await http
          .patch(
            Uri.parse('$baseUrl/trips/$tripBackendId/tasks/$taskBackendId'),
            headers: _headers(),
            body: json.encode({
              if (title != null && title.isNotEmpty) 'title': title,
              'description': ?description,
              if (assignedTripMemberId != null)
                'assigned_trip_member_id': _backendRecordId(
                  assignedTripMemberId,
                ),
              'status': ?status,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _taskFromFinalJson(data, members: members);
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return updateTripTask(
          tripId,
          taskId,
          title: title,
          description: description,
          assignedTripMemberId: assignedTripMemberId,
          status: status,
          members: members,
        );
      }
      lastError = _errorFromResponse(response, 'Failed to update task.');
    } catch (e) {
      lastError = 'Failed to update task.';
      if (kDebugMode) print('Error updating trip task: $e');
    }
    return null;
  }

  Future<bool> deleteTripTask(String tripId, String taskId) async {
    final tripBackendId = _backendTripId(tripId);
    final taskBackendId = _backendRecordId(taskId);
    if (tripBackendId == null || taskBackendId == null || token == null) {
      return false;
    }

    try {
      lastError = null;
      final response = await http
          .delete(
            Uri.parse('$baseUrl/trips/$tripBackendId/tasks/$taskBackendId'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 401 && await refreshSession()) {
        return deleteTripTask(tripId, taskId);
      }
      lastError = _errorFromResponse(response, 'Failed to delete task.');
    } catch (e) {
      lastError = 'Failed to delete task.';
      if (kDebugMode) print('Error deleting trip task: $e');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> fetchTripExpenses(String tripId) async {
    final id = _backendTripId(tripId);
    if (id == null) return const [];
    if (token == null) {
      lastError = 'Sign in to load trip data.';
      return const [];
    }

    try {
      lastError = null;
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$id/expenses'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return _collaborationListFromBody(response.body)
            .whereType<Map>()
            .map((item) => _expenseFromFinalJson(item.cast<String, dynamic>()))
            .toList();
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchTripExpenses(tripId);
      }
      lastError = _errorFromResponse(response, 'Failed to load expenses.');
    } catch (e) {
      lastError = 'Failed to load expenses.';
      if (kDebugMode) print('Error fetching trip expenses: $e');
    }
    return const [];
  }

  Future<Map<String, dynamic>?> createTripExpense(
    String tripId, {
    required double amount,
    required String category,
    required String note,
    required String paidByTripMemberId,
  }) async {
    final id = _backendTripId(tripId);
    final payerId = _backendRecordId(paidByTripMemberId);
    if (id == null || payerId == null || token == null) return null;

    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/trips/$id/expenses'),
            headers: _headers(),
            body: json.encode({
              'title': note,
              'description': note,
              'category': _expenseApiCategory(category),
              'amount': amount.toStringAsFixed(2),
              'paid_by_trip_member_id': payerId,
              'notes': note,
              'split_method': 'equal',
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _expenseFromFinalJson(data);
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return createTripExpense(
          tripId,
          amount: amount,
          category: category,
          note: note,
          paidByTripMemberId: paidByTripMemberId,
        );
      }
      lastError = _errorFromResponse(response, 'Failed to add expense.');
    } catch (e) {
      lastError = 'Failed to add expense.';
      if (kDebugMode) print('Error creating trip expense: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> updateTripExpense(
    String tripId,
    String expenseId, {
    required double amount,
    required String category,
    required String note,
    String? paidByTripMemberId,
  }) async {
    final tripBackendId = _backendTripId(tripId);
    final expenseBackendId = _backendRecordId(expenseId);
    if (tripBackendId == null || expenseBackendId == null || token == null) {
      return null;
    }

    try {
      lastError = null;
      final response = await http
          .patch(
            Uri.parse(
              '$baseUrl/trips/$tripBackendId/expenses/$expenseBackendId',
            ),
            headers: _headers(),
            body: json.encode({
              'title': note,
              'description': note,
              'category': _expenseApiCategory(category),
              'amount': amount.toStringAsFixed(2),
              if (_backendRecordId(paidByTripMemberId) != null)
                'paid_by_trip_member_id': _backendRecordId(paidByTripMemberId),
              'notes': note,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _expenseFromFinalJson(data);
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return updateTripExpense(
          tripId,
          expenseId,
          amount: amount,
          category: category,
          note: note,
          paidByTripMemberId: paidByTripMemberId,
        );
      }
      lastError = _errorFromResponse(response, 'Failed to update expense.');
    } catch (e) {
      lastError = 'Failed to update expense.';
      if (kDebugMode) print('Error updating trip expense: $e');
    }
    return null;
  }

  Future<bool> deleteTripExpense(String tripId, String expenseId) async {
    final tripBackendId = _backendTripId(tripId);
    final expenseBackendId = _backendRecordId(expenseId);
    if (tripBackendId == null || expenseBackendId == null || token == null) {
      return false;
    }

    try {
      lastError = null;
      final response = await http
          .delete(
            Uri.parse(
              '$baseUrl/trips/$tripBackendId/expenses/$expenseBackendId',
            ),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 401 && await refreshSession()) {
        return deleteTripExpense(tripId, expenseId);
      }
      lastError = _errorFromResponse(response, 'Failed to delete expense.');
    } catch (e) {
      lastError = 'Failed to delete expense.';
      if (kDebugMode) print('Error deleting trip expense: $e');
    }
    return false;
  }

  Future<List<int>?> downloadTripReportPdf(String tripId) async {
    final id = _backendTripId(tripId);
    if (id == null) {
      lastError = 'Save this trip before exporting its report.';
      return null;
    }
    if (token == null) {
      lastError = 'Sign in to export a trip report.';
      return null;
    }

    try {
      lastError = null;
      final response = await http
          .get(
            Uri.parse('$baseUrl/trips/$id/reports/pdf'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 401 && await refreshSession()) {
        return downloadTripReportPdf(tripId);
      }
      if (response.statusCode != 200) {
        lastError = _errorFromResponse(
          response,
          'Could not generate the PDF report.',
        );
        return null;
      }
      final bytes = response.bodyBytes;
      final isPdf =
          bytes.length >= 5 &&
          bytes[0] == 0x25 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x44 &&
          bytes[3] == 0x46 &&
          bytes[4] == 0x2D;
      if (!isPdf) {
        lastError = 'The server did not return a valid PDF report.';
        return null;
      }
      return bytes;
    } catch (e) {
      lastError = 'Could not download the PDF report.';
      if (kDebugMode) print('Error downloading trip report: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchTripMemories(String tripId) async {
    final id = _backendTripId(tripId);
    if (id == null) return const [];
    if (token == null) {
      lastError = 'Sign in to load trip data.';
      return const [];
    }

    try {
      lastError = null;
      const pageSize = 100;
      final memories = <Map<String, dynamic>>[];
      for (var offset = 0; ; offset += pageSize) {
        final response = await http
            .get(
              Uri.parse(
                '$baseUrl/trips/$id/memories?limit=$pageSize&offset=$offset',
              ),
              headers: _headers(jsonBody: false),
            )
            .timeout(const Duration(seconds: 20));

        if (response.statusCode == 401 && await refreshSession()) {
          return fetchTripMemories(tripId);
        }
        if (response.statusCode != 200) {
          lastError = _errorFromResponse(response, 'Failed to load memories.');
          return const [];
        }
        final page = _collaborationListFromBody(response.body)
            .whereType<Map>()
            .map((item) => _memoryFromFinalJson(item.cast<String, dynamic>()))
            .where((item) => item['image'].toString().isNotEmpty)
            .toList();
        memories.addAll(page);
        if (page.length < pageSize) return memories;
      }
    } catch (e) {
      lastError = 'Failed to load memories.';
      if (kDebugMode) print('Error fetching trip memories: $e');
    }
    return const [];
  }

  Future<Map<String, dynamic>?> uploadTripMemoryImage(
    String tripId,
    String filePath,
  ) async {
    final id = _backendTripId(tripId);
    if (id == null || token == null) return null;

    try {
      lastError = null;
      final imageType = await _memoryImageContentType(filePath);
      if (imageType == null) {
        lastError = 'Only JPEG, PNG, or WebP images are allowed.';
        return null;
      }
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/trips/$id/memories/upload'),
      );
      request.headers.addAll(_headers(jsonBody: false));
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          filePath,
          contentType: imageType,
        ),
      );

      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 60)),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return uploadTripMemoryImage(tripId, filePath);
      }
      lastError = _errorFromResponse(response, 'Failed to upload photo.');
    } catch (e) {
      lastError = 'Failed to upload photo.';
      if (kDebugMode) print('Error uploading trip memory image: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>?> createTripMemory(
    String tripId, {
    required String imageUrl,
    String? cloudinaryPublicId,
    String? caption,
    String? locationTag,
  }) async {
    final id = _backendTripId(tripId);
    if (id == null || token == null) return null;

    try {
      lastError = null;
      final response = await http
          .post(
            Uri.parse('$baseUrl/trips/$id/memories'),
            headers: _headers(),
            body: json.encode({
              'image_url': imageUrl,
              if (cloudinaryPublicId != null && cloudinaryPublicId.isNotEmpty)
                'cloudinary_public_id': cloudinaryPublicId,
              if (caption != null && caption.isNotEmpty) 'caption': caption,
              if (locationTag != null && locationTag.isNotEmpty)
                'location_tag': locationTag,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _memoryFromFinalJson(data);
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return createTripMemory(
          tripId,
          imageUrl: imageUrl,
          cloudinaryPublicId: cloudinaryPublicId,
          caption: caption,
          locationTag: locationTag,
        );
      }
      lastError = _errorFromResponse(response, 'Failed to create memory.');
    } catch (e) {
      lastError = 'Failed to create memory.';
      if (kDebugMode) print('Error creating trip memory: $e');
    }
    return null;
  }

  Future<bool> deleteTripMemory(String tripId, String memoryId) async {
    final tripBackendId = _backendTripId(tripId);
    final memoryBackendId = _backendRecordId(memoryId);
    if (tripBackendId == null || memoryBackendId == null || token == null) {
      return false;
    }

    try {
      lastError = null;
      final response = await http
          .delete(
            Uri.parse(
              '$baseUrl/trips/$tripBackendId/memories/$memoryBackendId',
            ),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 204) return true;
      if (response.statusCode == 401 && await refreshSession()) {
        return deleteTripMemory(tripId, memoryId);
      }
      lastError = _errorFromResponse(response, 'Failed to delete memory.');
    } catch (e) {
      lastError = 'Failed to delete memory.';
      if (kDebugMode) print('Error deleting trip memory: $e');
    }
    return false;
  }

  Future<Trip?> createTrip(Trip newTrip) async {
    if (token == null) {
      lastError = 'Please sign in before saving trips.';
      return null;
    }

    try {
      lastError = null;
      final payload = await _tripCreatePayload(newTrip);

      final response = await http
          .post(
            Uri.parse('$baseUrl/trips'),
            headers: _headers(),
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 201) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _tripFromFinalJson(data);
      }

      if (response.statusCode == 401 && await refreshSession()) {
        return createTrip(newTrip);
      }

      lastError = _errorFromResponse(
        response,
        'Failed to save trip (Status ${response.statusCode})',
      );
      if (kDebugMode) {
        print('Failed to save trip: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      lastError = e is StateError
          ? e.message.toString()
          : e.toString().contains('TimeoutException')
          ? 'Connection timed out. Please check your internet and try again.'
          : 'Failed to save trip. Please try again.';
      if (kDebugMode) {
        print('Error saving trip: $e');
      }
    }

    return null;
  }

  Future<Trip?> updateTripMetadata(Trip trip) async {
    final id = _backendTripId(trip.id);
    if (id == null || token == null) return null;

    try {
      lastError = null;
      final startDate = _isoDateFromRange(trip.dateRange, end: false);
      final endDate = _isoDateFromRange(trip.dateRange, end: true);
      final response = await http
          .patch(
            Uri.parse('$baseUrl/trips/$id'),
            headers: _headers(),
            body: json.encode({
              if (trip.title.trim().length >= 2) 'title': trip.title.trim(),
              'description': trip.destinationName,
              'start_date': ?startDate,
              'end_date': ?endDate,
              'traveler_count': trip.numTravelers < 1 ? 1 : trip.numTravelers,
              'total_budget': trip.budget.toStringAsFixed(2),
              'notes': trip.notes,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return _tripFromFinalJson(data);
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return updateTripMetadata(trip);
      }
      lastError = _errorFromResponse(response, 'Failed to update trip.');
    } catch (e) {
      lastError = 'Failed to update trip.';
      if (kDebugMode) print('Error updating trip metadata: $e');
    }
    return null;
  }

  Future<Map<String, dynamic>> _tripCreatePayload(Trip trip) async {
    final destinations = await fetchDestinations();
    final destinationIds = _destinationIdsForTrip(trip, destinations);
    if (destinationIds.isEmpty) {
      throw StateError('No matching destination found for this trip.');
    }

    return {
      'title': trip.title.isEmpty ? 'Untitled Trip' : trip.title,
      'description': trip.destinationName,
      'start_date': _isoDateFromRange(trip.dateRange, end: false),
      'end_date': _isoDateFromRange(trip.dateRange, end: true),
      'traveler_count': trip.numTravelers < 1 ? 1 : trip.numTravelers,
      'total_budget': trip.budget.toStringAsFixed(2),
      'estimated_total_cost': _estimatedTripCost(trip).toStringAsFixed(2),
      'destination_ids': destinationIds,
      'notes': trip.notes,
      'itinerary_days': trip.itinerary.entries.map((entry) {
        final day = entry.key;
        final activities = entry.value;
        return {
          'day_number': day,
          'title': 'Day $day',
          'summary': activities.map((a) => a.title).take(3).join(', '),
          'activities': activities.asMap().entries.map((activityEntry) {
            final activity = activityEntry.value;
            final matchedId =
                _matchDestinationId(activity, destinations) ??
                destinationIds.first;
            return {
              'activity_order': activityEntry.key + 1,
              'time': activity.time.isEmpty ? null : activity.time,
              'title': activity.title.isEmpty ? 'Activity' : activity.title,
              'description': activity.description,
              'destination_id': matchedId,
              'accommodation_id': null,
              'transportation_id': null,
              'estimated_cost': _parseMoney(activity.cost).toStringAsFixed(2),
              'notes': activity.location,
            };
          }).toList(),
        };
      }).toList(),
    };
  }

  double _estimatedTripCost(Trip trip) {
    double total = 0;
    for (final activities in trip.itinerary.values) {
      for (final activity in activities) {
        total += _parseMoney(activity.cost);
      }
    }
    return total > 0 ? total : trip.budget;
  }

  List<int> _destinationIdsForTrip(Trip trip, List<Destination> destinations) {
    final ids = <int>{};
    for (final activities in trip.itinerary.values) {
      for (final activity in activities) {
        final id = _matchDestinationId(activity, destinations);
        if (id != null) ids.add(id);
      }
    }

    final tripTarget = trip.destinationName.toLowerCase();
    for (final dest in destinations) {
      if (tripTarget.contains(dest.name.toLowerCase()) ||
          tripTarget.contains(dest.district.toLowerCase()) ||
          dest.name.toLowerCase().contains(tripTarget)) {
        ids.add(dest.id);
      }
    }

    return ids.take(25).toList();
  }

  int? _matchDestinationId(
    TripActivity activity,
    List<Destination> destinations,
  ) {
    final haystack =
        '${activity.title} ${activity.description} ${activity.location}'
            .toLowerCase();
    for (final dest in destinations) {
      if (haystack.contains(dest.name.toLowerCase())) return dest.id;
    }
    for (final dest in destinations) {
      if (dest.location.isNotEmpty &&
          haystack.contains(dest.location.toLowerCase())) {
        return dest.id;
      }
    }
    return null;
  }

  Future<Map<String, dynamic>?> optimizeRoute({
    required List<Map<String, dynamic>> destinations,
    double? startLat,
    double? startLng,
    String? startName,
    bool returnToStart = false,
    bool useLiveTraffic = true,
    String travelMode = 'driving',
  }) async {
    try {
      final destinationIds = destinations
          .map((d) => _intValue(d['destination_id'] ?? d['id']))
          .whereType<int>()
          .where((id) => id > 0)
          .toSet()
          .toList();

      if (token != null && destinationIds.isNotEmpty) {
        final response = await http
            .post(
              Uri.parse('$baseUrl/routes/optimize'),
              headers: _headers(),
              body: json.encode({
                'destination_ids': destinationIds,
                'travel_mode': travelMode,
                'origin': startLat != null && startLng != null
                    ? {
                        'label': startName ?? 'Start Point',
                        'lat': startLat,
                        'lng': startLng,
                      }
                    : null,
                'return_to_origin': returnToStart,
                'preserve_first_destination': true,
                'use_live_traffic': useLiveTraffic && travelMode == 'driving',
              }),
            )
            .timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final finalRoute = json.decode(response.body) as Map<String, dynamic>;
          return _legacyRouteFromFinalRoute(finalRoute);
        } else if (response.statusCode == 401 && await refreshSession()) {
          return optimizeRoute(
            destinations: destinations,
            startLat: startLat,
            startLng: startLng,
            startName: startName,
            returnToStart: returnToStart,
            useLiveTraffic: useLiveTraffic,
            travelMode: travelMode,
          );
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error optimizing route from backend: $e');
      }
    }

    return null;
  }

  Map<String, dynamic> _legacyRouteFromFinalRoute(Map<String, dynamic> route) {
    final stops = route['stops'] is List ? route['stops'] as List : const [];
    final encoded = route['polyline']?.toString();
    final coordinates =
        route['polyline_encoding'] == 'polyline5' && encoded != null
        ? decodePolyline5(encoded)
        : <List<double>>[];
    return {
      'optimized_route': stops
          .whereType<Map>()
          .where((item) => item['is_origin'] != true)
          .map(
            (item) => {
              'destination_id': item['destination_id'],
              'id': item['destination_id'],
              'name': item['name'],
              'lat': item['lat'],
              'lng': item['lng'],
              'coordinate_basis': item['coordinate_basis'],
            },
          )
          .toList(),
      'total_distance_km': _doubleValue(route['total_distance_km']),
      'total_duration_minutes': _intValue(route['total_duration_minutes']) ?? 0,
      'legs': route['legs'] ?? const [],
      'stops': stops,
      'route_provider': route['route_provider'],
      'is_estimated': route['is_estimated'] == true,
      'arrival_points_verified': route['arrival_points_verified'] == true,
      'traffic': route['traffic'],
      'warnings': route['warnings'] ?? const [],
      'geometry': coordinates.isEmpty ? null : {'coordinates': coordinates},
    };
  }

  Future<bool> deleteTrip(String tripId) async {
    if (token == null) return false;

    try {
      lastError = null;
      final response = await http
          .delete(
            Uri.parse('$baseUrl/trips/$tripId'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) return true;
      if (response.statusCode == 401 && await refreshSession()) {
        return deleteTrip(tripId);
      }
      lastError = _errorFromResponse(
        response,
        'Failed to delete trip (Status ${response.statusCode})',
      );
    } catch (e) {
      lastError = 'Failed to delete trip. Please try again.';
      if (kDebugMode) {
        print('Error deleting trip: $e');
      }
    }
    return false;
  }

  Future<List<Destination>> fetchNearbyDestinations(
    int destinationId, {
    double radiusKm = 15.0,
    int limit = 5,
    bool sameCategory = false,
  }) async {
    final all = await fetchDestinations();
    if (all.isEmpty) return [];

    final origin = all.firstWhere(
      (d) => d.id == destinationId,
      orElse: () => all.first,
    );

    final candidates = List<Destination>.from(all)
      ..removeWhere((d) => d.id == destinationId);

    double distanceScore(Destination d) {
      final dx = d.longitude - origin.longitude;
      final dy = d.latitude - origin.latitude;
      return dx * dx + dy * dy;
    }

    candidates.sort((a, b) => distanceScore(a).compareTo(distanceScore(b)));

    if (sameCategory) {
      final keywords = origin.category
          .toLowerCase()
          .replaceAll('/', ',')
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      final matched = candidates.where((d) {
        return keywords.any((kw) => d.category.toLowerCase().contains(kw));
      }).toList();
      if (matched.isNotEmpty) return matched.take(limit).toList();
    }

    return candidates.take(limit).toList();
  }

  Future<Map<String, dynamic>?> fetchItineraryFeedback({
    required Trip trip,
  }) async {
    return null;
  }

  Future<List<Map<String, dynamic>>?> fetchNotifications() async {
    if (token == null) return null;

    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/notifications'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final list = _collaborationListFromBody(response.body);
        return list.whereType<Map>().map((item) {
          final raw = item.cast<String, dynamic>();
          final type = _notificationTypeFromEvent(
            raw['event_type']?.toString() ?? raw['type']?.toString() ?? '',
          );
          return {
            'id': (raw['notification_id'] ?? raw['id'] ?? '').toString(),
            'title': raw['title']?.toString() ?? '',
            'body': raw['message']?.toString() ?? raw['body']?.toString() ?? '',
            'time': _relativeTime(raw['created_at']),
            'icon': _iconFromNotificationType(type),
            'isNew': !(raw['is_read'] == true),
            'type': type,
            'tripId': (raw['trip_id'] ?? raw['related_trip_id'])?.toString(),
          };
        }).toList();
      }
      if (response.statusCode == 401 && await refreshSession()) {
        return fetchNotifications();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching notifications: $e');
      }
    }
    return null;
  }

  Future<bool> markNotificationAsRead(String id) async {
    if (token == null) return false;
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/notifications/$id/read'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 && await refreshSession()) {
        return markNotificationAsRead(id);
      }
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error marking notification as read: $e');
      }
      return false;
    }
  }

  Future<bool> markAllNotificationsAsRead() async {
    if (token == null) return false;
    try {
      final response = await http
          .patch(
            Uri.parse('$baseUrl/notifications/read-all'),
            headers: _headers(jsonBody: false),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 401 && await refreshSession()) {
        return markAllNotificationsAsRead();
      }
      return response.statusCode == 200;
    } catch (e) {
      if (kDebugMode) {
        print('Error marking all notifications as read: $e');
      }
      return false;
    }
  }

  Future<List<Destination>> _selectDestinationsForPlan({
    required String destinationName,
    required List<String> interests,
  }) async {
    final all = await fetchDestinations();
    if (all.isEmpty) return [];

    final lowerDestination = destinationName.toLowerCase();
    var selected = all.where((dest) {
      return lowerDestination.contains(dest.name.toLowerCase()) ||
          lowerDestination.contains(dest.district.toLowerCase()) ||
          lowerDestination.contains(dest.location.toLowerCase()) ||
          dest.name.toLowerCase().contains(lowerDestination) ||
          dest.district.toLowerCase().contains(lowerDestination);
    }).toList();

    if (selected.isEmpty && interests.isNotEmpty) {
      final loweredInterests = interests.map((i) => i.toLowerCase()).toList();
      selected = all.where((dest) {
        return loweredInterests.any(
          (interest) =>
              dest.category.toLowerCase().contains(interest) ||
              dest.activities.any(
                (activity) => activity.toLowerCase().contains(interest),
              ),
        );
      }).toList();
    }

    return selected.take(10).toList();
  }

  Map<String, dynamic> _legacyItineraryFromFinalOption(
    Map<String, dynamic> option,
    String destinationName,
    List<Destination> selected,
    double budget,
  ) {
    final byId = {for (final dest in selected) dest.id: dest};
    final itinerary = <String, dynamic>{};
    final days = option['days'];
    if (days is List) {
      for (final dayRaw in days.whereType<Map>()) {
        final day = dayRaw.cast<String, dynamic>();
        final dayNumber = _intValue(day['day']) ?? 1;
        final activities = <Map<String, dynamic>>[];
        final rawActivities = day['activities'];
        if (rawActivities is List) {
          for (final actRaw in rawActivities.whereType<Map>()) {
            final act = actRaw.cast<String, dynamic>();
            final dest = byId[_intValue(act['destination_id'])];
            activities.add({
              'time': act['time']?.toString() ?? '',
              'title': act['title']?.toString() ?? '',
              'description': act['description']?.toString() ?? '',
              'cost': _formatCurrency(_doubleValue(act['estimated_cost'])),
              'location': dest?.name ?? dest?.location ?? '',
            });
          }
        }
        itinerary[dayNumber.toString()] = activities;
      }
    }

    return {
      'title': option['title']?.toString() ?? 'AI Trip to $destinationName',
      'destination': destinationName,
      'num_days': itinerary.length,
      'projected_cost': _doubleValue(option['estimated_total_cost']),
      'budget_status': option['is_over_budget'] == true
          ? 'over_budget'
          : 'within_budget',
      'itinerary': itinerary,
      'explanation': option['summary']?.toString(),
      'budget': budget,
    };
  }
}
