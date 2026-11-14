import 'package:flutter/material.dart';

import '../../providers/trip_provider.dart';
import '../../widgets/inputs/activity_selection_fields.dart';
import '../../widgets/inputs/allowance_suggester.dart';
import '../../widgets/inputs/destination_fee_fields.dart';
import '../../widgets/inputs/party_details_fields.dart';

/// Collects explicit traveler assumptions needed for a complete planning preview.
class ChatPlanReviewSheet extends StatefulWidget {
  final TripProvider provider;

  const ChatPlanReviewSheet({super.key, required this.provider});

  @override
  State<ChatPlanReviewSheet> createState() => _ChatPlanReviewSheetState();
}

class _ChatPlanReviewSheetState extends State<ChatPlanReviewSheet> {
  final _partyDetailsKey = GlobalKey<PartyDetailsFieldsState>();
  GlobalKey<DestinationFeeFieldsState> _destinationFeeKey = GlobalKey();
  GlobalKey<ActivitySelectionFieldsState> _activityKey = GlobalKey();
  late final TextEditingController _origin;
  late final TextEditingController _days;
  late final TextEditingController _nights;
  late final TextEditingController _travelers;
  late final TextEditingController _budget;
  late final TextEditingController _transportCost;
  late final TextEditingController _foodCost;
  late final TextEditingController _accommodationCost;
  late final TextEditingController _otherCost;
  int? _destinationId;
  String? _transportOptionId;
  bool _returnToOrigin = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = widget.provider.chatPlanningState;
    final ids = state['destination_ids'] as List? ?? const [];
    _destinationId = ids.isNotEmpty && ids.first is int
        ? ids.first as int
        : null;
    final allowances = (state['cost_allowances'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    String allowance(String category) {
      for (final item in allowances) {
        if (item['category'] == category &&
            (category != 'destination' ||
                item['destination_id'] == _destinationId)) {
          return item['amount']?.toString() ?? '';
        }
      }
      return '';
    }

    final origin = state['origin'];
    _origin = TextEditingController(
      text: origin is Map ? origin['label']?.toString() ?? '' : '',
    );
    _days = TextEditingController(text: state['day_count']?.toString() ?? '');
    _nights = TextEditingController(
      text: state['night_count']?.toString() ?? '',
    );
    _travelers = TextEditingController(
      text: state['traveler_count']?.toString() ?? '',
    );
    _budget = TextEditingController(
      text: state['total_budget']?.toString() ?? '',
    );
    _transportCost = TextEditingController(text: allowance('transportation'));
    _foodCost = TextEditingController(text: allowance('food'));
    _accommodationCost = TextEditingController(
      text: allowance('accommodation'),
    );
    _otherCost = TextEditingController(text: allowance('other'));
    _suggester = AllowanceSuggester(
      provider: widget.provider,
      days: _days,
      nights: _nights,
      budget: _budget,
      transport: _transportCost,
      food: _foodCost,
      accommodation: _accommodationCost,
      other: _otherCost,
      isActive: () => mounted,
    );
    final selectedOptions = state['selected_transport_option_ids'] as List?;
    _transportOptionId = selectedOptions?.isNotEmpty == true
        ? selectedOptions!.first.toString()
        : null;
    _returnToOrigin = state['return_to_origin'] == true;

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (widget.provider.destinations.isEmpty) {
        await widget.provider.refreshDestinations();
      }
      if (widget.provider.chatPlanningPreview == null) {
        await widget.provider.refreshChatPlanningPreview();
      }
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    for (final controller in [
      _origin,
      _days,
      _nights,
      _travelers,
      _budget,
      _transportCost,
      _foodCost,
      _accommodationCost,
      _otherCost,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  late final AllowanceSuggester _suggester;

  Future<void> _suggest() async {
    setState(() => _error = null);
    final error = await _suggester.suggest();
    if (!mounted) return;
    setState(() => _error = error);
  }

  String? _money(TextEditingController controller) {
    final value = double.tryParse(controller.text.trim().replaceAll(',', ''));
    if (value == null || !value.isFinite || value < 0) return null;
    return value.toStringAsFixed(2);
  }

  Future<void> _submit() async {
    final days = int.tryParse(_days.text.trim());
    final nights = int.tryParse(_nights.text.trim());
    final travelers = int.tryParse(_travelers.text.trim());
    final partyDetails = _partyDetailsKey.currentState?.validatedState(
      travelers,
    );
    final budget = _money(_budget);
    final destinationFee = _destinationFeeKey.currentState
        ?.validatedSelection();
    final activitySelection = _activityKey.currentState?.validatedSelection(
      destinationAllowanceIds: {
        if (_destinationId != null && destinationFee?.allowance != null)
          _destinationId!,
      },
    );
    final transportCost = _money(_transportCost);
    final foodCost = _money(_foodCost);
    final accommodationCost = _money(_accommodationCost);
    // Optional: blank is fine, but something typed must be a valid amount.
    final otherText = _otherCost.text.trim();
    final otherCost = otherText.isEmpty ? null : _money(_otherCost);
    final otherInvalid = otherText.isNotEmpty && otherCost == null;
    if (_destinationId == null ||
        _origin.text.trim().isEmpty ||
        days == null ||
        days < 1 ||
        days > 30 ||
        nights == null ||
        nights < 0 ||
        nights > days ||
        travelers == null ||
        travelers < 1 ||
        travelers > 100 ||
        partyDetails == null ||
        budget == null ||
        double.parse(budget) <= 0 ||
        destinationFee == null ||
        activitySelection == null ||
        transportCost == null ||
        foodCost == null ||
        (nights > 0 && accommodationCost == null) ||
        otherInvalid ||
        _transportOptionId == null) {
      setState(() {
        _error =
            'Complete the destination, details, transport, and cost estimates.';
      });
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final changes = <String, dynamic>{
      'origin': {'label': _origin.text.trim()},
      'destination_ids': <int>[_destinationId!],
      'total_budget': budget,
      'budget_scope': 'whole_trip',
      'traveler_count': travelers,
      ...partyDetails,
      'day_count': days,
      'night_count': nights,
      'return_to_origin': _returnToOrigin,
      'selected_transport_option_ids': <String>[_transportOptionId!],
      'selected_activity_option_ids': activitySelection.selectedIds,
      'selected_accommodation_ids': <int>[],
      'transport_pricing': <Map<String, dynamic>>[],
      'accommodation_pricing': <Map<String, dynamic>>[],
      'age_pricing_rules': [
        if (destinationFee.ageRule != null) destinationFee.ageRule!,
      ],
      'cost_allowances': [
        if (destinationFee.allowance != null)
          {
            ...destinationFee.allowance!,
            if (activitySelection
                    .destinationInclusions[_destinationId!]
                    ?.isNotEmpty ==
                true)
              'includes_activity_option_ids':
                  activitySelection.destinationInclusions[_destinationId!]!,
          },
        ...activitySelection.activityAllowances,
        {'category': 'transportation', 'amount': transportCost},
        {
          'category': 'food',
          'amount': foodCost,
          if (activitySelection.foodInclusions.isNotEmpty)
            'includes_activity_option_ids': activitySelection.foodInclusions,
        },
        if (nights > 0)
          {'category': 'accommodation', 'amount': accommodationCost},
        if (otherCost != null) {'category': 'other', 'amount': otherCost},
      ],
    };
    final success = await widget.provider.updateChatPlanning(changes);
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = success
          ? widget.provider.canGenerateChatPlan
                ? null
                : 'The estimate still needs attention. Review the items below.'
          : widget.provider.errorMessage;
    });
    if (success && widget.provider.canGenerateChatPlan) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) {
        final destinations = widget.provider.destinations;
        final rawOptions =
            widget.provider.chatPlanningPreview?['transport_options'];
        final transportOptions = rawOptions is List
            ? rawOptions.whereType<Map>().toList()
            : <Map>[];
        final availableTransportIds = transportOptions
            .map((item) => item['option_id']?.toString())
            .toSet();
        final selectedTransport =
            availableTransportIds.contains(_transportOptionId)
            ? _transportOptionId
            : null;
        final selectedDestination = destinations.where(
          (item) => item.id == _destinationId,
        );
        final preview = widget.provider.chatPlanningPreview;
        final previewDestinations =
            (preview?['destinations'] as List? ?? const [])
                .whereType<Map>()
                .where((item) => item['destination_id'] == _destinationId)
                .toList();
        final activityOptions =
            (preview?['activity_options'] as List? ?? const [])
                .whereType<Map>()
                .where((item) => item['destination_id'] == _destinationId)
                .toList();
        final budget = preview?['budget'];
        final budgetDetails = budget is Map
            ? budget
            : const <String, dynamic>{};
        final missingCosts =
            (budgetDetails['missing_costs'] as List? ?? const [])
                .whereType<Map>()
                .map((item) => item['message']?.toString() ?? '')
                .where((item) => item.isNotEmpty);
        final problems = (preview?['selection_problems'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => item['message']?.toString() ?? '')
            .where((item) => item.isNotEmpty);
        final route = preview?['route'];
        final routeDetails = route is Map ? route : const <String, dynamic>{};
        final routeWarnings = (routeDetails['warnings'] as List? ?? const [])
            .map((item) => item.toString());
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Review your plan',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Confirm destination fees and whole-trip allowances before asking AI to build an itinerary.',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int>(
                    key: ValueKey(_destinationId),
                    initialValue: selectedDestination.isEmpty
                        ? null
                        : _destinationId,
                    decoration: const InputDecoration(labelText: 'Destination'),
                    isExpanded: true,
                    items: [
                      for (final item in destinations)
                        DropdownMenuItem(
                          value: item.id,
                          child: Text(item.name),
                        ),
                    ],
                    onChanged: _submitting
                        ? null
                        : (id) async {
                            if (id == null) return;
                            final match = destinations.firstWhere(
                              (d) => d.id == id,
                            );
                            setState(() {
                              _destinationId = id;
                              _transportOptionId = null;
                              _destinationFeeKey = GlobalKey();
                              _activityKey = GlobalKey();
                            });
                            await widget.provider.chooseChatDestination(match);
                            if (mounted) setState(() {});
                          },
                  ),
                  if (destinations.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.provider.catalogError ?? 'Loading destinations...',
                    ),
                    TextButton(
                      onPressed: widget.provider.refreshDestinations,
                      child: const Text('Retry catalog'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  _field(_origin, 'Starting place', hint: 'e.g. Davao City'),
                  _field(_days, 'Days', number: true),
                  _field(_nights, 'Nights (confirm)', number: true),
                  _field(_travelers, 'Travelers', number: true),
                  PartyDetailsFields(
                    key: _partyDetailsKey,
                    onChanged: () => setState(() {}),
                    initialAdultCount:
                        widget.provider.chatPlanningState['adult_count']
                            as int? ??
                        widget.provider.chatPlanningState['traveler_count']
                            as int?,
                    initialChildAges:
                        (widget.provider.chatPlanningState['child_ages']
                                    as List? ??
                                const [])
                            .whereType<int>()
                            .toList(),
                  ),
                  _field(_budget, 'Whole-trip budget (₱)', number: true),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Return to starting place'),
                    value: _returnToOrigin,
                    onChanged: (value) =>
                        setState(() => _returnToOrigin = value),
                  ),
                  DropdownButtonFormField<String>(
                    key: ValueKey('transport-$selectedTransport'),
                    initialValue: selectedTransport,
                    decoration: const InputDecoration(labelText: 'Travel mode'),
                    isExpanded: true,
                    items: [
                      for (final option in transportOptions)
                        if (option['option_id'] != null)
                          DropdownMenuItem(
                            value: option['option_id'].toString(),
                            child: Text(
                              option['label']?.toString() ?? 'Transport',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setState(() => _transportOptionId = value),
                  ),
                  if (transportOptions.isEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      widget.provider.errorMessage ??
                          'Choose a destination to load travel choices.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  Text(
                    'Cost assumptions',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (_destinationId != null)
                    DestinationFeeFields(
                      key: _destinationFeeKey,
                      destinationId: _destinationId!,
                      childAges:
                          _partyDetailsKey.currentState?.enteredChildAges ??
                          (widget.provider.chatPlanningState['child_ages']
                                      as List? ??
                                  const [])
                              .whereType<int>()
                              .toList(),
                      initialAllowance:
                          (widget.provider.chatPlanningState['cost_allowances']
                                      as List? ??
                                  const [])
                              .whereType<Map>()
                              .where(
                                (item) =>
                                    item['category'] == 'destination' &&
                                    item['destination_id'] == _destinationId,
                              )
                              .firstOrNull,
                      initialAgeRule:
                          (widget.provider.chatPlanningState['age_pricing_rules']
                                      as List? ??
                                  const [])
                              .whereType<Map>()
                              .where(
                                (item) =>
                                    item['category'] == 'destination' &&
                                    item['reference_id'] ==
                                        'destination:$_destinationId',
                              )
                              .firstOrNull,
                    ),
                  const SizedBox(height: 16),
                  ActivitySelectionFields(
                    key: _activityKey,
                    destinations: previewDestinations,
                    options: activityOptions,
                    initialSelectedIds:
                        (widget.provider.chatPlanningState['selected_activity_option_ids']
                                    as List? ??
                                const [])
                            .whereType<String>()
                            .toList(),
                    initialAllowances:
                        (widget.provider.chatPlanningState['cost_allowances']
                                    as List? ??
                                const [])
                            .whereType<Map>()
                            .toList(),
                  ),
                  OutlinedButton.icon(
                    key: const Key('suggest-amounts'),
                    onPressed: _suggest,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Suggest amounts from my budget'),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 12),
                    child: Text(_suggester.note ?? suggestionIntro),
                  ),
                  _field(
                    _transportCost,
                    'All transport and transfers (₱)',
                    number: true,
                  ),
                  _field(_foodCost, 'Whole-trip food (₱)', number: true),
                  _field(
                    _accommodationCost,
                    'Whole-trip accommodation, if overnight (₱)',
                    number: true,
                  ),
                  _field(
                    _otherCost,
                    'Whole-trip other expenses, optional (₱)',
                    number: true,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter 0 only when you have confirmed that no cost applies. Route and room availability still need separate confirmation.',
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      'Estimate: ${budgetDetails['total_estimate'] == null ? 'incomplete' : '₱${budgetDetails['total_estimate']}'} • ${budgetDetails['fit'] ?? 'undetermined'}',
                    ),
                    Text('Route: ${routeStatusLabel(routeDetails['status'])}'),
                    for (final warning in [
                      ...missingCosts,
                      ...problems,
                      ...routeWarnings,
                    ].take(4))
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $warning'),
                      ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Review estimate'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        decoration: InputDecoration(labelText: label, hintText: hint),
      ),
    );
  }
}
