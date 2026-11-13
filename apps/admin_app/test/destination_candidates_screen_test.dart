import 'dart:convert';

import 'package:final_adminlakbay/screens/destination_candidates_screen.dart';
import 'package:final_adminlakbay/services/api_service.dart';
import 'package:final_adminlakbay/widgets/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> _place(int id, String name) => {
  'candidate_id': id,
  'osm_type': 'node',
  'osm_id': 1000 + id,
  'osm_url': 'https://www.openstreetmap.org/node/${1000 + id}',
  'source_area': 'Davao City',
  'source_tag': 'waterway=waterfall',
  'suggested_category': 'waterfall',
  'name': name,
  'lat': 7.1,
  'lng': 125.6,
  'review_status': 'staged',
};

/// Answers list requests the way the server does: filters by `q` when present.
ApiService _searchableApi(
  List<http.Request> requests,
  List<Map<String, dynamic>> all,
) {
  return ApiService(
    tokenProvider: () async => 'admin-token',
    client: MockClient((request) async {
      requests.add(request);
      final q = request.url.queryParameters['q']?.toLowerCase();
      final rows = q == null
          ? all
          : all
                .where((p) => p['name'].toString().toLowerCase().contains(q))
                .toList();
      return http.Response(jsonEncode(rows), 200);
    }),
  );
}

Future<void> _open(WidgetTester tester, ApiService api) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(home: Scaffold(body: DestinationCandidatesScreen(api: api))),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('candidate stays staged until admin publishes it', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final candidate = <String, dynamic>{
      'candidate_id': 7,
      'osm_type': 'node',
      'osm_id': 123,
      'osm_url': 'https://www.openstreetmap.org/node/123',
      'source_area': 'Davao City',
      'source_tag': 'leisure=garden',
      'suggested_category': 'garden',
      'name': 'Test Garden',
      'lat': 7.1,
      'lng': 125.6,
      'review_status': 'staged',
    };
    final api = ApiService(
      tokenProvider: () async => 'admin-token',
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(jsonEncode([candidate]), 200);
        }
        return http.Response(jsonEncode(candidate), 200);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: DestinationCandidatesScreen(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Test Garden'), findsOneWidget);
    expect(requests, hasLength(1));
    expect(requests.single.url.path, '/api/v1/admin/destination-candidates');

    await tester.tap(find.text('Test Garden'));
    await tester.pumpAndSettle();
    expect(find.text('OSM source: node 123'), findsOneWidget);
    expect(find.text('Publish destination'), findsOneWidget);
    expect(requests, hasLength(1));

    await tester.ensureVisible(find.text('Save review'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save review'));
    await tester.pumpAndSettle();
    expect(
      requests.where((request) => request.method == 'PATCH'),
      hasLength(1),
    );
    expect(
      requests.where((request) => request.url.path.endsWith('/publish')),
      isEmpty,
    );
    expect(adminHasUnsavedChanges.value, isFalse);
  });

  group('search', () {
    final all = [
      _place(1, 'Baradi Falls'),
      _place(2, 'Bayna Falls'),
      _place(3, 'Amador Inland Resort'),
    ];

    testWidgets(
      'typing searches the whole queue on the server after a short pause',
      (tester) async {
        final requests = <http.Request>[];
        final api = _searchableApi(requests, all);
        addTearDown(api.close);
        await _open(tester, api);
        expect(requests.single.url.queryParameters.containsKey('q'), isFalse);
        expect(find.text('Amador Inland Resort'), findsOneWidget);

        await tester.enterText(
          find.byKey(const Key('candidate-search')),
          'falls',
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(requests, hasLength(1), reason: 'waits for a pause in typing');
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pumpAndSettle();

        expect(requests, hasLength(2));
        expect(requests.last.url.queryParameters['q'], 'falls');
        expect(requests.last.url.queryParameters['offset'], '0');
        expect(requests.last.url.queryParameters['review_status'], 'staged');
        expect(find.text('Baradi Falls'), findsOneWidget);
        expect(find.text('Amador Inland Resort'), findsNothing);
      },
    );

    testWidgets('several keystrokes send one request', (tester) async {
      final requests = <http.Request>[];
      final api = _searchableApi(requests, all);
      addTearDown(api.close);
      await _open(tester, api);

      final field = find.byKey(const Key('candidate-search'));
      for (final text in ['b', 'ba', 'bar', 'bara']) {
        await tester.enterText(field, text);
        await tester.pump(const Duration(milliseconds: 150));
      }
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(requests, hasLength(2));
      expect(requests.last.url.queryParameters['q'], 'bara');
    });

    testWidgets(
      'pressing Enter searches immediately and encodes special characters',
      (tester) async {
        final requests = <http.Request>[];
        final api = _searchableApi(requests, all);
        addTearDown(api.close);
        await _open(tester, api);

        await tester.enterText(
          find.byKey(const Key('candidate-search')),
          'a&b %',
        );
        await tester.testTextInput.receiveAction(TextInputAction.search);
        await tester.pumpAndSettle();

        expect(requests, hasLength(2));
        expect(requests.last.url.queryParameters['q'], 'a&b %');
      },
    );

    testWidgets('no match says so, and clearing restores the full list', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final api = _searchableApi(requests, all);
      addTearDown(api.close);
      await _open(tester, api);

      await tester.enterText(find.byKey(const Key('candidate-search')), 'zzz');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.text('No places match "zzz" in this list.'), findsOneWidget);

      await tester.tap(find.byKey(const Key('candidate-search-clear')));
      await tester.pumpAndSettle();

      expect(requests.last.url.queryParameters.containsKey('q'), isFalse);
      expect(find.text('Amador Inland Resort'), findsOneWidget);
      expect(find.byKey(const Key('candidate-search-clear')), findsNothing);
    });

    testWidgets('a new search starts from the first page', (tester) async {
      final requests = <http.Request>[];
      final fullPage = [for (var i = 1; i <= 50; i++) _place(i, 'Place $i')];
      final api = ApiService(
        tokenProvider: () async => 'admin-token',
        client: MockClient((request) async {
          requests.add(request);
          final q = request.url.queryParameters['q'];
          return http.Response(
            jsonEncode(q == null ? fullPage : [_place(99, 'Match $q')]),
            200,
          );
        }),
      );
      addTearDown(api.close);
      await _open(tester, api);

      await tester.ensureVisible(find.text('Next'));
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['offset'], '50');

      await tester.enterText(find.byKey(const Key('candidate-search')), 'x');
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(requests.last.url.queryParameters['q'], 'x');
      expect(requests.last.url.queryParameters['offset'], '0');
      expect(find.text('Page 1'), findsOneWidget);
    });

    testWidgets('the search survives changing the status and opening a place', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final api = _searchableApi(requests, all);
      addTearDown(api.close);
      await _open(tester, api);

      await tester.enterText(
        find.byKey(const Key('candidate-search')),
        'falls',
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Staged'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Published').last);
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters['review_status'], 'published');
      expect(requests.last.url.queryParameters['q'], 'falls');

      await tester.tap(find.text('Baradi Falls'));
      await tester.pumpAndSettle();
      expect(find.text('OSM source: node 1001'), findsOneWidget);
      await tester.tap(find.text('Back to review queue'));
      await tester.pumpAndSettle();

      final field = tester.widget<TextField>(
        find.byKey(const Key('candidate-search')),
      );
      expect(field.controller!.text, 'falls');
    });
  });
}
