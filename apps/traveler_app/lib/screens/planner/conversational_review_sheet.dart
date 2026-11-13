import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/inputs/activity_selection_fields.dart';
import '../../widgets/inputs/destination_fee_fields.dart';
import '../../widgets/inputs/party_details_fields.dart';

/// Confirms the few assumptions that need a traveler, after chat has collected
/// the rest of the plan. Each destination has an independent cost choice.
class ConversationalReviewSheet extends StatefulWidget {
  final TripProvider provider;

  const ConversationalReviewSheet({super.key, required this.provider});

  @override
  State<ConversationalReviewSheet> createState() =>
      _ConversationalReviewSheetState();
}

class _ConversationalReviewSheetState extends State<ConversationalReviewSheet> {
  final _partyDetailsKey = GlobalKey<PartyDetailsFieldsState>();
  final _activityKey = GlobalKey<ActivitySelectionFieldsState>();
  late final TextEditingController _origin;
  late final TextEditingController _days;
  late final TextEditingController _nights;
  late final TextEditingController _travelers;
  late final TextEditingController _budget;
  late final TextEditingController _transportCost;
  late final TextEditingController _foodCost;
  late final TextEditingController _accommodationCost;
  final Map<int, GlobalKey<DestinationFeeFieldsState>> _destinationFeeKeys = {};
  String? _transportOptionId;
  bool _returnToOrigin = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final state = widget.provider.chatPlanningState;
    final allowances = (state['cost_allowances'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    String amount(String category, {int? destinationId}) {
      for (final item in allowances) {
        if (item['category'] == category &&
            item['destination_id'] == destinationId) {
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
    _transportCost = TextEditingController(text: amount('transportation'));
    _foodCost = TextEditingController(text: amount('food'));
    _accommodationCost = TextEditingController(text: amount('accommodation'));
    for (final id
        in (state['destination_ids'] as List? ?? const []).whereType<int>()) {
      _destinationFeeKeys[id] = GlobalKey<DestinationFeeFieldsState>();
    }
    final chosen = state['selected_transport_option_ids'] as List?;
    _transportOptionId = chosen?.isNotEmpty == true
        ? chosen!.first.toString()
        : null;
    _returnToOrigin = state['return_to_origin'] == true;
    if (widget.provider.chatPlanningPreview == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await widget.provider.refreshChatPlanningPreview();
        if (mounted) setState(() {});
      });
    }
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
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _money(TextEditingController controller) {
    final amount = double.tryParse(controller.text.trim().replaceAll(',', ''));
    if (amount == null || !amount.isFinite || amount < 0) return null;
    return amount.toStringAsFixed(2);
  }

  Future<void> _confirm() async {
    final state = widget.provider.chatPlanningState;
    final ids = (state['destination_ids'] as List? ?? const [])
        .whereType<int>()
        .toList();
    final days = int.tryParse(_days.text.trim());
    final nights = int.tryParse(_nights.text.trim());
    final travelers = int.tryParse(_travelers.text.trim());
    final partyDetails = _partyDetailsKey.currentState?.validatedState(
      travelers,
    );
    final budget = _money(_budget);
    final transportCost = _money(_transportCost);
    final foodCost = _money(_foodCost);
    final accommodationCost = _money(_accommodationCost);
    final destinationFees = {
      for (final id in ids)
        id: _destinationFeeKeys[id]?.currentState?.validatedSelection(),
    };
    final activitySelection = _activityKey.currentState?.validatedSelection(
      destinationAllowanceIds: {
        for (final entry in destinationFees.entries)
          if (entry.value?.allowance != null) entry.key,
      },
    );
    if (ids.isEmpty ||
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
        _transportOptionId == null ||
        transportCost == null ||
        foodCost == null ||
        (nights > 0 && accommodationCost == null) ||
        destinationFees.values.any((value) => value == null) ||
        activitySelection == null) {
      final destinationNames = {
        for (final item
            in (widget.provider.chatPlanningPreview?['destinations'] as List? ??
                    const [])
                .whereType<Map>())
          if (item['destination_id'] is int)
            item['destination_id'] as int:
                item['name']?.toString() ?? 'a destination',
      };
      final missing = <String>[
        if (ids.isEmpty) 'a destination (choose one in the chat first)',
        if (_origin.text.trim().isEmpty) 'your starting place',
        if (days == null || days < 1 || days > 30) 'days (1 to 30)',
        if (nights == null || nights < 0)
          'nights (0 or more)'
        else if (days != null && nights > days)
          'nights (cannot be more than days)',
        if (travelers == null || travelers < 1 || travelers > 100)
          'travelers (1 to 100)',
        if (partyDetails == null) 'party details (adults and child ages)',
        if (budget == null || double.parse(budget) <= 0)
          'whole-trip budget (more than 0)',
        if (_transportOptionId == null) 'a travel mode',
        if (transportCost == null) 'transport allowance (enter 0 if none)',
        if (foodCost == null) 'food amount (enter 0 if none)',
        if ((nights ?? 0) > 0 && accommodationCost == null)
          'lodging amount (enter 0 if none)',
        for (final entry in destinationFees.entries)
          if (entry.value == null)
            'fee choice for ${destinationNames[entry.key] ?? 'a destination'}',
        if (activitySelection == null) 'your activities choice',
      ];
      setState(
        () => _error = missing.isEmpty
            ? 'Confirm the destination fees, trip details, travel mode, and whole-trip allowances.'
            : 'Please complete: ${missing.join(', ')}.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    final oldOrigin = state['origin'];
    final origin = oldOrigin is Map && oldOrigin['label'] == _origin.text.trim()
        ? Map<String, dynamic>.from(oldOrigin)
        : <String, dynamic>{'label': _origin.text.trim()};
    final success = await widget.provider.updateChatPlanning({
      'origin': origin,
      'day_count': days,
      'night_count': nights,
      'traveler_count': travelers,
      ...partyDetails,
      'total_budget': budget,
      'budget_scope': 'whole_trip',
      'return_to_origin': _returnToOrigin,
      'selected_transport_option_ids': <String>[_transportOptionId!],
      'selected_activity_option_ids': activitySelection.selectedIds,
      'selected_accommodation_ids': <int>[],
      'transport_pricing': <Map<String, dynamic>>[],
      'accommodation_pricing': <Map<String, dynamic>>[],
      'age_pricing_rules': [
        for (final fee in destinationFees.values)
          if (fee?.ageRule != null) fee!.ageRule!,
      ],
      'cost_allowances': [
        for (final fee in destinationFees.values)
          if (fee?.allowance != null)
            {
              ...fee!.allowance!,
              if (activitySelection
                      .destinationInclusions[fee.allowance!['destination_id']]
                      ?.isNotEmpty ==
                  true)
                'includes_activity_option_ids': activitySelection
                    .destinationInclusions[fee.allowance!['destination_id']]!,
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
      ],
    });
    if (!mounted) return;
    setState(() {
      _submitting = false;
      _error = success
          ? widget.provider.canGenerateChatPlan
                ? null
                : 'The estimate still needs attention. Review the warnings below.'
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
        final preview = widget.provider.chatPlanningPreview;
        final destinations = (preview?['destinations'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final activities = (preview?['activity_options'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final transport = (preview?['transport_options'] as List? ?? const [])
            .whereType<Map>()
            .toList();
        final availableIds = transport
            .map((item) => item['option_id']?.toString())
            .toSet();
        final selectedTransport = availableIds.contains(_transportOptionId)
            ? _transportOptionId
            : null;
        final selectedTransportOption = transport
            .where((item) => item['option_id']?.toString() == selectedTransport)
            .firstOrNull;
        final budget = preview?['budget'] is Map
            ? preview!['budget'] as Map
            : const <String, dynamic>{};
        final warnings = [
          // The plan cannot be generated while it is over budget, so say so.
          if (budget['fit'] == 'over_budget')
            'Your confirmed amounts total ₱${budget['total_estimate']}'
                '${budget['over_budget_amount'] == null ? '' : ', which is ₱${budget['over_budget_amount']} over'}'
                ' your whole-trip budget of ₱${widget.provider.chatPlanningState['total_budget'] ?? _budget.text}.'
                ' Lower an amount or raise the budget.',
          for (final item
              in (budget['missing_costs'] as List? ?? const [])
                  .whereType<Map>())
            item['message']?.toString() ?? '',
          for (final item
              in (preview?['selection_problems'] as List? ?? const [])
                  .whereType<Map>())
            item['message']?.toString() ?? '',
        ].where((item) => item.isNotEmpty).toList();
        final route = preview?['route'] is Map
            ? preview!['route'] as Map
            : const <String, dynamic>{};
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: FractionallySizedBox(
              heightFactor: 0.9,
              child: ListView(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                children: [
                  Text(
                    'Confirm your trip',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  const Text(
                    'Check the details from your conversation, then confirm destination fees and whole-trip allowances.',
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  if (destinations.isEmpty)
                    Text(
                      (widget.provider.chatPlanningState['destination_ids']
                                      as List? ??
                                  const [])
                              .isEmpty
                          ? 'Choose a catalog destination in the conversation first.'
                          : preview == null
                          ? 'Loading your selected destinations...'
                          : 'Your selected destinations are not available in the catalog. Choose another in the conversation.',
                    ),
                  Text(
                    'Catalog references',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'These are reference prices or estimates. They are not automatically added to your trip total.',
                  ),
                  for (final destination in destinations)
                    Padding(
                      padding: const EdgeInsets.only(top: AppConstants.spaceS),
                      child: Text(
                        '${destination['name'] ?? 'Destination'}: ${destination['catalog_estimated_cost'] == null ? 'no estimate listed' : '₱${destination['catalog_estimated_cost']} destination estimate'}',
                      ),
                    ),
                  if (selectedTransportOption?['listed_price'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppConstants.spaceS),
                      child: Text(
                        '${selectedTransportOption?['label'] ?? 'Travel mode'}: ₱${selectedTransportOption?['listed_price']} listed fare; charging and trip coverage need confirmation.',
                      ),
                    ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    'Trip details and budget',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  _field(_origin, 'Starting city or place'),
                  _field(_days, 'Days', number: true),
                  _field(_nights, 'Nights', number: true),
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
                    key: ValueKey(selectedTransport),
                    initialValue: selectedTransport,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Travel mode'),
                    items: [
                      for (final option in transport)
                        if (option['option_id'] != null)
                          DropdownMenuItem(
                            value: option['option_id'].toString(),
                            child: Text(
                              option['label']?.toString() ?? 'Travel mode',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                    ],
                    onChanged: (value) =>
                        setState(() => _transportOptionId = value),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    'Amounts you confirm',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Text(
                    'Choose a whole-trip allowance or age-based fees for each destination. Enter 0 only when you have confirmed no cost applies.',
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  for (final destination in destinations) ...[
                    Text(
                      destination['name']?.toString() ?? 'Destination',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    DestinationFeeFields(
                      key: _destinationFeeKeys.putIfAbsent(
                        destination['destination_id'] as int,
                        () => GlobalKey<DestinationFeeFieldsState>(),
                      ),
                      destinationId: destination['destination_id'] as int,
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
                                    item['destination_id'] ==
                                        destination['destination_id'],
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
                                        'destination:${destination['destination_id']}',
                              )
                              .firstOrNull,
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                  ],
                  ActivitySelectionFields(
                    key: _activityKey,
                    destinations: destinations,
                    options: activities,
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
                  const SizedBox(height: AppConstants.spaceM),
                  _field(
                    _transportCost,
                    'Your whole-trip transport allowance (₱)',
                    number: true,
                  ),
                  const Text(
                    'This allowance covers all selected travel and transfers and replaces individual listed fares in the projection.',
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  _field(
                    _foodCost,
                    'Your whole-trip food amount (₱)',
                    number: true,
                  ),
                  _field(
                    _accommodationCost,
                    'Your whole-trip lodging amount (₱)',
                    number: true,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    'Projected total from confirmed amounts: ${budget['total_estimate'] == null ? 'incomplete' : '₱${budget['total_estimate']}'}',
                  ),
                  Text('Route: ${route['status'] ?? 'not requested'}'),
                  for (final warning in warnings.take(4)) Text('• $warning'),
                  if (_error != null) ...[
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: AppConstants.spaceM),
                  FilledButton(
                    onPressed: _submitting ? null : _confirm,
                    child: Text(
                      _submitting ? 'Checking...' : 'Confirm amounts',
                    ),
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
  }) => Padding(
    padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
    child: TextField(
      controller: controller,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(labelText: label, hintText: hint),
    ),
  );
}
