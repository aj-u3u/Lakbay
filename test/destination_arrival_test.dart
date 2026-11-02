import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/destination.dart';

void main() {
  test('keeps attraction and verified arrival coordinates separate', () {
    final destination = Destination.fromJson({
      'destination_id': 42,
      'name': 'Example Falls',
      'lat': 7.1,
      'lng': 125.1,
      'arrival_lat': 7.12,
      'arrival_lng': 125.13,
      'route_ready': true,
    });

    expect(destination.latitude, 7.1);
    expect(destination.longitude, 125.1);
    expect(destination.arrivalLatitude, 7.12);
    expect(destination.arrivalLongitude, 125.13);
    expect(destination.routeReady, isTrue);
  });
}
