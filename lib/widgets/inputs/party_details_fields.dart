import 'package:flutter/material.dart';

/// Collects an explicit adult count and one age for each child in a plan.
class PartyDetailsFields extends StatefulWidget {
  final int? initialAdultCount;
  final List<int> initialChildAges;
  final VoidCallback? onChanged;

  const PartyDetailsFields({
    super.key,
    this.initialAdultCount,
    this.initialChildAges = const [],
    this.onChanged,
  });

  @override
  State<PartyDetailsFields> createState() => PartyDetailsFieldsState();
}

class PartyDetailsFieldsState extends State<PartyDetailsFields>
    with AutomaticKeepAliveClientMixin<PartyDetailsFields> {
  late final TextEditingController _adults;
  final List<TextEditingController> _childAges = [];
  String? _error;

  @override
  bool get wantKeepAlive => true;

  List<int> get enteredChildAges => _childAges
      .map((field) => int.tryParse(field.text.trim()))
      .whereType<int>()
      .where((age) => age >= 0 && age <= 17)
      .toList();

  @override
  void initState() {
    super.initState();
    _adults = TextEditingController(
      text: widget.initialAdultCount?.toString() ?? '',
    );
    _childAges.addAll(
      widget.initialChildAges.map(
        (age) => TextEditingController(text: age.toString()),
      ),
    );
  }

  @override
  void dispose() {
    _adults.dispose();
    for (final controller in _childAges) {
      controller.dispose();
    }
    super.dispose();
  }

  Map<String, dynamic>? validatedState(int? travelerCount) {
    final adults = int.tryParse(_adults.text.trim());
    final ages = _childAges
        .map((field) => int.tryParse(field.text.trim()))
        .toList();
    String? error;
    if (travelerCount == null || travelerCount < 1 || travelerCount > 100) {
      error = 'Enter a valid total number of travelers.';
    } else if (adults == null || adults < 0 || adults > travelerCount) {
      error = 'Enter how many adults are traveling.';
    } else if (ages.any((age) => age == null || age < 0 || age > 17)) {
      error = 'Enter each child’s age from 0 to 17.';
    } else if (adults + ages.length != travelerCount) {
      error = 'Adults and children must add up to $travelerCount travelers.';
    }
    setState(() => _error = error);
    if (error != null) return null;
    return {'adult_count': adults, 'child_ages': ages.cast<int>()};
  }

  void _addChild() {
    if (_childAges.length >= 100) return;
    setState(() {
      _childAges.add(TextEditingController());
      _error = null;
    });
    widget.onChanged?.call();
  }

  void _removeChild(int index) {
    late final TextEditingController controller;
    setState(() {
      controller = _childAges.removeAt(index);
      _error = null;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Party details', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _adults,
          onChanged: (_) => widget.onChanged?.call(),
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Adults'),
        ),
        for (var index = 0; index < _childAges.length; index++)
          Row(
            key: ValueKey(_childAges[index]),
            children: [
              Expanded(
                child: TextField(
                  controller: _childAges[index],
                  onChanged: (_) => widget.onChanged?.call(),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Child ${index + 1} age',
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Remove child ${index + 1}',
                onPressed: () => _removeChild(index),
                icon: const Icon(Icons.remove_circle_outline),
              ),
            ],
          ),
        TextButton.icon(
          onPressed: _childAges.length >= 100 ? null : _addChild,
          icon: const Icon(Icons.add),
          label: const Text('Add child'),
        ),
        if (_error != null)
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
      ],
    );
  }
}
