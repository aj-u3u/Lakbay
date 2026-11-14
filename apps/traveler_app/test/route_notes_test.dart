import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/core/config/route_notes.dart';

Map<String, dynamic> _stop(int? id, {bool origin = false}) => {
  'destination_id': id,
  'is_origin': origin,
};

void main() {
  test('a ferry crossing is described as unconfirmed and listed first', () {
    final notes = routeNotes({
      'ferry_crossings': [
        {'name': 'Sasa-Samal RoRo', 'duration_minutes': 25},
      ],
      'warnings': [
        'Arrival points need confirmation.',
        'This route includes a ferry crossing (Sasa-Samal RoRo), about 25 min.',
      ],
    });

    expect(notes.first, contains('Ferry crossing (Sasa-Samal RoRo)'));
    expect(notes.first, contains('about 25 min on the boat'));
    expect(notes.first, contains('not included'));
    expect(notes, contains('Arrival points need confirmation.'));
    // The server's duplicate ferry sentence is replaced, not repeated.
    expect(notes.where((n) => n.contains('ferry crossing')), isEmpty);
  });

  test('ferry note survives many other warnings', () {
    final notes = routeNotes({
      'ferry_crossings': [
        {'duration_minutes': 30},
      ],
      'warnings': ['a', 'b', 'c', 'd'],
    });

    expect(notes.first, startsWith('Ferry crossing, about 30 min'));
    expect(notes.length, 5);
  });

  test('reordered stops get a note; unchanged order does not', () {
    Map<String, dynamic> route(List<int> ids) => {
      'stops': [_stop(null, origin: true), for (final id in ids) _stop(id)],
    };

    expect(
      routeNotes(route([2, 1, 3]), requestedDestinationIds: [1, 2, 3]),
      contains(contains('reordered')),
    );
    expect(
      routeNotes(route([1, 2, 3]), requestedDestinationIds: [1, 2, 3]),
      isEmpty,
    );
    expect(routeNotes(route([1]), requestedDestinationIds: [1]), isEmpty);
  });

  test('no route means no notes', () {
    expect(routeNotes(null), isEmpty);
    expect(routeNotes({}), isEmpty);
  });
}
