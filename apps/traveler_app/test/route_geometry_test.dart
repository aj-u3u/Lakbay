import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/route_geometry.dart';

void main() {
  test('decodes a polyline5 into longitude-latitude map coordinates', () {
    final points = decodePolyline5('_p~iF~ps|U_ulLnnqC_mqNvxq`@');

    expect(points, hasLength(3));
    expect(points[0][0], closeTo(-120.2, 0.00001));
    expect(points[0][1], closeTo(38.5, 0.00001));
    expect(points[2][0], closeTo(-126.453, 0.00001));
    expect(points[2][1], closeTo(43.252, 0.00001));
  });

  test('rejects an incomplete encoded line', () {
    expect(decodePolyline5('_p~iF'), isEmpty);
  });
}
