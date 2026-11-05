import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'session_manager.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

/// Client for the final, versioned Lakbay API. No sample data is substituted.
class ApiService {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://lakbay-backend-final.onrender.com/api/v1',
  );
  final http.Client _client;
  final Future<String?> Function() _tokenProvider;
  final String _base;
  static Future<bool>? _refreshing;

  ApiService({
    http.Client? client,
    Future<String?> Function()? tokenProvider,
    String? apiBaseUrl,
  }) : _client = client ?? http.Client(),
       _tokenProvider = tokenProvider ?? SessionManager.instance.getToken,
       _base = (apiBaseUrl ?? baseUrl).replaceFirst(RegExp(r'/+$'), '');

  Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? data,
    bool authenticated = true,
    bool retryOnUnauthorized = true,
  }) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (data != null) headers['Content-Type'] = 'application/json';
    if (authenticated) {
      final token = await _tokenProvider();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    final uri = Uri.parse('$_base$path');
    try {
      final body = data == null ? null : jsonEncode(data);
      final request = switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(uri, headers: headers, body: body),
        'PATCH' => _client.patch(uri, headers: headers, body: body),
        'DELETE' => _client.delete(uri, headers: headers),
        _ => throw ArgumentError('Unsupported request method'),
      };
      final response = await request.timeout(const Duration(seconds: 20));
      if (response.statusCode == 401 && authenticated && retryOnUnauthorized) {
        final refreshed = await _refreshAccess();
        if (refreshed) {
          return _request(
            method,
            path,
            data: data,
            authenticated: true,
            retryOnUnauthorized: false,
          );
        }
      }
      dynamic decoded;
      if (response.body.isNotEmpty) {
        try {
          decoded = jsonDecode(response.body);
        } on FormatException {
          if (response.statusCode >= 200 && response.statusCode < 300) {
            throw const ApiException(
              'The server returned an unreadable response. Please try again.',
            );
          }
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final defaultMessage = switch (response.statusCode) {
          401 => 'Your session has expired. Please sign in again.',
          403 => 'Your account does not have permission for this action.',
          404 => 'This record is no longer available.',
          _ => 'The request could not be completed. Please try again.',
        };
        String message = defaultMessage;
        if (decoded is Map) {
          final detail =
              decoded['detail'] ??
              decoded['message'] ??
              (decoded['error'] is Map ? decoded['error']['message'] : null);
          if (detail is String && detail.isNotEmpty) message = detail;
          if (detail is List) {
            message = detail
                .map((item) {
                  if (item is! Map) return 'Check the entered values.';
                  final loc = item['loc'];
                  final field = loc is List
                      ? loc.where((part) => part != 'body').join(' / ')
                      : '';
                  return '${field.isEmpty ? 'Value' : field}: ${item['msg'] ?? 'Invalid value'}';
                })
                .join('\n');
          }
        }
        throw ApiException(message, statusCode: response.statusCode);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        'The server took too long to respond. Please try again.',
      );
    } on http.ClientException {
      throw const ApiException(
        'Unable to reach Lakbay. Check the connection and try again.',
      );
    }
  }

  Map<String, dynamic> _object(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    throw const ApiException('The server returned an unexpected record.');
  }

  List<dynamic> _list(dynamic value) {
    if (value is List) return value;
    throw const ApiException('The server returned an unexpected list.');
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = _object(
      await _request(
        'POST',
        '/auth/login',
        authenticated: false,
        data: {'email': email, 'password': password},
      ),
    );
    return _sessionResponse(response);
  }

  Map<String, dynamic> _sessionResponse(Map<String, dynamic> response) {
    final user = _object(response['user']);
    final tokens = _object(response['tokens']);
    if ((tokens['access_token'] ?? '').toString().isEmpty) {
      throw const ApiException('Sign-in did not return a valid session.');
    }
    return {...user, ...tokens, 'name': user['full_name']};
  }

  Future<bool> _refreshAccess() async {
    final existing = _refreshing;
    if (existing != null) return existing;
    final pending = _rotateSession();
    _refreshing = pending;
    try {
      return await pending;
    } finally {
      if (identical(_refreshing, pending)) _refreshing = null;
    }
  }

  Future<bool> _rotateSession() async {
    final session = SessionManager.instance;
    final refreshToken = await session.getRefreshToken();
    if (refreshToken == null || refreshToken.isEmpty) return false;
    try {
      final result = _sessionResponse(
        _object(
          await _request(
            'POST',
            '/auth/refresh',
            authenticated: false,
            retryOnUnauthorized: false,
            data: {'refresh_token': refreshToken},
          ),
        ),
      );
      if (result['role'] != 'admin') return false;
      return await session.saveRefreshedSession(
        expectedRefreshToken: refreshToken,
        token: result['access_token'].toString(),
        refreshToken: result['refresh_token']?.toString(),
        name: (result['full_name'] ?? '').toString(),
        email: result['email'].toString(),
        role: result['role'].toString(),
        userId: result['user_id'].toString(),
      );
    } on ApiException {
      return false;
    }
  }

  Future<void> logout() async {
    final refreshToken = await SessionManager.instance.getRefreshToken();
    try {
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await _request(
          'POST',
          '/auth/logout',
          data: {'refresh_token': refreshToken},
          retryOnUnauthorized: false,
        );
      }
    } finally {
      await SessionManager.instance.clearSession();
    }
  }

  Future<Map<String, dynamic>> getCurrentUser() async =>
      _object(await _request('GET', '/users/me'));
  Future<Map<String, dynamic>> updateOwnProfile(
    Map<String, dynamic> data,
  ) async => _object(await _request('PATCH', '/users/me', data: data));

  Future<List<dynamic>> getDestinations() async {
    final records = <dynamic>[];
    var offset = 0;
    while (true) {
      final page = _list(
        await _request(
          'GET',
          '/destinations?limit=100&offset=$offset',
          authenticated: false,
        ),
      );
      records.addAll(page);
      if (page.length < 100) return records;
      offset += page.length;
    }
  }

  Future<List<dynamic>> getDestinationCandidates({
    String reviewStatus = 'staged',
    int limit = 50,
    int offset = 0,
  }) async => _list(
    await _request(
      'GET',
      '/admin/destination-candidates?review_status=${Uri.encodeQueryComponent(reviewStatus)}&limit=$limit&offset=$offset',
    ),
  );

  Future<Map<String, dynamic>> updateDestinationCandidate(
    int id,
    Map<String, dynamic> data,
  ) async => _object(
    await _request('PATCH', '/admin/destination-candidates/$id', data: data),
  );

  Future<Map<String, dynamic>> rejectDestinationCandidate(
    int id,
    String reason,
  ) async => _object(
    await _request(
      'POST',
      '/admin/destination-candidates/$id/reject',
      data: {'reason': reason},
    ),
  );

  Future<Map<String, dynamic>> publishDestinationCandidate(int id) async =>
      _object(
        await _request('POST', '/admin/destination-candidates/$id/publish'),
      );

  Future<Map<String, dynamic>> createDestination(
    Map<String, dynamic> data,
  ) async => _object(await _request('POST', '/destinations', data: data));
  Future<Map<String, dynamic>> updateDestination(
    String id,
    Map<String, dynamic> data,
  ) async => _object(
    await _request(
      'PATCH',
      '/destinations/${Uri.encodeComponent(id)}',
      data: data,
    ),
  );
  Future<bool> deleteDestination(String id) async {
    await _request('DELETE', '/destinations/${Uri.encodeComponent(id)}');
    return true;
  }

  Future<List<dynamic>> _rates(String type, String? destinationId) async {
    if (destinationId == null || destinationId.isEmpty) {
      throw const ApiException('Choose a destination to view its rates.');
    }
    return _list(
      await _request(
        'GET',
        '/destinations/${Uri.encodeComponent(destinationId)}/$type',
        authenticated: false,
      ),
    );
  }

  Future<List<dynamic>> getAccommodationRates({String? destinationId}) =>
      _rates('accommodations', destinationId);
  Future<List<dynamic>> getTransportRates({String? destinationId}) =>
      _rates('transportations', destinationId);
  Future<Map<String, dynamic>> _createRate(
    String type,
    Map<String, dynamic> data,
  ) async {
    final payload = Map<String, dynamic>.from(data);
    final destinationId = payload.remove('destination_id')?.toString();
    if (destinationId == null || destinationId.isEmpty) {
      throw const ApiException('Choose a destination for this rate.');
    }
    return _object(
      await _request(
        'POST',
        '/destinations/${Uri.encodeComponent(destinationId)}/$type',
        data: payload,
      ),
    );
  }

  Map<String, dynamic> _rateUpdate(Map<String, dynamic> data) =>
      Map<String, dynamic>.from(data)..remove('destination_id');
  Future<Map<String, dynamic>> createAccommodationRate(
    Map<String, dynamic> data,
  ) => _createRate('accommodations', data);
  Future<Map<String, dynamic>> createTransportRate(Map<String, dynamic> data) =>
      _createRate('transportations', data);
  Future<Map<String, dynamic>> updateAccommodationRate(
    String id,
    Map<String, dynamic> data,
  ) async => _object(
    await _request(
      'PATCH',
      '/accommodations/${Uri.encodeComponent(id)}',
      data: _rateUpdate(data),
    ),
  );
  Future<Map<String, dynamic>> updateTransportRate(
    String id,
    Map<String, dynamic> data,
  ) async => _object(
    await _request(
      'PATCH',
      '/transportations/${Uri.encodeComponent(id)}',
      data: _rateUpdate(data),
    ),
  );
  Future<bool> deleteAccommodationRate(String id) async {
    await _request('DELETE', '/accommodations/${Uri.encodeComponent(id)}');
    return true;
  }

  Future<bool> deleteTransportRate(String id) async {
    await _request('DELETE', '/transportations/${Uri.encodeComponent(id)}');
    return true;
  }

  void close() => _client.close();
}
