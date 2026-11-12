import 'package:flutter/material.dart';

/// The selected catalog activities and the traveler-confirmed cost coverage.
class ActivityCostSelection {
  final List<String> selectedIds;
  final List<Map<String, dynamic>> activityAllowances;
  final Map<int, List<String>> destinationInclusions;
  final List<String> foodInclusions;

  const ActivityCostSelection({
    required this.selectedIds,
    required this.activityAllowances,
    required this.destinationInclusions,
    required this.foodInclusions,
  });
}

class ActivitySelectionFields extends StatefulWidget {
  final List<Map> destinations;
  final List<Map> options;
  final List<String> initialSelectedIds;
  final List<Map> initialAllowances;

  const ActivitySelectionFields({
    super.key,
    required this.destinations,
    required this.options,
    required this.initialSelectedIds,
    required this.initialAllowances,
  });

  @override
  State<ActivitySelectionFields> createState() =>
      ActivitySelectionFieldsState();
}

class ActivitySelectionFieldsState extends State<ActivitySelectionFields>
    with AutomaticKeepAliveClientMixin<ActivitySelectionFields> {
  final Set<String> _selected = {};
  final Map<String, String> _costMethods = {};
  final Map<String, TextEditingController> _amounts = {};
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initialSelectedIds);
    for (final id in _selected) {
      final activityAllowance = widget.initialAllowances
          .where(
            (item) => item['category'] == 'activity' && item['option_id'] == id,
          )
          .firstOrNull;
      final destinationIncludes = widget.initialAllowances.any(
        (item) =>
            item['category'] == 'destination' &&
            (item['includes_activity_option_ids'] as List? ?? const [])
                .contains(id),
      );
      final foodIncludes = widget.initialAllowances.any(
        (item) =>
            item['category'] == 'food' &&
            (item['includes_activity_option_ids'] as List? ?? const [])
                .contains(id),
      );
      _costMethods[id] = activityAllowance != null
          ? 'separate'
          : destinationIncludes
          ? 'destination'
          : foodIncludes
          ? 'food'
          : 'separate';
      _amounts[id] = TextEditingController(
        text: activityAllowance?['amount']?.toString() ?? '',
      );
    }
  }

  @override
  void dispose() {
    for (final controller in _amounts.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _money(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return '${parts[0]}.${parts.length == 1 ? '00' : parts[1].padRight(2, '0')}';
  }

  ActivityCostSelection? validatedSelection({
    required Set<int> destinationAllowanceIds,
  }) {
    final available = {
      for (final option in widget.options)
        if (option['option_id'] is String)
          option['option_id'] as String: option,
    };
    final selectedIds = <String>[];
    final activityAllowances = <Map<String, dynamic>>[];
    final destinationInclusions = <int, List<String>>{};
    final foodInclusions = <String>[];
    String? error;
    if (_selected.any((id) => !available.containsKey(id))) {
      error = 'Remove unavailable activities before confirming.';
    } else {
      for (final option in widget.options) {
        final id = option['option_id'];
        if (id is! String || !_selected.contains(id)) continue;
        selectedIds.add(id);
        final method = _costMethods[id] ?? 'separate';
        if (method == 'separate') {
          final amount = _money(
            _amounts.putIfAbsent(id, () => TextEditingController()),
          );
          if (amount == null) {
            error = 'Enter a whole-trip amount for every selected activity.';
            break;
          }
          activityAllowances.add({
            'category': 'activity',
            'option_id': id,
            'amount': amount,
          });
        } else if (method == 'destination') {
          final destinationId = option['destination_id'];
          if (destinationId is! int ||
              !destinationAllowanceIds.contains(destinationId)) {
            error =
                'A destination can include an activity only when it uses a whole-trip allowance.';
            break;
          }
          destinationInclusions.putIfAbsent(destinationId, () => []).add(id);
        } else {
          foodInclusions.add(id);
        }
      }
    }
    setState(() => _error = error);
    if (error != null) return null;
    return ActivityCostSelection(
      selectedIds: selectedIds,
      activityAllowances: activityAllowances,
      destinationInclusions: destinationInclusions,
      foodInclusions: foodInclusions,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final availableIds = widget.options
        .map((item) => item['option_id'])
        .whereType<String>()
        .toSet();
    final unavailable = _selected.difference(availableIds).toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Activities', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Choose activities you plan to do. Their fees are not listed in the catalog.',
        ),
        const SizedBox(height: 4),
        const Text(
          'Enter 0 only when you have confirmed no extra cost applies.',
        ),
        if (widget.options.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'No selectable activities are listed for these destinations.',
            ),
          ),
        for (final destination in widget.destinations)
          if (widget.options.any(
            (option) =>
                option['destination_id'] == destination['destination_id'],
          )) ...[
            const SizedBox(height: 12),
            Text(
              destination['name']?.toString() ?? 'Destination',
              style: theme.textTheme.titleSmall,
            ),
            for (final option in widget.options.where(
              (item) => item['destination_id'] == destination['destination_id'],
            ))
              _buildOption(option),
          ],
        for (final id in unavailable)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Previously selected activity is unavailable'),
            subtitle: Text(id, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: 'Remove unavailable activity $id',
              onPressed: () => setState(() {
                _selected.remove(id);
                _error = null;
              }),
              icon: const Icon(Icons.remove_circle_outline),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _error!,
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
  }

  Widget _buildOption(Map option) {
    final id = option['option_id'] as String;
    final selected = _selected.contains(id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CheckboxListTile(
          key: ValueKey('activity-select-$id'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(option['label']?.toString() ?? 'Activity'),
          value: selected,
          onChanged: (value) => setState(() {
            if (value == true) {
              if (_selected.length >= 50) {
                _error = 'Choose at most 50 activities.';
                return;
              }
              _selected.add(id);
              _costMethods.putIfAbsent(id, () => 'separate');
              _amounts.putIfAbsent(id, () => TextEditingController());
            } else {
              _selected.remove(id);
            }
            _error = null;
          }),
        ),
        if (selected)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  key: ValueKey('activity-cost-method-$id'),
                  initialValue: _costMethods[id] ?? 'separate',
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Cost coverage'),
                  items: const [
                    DropdownMenuItem(
                      value: 'separate',
                      child: Text('Separate whole-trip amount'),
                    ),
                    DropdownMenuItem(
                      value: 'destination',
                      child: Text('Included in destination allowance'),
                    ),
                    DropdownMenuItem(
                      value: 'food',
                      child: Text('Included in food allowance'),
                    ),
                  ],
                  onChanged: (method) => setState(() {
                    if (method != null) _costMethods[id] = method;
                    _error = null;
                  }),
                ),
                if ((_costMethods[id] ?? 'separate') == 'separate')
                  TextField(
                    key: ValueKey('activity-amount-$id'),
                    controller: _amounts[id],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Whole-trip activity amount (₱)',
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
