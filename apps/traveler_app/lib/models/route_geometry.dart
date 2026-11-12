/// Decodes a Google encoded polyline with five decimal places into
/// [longitude, latitude] pairs for GeoJSON-style map consumers.
List<List<double>> decodePolyline5(String encoded) {
  final points = <List<double>>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int? nextDelta() {
    var shift = 0;
    var result = 0;
    while (index < encoded.length) {
      final value = encoded.codeUnitAt(index++) - 63;
      if (value < 0 || value > 63) return null;
      result |= (value & 0x1f) << shift;
      if (value < 0x20) {
        return (result & 1) == 1 ? ~(result >> 1) : result >> 1;
      }
      shift += 5;
      if (shift > 30) return null;
    }
    return null;
  }

  while (index < encoded.length) {
    final latDelta = nextDelta();
    final lngDelta = nextDelta();
    if (latDelta == null || lngDelta == null) return [];
    latitude += latDelta;
    longitude += lngDelta;
    points.add([longitude / 100000, latitude / 100000]);
  }
  return points;
}
