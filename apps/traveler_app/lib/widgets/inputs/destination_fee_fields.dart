import 'package:flutter/material.dart';

/// Exactly one destination costing input: a party allowance or age-based fees.
class DestinationFeeSelection {
  final Map<String, dynamic>? allowance;
  final Map<String, dynamic>? ageRule;

  const DestinationFeeSelection({this.allowance, this.ageRule});
}

class DestinationFeeFields extends StatefulWidget {
  final int destinationId;
  final List<int> childAges;
  final Map? initialAllowance;
  final Map? initialAgeRule;

  const DestinationFeeFields({
    super.key,
    required this.destinationId,
    required this.childAges,
    this.initialAllowance,
    this.initialAgeRule,
  });

  @override
  State<DestinationFeeFields> createState() => DestinationFeeFieldsState();
}

class DestinationFeeFieldsState extends State<DestinationFeeFields>
    with AutomaticKeepAliveClientMixin<DestinationFeeFields> {
  late final TextEditingController _allowance;
  late final TextEditingController _adultFee;
  final Map<int, String> _childRates = {};
  late String _mode;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialAgeRule == null ? 'allowance' : 'age_based';
    _allowance = TextEditingController(
      text: widget.initialAllowance?['amount']?.toString() ?? '',
    );
    _adultFee = TextEditingController(
      text: widget.initialAgeRule?['adult_unit_amount']?.toString() ?? '',
    );
    for (final age in widget.childAges) {
      final bands = (widget.initialAgeRule?['child_bands'] as List? ?? const [])
          .whereType<Map>();
      for (final band in bands) {
        final minimum = band['min_age'];
        final maximum = band['max_age'];
        final rate = band['rate'];
        if (minimum is int &&
            maximum is int &&
            rate is String &&
            minimum <= age &&
            age <= maximum) {
          _childRates[age] = rate;
          break;
        }
      }
    }
  }

  @override
  void didUpdateWidget(covariant DestinationFeeFields oldWidget) {
    super.didUpdateWidget(oldWidget);
    final currentAges = widget.childAges.toSet();
    _childRates.removeWhere((age, _) => !currentAges.contains(age));
  }

  @override
  void dispose() {
    _allowance.dispose();
    _adultFee.dispose();
    super.dispose();
  }

  String? _money(TextEditingController controller) {
    final value = controller.text.trim().replaceAll(',', '');
    if (!RegExp(r'^\d{1,8}(?:\.\d{1,2})?$').hasMatch(value)) return null;
    final parts = value.split('.');
    return '${parts[0]}.${parts.length == 1 ? '00' : parts[1].padRight(2, '0')}';
  }

  DestinationFeeSelection? validatedSelection() {
    if (_mode == 'allowance') {
      final amount = _money(_allowance);
      setState(
        () => _error = amount == null
            ? 'Enter a whole-trip destination allowance.'
            : null,
      );
      if (amount == null) return null;
      return DestinationFeeSelection(
        allowance: {
          'category': 'destination',
          'destination_id': widget.destinationId,
          'amount': amount,
        },
      );
    }

    final adultFee = _money(_adultFee);
    final ages = widget.childAges.toSet().toList()..sort();
    String? error;
    if (ages.isEmpty) {
      error = 'Enter child ages before using age-based fees.';
    } else if (adultFee == null) {
      error = 'Enter the adult fee for this destination.';
    } else if (ages.any((age) => !_childRates.containsKey(age))) {
      error = 'Choose a fee rule for every child age.';
    }
    setState(() => _error = error);
    if (error != null) return null;
    return DestinationFeeSelection(
      ageRule: {
        'category': 'destination',
        'reference_id': 'destination:${widget.destinationId}',
        'adult_unit_amount': adultFee,
        'child_bands': [
          for (final age in ages)
            {'min_age': age, 'max_age': age, 'rate': _childRates[age]},
        ],
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final ages = widget.childAges.toSet().toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('destination-fee-mode-${widget.destinationId}-$_mode'),
          initialValue: _mode,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Destination fee method',
          ),
          items: const [
            DropdownMenuItem(
              value: 'allowance',
              child: Text('Whole-trip allowance'),
            ),
            DropdownMenuItem(
              value: 'age_based',
              child: Text('Adult and child fees'),
            ),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _mode = value;
              _error = null;
            });
          },
        ),
        const SizedBox(height: 8),
        if (_mode == 'allowance')
          TextField(
            controller: _allowance,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Whole-trip destination allowance (₱)',
            ),
          )
        else ...[
          TextField(
            controller: _adultFee,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Adult fee per person (₱)',
            ),
          ),
          const SizedBox(height: 8),
          if (ages.isEmpty)
            const Text('Enter child ages in Party details first.'),
          for (final age in ages)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<String>(
                key: ValueKey('destination-${widget.destinationId}-age-$age'),
                initialValue: _childRates[age],
                isExpanded: true,
                decoration: InputDecoration(labelText: 'Age $age fee'),
                items: const [
                  DropdownMenuItem(value: 'free', child: Text('Free')),
                  DropdownMenuItem(value: 'half', child: Text('Half price')),
                  DropdownMenuItem(value: 'full', child: Text('Full price')),
                ],
                onChanged: (rate) => setState(() {
                  if (rate == null) {
                    _childRates.remove(age);
                  } else {
                    _childRates[age] = rate;
                  }
                  _error = null;
                }),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'These child rates are your estimates until the venue confirms them.',
            style: theme.textTheme.bodySmall,
          ),
        ],
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
}
