import 'package:flutter/material.dart';

import '../../providers/trip_provider.dart';
import '../../widgets/cards/itinerary_option_card.dart';
import 'planning_feedback_dialog.dart';

/// Shows the validated options from one AI run and saves the selected option.
class ChatAIOptionsSheet extends StatefulWidget {
  final TripProvider provider;
  final VoidCallback onSaved;

  const ChatAIOptionsSheet({
    super.key,
    required this.provider,
    required this.onSaved,
  });

  @override
  State<ChatAIOptionsSheet> createState() => _ChatAIOptionsSheetState();
}

class _ChatAIOptionsSheetState extends State<ChatAIOptionsSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final selected = widget.provider.latestGeneratedTrip;
    if (selected == null) return;
    final revision = widget.provider.chatPlanningRevision;
    setState(() {
      _saving = true;
      _error = null;
    });
    final reviewed = await reviewPlanningFeedback(context, widget.provider);
    if (!mounted) return;
    if (!reviewed) {
      setState(() => _saving = false);
      return;
    }
    if (revision != widget.provider.chatPlanningRevision ||
        widget.provider.latestGeneratedTrip?.id != selected.id) {
      setState(() {
        _saving = false;
        _error = 'The plan changed. Review its feedback again.';
      });
      return;
    }
    final success = await widget.provider.addNewTrip(selected);
    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
      widget.onSaved();
      return;
    }
    setState(() {
      _saving = false;
      _error = widget.provider.errorMessage ?? 'The option could not be saved.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.provider,
      builder: (context, _) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: 0.85,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AI itinerary options',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Activity costs are AI draft estimates. Check prices and availability before booking.',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final options = widget.provider.chatAIOptions;
                    final cardContext = ItineraryOptionCard.contextFrom(
                      widget.provider.chatPlanningPreview,
                      widget.provider.destinations,
                    );
                    final badges = ItineraryOptionCard.badgesFor(options);
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: options.length,
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final number = option['option_number'] as int?;
                        return ItineraryOptionCard(
                          option: option,
                          destinations: cardContext.destinations,
                          wholeTripBudget: cardContext.budget,
                          badges: badges[number] ?? const [],
                          selected:
                              number == widget.provider.chatSelectedOptionNumber,
                          actionLabel: 'Select this itinerary',
                          busy: _saving,
                          onSelect: number == null
                              ? null
                              : () => widget.provider.selectChatAIOption(number),
                        );
                      },
                    );
                  },
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed:
                        _saving || widget.provider.latestGeneratedTrip == null
                        ? null
                        : _save,
                    child: Text(
                      _saving ? 'Saving...' : 'Save selected itinerary',
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
