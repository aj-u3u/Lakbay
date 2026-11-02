import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../models/planning_feedback.dart';
import '../../providers/trip_provider.dart';

/// Returns true only after the traveler has reviewed current feedback.
Future<bool> reviewPlanningFeedback(
  BuildContext context,
  TripProvider provider,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PlanningFeedbackDialog(provider: provider),
  );
  return confirmed == true;
}

class PlanningFeedbackDialog extends StatefulWidget {
  final TripProvider provider;

  const PlanningFeedbackDialog({super.key, required this.provider});

  @override
  State<PlanningFeedbackDialog> createState() => _PlanningFeedbackDialogState();
}

class _PlanningFeedbackDialogState extends State<PlanningFeedbackDialog> {
  bool? _travelingWithChildren;
  PlanningFeedback? _feedback;
  String? _error;
  bool _loading = false;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _feedback = null;
      _error = null;
    });
    final feedback = await widget.provider.reviewChatPlanningFeedback(
      travelingWithChildren: _travelingWithChildren,
    );
    if (!mounted || serial != _requestSerial) return;
    setState(() {
      _loading = false;
      _feedback = feedback;
      _error = feedback == null
          ? widget.provider.errorMessage ?? 'Could not check this plan.'
          : null;
    });
  }

  void _chooseChildren(bool? value) {
    if (_travelingWithChildren == value) return;
    setState(() => _travelingWithChildren = value);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final feedback = _feedback;
    return AlertDialog(
      title: const Text('Review before saving'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 460,
          maxHeight: MediaQuery.sizeOf(context).height * 0.62,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This check uses your current trip selections. Review the AI option’s daily times and prices separately.',
              ),
              const SizedBox(height: AppConstants.spaceM),
              Text(
                'Are children traveling?',
                style: theme.textTheme.titleSmall,
              ),
              const SizedBox(height: AppConstants.spaceS),
              Wrap(
                spacing: AppConstants.spaceS,
                runSpacing: AppConstants.spaceS,
                children: [
                  ChoiceChip(
                    label: const Text('Not specified'),
                    selected: _travelingWithChildren == null,
                    onSelected: (_) => _chooseChildren(null),
                  ),
                  ChoiceChip(
                    label: const Text('Yes'),
                    selected: _travelingWithChildren == true,
                    onSelected: (_) => _chooseChildren(true),
                  ),
                  ChoiceChip(
                    label: const Text('No'),
                    selected: _travelingWithChildren == false,
                    onSelected: (_) => _chooseChildren(false),
                  ),
                ],
              ),
              if (_travelingWithChildren == null) ...[
                const SizedBox(height: AppConstants.spaceS),
                Text(
                  'Choose Yes to check kid-friendly destination flags.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: AppConstants.spaceM),
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (_error != null) ...[
                Text(_error!, style: TextStyle(color: colors.error)),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry check'),
                ),
              ],
              if (feedback != null && feedback.findings.isEmpty)
                const Text(
                  'No issues flagged in this plan. Confirm current access, prices, and the AI option’s day-by-day schedule before travel.',
                ),
              if (feedback != null)
                for (final finding in feedback.findings)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppConstants.spaceS),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          finding.severity == 'required'
                              ? Icons.error_outline
                              : finding.severity == 'review'
                              ? Icons.warning_amber_rounded
                              : Icons.info_outline,
                          color: finding.severity == 'required'
                              ? colors.error
                              : colors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        Expanded(child: Text(finding.message)),
                      ],
                    ),
                  ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: _loading || feedback == null || feedback.needsDetails
              ? null
              : () => Navigator.of(context).pop(true),
          child: Text(
            feedback?.status == 'needs_review'
                ? 'Save with warnings'
                : 'Save itinerary',
          ),
        ),
      ],
    );
  }
}
