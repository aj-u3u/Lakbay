import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/services/api_service.dart';

void main() {
  late HttpServer server;
  late String originalBaseUrl;
  var unavailable = false;
  var price = '250.00';
  var failCatalog = false;

  setUp(() async {
    unavailable = false;
    price = '250.00';
    failCatalog = false;
    originalBaseUrl = ApiService.baseUrl;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    ApiService.baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
    server.listen((request) async {
      final path = request.uri.path;
      Object body;
      var status = 200;
      if (path == '/api/v1/destinations') {
        if (failCatalog) {
          status = 503;
          body = {'error': 'offline'};
        } else {
          final offset = int.parse(
            request.uri.queryParameters['offset'] ?? '0',
          );
          final limit = int.parse(
            request.uri.queryParameters['limit'] ?? '100',
          );
          body = List.generate(
            101,
            (index) => {
              'destination_id': index + 1,
              'name': 'Place ${index + 1}',
              'description': 'Davao catalog place',
              'district': 'Davao City',
              'lat': 7.0,
              'lng': 125.0,
              'image_url': 'https://example.com/place.jpg',
              'entrance_fee': 'PHP 50',
              'overnight_fee': 'PHP 800',
              'estimated_cost': index == 0
                  ? null
                  : index == 1
                  ? '0.00'
                  : '250.00',
              if (index == 0) 'cost': '0.00',
              'is_active': true,
            },
          ).skip(offset).take(limit).toList();
        }
      } else if (path == '/api/v1/destinations/1/accommodations') {
        body = [
          {
            'accommodation_id': 42,
            'destination_id': 1,
            'name': 'City Stay',
            'room_type': 'Standard',
            'price': price,
            'currency': 'PHP',
            'charging_unit': 'per_room_per_night',
            'is_available': !unavailable,
          },
        ];
      } else if (path == '/api/v1/destinations/1/transportations') {
        body = [
          {
            'transportation_id': 77,
            'destination_id': 1,
            'vehicle_type': 'Van',
            'transport_mode': 'public_transport',
            'route_from': 'Davao City',
            'route_to': 'City Stay',
            'price': price,
            'currency': 'PHP',
            'charging_unit': 'per_person',
            'is_available': !unavailable,
          },
        ];
      } else {
        status = 404;
        body = {'error': 'missing'};
      }
      request.response
        ..statusCode = status
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(body));
      await request.response.close();
    });
  });

  tearDown(() async {
    ApiService.baseUrl = originalBaseUrl;
    await server.close(force: true);
  });

  test(
    'loads every destination page and maps backend fields and IDs',
    () async {
      final destinations = await ApiService().fetchDestinations();
      expect(destinations.length, 101);
      expect(destinations.first.id, 1);
      expect(destinations.last.id, 101);
      expect(destinations.first.imageUrl, 'https://example.com/place.jpg');
      expect(destinations.first.entranceFee, 'PHP 50');
      expect(destinations.first.overnightFee, 'PHP 800');
      expect(destinations.first.estimatedCost, isNull);
      expect(destinations[1].estimatedCost, 0);
      expect(destinations.first.extra.accommodationTypes, isEmpty);
    },
  );

  test('unknown cost is excluded from budget matches and averages', () async {
    final api = ApiService();
    final matches = await api.fetchRecommendedDestinations(budget: 0);
    expect(matches.map((destination) => destination.id), [2]);

    final groups = await api.fetchGroupedDestinations();
    expect(groups.single.averageCost, closeTo(247.5, 0.01));
  });

  test(
    'rate refresh keeps the same IDs after edit and hides deactivation',
    () async {
      final api = ApiService();
      final stay = await api.fetchAccommodationRates(1);
      final ride = await api.fetchTransportationRates(1);
      expect(stay.single.id, 42);
      expect(ride.single.id, 77);
      expect(stay.single.priceLabel, '₱250.00');
      expect(ride.single.chargingUnit, 'per_person');

      price = '300.00';
      expect((await api.fetchAccommodationRates(1)).single.id, 42);
      expect((await api.fetchAccommodationRates(1)).single.price, 300);
      expect((await api.fetchTransportationRates(1)).single.id, 77);
      unavailable = true;
      expect(await api.fetchAccommodationRates(1), isEmpty);
      expect(await api.fetchTransportationRates(1), isEmpty);
    },
  );

  test(
    'catalog failure is explicit and never returns preview records',
    () async {
      failCatalog = true;
      await expectLater(
        ApiService().fetchDestinations(),
        throwsA(isA<CatalogException>()),
      );
    },
  );
}
