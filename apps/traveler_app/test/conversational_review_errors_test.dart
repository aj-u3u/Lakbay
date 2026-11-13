import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/conversational_review_sheet.dart';

class _Provider extends TripProvider {
  final Map<String, dynamic> state;
  final Map<String, dynamic>? preview;
  Map<String, dynamic>? submitted;

  _Provider({required this.state, required this.preview});

  @override
  Map<String, dynamic> get chatPlanningState => state;

  @override
  Map<String, dynamic>? get chatPlanningPreview => preview;

  @override
  Future<bool> refreshChatPlanningPreview() async => true;

  @override
  Future<bool> updateChatPlanning(Map<String, dynamic> changes) async {
    submitted = changes;
    return true;
  }
}

Future<void> _open(WidgetTester tester, _Provider provider) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ConversationalReviewSheet(provider: provider)),
    ),
  );
}

Future<void> _tapConfirm(WidgetTester tester) async {
  final scrollable = find
      .descendant(
        of: find.byType(ConversationalReviewSheet),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.text('Confirm amounts'),
    300,
    scrollable: scrollable,
  );
  await tester.tap(find.text('Confirm amounts'));
  await tester.pumpAndSettle();
}

String _errorText(WidgetTester tester) {
  final match = find.textContaining('Please complete:');
  expect(match, findsOneWidget);
  return tester.widget<Text>(match).data!;
}

void main() {
  testWidgets('no destination chosen: error names the destination and travel mode', (
    tester,
  ) async {
    final provider = _Provider(
      state: {
        'destination_ids': <int>[],
        'origin': {'label': 'Davao City'},
        'day_count': 2,
        'night_count': 1,
        'traveler_count': 1,
        'adult_count': 1,
        'total_budget': '10000',
      },
      preview: {
        'destinations': [],
        'transport_options': [],
        'activity_options': [],
        'budget': {'missing_costs': []},
      },
    );
    await _open(tester, provider);

    expect(
      find.text('Choose a catalog destination in the conversation first.'),
      findsOneWidget,
    );
    await _tapConfirm(tester);

    final message = _errorText(tester);
    expect(message, contains('a destination (choose one in the chat first)'));
    expect(message, contains('a travel mode'));
    expect(message, contains('transport allowance'));
    expect(provider.submitted, isNull);
  });

  testWidgets('destination chosen but no travel mode: error names the missing items only', (
    tester,
  ) async {
    final provider = _Provider(
      state: {
        'destination_ids': <int>[7],
        'origin': {'label': 'Davao City'},
        'day_count': 2,
        'night_count': 1,
        'traveler_count': 1,
        'adult_count': 1,
        'total_budget': '10000',
        'cost_allowances': [
          {'category': 'transportation', 'amount': '100.00'},
          {'category': 'food', 'amount': '200.00'},
          {'category': 'accommodation', 'amount': '300.00'},
        ],
      },
      preview: {
        'destinations': [
          {'destination_id': 7, 'name': 'Beach 7'},
        ],
        'transport_options': [
          {'option_id': 'car', 'label': 'Car'},
        ],
        'activity_options': [],
        'budget': {'missing_costs': []},
      },
    );
    await _open(tester, provider);
    await _tapConfirm(tester);

    final message = _errorText(tester);
    expect(message, contains('a travel mode'));
    expect(message, contains('fee choice for Beach 7'));
    // Things that were filled in are not reported.
    expect(message, isNot(contains('starting place')));
    expect(message, isNot(contains('days')));
    expect(message, isNot(contains('whole-trip budget')));
    expect(message, isNot(contains('lodging amount')));
    expect(provider.submitted, isNull);
  });

  testWidgets('nights above days is reported specifically', (tester) async {
    final provider = _Provider(
      state: {
        'destination_ids': <int>[7],
        'origin': {'label': 'Davao City'},
        'day_count': 2,
        'night_count': 5,
        'traveler_count': 1,
        'adult_count': 1,
        'total_budget': '10000',
      },
      preview: {
        'destinations': [
          {'destination_id': 7, 'name': 'Beach 7'},
        ],
        'transport_options': [],
        'activity_options': [],
        'budget': {'missing_costs': []},
      },
    );
    await _open(tester, provider);
    await _tapConfirm(tester);

    expect(_errorText(tester), contains('nights (cannot be more than days)'));
  });

  testWidgets('shows a loading note, not "choose a destination", while the preview loads', (
    tester,
  ) async {
    final provider = _Provider(
      state: {
        'destination_ids': <int>[7],
        'origin': {'label': 'Davao City'},
      },
      preview: null,
    );
    await _open(tester, provider);

    expect(find.text('Loading your selected destinations...'), findsOneWidget);
    expect(
      find.text('Choose a catalog destination in the conversation first.'),
      findsNothing,
    );
  });
}
