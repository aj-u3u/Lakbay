import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_constants.dart';
import '../../models/chat_destination_suggestion.dart';
import '../../providers/nav_provider.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/cards/itinerary_option_card.dart';
import 'conversational_review_sheet.dart';
import 'planner_screen.dart';
import 'planning_feedback_dialog.dart';

/// The traveler plans in messages; the backend preview remains authoritative.
class ConversationalPlannerScreen extends StatefulWidget {
  const ConversationalPlannerScreen({super.key});

  @override
  State<ConversationalPlannerScreen> createState() =>
      _ConversationalPlannerScreenState();
}

class _ConversationalPlannerScreenState
    extends State<ConversationalPlannerScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final List<_PlannerTurn> _turns = [];
  NavProvider? _navigation;
  TripProvider? _provider;
  bool _initialized = false;
  bool _pending = false;
  bool _summaryExpanded = false;
  int? _contextDestinationId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = context.read<NavProvider>();
    if (_navigation != navigation) {
      _navigation?.removeListener(_onNavigationChanged);
      _navigation = navigation..addListener(_onNavigationChanged);
    }
    final provider = context.read<TripProvider>();
    if (_provider != provider) {
      _provider?.removeListener(_onProviderChanged);
      _provider = provider..addListener(_onProviderChanged);
    }
  }

  @override
  void dispose() {
    _navigation?.removeListener(_onNavigationChanged);
    _provider?.removeListener(_onProviderChanged);
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onNavigationChanged() {
    if (_navigation?.currentIndex == 1) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumeContext());
    }
  }

  void _onProviderChanged() {
    if (_navigation?.currentIndex != 1) return;
    final destinationId = _provider?.activePlanDestination?.id;
    if (destinationId != null && destinationId != _contextDestinationId) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _consumeContext());
    }
  }

  void _initialize() {
    if (!mounted || _initialized) return;
    _initialized = true;
    final provider = context.read<TripProvider>();
    final destination = provider.activePlanDestination;
    _contextDestinationId = destination?.id;
    provider.startChatPlanning(destination: destination);
    provider.refreshChatPlanningPreview();
    setState(() {
      _turns.add(
        _PlannerTurn.assistant(
          destination == null
              ? 'Tell me the trip you have in mind: places, dates or days, travelers, interests, and budget. I will help you shape it step by step.'
              : 'Let’s plan a visit to ${destination.name}. Tell me what you enjoy, who is coming, and your budget.',
        ),
      );
    });
    _consumeMoodPrompt();
  }

  void _consumeContext() {
    if (!mounted || !_initialized) return;
    final provider = context.read<TripProvider>();
    final destination = provider.activePlanDestination;
    if (destination != null && destination.id != _contextDestinationId) {
      _contextDestinationId = destination.id;
      provider.startChatPlanning(destination: destination);
      provider.refreshChatPlanningPreview();
      setState(() {
        _turns
          ..clear()
          ..add(
            _PlannerTurn.assistant(
              'Let’s plan ${destination.name}. Tell me about your travelers, interests, duration, and budget.',
            ),
          );
      });
    }
    _consumeMoodPrompt();
  }

  void _consumeMoodPrompt() {
    final provider = context.read<TripProvider>();
    final prompt = provider.activePlanningMoodPrompt;
    if (prompt == null || prompt.trim().isEmpty) return;
    provider.setActivePlanningMoodPrompt(null);
    _send(prompt);
  }

  void _restart() {
    final provider = context.read<TripProvider>();
    provider.setActivePlanDestination(null);
    provider.setActivePlanningMoodPrompt(null);
    provider.startChatPlanning();
    provider.refreshChatPlanningPreview();
    _contextDestinationId = null;
    setState(() {
      _turns
        ..clear()
        ..add(
          _PlannerTurn.assistant(
            'What trip would you like to plan? You can describe it in your own words.',
          ),
        );
      _summaryExpanded = false;
    });
  }

  bool _isGenerateRequest(String text) => RegExp(
    r'\b(generate|build|make|create)\b.*\b(itinerary|trip plan)\b',
    caseSensitive: false,
  ).hasMatch(text);

  Future<void> _send(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty || _pending || !mounted) return;
    final provider = context.read<TripProvider>();
    _composer.clear();
    final history = _turns
        .where((turn) => turn.text.isNotEmpty)
        .map(
          (turn) => <String, String>{
            'role': turn.isUser ? 'user' : 'assistant',
            'content': turn.text,
          },
        )
        .toList();
    setState(() {
      _turns.add(_PlannerTurn.user(text));
      _pending = true;
    });
    _scrollToBottom();

    if (_isGenerateRequest(text) && provider.canGenerateChatPlan) {
      await _generate();
      return;
    }
    final success = await provider.sendFreeFormChat(text, history: history);
    if (!mounted) return;
    List<ChatDestinationSuggestion> suggestions = const [];
    if (success) {
      // Keep offering cards after a stop is added, minus places already planned.
      final selected = (provider.chatPlanningState['destination_ids'] as List? ??
              const [])
          .whereType<int>()
          .toSet();
      suggestions = provider.chatSuggestions
          .where((item) => !selected.contains(item.id))
          .toList();
    }
    setState(() {
      _pending = false;
      if (success) {
        for (var i = 0; i < _turns.length; i++) {
          if (_turns[i].suggestions.isNotEmpty) {
            _turns[i] = _turns[i].withoutSuggestions();
          }
        }
      }
      _turns.add(
        _PlannerTurn.assistant(
          success
              ? provider.latestChatResponse ?? 'What would you like to adjust?'
              : provider.errorMessage ??
                    'I could not update the plan. Please retry.',
          suggestions: suggestions,
          candidateCount: provider.chatRecommendationTotalCandidates,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _choose(ChatDestinationSuggestion suggestion) async {
    if (_pending) return;
    final provider = context.read<TripProvider>();
    final ids = List<int>.from(
      (provider.chatPlanningState['destination_ids'] as List? ?? const [])
          .whereType<int>(),
    );
    if (ids.contains(suggestion.id)) return;
    setState(() {
      _pending = true;
      _turns.add(_PlannerTurn.user('Add ${suggestion.name} to my plan.'));
    });
    final success = await provider.setChatDestinationIds([
      ...ids,
      suggestion.id,
    ]);
    if (!mounted) return;
    setState(() {
      _pending = false;
      _turns.add(
        _PlannerTurn.assistant(
          success
              ? '${suggestion.name} is in your plan. Tell me what to change, or continue with the trip details.'
              : provider.errorMessage ?? 'I could not add this destination.',
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _generate() async {
    if (_pending && _turns.last.isUser == false) return;
    final provider = context.read<TripProvider>();
    if (!provider.canGenerateChatPlan) {
      _openReview();
      return;
    }
    if (!_pending) setState(() => _pending = true);
    final success = await provider.generateChatItinerary();
    if (!mounted) return;
    setState(() {
      _pending = false;
      _turns.add(
        _PlannerTurn.assistant(
          success
              ? 'Here are the validated itinerary options. Choose one to save, or tell me what to adjust.'
              : provider.errorMessage ??
                    'Itinerary generation failed. Please retry.',
          hasOptions: success,
        ),
      );
    });
    _scrollToBottom();
  }

  Future<void> _saveOption(int number) async {
    if (_pending) return;
    final provider = context.read<TripProvider>();
    if (!provider.selectChatAIOption(number)) return;
    final revision = provider.chatPlanningRevision;
    setState(() => _pending = true);
    final reviewed = await reviewPlanningFeedback(context, provider);
    if (!mounted) return;
    if (!reviewed) {
      setState(() => _pending = false);
      return;
    }
    if (revision != provider.chatPlanningRevision ||
        provider.chatSelectedOptionNumber != number) {
      setState(() {
        _pending = false;
        _turns.add(
          _PlannerTurn.assistant(
            'The plan changed. Review its feedback again before saving.',
          ),
        );
      });
      _scrollToBottom();
      return;
    }
    final success = await provider.saveGeneratedTrip();
    if (!mounted) return;
    setState(() {
      _pending = false;
      _turns.add(
        _PlannerTurn.assistant(
          success
              ? 'Saved to My Trips. You can open it there to manage the plan with your group.'
              : provider.errorMessage ??
                    'I could not save that option. Please retry.',
        ),
      );
    });
    _scrollToBottom();
  }

  void _openReview() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) =>
          ConversationalReviewSheet(provider: context.read<TripProvider>()),
    );
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: AppConstants.animDurationFast,
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        // A tab of the main navigation, so there is nothing to go back to.
        automaticallyImplyLeading: false,
        title: const Text('Lakbay Planner'),
        actions: [
          IconButton(
            tooltip: 'Open detailed planner',
            onPressed: _pending
                ? null
                : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const PlannerScreen(),
                    ),
                  ),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: 'New conversation',
            onPressed: _pending ? null : _restart,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scroll,
                padding: const EdgeInsets.all(AppConstants.spaceM),
                itemCount: _turns.length + (_pending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _turns.length) {
                    return const Padding(
                      padding: EdgeInsets.all(AppConstants.spaceM),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  return _buildTurn(
                    _turns[index],
                    colors,
                    showOptions:
                        index ==
                        _turns.lastIndexWhere((turn) => turn.hasOptions),
                  );
                },
              ),
            ),
            _buildPlanSummary(colors),
            _buildComposer(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildTurn(
    _PlannerTurn turn,
    ColorScheme colors, {
    required bool showOptions,
  }) {
    return Align(
      alignment: turn.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
          crossAxisAlignment: turn.isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(bottom: AppConstants.spaceS),
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color: turn.isUser
                    ? Color.lerp(colors.primary, Colors.black, 0.18)
                    : colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
              ),
              child: Text(
                turn.text,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: turn.isUser ? colors.onPrimary : colors.onSurface,
                ),
              ),
            ),
            if (turn.suggestions.isNotEmpty) _buildSuggestions(turn),
            if (turn.hasOptions && showOptions) _buildOptions(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestions(_PlannerTurn turn) {
    final selectedIds =
        (context.read<TripProvider>().chatPlanningState['destination_ids']
                    as List? ??
                const [])
            .whereType<int>()
            .toSet();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Catalog matches (${turn.suggestions.length})',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          if (turn.candidateCount < 5)
            Text(
              'Only ${turn.candidateCount} matched the current preferences.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          for (final suggestion in turn.suggestions)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    if (suggestion.district != null)
                      Text(
                        suggestion.district!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (suggestion.reasons.isNotEmpty)
                      Text(suggestion.reasons.first),
                    Text(
                      suggestion.catalogEstimate == null
                          ? 'Catalog destination estimate not listed. Full trip costs and route need review.'
                          : 'Catalog destination estimate: ₱${suggestion.catalogEstimate!.toStringAsFixed(0)}. Full trip costs and route need review.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed:
                            _pending || selectedIds.contains(suggestion.id)
                            ? null
                            : () => _choose(suggestion),
                        icon: const Icon(Icons.add_location_alt_outlined),
                        label: Text(
                          selectedIds.contains(suggestion.id)
                              ? 'Added to plan'
                              : 'Add to plan',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptions(ColorScheme colors) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final options = provider.chatAIOptions;
        if (options.isEmpty) return const SizedBox.shrink();
        final cardContext = ItineraryOptionCard.contextFrom(
          provider.chatPlanningPreview,
          provider.destinations,
        );
        final badges = ItineraryOptionCard.badgesFor(options);
        return Column(
          children: [
            for (final option in options)
              ItineraryOptionCard(
                option: option,
                destinations: cardContext.destinations,
                wholeTripBudget: cardContext.budget,
                badges:
                    badges[(option['option_number'] as num?)?.toInt()] ??
                    const [],
                busy: _pending,
                onSelect: () => _saveOption(option['option_number'] as int),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPlanSummary(ColorScheme colors) {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final state = provider.chatPlanningState;
        final preview = provider.chatPlanningPreview;
        final destinations = (preview?['destinations'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => item['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .toList();
        final budget = preview?['budget'] is Map
            ? preview!['budget'] as Map
            : const <String, dynamic>{};
        final missingFields = (preview?['missing_inputs'] as List? ?? const [])
            .where(
              (item) =>
                  item != 'origin.coordinates' ||
                  state['route_preferences'] != null,
            )
            .map((item) => item.toString())
            .toList();
        final missing = missingFields
            .map((item) => item.replaceAll('_', ' '))
            .toList();
        final costs = (budget['missing_costs'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => item['message']?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
        final route = preview?['route'] is Map
            ? preview!['route'] as Map
            : const <String, dynamic>{};
        final routeWarnings = (route['warnings'] as List? ?? const [])
            .map((item) => item.toString())
            .toList();
        final total = budget['total_estimate'];
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          decoration: BoxDecoration(
            color: colors.surfaceContainerLow,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () =>
                    setState(() => _summaryExpanded = !_summaryExpanded),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        destinations.isEmpty
                            ? 'Your plan • choose a destination'
                            : 'Your plan • ${destinations.join(', ')}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Icon(
                      _summaryExpanded
                          ? Icons.expand_more_rounded
                          : Icons.expand_less_rounded,
                    ),
                  ],
                ),
              ),
              if (_summaryExpanded) ...[
                const SizedBox(height: AppConstants.spaceS),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    if (state['origin'] is Map &&
                        (state['origin'] as Map)['label'] != null)
                      _chip('From ${(state['origin'] as Map)['label']}'),
                    if (state['day_count'] != null)
                      _chip('${state['day_count']} days'),
                    if (state['traveler_count'] != null)
                      _chip('${state['traveler_count']} travelers'),
                    if (state['total_budget'] != null)
                      _chip('Budget ₱${state['total_budget']}'),
                    for (final interest
                        in (state['interests'] as List? ?? const []))
                      _chip(interest.toString()),
                  ],
                ),
                if (total != null)
                  Text('Projected whole-trip cost: ₱$total (${budget['fit']})'),
                if (missing.isNotEmpty)
                  Text('Still needed: ${missing.take(3).join(', ')}'),
                if (costs.isNotEmpty) Text(costs.first),
                Text(
                  'Route: ${route['status'] ?? 'not requested'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (routeWarnings.isNotEmpty)
                  Text(
                    routeWarnings.first,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (provider.errorMessage != null && preview == null)
                  Text(
                    provider.errorMessage!,
                    style: TextStyle(color: colors.error),
                  ),
              ],
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppConstants.spaceS,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 18, color: colors.primary),
                    const SizedBox(width: AppConstants.spaceS),
                    Expanded(
                      child: Text(
                        _nextPlanningStep(
                          preview: preview,
                          state: state,
                          missingFields: missingFields,
                          missingCosts: costs,
                          destinationCount: destinations.length,
                          canGenerate: provider.canGenerateChatPlan,
                          errorMessage: provider.errorMessage,
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _pending ? null : _openReview,
                    child: const Text('Review details and costs'),
                  ),
                  FilledButton.tonal(
                    onPressed: _pending || !provider.canGenerateChatPlan
                        ? null
                        : _generate,
                    child: const Text('Generate itinerary'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label) => Chip(
    label: Text(label, overflow: TextOverflow.ellipsis),
    visualDensity: VisualDensity.compact,
  );

  String _nextPlanningStep({
    required Map<String, dynamic>? preview,
    required Map<String, dynamic> state,
    required List<String> missingFields,
    required List<String> missingCosts,
    required int destinationCount,
    required bool canGenerate,
    required String? errorMessage,
  }) {
    if (preview == null) {
      return errorMessage ?? 'Checking your plan...';
    }
    if (destinationCount == 0) return 'Next: choose a catalog destination.';
    if (missingFields.contains('origin')) {
      return 'Next: tell me where your trip starts.';
    }
    if (missingFields.contains('day_count')) {
      return 'Next: tell me how many days you will travel.';
    }
    if (missingFields.contains('night_count')) {
      return 'Next: tell me how many nights you will stay.';
    }
    if (missingFields.contains('traveler_count')) {
      return 'Next: tell me how many people are going.';
    }
    if (missingFields.contains('total_budget')) {
      return 'Next: tell me your whole-trip budget.';
    }
    if (missingFields.contains('return_to_origin')) {
      return 'Next: will you return to your starting place?';
    }
    if ((preview['selection_problems'] as List? ?? const []).isNotEmpty) {
      return 'Next: review the selected travel options.';
    }
    final budget = preview['budget'];
    if (budget is Map && budget['fit'] == 'over_budget') {
      return 'Next: reduce your planned costs or adjust your budget.';
    }
    if (missingCosts.isNotEmpty) {
      return 'Next: review and confirm your whole-trip cost amounts.';
    }
    if (state['route_preferences'] != null &&
        (preview['route'] is! Map ||
            (preview['route'] as Map)['status'] != 'calculated')) {
      return 'Next: review the route details.';
    }
    return canGenerate
        ? 'Ready: generate your itinerary.'
        : 'Next: review the remaining trip details.';
  }

  Widget _buildComposer(ColorScheme colors) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppConstants.spaceM,
        AppConstants.spaceS,
        AppConstants.spaceM,
        AppConstants.spaceS,
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _composer,
              enabled: !_pending,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: _send,
              decoration: InputDecoration(
                hintText: 'Tell me about your trip...',
                filled: true,
                fillColor: colors.surfaceContainerLow,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusL),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppConstants.spaceS),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: _pending ? null : () => _send(_composer.text),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _PlannerTurn {
  final String text;
  final bool isUser;
  final List<ChatDestinationSuggestion> suggestions;
  final int candidateCount;
  final bool hasOptions;

  const _PlannerTurn._(
    this.text,
    this.isUser, {
    this.suggestions = const [],
    this.candidateCount = 0,
    this.hasOptions = false,
  });

  factory _PlannerTurn.user(String text) => _PlannerTurn._(text, true);

  factory _PlannerTurn.assistant(
    String text, {
    List<ChatDestinationSuggestion> suggestions = const [],
    int candidateCount = 0,
    bool hasOptions = false,
  }) => _PlannerTurn._(
    text,
    false,
    suggestions: suggestions,
    candidateCount: candidateCount,
    hasOptions: hasOptions,
  );

  _PlannerTurn withoutSuggestions() =>
      _PlannerTurn._(text, isUser, hasOptions: hasOptions);
}
