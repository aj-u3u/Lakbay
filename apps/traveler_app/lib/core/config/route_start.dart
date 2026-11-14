import 'package:latlong2/latlong.dart';

/// Lakbay plans local Davao Region travel. A traveler's GPS position outside the
/// region (for example in Manila) must not become the start of the local itinerary.
const LatLng davaoCityCenter = LatLng(7.0706, 125.6092);
const LatLng panaboTerminal = LatLng(7.3079, 125.6811);

// Generous bounding box around Davao Region (Region XI), not an exact border.
const double _minLat = 5.3;
const double _maxLat = 8.1;
const double _minLng = 124.9;
const double _maxLng = 126.9;

bool isInDavaoRegion(double lat, double lng) =>
    lat >= _minLat && lat <= _maxLat && lng >= _minLng && lng <= _maxLng;

class RouteStart {
  final LatLng location;
  final String name;

  /// True when the traveler chose "Current Location" but is outside the region,
  /// so a Davao start was used instead.
  final bool outsideRegion;

  const RouteStart(this.location, this.name, {this.outsideRegion = false});
}

/// Resolves the start of a local route from the selected start point.
RouteStart resolveRouteStart(
  String selectedStart, {
  double? deviceLat,
  double? deviceLng,
}) {
  if (selectedStart == 'Panabo') {
    return const RouteStart(panaboTerminal, 'Panabo Terminal');
  }
  if (selectedStart == 'Current Location') {
    if (deviceLat == null || deviceLng == null) {
      return const RouteStart(
        davaoCityCenter,
        'Davao City Center (GPS Loading...)',
      );
    }
    if (!isInDavaoRegion(deviceLat, deviceLng)) {
      return const RouteStart(
        davaoCityCenter,
        'Davao City Center (outside region)',
        outsideRegion: true,
      );
    }
    return RouteStart(LatLng(deviceLat, deviceLng), 'Your Location');
  }
  return const RouteStart(davaoCityCenter, 'Davao City Center');
}
