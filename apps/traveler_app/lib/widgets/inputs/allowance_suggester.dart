import 'package:flutter/widgets.dart';

import '../../providers/trip_provider.dart';

const String suggestionIntro =
    'System estimates from your whole-trip budget. They only fill empty boxes, are not catalog prices, and you can edit them.';

/// Plain-language text for the planning preview's route status code.
String routeStatusLabel(Object? status) => switch (status) {
  'calculated' => 'calculated',
  'needs_review' => 'needs your review',
  'needs_details' => 'needs more details',
  _ => 'not calculated yet (worked out when you generate)',
};

/// Fills a review sheet's transport, food and lodging boxes from the server's
/// suggested allowances. Shared by both planner review sheets.
class AllowanceSuggester {
  final TripProvider provider;
  final TextEditingController days;
  final TextEditingController nights;
  final TextEditingController budget;
  final TextEditingController transport;
  final TextEditingController food;
  final TextEditingController accommodation;

  /// Whether the sheet is still on screen; checked after the server call.
  final bool Function() isActive;

  /// Message to show next to the button after the last tap.
  String? note;

  /// What each box held right after it was last filled by a suggestion.
  final Map<TextEditingController, String> _lastSuggested = {};

  AllowanceSuggester({
    required this.provider,
    required this.days,
    required this.nights,
    required this.budget,
    required this.transport,
    required this.food,
    required this.accommodation,
    required this.isActive,
  });

  String? _money(TextEditingController controller) {
    final amount = double.tryParse(controller.text.trim().replaceAll(',', ''));
    if (amount == null || !amount.isFinite || amount < 0) return null;
    return amount.toStringAsFixed(2);
  }

  Map<String, String> _suggestions(Map<String, dynamic>? preview) {
    final raw = preview?['suggested_allowances'];
    if (raw is! List) return const {};
    return {
      for (final item in raw.whereType<Map>())
        if (item['category'] != null && item['amount'] != null)
          item['category'].toString(): item['amount'].toString(),
    };
  }

  /// Sends the sheet's current days, nights and budget first, so the suggestion
  /// matches what is on screen and not the previously saved plan. Returns an
  /// error message to show, or null when the boxes were updated.
  Future<String?> suggest() async {
    final state = provider.chatPlanningState;
    final dayCount = int.tryParse(days.text.trim());
    final nightCount = int.tryParse(nights.text.trim());
    final total = _money(budget);
    final knownDays = dayCount ?? (state['day_count'] as num?)?.toInt();
    final changes = <String, dynamic>{
      if (dayCount != null &&
          dayCount >= 1 &&
          dayCount <= 30 &&
          dayCount != state['day_count'])
        'day_count': dayCount,
      if (nightCount != null &&
          nightCount >= 0 &&
          (knownDays == null || nightCount <= knownDays) &&
          nightCount != state['night_count'])
        'night_count': nightCount,
      if (total != null &&
          double.parse(total) > 0 &&
          double.parse(total) !=
              double.tryParse(state['total_budget']?.toString() ?? ''))
        'total_budget': total,
    };
    if (changes.isNotEmpty) {
      final ok = await provider.updateChatPlanning(changes);
      if (!isActive()) return null;
      if (!ok) return provider.errorMessage;
    }
    _apply(provider.chatPlanningPreview);
    return null;
  }

  /// Fills empty boxes and boxes still holding an earlier suggestion; amounts the
  /// traveler typed themselves are never overwritten.
  void _apply(Map<String, dynamic>? preview) {
    final suggestions = _suggestions(preview);
    var filled = 0;
    void fill(TextEditingController controller, String category) {
      final value = suggestions[category];
      if (value == null) return;
      final current = controller.text.trim();
      if (current.isNotEmpty && current != _lastSuggested[controller]) return;
      final amount = double.tryParse(value);
      final text = amount == null
          ? value
          : amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2);
      controller.text = text;
      _lastSuggested[controller] = text;
      filled++;
    }

    fill(transport, 'transportation');
    fill(food, 'food');
    fill(accommodation, 'accommodation');
    note = suggestions.isEmpty
        ? 'Enter a whole-trip budget above first, then tap the button again.'
        : filled == 0
        ? 'Nothing to fill: your boxes already have amounts.'
        : 'Filled $filled box(es) with system estimates. Edit any amount before confirming.';
  }
}
