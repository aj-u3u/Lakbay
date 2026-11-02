class ChatDestinationSuggestion {
  final int id;
  final String name;
  final String? district;
  final String? category;
  final double? catalogEstimate;
  final List<String> reasons;

  const ChatDestinationSuggestion({
    required this.id,
    required this.name,
    required this.district,
    required this.category,
    required this.catalogEstimate,
    required this.reasons,
  });

  factory ChatDestinationSuggestion.fromJson(Map<String, dynamic> json) {
    return ChatDestinationSuggestion(
      id: json['destination_id'] as int,
      name: json['name']?.toString() ?? 'Destination',
      district: json['district']?.toString(),
      category: json['category']?.toString(),
      catalogEstimate: double.tryParse(
        json['estimated_cost']?.toString() ?? '',
      ),
      reasons: (json['reasons'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(),
    );
  }
}
