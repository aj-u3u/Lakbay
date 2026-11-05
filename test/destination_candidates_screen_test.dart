import 'dart:convert';

import 'package:final_adminlakbay/screens/destination_candidates_screen.dart';
import 'package:final_adminlakbay/services/api_service.dart';
import 'package:final_adminlakbay/widgets/admin_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}
