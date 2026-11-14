import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:lakbay_plus/widgets/map/ferry_markers.dart';

Map<String, dynamic> _route(List<Map<String, dynamic>> crossings) => {
  'ferry_crossings': crossings,
};

void main() {
  const crossing = {
    'name': 'Sasa-Samal RoRo',
    'duration_minutes': 25,
    'from_lat': 7.08,
    'from_lng': 125.65,
    'to_lat': 7.07,
    'to_lng': 125.70,
  };

  test('a crossing gives a departure pier and a landing pier', () {
    final points = ferryPoints(_route([crossing]));

    expect(points.length, 2);
    expect(points[0].departure, isTrue);
    expect(points[0].point, const LatLng(7.08, 125.65));
    expect(points[0].label, contains('Sasa-Samal RoRo'));
    expect(points[1].departure, isFalse);
    expect(points[1].point, const LatLng(7.07, 125.70));
  });

  test('an unnamed crossing is labelled Ferry', () {
    final points = ferryPoints(
      _route([
        {...crossing, 'name': null},
      ]),
    );

    expect(points.first.label, startsWith('Ferry:'));
  });

  test('missing or invalid coordinates are skipped, not guessed', () {
    expect(
      ferryPoints(
        _route([
          {'name': 'No coordinates', 'duration_minutes': 20},
        ]),
      ),
      isEmpty,
    );
    expect(
      ferryPoints(
        _route([
          {...crossing, 'from_lat': 999.0, 'to_lat': null},
        ]),
      ),
      isEmpty,
    );
    expect(ferryPoints(null), isEmpty);
    expect(ferryPoints({}), isEmpty);
  });

  test('only a crossing with both ends gets a dashed line', () {
    expect(ferryLines(_route([crossing])).single.length, 2);
    expect(
      ferryLines(
        _route([
          {...crossing, 'to_lat': null},
        ]),
      ),
      isEmpty,
    );
    expect(ferryPolylines(_route([crossing])).length, 1);
  });

  testWidgets('the marker shows a boat for departure and an anchor for landing', (
    tester,
  ) async {
    final points = ferryPoints(_route([crossing]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Row(
            children: [for (final p in points) ferryMarker(p).child],
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.directions_boat_filled_rounded), findsOneWidget);
    expect(find.byIcon(Icons.anchor_rounded), findsOneWidget);
    expect(find.byType(Tooltip), findsNWidgets(2));
  });
}
