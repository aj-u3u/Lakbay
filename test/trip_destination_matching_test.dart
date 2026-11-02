import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/trip.dart';
import 'package:lakbay_plus/services/api_service.dart';

void main() {
  late HttpServer server;
  late String originalBaseUrl;
  late ApiService api;
  final postedTrips = <Map<String, dynamic>>[];

  setUp(() async {
    postedTrips.clear();
    originalBaseUrl = ApiService.baseUrl;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiService.baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
    api = ApiService.testing()..setToken('test-token');
    server.listen((request) async {
      if (request.uri.path == '/api/v1/destinations') {
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(
            jsonEncode([
              {
                'destination_id': 12,
                'name': 'Tudaya Falls',
                'district': 'Davao del Sur',
                'description': 'Waterfall',
                'lat': 6.98,
                'lng': 125.39,
                'is_active': true,
              },
              {
                'destination_id': 13,
                'name': 'Aliwagwag Falls',
                'district': 'Davao Oriental',
                'description': 'Waterfall',
                'lat': 7.73,
                'lng': 126.38,
                'is_active': true,
              },
            ]),
          );
      } else if (request.uri.path == '/api/v1/trips') {
        postedTrips.add(
          jsonDecode(await utf8.decoder.bind(request).join())
              as Map<String, dynamic>,
        );
        request.response
          ..statusCode = 422
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'test response'}));
      } else {
        request.response.statusCode = 404;
      }
      await request.response.close();
    });
  });

  tearDown(() async {
    ApiService.baseUrl = originalBaseUrl;
    await server.close(force: true);
  });

  Trip tripTo(String destination) => Trip(
    id: 'draft',
    title: 'Demo trip',
    destinationName: destination,
    dateRange: 'Flexible Dates',
    budget: 5000,
    imageUrl: '',
    itinerary: const {},
  );

  test(
    'unknown destination does not silently save the first catalog place',
    () async {
      expect(await api.createTrip(tripTo('daval del sur')), isNull);
      expect(api.lastError, 'No matching destination found for this trip.');
      expect(postedTrips, isEmpty);
    },
  );

  test('matching destination sends its catalog ID', () async {
    await api.createTrip(tripTo('Tudaya Falls'));
    expect(postedTrips, hasLength(1));
    expect(postedTrips.single['destination_ids'], [12]);
  });
}
