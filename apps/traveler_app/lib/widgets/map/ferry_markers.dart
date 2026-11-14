import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// A pier on a route: where a ferry crossing starts or ends.
class FerryPoint {
  final LatLng point;
  final bool departure;
  final String label;

  const FerryPoint(this.point, {required this.departure, required this.label});
}

/// Crossing endpoints reported by the route provider. Crossings without
/// coordinates are skipped, since there is nothing honest to draw.
List<FerryPoint> ferryPoints(Map<String, dynamic>? route) {
  final crossings = route?['ferry_crossings'];
  if (crossings is! List) return const [];
  final points = <FerryPoint>[];
  for (final item in crossings.whereType<Map>()) {
    final name = item['name']?.toString().trim();
    final named = name == null || name.isEmpty ? 'Ferry' : name;
    final from = _latLng(item['from_lat'], item['from_lng']);
    final to = _latLng(item['to_lat'], item['to_lng']);
    if (from != null) {
      points.add(
        FerryPoint(from, departure: true, label: '$named: boat leaves here'),
      );
    }
    if (to != null) {
      points.add(
        FerryPoint(to, departure: false, label: '$named: boat lands here'),
      );
    }
  }
  return points;
}

/// The water leg of each crossing, for a dashed line over the route.
List<List<LatLng>> ferryLines(Map<String, dynamic>? route) {
  final crossings = route?['ferry_crossings'];
  if (crossings is! List) return const [];
  return [
    for (final item in crossings.whereType<Map>())
      if (_latLng(item['from_lat'], item['from_lng']) != null &&
          _latLng(item['to_lat'], item['to_lng']) != null)
        [
          _latLng(item['from_lat'], item['from_lng'])!,
          _latLng(item['to_lat'], item['to_lng'])!,
        ],
  ];
}

LatLng? _latLng(Object? lat, Object? lng) {
  if (lat is! num || lng is! num) return null;
  final la = lat.toDouble();
  final lo = lng.toDouble();
  if (!la.isFinite || !lo.isFinite || la.abs() > 90 || lo.abs() > 180) {
    return null;
  }
  return LatLng(la, lo);
}

/// Boat marker for a pier. Amber so it reads differently from stops and the start.
Marker ferryMarker(FerryPoint point) => Marker(
  point: point.point,
  width: 36,
  height: 36,
  child: Tooltip(
    message: point.label,
    child: Container(
      key: ValueKey(
        'ferry-${point.departure ? 'departure' : 'landing'}-'
        '${point.point.latitude}-${point.point.longitude}',
      ),
      decoration: BoxDecoration(
        color: Colors.amber[800],
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Icon(
        point.departure
            ? Icons.directions_boat_filled_rounded
            : Icons.anchor_rounded,
        color: Colors.white,
        size: 18,
      ),
    ),
  ),
);

/// Dashed amber line over each water leg, so the boat part is not drawn as road.
List<Polyline<Object>> ferryPolylines(Map<String, dynamic>? route) => [
  for (final line in ferryLines(route))
    Polyline<Object>(
      points: line,
      color: Colors.amber[800]!,
      strokeWidth: 5,
      pattern: StrokePattern.dashed(segments: const [10, 8]),
    ),
];
