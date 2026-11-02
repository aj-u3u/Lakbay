/// A rate from the shared Lakbay catalog. IDs are the database record IDs.
class CatalogRate {
  final int id;
  final int destinationId;
  final String title;
  final String subtitle;
  final double price;
  final String currency;
  final String? chargingUnit;
  final String? detail;
  final int? capacity;
  final int? durationMinutes;
  final String? routeFrom;
  final String? routeTo;

  const CatalogRate({
    required this.id,
    required this.destinationId,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.currency,
    required this.chargingUnit,
    this.detail,
    this.capacity,
    this.durationMinutes,
    this.routeFrom,
    this.routeTo,
  });

  factory CatalogRate.accommodation(Map<String, dynamic> json) {
    return CatalogRate(
      id: _requiredId(json, 'accommodation_id'),
      destinationId: _requiredId(json, 'destination_id'),
      title: (json['name'] ?? '').toString(),
      subtitle: (json['room_type'] ?? '').toString(),
      price: _requiredPrice(json),
      currency: (json['currency'] ?? 'PHP').toString(),
      chargingUnit: json['charging_unit']?.toString(),
      detail: json['description']?.toString(),
      capacity: int.tryParse(json['capacity']?.toString() ?? ''),
    );
  }

  factory CatalogRate.transportation(Map<String, dynamic> json) {
    return CatalogRate(
      id: _requiredId(json, 'transportation_id'),
      destinationId: _requiredId(json, 'destination_id'),
      title: (json['vehicle_type'] ?? '').toString(),
      subtitle: '${json['route_from'] ?? ''} → ${json['route_to'] ?? ''}',
      price: _requiredPrice(json),
      currency: (json['currency'] ?? 'PHP').toString(),
      chargingUnit: json['charging_unit']?.toString(),
      detail: json['notes']?.toString(),
      durationMinutes: int.tryParse(json['duration_minutes']?.toString() ?? ''),
      routeFrom: json['route_from']?.toString(),
      routeTo: json['route_to']?.toString(),
    );
  }

  String get priceLabel =>
      '${currency == 'PHP' ? '₱' : '$currency '}${price.toStringAsFixed(2)}';

  String get unitLabel => switch (chargingUnit) {
    'per_room_per_night' => 'room / night',
    'per_room_per_stay' => 'room / stay',
    'per_person' => 'person / one-way leg',
    'per_vehicle' => 'vehicle / one-way leg',
    'per_group' => 'group / one-way leg',
    _ => 'basis unverified',
  };

  String get priceWithUnit => chargingUnit == null
      ? '$priceLabel · basis unverified'
      : '$priceLabel / $unitLabel';

  static int _requiredId(Map<String, dynamic> json, String field) {
    final id = int.tryParse(json[field]?.toString() ?? '');
    if (id == null || id <= 0) {
      throw FormatException('The catalog rate has no valid $field.');
    }
    return id;
  }

  static double _requiredPrice(Map<String, dynamic> json) {
    final price = double.tryParse(json['price']?.toString() ?? '');
    if (price == null || !price.isFinite || price < 0) {
      throw const FormatException('The catalog rate has no valid price.');
    }
    return price;
  }
}
