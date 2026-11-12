import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:final_adminlakbay/services/api_service.dart';
import 'package:final_adminlakbay/services/session_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('candidate review calls use the protected admin endpoints', () async {
    final requests = <http.Request>[];
    final api = ApiService(
      tokenProvider: () async => 'admin-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            '[{"candidate_id":7,"review_status":"staged"}]',
            200,
          );
        }
        return http.Response(
          '{"candidate_id":7,"review_status":"staged"}',
          200,
        );
      }),
    );
    addTearDown(api.close);

    final candidates = await api.getDestinationCandidates(
      limit: 50,
      offset: 50,
    );
    expect(candidates.single['candidate_id'], 7);
    await api.updateDestinationCandidate(7, {'category': 'garden'});
    await api.rejectDestinationCandidate(7, 'Not open to visitors');
    await api.publishDestinationCandidate(7);

    expect(requests.map((request) => request.method), [
      'GET',
      'PATCH',
      'POST',
      'POST',
    ]);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/admin/destination-candidates',
      '/api/v1/admin/destination-candidates/7',
      '/api/v1/admin/destination-candidates/7/reject',
      '/api/v1/admin/destination-candidates/7/publish',
    ]);
    expect(requests.first.url.queryParameters, {
      'review_status': 'staged',
      'limit': '50',
      'offset': '50',
    });
    expect(
      requests.every(
        (request) => request.headers['Authorization'] == 'Bearer admin-token',
      ),
      isTrue,
    );
    expect(jsonDecode(requests[1].body), {'category': 'garden'});
    expect(jsonDecode(requests[2].body), {'reason': 'Not open to visitors'});
  });

  test('expired access token rotates the session and retries once', () async {
    final session = SessionManager.instance;
    await session.saveSession(
      token: 'expired',
      refreshToken: 'old-refresh',
      name: 'Administrator',
      email: 'admin@example.test',
      role: 'admin',
      userId: '42',
    );
    final paths = <String>[];
    final api = ApiService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(jsonDecode(request.body), {'refresh_token': 'old-refresh'});
          return http.Response(
            jsonEncode({
              'user': {
                'user_id': 42,
                'full_name': 'Administrator',
                'email': 'admin@example.test',
                'role': 'admin',
              },
              'tokens': {
                'access_token': 'rotated',
                'refresh_token': 'new-refresh',
              },
            }),
            200,
          );
        }
        if (request.headers['Authorization'] == 'Bearer expired') {
          return http.Response('{"detail":"Expired token"}', 401);
        }
        expect(request.headers['Authorization'], 'Bearer rotated');
        return http.Response('{"user_id":42}', 200);
      }),
    );
    addTearDown(api.close);
    expect((await api.getCurrentUser())['user_id'], 42);
    expect(paths, [
      '/api/v1/users/me',
      '/api/v1/auth/refresh',
      '/api/v1/users/me',
    ]);
    expect(await session.getRefreshToken(), 'new-refresh');
  });

  test('late refresh cannot restore a signed-out session', () async {
    final session = SessionManager.instance;
    await session.saveSession(
      token: 'expired',
      refreshToken: 'old-refresh',
      name: 'Administrator',
      email: 'admin@example.test',
      role: 'admin',
      userId: '42',
    );
    final refreshStarted = Completer<void>();
    final response = Completer<http.Response>();
    final api = ApiService(
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/refresh')) {
          refreshStarted.complete();
          return response.future;
        }
        return http.Response('{"detail":"Expired token"}', 401);
      }),
    );
    addTearDown(api.close);
    final pending = expectLater(
      api.getCurrentUser(),
      throwsA(isA<ApiException>()),
    );
    await refreshStarted.future;
    await session.clearSession();
    response.complete(
      http.Response(
        jsonEncode({
          'user': {
            'user_id': 42,
            'full_name': 'Administrator',
            'email': 'admin@example.test',
            'role': 'admin',
          },
          'tokens': {'access_token': 'rotated', 'refresh_token': 'new-refresh'},
        }),
        200,
      ),
    );
    await pending;
    expect(await session.getToken(), isNull);
    expect(await session.isLoggedIn(), isFalse);
  });
  test(
    'login reads the final nested session response without an old token',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/auth/login');
          expect(request.headers.containsKey('Authorization'), isFalse);
          expect(jsonDecode(request.body), {
            'email': 'admin@example.test',
            'password': 'example-password',
          });
          return http.Response(
            jsonEncode({
              'user': {
                'user_id': 42,
                'full_name': 'Test Administrator',
                'email': 'admin@example.test',
                'role': 'admin',
              },
              'tokens': {
                'access_token': 'test-access',
                'refresh_token': 'test-refresh',
              },
            }),
            200,
          );
        }),
        tokenProvider: () async => 'old-token',
      );
      addTearDown(api.close);
      final session = await api.login('admin@example.test', 'example-password');
      expect(session['role'], 'admin');
      expect(session['name'], 'Test Administrator');
      expect(session['access_token'], 'test-access');
      expect(session['refresh_token'], 'test-refresh');
    },
  );

  test(
    'destination inventory traverses API pagination beyond the first 100',
    () async {
      final offsets = <String>[];
      final api = ApiService(
        client: MockClient((request) async {
          offsets.add(request.url.queryParameters['offset']!);
          expect(request.url.queryParameters['limit'], '100');
          final offset = int.parse(offsets.last);
          return http.Response(
            jsonEncode(
              List.generate(
                offset == 0 ? 100 : 3,
                (index) => {'destination_id': offset + index + 1},
              ),
            ),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final places = await api.getDestinations();
      expect(places, hasLength(103));
      expect(offsets, ['0', '100']);
      expect(places.last['destination_id'], 103);
    },
  );

  test(
    'destination updates use PATCH with the administrator bearer token',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.path, '/api/v1/destinations/12');
          expect(request.headers['Authorization'], 'Bearer test-access');
          expect(jsonDecode(request.body), {
            'name': 'Updated place',
            'activities': 'Hiking',
          });
          return http.Response(
            '{"destination_id":12,"name":"Updated place"}',
            200,
          );
        }),
        tokenProvider: () async => 'test-access',
      );
      addTearDown(api.close);
      expect(
        (await api.updateDestination('12', {
          'name': 'Updated place',
          'activities': 'Hiking',
        }))['destination_id'],
        12,
      );
    },
  );

  test(
    'accommodation create scopes destination in URL and preserves decimal values',
    () async {
      final api = ApiService(
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/destinations/8/accommodations');
          expect(request.method, 'POST');
          final data = jsonDecode(request.body) as Map;
          expect(data.containsKey('destination_id'), isFalse);
          expect(data['price'], '1234.50');
          return http.Response('{"accommodation_id":9}', 201);
        }),
        tokenProvider: () async => 'test-access',
      );
      addTearDown(api.close);
      final input = {
        'destination_id': 8,
        'name': 'Room',
        'room_type': 'Double',
        'price': '1234.50',
      };
      await api.createAccommodationRate(input);
      expect(
        input['destination_id'],
        8,
        reason: 'The caller payload must not be mutated.',
      );
    },
  );

  test(
    'rates require an explicit destination rather than unsupported global reads',
    () async {
      var calls = 0;
      final api = ApiService(
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );
      addTearDown(api.close);
      await expectLater(api.getTransportRates(), throwsA(isA<ApiException>()));
      expect(calls, 0);
    },
  );

  test('admin rate create, edit and deactivation keep one record ID', () async {
    Map<String, dynamic>? record;
    final api = ApiService(
      tokenProvider: () async => 'admin-token',
      client: MockClient((request) async {
        if (request.method != 'GET') {
          expect(request.headers['Authorization'], 'Bearer admin-token');
        }
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v1/destinations/8/transportations');
          final payload = jsonDecode(request.body) as Map<String, dynamic>;
          expect(payload['currency'], 'PHP');
          expect(payload['charging_unit'], 'per_vehicle');
          record = {
            ...payload,
            'transportation_id': 77,
            'destination_id': 8,
            'is_available': true,
          };
          return http.Response(jsonEncode(record), 201);
        }
        if (request.method == 'PATCH') {
          expect(request.url.path, '/api/v1/transportations/77');
          record = {
            ...record!,
            ...(jsonDecode(request.body) as Map<String, dynamic>),
          };
          return http.Response(jsonEncode(record), 200);
        }
        if (request.method == 'DELETE') {
          expect(request.url.path, '/api/v1/transportations/77');
          record = {...record!, 'is_available': false};
          return http.Response(jsonEncode(record), 200);
        }
        expect(request.url.path, '/api/v1/destinations/8/transportations');
        return http.Response(
          jsonEncode(record?['is_available'] == true ? [record] : []),
          200,
        );
      }),
    );
    addTearDown(api.close);
    final created = await api.createTransportRate({
      'destination_id': 8,
      'vehicle_type': 'Van',
      'transport_mode': 'public_transport',
      'route_from': 'Davao',
      'route_to': 'Samal',
      'price': '500.00',
      'currency': 'PHP',
      'charging_unit': 'per_vehicle',
    });
    expect(created['transportation_id'], 77);
    expect(
      (await api.getTransportRates(
        destinationId: '8',
      )).single['transportation_id'],
      77,
    );
    final edited = await api.updateTransportRate('77', {'price': '550.00'});
    expect(edited['transportation_id'], 77);
    expect(
      (await api.getTransportRates(destinationId: '8')).single['price'],
      '550.00',
    );
    expect(await api.deleteTransportRate('77'), isTrue);
    expect(await api.getTransportRates(destinationId: '8'), isEmpty);
  });

  test(
    'permission errors preserve status and never become an empty list',
    () async {
      final api = ApiService(
        client: MockClient(
          (_) async => http.Response('{"detail":"Permission denied"}', 403),
        ),
        tokenProvider: () async => 'test-access',
      );
      addTearDown(api.close);
      await expectLater(
        api.updateDestination('8', {'name': 'Place'}),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'status', 403)
              .having((error) => error.message, 'message', 'Permission denied'),
        ),
      );
    },
  );

  test(
    'network failure is reported instead of substituting traveler sample data',
    () async {
      final api = ApiService(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      addTearDown(api.close);
      await expectLater(api.getDestinations(), throwsA(isA<ApiException>()));
    },
  );
}
