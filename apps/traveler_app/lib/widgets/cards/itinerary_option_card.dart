import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../models/destination.dart';

/// A destination shown on an itinerary card: its name and (optional) photo.
class ItineraryCardDestination {
  final String name;
  final String? imageUrl;

  const ItineraryCardDestination({required this.name, this.imageUrl});
}

/// One generated itinerary option, laid out for comparing options at a glance:
/// photo with badges, title and facts, a price panel with a budget chip, a save
/// button, and the day-by-day plan tucked into an expander.
///
/// Costs are the AI's draft estimate and say so; nothing here is presented as a
/// verified price or rating.
class ItineraryOptionCard extends StatelessWidget {
  final Map<dynamic, dynamic> option;
  final List<ItineraryCardDestination> destinations;

  /// The traveler's whole-trip budget, when known, for the under/over chip.
  final double? wholeTripBudget;
  final List<String> badges;
  final bool busy;
  final VoidCallback? onSelect;

  const ItineraryOptionCard({
    super.key,
    required this.option,
    this.destinations = const [],
    this.wholeTripBudget,
    this.badges = const [],
    this.busy = false,
    this.onSelect,
  });

  int get number => (option['option_number'] as num?)?.toInt() ?? 0;

  List<Map<dynamic, dynamic>> get _days =>
      (option['days'] as List? ?? const []).whereType<Map>().toList();

  int get activityCount => countActivities(option);

  double? get totalCost => double.tryParse('${option['estimated_total_cost']}');

  /// Whole pesos with thousands separators, e.g. `₱6,462`.
  static String peso(Object? value) {
    final amount = double.tryParse(value?.toString() ?? '');
    if (amount == null) return '₱—';
    final rounded = amount.round();
    final digits = rounded.abs().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return '${rounded < 0 ? '-' : ''}₱$buffer';
  }

  static int countActivities(Map<dynamic, dynamic> option) {
    var count = 0;
    for (final day in (option['days'] as List? ?? const []).whereType<Map>()) {
      count += (day['activities'] as List? ?? const []).length;
    }
    return count;
  }

  /// Comparison badges across a set of options, keyed by option number.
  ///
  /// "Best value" goes to the cheapest option that fits the budget and "Most to
  /// do" to the one with the most activities, only when they genuinely differ from
  /// the rest. Nothing is badged when there is a single option.
  static Map<int, List<String>> badgesFor(
    List<Map<dynamic, dynamic>> incoming,
  ) {
    final result = <int, List<String>>{};
    if (incoming.length < 2) return result;
    // Copy into plainly typed maps: callers pass List<Map<String, dynamic>>, and
    // reduce() on such a covariant list throws at runtime.
    final options = [for (final o in incoming) Map<dynamic, dynamic>.from(o)];
    int numberOf(Map<dynamic, dynamic> o) =>
        (o['option_number'] as num?)?.toInt() ?? 0;
    double costOf(Map<dynamic, dynamic> o) =>
        double.tryParse('${o['estimated_total_cost']}') ?? double.infinity;

    final withinBudget = options
        .where((o) => o['is_over_budget'] != true)
        .toList();
    Map<dynamic, dynamic>? best;
    if (withinBudget.isNotEmpty) {
      best = withinBudget.reduce((a, b) => costOf(b) < costOf(a) ? b : a);
      final ties = withinBudget.where((o) => costOf(o) == costOf(best!)).length;
      if (ties == 1) {
        result.putIfAbsent(numberOf(best), () => []).add('Best value');
      }
    }
    final mostActivities = options.reduce(
      (a, b) => countActivities(b) > countActivities(a) ? b : a,
    );
    final topCount = countActivities(mostActivities);
    final tiedForMost = options
        .where((o) => countActivities(o) == topCount)
        .length;
    if (tiedForMost == 1 && topCount > 0) {
      result.putIfAbsent(numberOf(mostActivities), () => []).add('Most to do');
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final overBudget = option['is_over_budget'] == true;
    final warnings = (option['quality_warnings'] as List? ?? const [])
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList();
    final title = option['title']?.toString() ?? 'Itinerary';
    final summary = option['summary']?.toString() ?? '';
    final names = destinations.map((d) => d.name).where((n) => n.isNotEmpty);

    // The surface must be a Material (not a colored DecoratedBox) so the expander's
    // ListTile can paint its ink; the shadow sits on a separate, colorless layer.
    return Container(
      key: Key('itinerary-card-$number'),
      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Material(
        color: colors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          side: BorderSide(color: colors.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _hero(colors),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceM,
                AppConstants.spaceM,
                AppConstants.spaceM,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (names.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceXS),
                    Row(
                      children: [
                        Icon(
                          Icons.place_outlined,
                          size: 16,
                          color: colors.primary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            names.join(', '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (summary.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      summary,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                  const SizedBox(height: AppConstants.spaceS),
                  Wrap(
                    spacing: AppConstants.spaceM,
                    runSpacing: AppConstants.spaceXS,
                    children: [
                      _fact(
                        context,
                        Icons.calendar_month_outlined,
                        '${_days.length} ${_days.length == 1 ? 'day' : 'days'}',
                      ),
                      _fact(
                        context,
                        Icons.checklist_rounded,
                        '$activityCount ${activityCount == 1 ? 'activity' : 'activities'}',
                      ),
                      if (destinations.length > 1)
                        _fact(
                          context,
                          Icons.route_outlined,
                          '${destinations.length} stops',
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: _pricePanel(context, overBudget),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: Key('itinerary-save-$number'),
                  onPressed: busy ? null : onSelect,
                  child: const Text('Save this itinerary'),
                ),
              ),
            ),
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                key: Key('itinerary-expand-$number'),
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppConstants.spaceM,
                  0,
                  AppConstants.spaceM,
                  AppConstants.spaceM,
                ),
                title: Text(
                  'Day-by-day plan',
                  style: theme.textTheme.titleSmall,
                ),
                subtitle: warnings.isEmpty
                    ? null
                    : Text(
                        '${warnings.length} ${warnings.length == 1 ? 'thing' : 'things'} to check',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.secondary,
                        ),
                      ),
                children: [
                  for (final day in _days) _day(context, day),
                  if (warnings.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceS),
                    Text('Things to check', style: theme.textTheme.titleSmall),
                    for (final warning in warnings)
                      Padding(
                        padding: const EdgeInsets.only(
                          top: AppConstants.spaceXS,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 16,
                              color: colors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                warning,
                                style: theme.textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(ColorScheme colors) {
    final imageUrl = destinations
        .map((d) => d.imageUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .firstOrNull;
    final overBudget = option['is_over_budget'] == true;
    final placeholder = Container(
      color: colors.primary.withValues(alpha: 0.14),
      alignment: Alignment.center,
      child: Icon(Icons.landscape_rounded, size: 48, color: colors.primary),
    );
    return SizedBox(
      height: 150,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (imageUrl == null)
            placeholder
          else
            Destination.loadImage(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => placeholder,
            ),
          Positioned(
            left: AppConstants.spaceS,
            top: AppConstants.spaceS,
            child: Wrap(
              spacing: 6,
              children: [
                for (final badge in badges)
                  _badge(badge, colors.primary, Colors.white),
              ],
            ),
          ),
          if (overBudget)
            Positioned(
              right: AppConstants.spaceS,
              top: AppConstants.spaceS,
              child: _badge('Over budget', colors.error, Colors.white),
            ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color background, Color foreground) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(AppConstants.radiusS),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: foreground,
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );

  Widget _fact(BuildContext context, IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 4),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _pricePanel(BuildContext context, bool overBudget) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final total = totalCost;
    final budget = wholeTripBudget;
    Widget? chip;
    if (total != null && budget != null && budget > 0) {
      final difference = (budget - total).abs();
      final over = total > budget;
      chip = Container(
        key: Key('itinerary-budget-chip-$number'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: over ? colors.errorContainer : const Color(0xFFE3F5E8),
          borderRadius: BorderRadius.circular(AppConstants.radiusS),
        ),
        child: Text(
          over
              ? '${peso(difference)} over budget'
              : '${peso(difference)} under budget',
          style: TextStyle(
            color: over ? colors.onErrorContainer : const Color(0xFF1B7F3B),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    } else if (overBudget) {
      chip = Text(
        'Over budget',
        style: TextStyle(color: colors.error, fontWeight: FontWeight.w700),
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI draft estimate', style: theme.textTheme.bodySmall),
          const SizedBox(height: 2),
          Text(
            key: Key('itinerary-price-$number'),
            peso(option['estimated_total_cost']),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          if (chip != null) ...[
            const SizedBox(height: AppConstants.spaceS),
            chip,
          ],
        ],
      ),
    );
  }

  Widget _day(BuildContext context, Map<dynamic, dynamic> day) {
    final theme = Theme.of(context);
    final activities = (day['activities'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spaceS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day ${day['day']}: ${day['title'] ?? ''}',
            style: theme.textTheme.titleSmall,
          ),
          if (day['summary'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                day['summary'].toString(),
                style: theme.textTheme.bodySmall,
              ),
            ),
          for (final activity in activities)
            Padding(
              padding: const EdgeInsets.only(top: AppConstants.spaceS),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      '${activity['time'] ?? ''}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${activity['title'] ?? ''}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if ('${activity['description'] ?? ''}'.isNotEmpty)
                          Text(
                            '${activity['description']}',
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  if ((double.tryParse('${activity['estimated_cost']}') ?? 0) >
                      0)
                    Padding(
                      padding: const EdgeInsets.only(left: AppConstants.spaceS),
                      child: Text(
                        peso(activity['estimated_cost']),
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
