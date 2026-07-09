import 'destination.dart';

class GroupedDestinations {
  final String district;
  final int count;
  final double averageCost;
  final double averageRating;
  final List<Destination> destinations;

  GroupedDestinations({
    required this.district,
    required this.count,
    required this.averageCost,
    required this.averageRating,
    required this.destinations,
  });

  factory GroupedDestinations.fromJson(Map<String, dynamic> json) {
    final list = json['destinations'] as List? ?? [];
    final dests = list.map((d) => Destination.fromJson(d as Map<String, dynamic>)).toList();
    return GroupedDestinations(
      district: json['district'] ?? 'Unknown',
      count: json['count'] ?? 0,
      averageCost: (json['average_cost'] as num?)?.toDouble() ?? 0.0,
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
      destinations: dests,
    );
  }
}
