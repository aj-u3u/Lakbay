import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:final_adminlakbay/services/api_service.dart';
import 'package:final_adminlakbay/screens/dashboard_screen.dart';
import 'package:final_adminlakbay/screens/destinations_screen.dart';
import 'package:final_adminlakbay/screens/market_rates_screen.dart';
import 'package:final_adminlakbay/screens/users_screen.dart';

const destination = {
  'destination_id': 1,
  'name': 'Test Garden',
  'district': 'Davao',
  'category': 'Nature',
  'is_active': true,
};

Future<void> mountScreen(WidgetTester tester, Widget screen) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1440, 1000);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(),
      home: Scaffold(body: screen),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'Overview refresh replaces the catalog request without a framework error',
    (tester) async {
      var reads = 0;
      final api = ApiService(
        client: MockClient((_) async {
          reads++;
          return http.Response(jsonEncode([destination]), 200);
        }),
      );
      await mountScreen(tester, DashboardScreen(api: api));
      await tester.tap(find.text('Refresh catalog'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'destination refresh reloads the active list without a framework error',
    (tester) async {
      var reads = 0;
      final api = ApiService(
        client: MockClient((_) async {
          reads++;
          return http.Response(jsonEncode([destination]), 200);
        }),
      );
      await mountScreen(tester, DestinationsScreen(api: api));
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();
      expect(reads, 2);
      expect(find.text('Test Garden'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('own-account Retry recovers from a failed request', (
    tester,
  ) async {
    var reads = 0;
    final api = ApiService(
      tokenProvider: () async => 'test-access',
      client: MockClient((_) async {
        reads++;
        if (reads == 1) return http.Response('{"detail":"Try again"}', 503);
        return http.Response(
          jsonEncode({
            'user_id': 42,
            'full_name': 'Test Admin',
            'email': 'admin@example.test',
            'role': 'admin',
            'is_active': true,
          }),
          200,
        );
      }),
    );
    await mountScreen(tester, UsersScreen(api: api));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(reads, 2);
    expect(find.text('admin@example.test'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rate refresh and post-save refresh show the server result', (
    tester,
  ) async {
    var rateReads = 0;
    var price = '1500.00';
    final api = ApiService(
      tokenProvider: () async => 'test-access',
      client: MockClient((request) async {
        if (request.method == 'PATCH') {
          expect(request.url.path, '/api/v1/accommodations/10');
          final payload = jsonDecode(request.body) as Map;
          expect(payload['currency'], 'PHP');
          expect(payload['charging_unit'], 'per_room_per_night');
          price = payload['price'].toString();
          return http.Response('{"accommodation_id":10}', 200);
        }
        if (request.url.path.endsWith('/accommodations')) {
          rateReads++;
          return http.Response(
            jsonEncode([
              {
                'accommodation_id': 10,
                'destination_id': 1,
                'name': 'Test Room',
                'room_type': 'Double',
                'price': price,
                'currency': 'PHP',
                'charging_unit': 'per_room_per_night',
                'capacity': 2,
                'description': 'PHP per room/night',
                'is_available': true,
              },
            ]),
            200,
          );
        }
        return http.Response(jsonEncode([destination]), 200);
      }),
    );
    await mountScreen(tester, MarketRatesScreen(api: api, destinationId: '1'));
    await tester.tap(find.text('Refresh rates'));
    await tester.pumpAndSettle();
    expect(rateReads, 2);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final priceField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Price *',
    );
    await tester.enterText(priceField, '1600.50');
    await tester.tap(find.text('Save rate'));
    await tester.pumpAndSettle();
    expect(rateReads, 3);
    expect(find.text('₱1600.50 / room / night'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
