import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/core/config/route_start.dart';

void main() {
  test('places inside Davao Region are recognised', () {
    expect(isInDavaoRegion(7.0731, 125.6128), isTrue); // Davao City
    expect(isInDavaoRegion(7.4475, 125.8016), isTrue); // Tagum area
    expect(isInDavaoRegion(6.9, 126.2), isTrue); // Davao Oriental coast
  });

  test('places outside Davao Region are rejected', () {
    expect(isInDavaoRegion(14.5995, 120.9842), isFalse); // Manila
    expect(isInDavaoRegion(10.3157, 123.8854), isFalse); // Cebu
    expect(isInDavaoRegion(8.4542, 124.6319), isFalse); // Cagayan de Oro
  });

  test('a Manila GPS position does not become the route start', () {
    final start = resolveRouteStart(
      'Current Location',
      deviceLat: 14.5995,
      deviceLng: 120.9842,
    );

    expect(start.outsideRegion, isTrue);
    expect(start.location, davaoCityCenter);
    expect(start.name, contains('outside the Davao Region'));
  });

  test('a Davao GPS position is used as the start', () {
    final start = resolveRouteStart(
      'Current Location',
      deviceLat: 7.1,
      deviceLng: 125.6,
    );

    expect(start.outsideRegion, isFalse);
    expect(start.location.latitude, 7.1);
    expect(start.name, 'Your Location');
  });

  test('other start points stay as chosen', () {
    expect(resolveRouteStart('Panabo').location, panaboTerminal);
    expect(resolveRouteStart('Davao City').location, davaoCityCenter);
    expect(
      resolveRouteStart('Current Location').name,
      contains('GPS Loading'),
    );
  });
}
