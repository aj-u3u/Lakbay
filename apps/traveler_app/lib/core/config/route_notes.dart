/// Plain-language notes for a route summary: ferry crossings first, then a note
/// when the stops were reordered, then the server's other warnings.
///
/// A ferry crossing is shown as unconfirmed: the route provider found a boat leg
/// but does not know the schedule, fare or pier waiting time.
List<String> routeNotes(
  Map<String, dynamic>? route, {
  List<int> requestedDestinationIds = const [],
}) {
  if (route == null) return const [];
  final notes = <String>[];

  final crossings = route['ferry_crossings'];
  if (crossings is List) {
    for (final item in crossings.whereType<Map>()) {
      final name = item['name']?.toString().trim();
      final minutes = item['duration_minutes'];
      final named = name == null || name.isEmpty ? '' : ' ($name)';
      final time = minutes is num && minutes > 0 ? ', about $minutes min on the boat' : '';
      notes.add(
        'Ferry crossing$named$time. Fare, schedule and waiting at the pier are '
        'not included. Confirm them before you travel.',
      );
    }
  }

  final order = _orderNote(route, requestedDestinationIds);
  if (order != null) notes.add(order);

  final warnings = route['warnings'];
  if (warnings is List) {
    for (final warning in warnings) {
      final text = warning?.toString() ?? '';
      // The structured ferry note above replaces the server's ferry sentence.
      if (text.isEmpty ||
          (notes.isNotEmpty &&
              crossings is List &&
              crossings.isNotEmpty &&
              text.contains('ferry crossing'))) {
        continue;
      }
      notes.add(text);
    }
  }
  return notes;
}

String? _orderNote(Map<String, dynamic> route, List<int> requestedIds) {
  final stops = route['stops'];
  if (stops is! List || requestedIds.length < 2) return null;
  final routedIds = <int>[
    for (final stop in stops.whereType<Map>())
      if (stop['is_origin'] != true && stop['destination_id'] is int)
        stop['destination_id'] as int,
  ];
  if (routedIds.length != requestedIds.length) return null;
  for (var i = 0; i < routedIds.length; i++) {
    if (routedIds[i] != requestedIds[i]) {
      return 'Stops were reordered to shorten travel, so the map order may '
          'differ from your itinerary.';
    }
  }
  return null;
}
