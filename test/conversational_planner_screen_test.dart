import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/chat_destination_suggestion.dart';
import 'package:lakbay_plus/models/destination.dart';
import 'package:lakbay_plus/providers/nav_provider.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/conversational_planner_screen.dart';
import 'package:lakbay_plus/screens/planner/conversational_review_sheet.dart';
import 'package:provider/provider.dart';

class _PlannerTripProvider extends TripProvider {
  final Map<String, dynamic> _state = {'destination_ids': <int>[]};
  String? sentMessage;

  @override
  Map<String, dynamic> get chatPlanningState => _state;

  @override
  Map<String, dynamic>? get chatPlanningPreview => {
    'destinations': [
      for (final id in (_state['destination_ids'] as List<int>))
        {
          'destination_id': id,
          'name': 'Beach $id',
          'catalog_estimated_cost': '300.00',
        },
    ],
    'budget': {'missing_costs': []},
    'missing_inputs': ['total_budget'],
  };

  @override
  List<ChatDestinationSuggestion> get chatSuggestions => [
    for (var id = 7; id <= 11; id++)
      ChatDestinationSuggestion(
        id: id,
        name: 'Beach $id',
        district: 'Davao Oriental',
        category: 'beach',
        catalogEstimate: 300,
        reasons: const ['Matches your beach interest.'],
      ),
  ];

  @override
  int get chatRecommendationTotalCandidates => 5;

  @override
  String? get latestChatResponse => 'These beaches match your interests.';

  @override
  void startChatPlanning({Destination? destination}) {
    _state['destination_ids'] = <int>[];
    notifyListeners();
  }

  @override
  Future<bool> refreshChatPlanningPreview() async {
    notifyListeners();
    return true;
  }

  @override
  Future<bool> sendFreeFormChat(
    String message, {
    List<Map<String, String>>? history,
  }) async {
    sentMessage = message;
    notifyListeners();
    return true;
  }

  @override
  Future<bool> setChatDestinationIds(List<int> ids) async {
    _state['destination_ids'] = ids;
    notifyListeners();
    return true;
  }
}

void main() {
  testWidgets('traveler chats, sees five matches, and adds one to plan', (
    tester,
  ) async {
    final provider = _PlannerTripProvider();
    final navigation = NavProvider()..setIndex(1);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<TripProvider>.value(value: provider),
          ChangeNotifierProvider<NavProvider>.value(value: navigation),
        ],
        child: const MaterialApp(home: ConversationalPlannerScreen()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'Find beach trips');
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();

    expect(provider.sentMessage, 'Find beach trips');
    expect(find.text('Catalog matches (5)'), findsOneWidget);
    expect(find.text('Beach 7'), findsOneWidget);
    expect(find.text('Beach 11'), findsOneWidget);
    expect(find.text('Generate itinerary'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Find beach trips'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    final userText = tester.widget<Text>(find.text('Find beach trips'));
    expect(userText.style?.color, Colors.white);

    await tester.enterText(
      find.byType(TextField).first,
      'Add a new preference',
    );
    await tester.tap(find.byTooltip('Send'));
    await tester.pumpAndSettle();
    expect(find.text('Catalog matches (5)'), findsOneWidget);

    await tester.ensureVisible(find.text('Add to plan').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add to plan').first);
    await tester.pumpAndSettle();

    expect(provider.chatPlanningState['destination_ids'], [7]);
    expect(find.textContaining('Your plan • Beach 7'), findsOneWidget);
    expect(find.text('Next: tell me your whole-trip budget.'), findsOneWidget);

    await tester.tap(find.text('Review details and costs'));
    await tester.pumpAndSettle();
    expect(find.byType(ConversationalReviewSheet), findsOneWidget);
    expect(find.text('Catalog references'), findsOneWidget);
    expect(
      find.textContaining('Beach 7: ₱300.00 destination estimate'),
      findsOneWidget,
    );
    final reviewScroll = find
        .descendant(
          of: find.byType(ConversationalReviewSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Amounts you confirm'),
      300,
      scrollable: reviewScroll,
    );
    expect(find.text('Amounts you confirm'), findsOneWidget);
    final allowanceField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField &&
          widget.decoration?.labelText ==
              'Whole-trip destination allowance (₱)',
    );
    await tester.scrollUntilVisible(
      allowanceField,
      300,
      scrollable: reviewScroll,
    );
    expect(allowanceField, findsOneWidget);
  });
}
