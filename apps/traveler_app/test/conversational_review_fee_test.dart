import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/conversational_review_sheet.dart';

class _ReviewProvider extends TripProvider {
  final List<Map<String, dynamic>> activityOptions;
  Map<String, dynamic>? submitted;

  _ReviewProvider({this.activityOptions = const []});

  @override
  Map<String, dynamic> get chatPlanningState => {
    'destination_ids': <int>[7],
    'origin': {'label': 'Davao City'},
    'day_count': 1,
    'night_count': 0,
    'traveler_count': 2,
    'adult_count': 1,
    'child_ages': <int>[4],
    'total_budget': '1000.00',
    'selected_transport_option_ids': <String>['car'],
    'cost_allowances': [
      {'category': 'transportation', 'amount': '100.00'},
      {'category': 'food', 'amount': '200.00'},
    ],
  };

  @override
  Map<String, dynamic>? get chatPlanningPreview => {
    'destinations': [
      {'destination_id': 7, 'name': 'Beach 7'},
    ],
    'transport_options': [
      {'option_id': 'car', 'label': 'Car'},
    ],
    'activity_options': activityOptions,
    'budget': {'missing_costs': []},
  };

  @override
  Future<bool> updateChatPlanning(Map<String, dynamic> changes) async {
    submitted = changes;
    return true;
  }
}

void main() {
  testWidgets('review submits destination child fees without an allowance', (
    tester,
  ) async {
    final provider = _ReviewProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConversationalReviewSheet(provider: provider)),
      ),
    );
    final scrollable = find
        .descendant(
          of: find.byType(ConversationalReviewSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('destination-fee-mode-7-allowance')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(
      find.byKey(const ValueKey('destination-fee-mode-7-allowance')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adult and child fees').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Adult fee per person (₱)'),
      '100',
    );
    await tester.tap(find.byKey(const ValueKey('destination-7-age-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free').last);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Confirm amounts'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Confirm amounts'));
    await tester.pumpAndSettle();

    expect(provider.submitted?['adult_count'], 1);
    expect(provider.submitted?['child_ages'], [4]);
    expect(provider.submitted?['age_pricing_rules'], [
      {
        'category': 'destination',
        'reference_id': 'destination:7',
        'adult_unit_amount': '100.00',
        'child_bands': [
          {'min_age': 4, 'max_age': 4, 'rate': 'free'},
        ],
      },
    ]);
    expect(
      (provider.submitted?['cost_allowances'] as List).where(
        (item) => item['category'] == 'destination',
      ),
      isEmpty,
    );
  });

  testWidgets('review submits selected activity and its separate amount', (
    tester,
  ) async {
    const activityId = 'activity:7:0123456789abcdef';
    final provider = _ReviewProvider(
      activityOptions: const [
        {'option_id': activityId, 'destination_id': 7, 'label': 'Kayaking'},
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConversationalReviewSheet(provider: provider)),
      ),
    );
    final scrollable = find
        .descendant(
          of: find.byType(ConversationalReviewSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    final destinationAmount = find.widgetWithText(
      TextField,
      'Whole-trip destination allowance (₱)',
    );
    await tester.scrollUntilVisible(
      destinationAmount,
      300,
      scrollable: scrollable,
    );
    await tester.enterText(destinationAmount, '300');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('activity-select-$activityId')),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.byKey(const ValueKey('activity-select-$activityId')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('activity-amount-$activityId')),
      '50',
    );
    await tester.scrollUntilVisible(
      find.text('Confirm amounts'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Confirm amounts'));
    await tester.pumpAndSettle();

    expect(provider.submitted?['selected_activity_option_ids'], [activityId]);
    expect(
      (provider.submitted?['cost_allowances'] as List)
          .where((item) => item['category'] == 'activity')
          .single,
      {'category': 'activity', 'option_id': activityId, 'amount': '50.00'},
    );
  });

  Future<Finder> openWithDestinationAmount(
    WidgetTester tester,
    _ReviewProvider provider,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ConversationalReviewSheet(provider: provider)),
      ),
    );
    final scrollable = find
        .descendant(
          of: find.byType(ConversationalReviewSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    final destinationAmount = find.widgetWithText(
      TextField,
      'Whole-trip destination allowance (₱)',
    );
    await tester.scrollUntilVisible(
      destinationAmount,
      300,
      scrollable: scrollable,
    );
    await tester.enterText(destinationAmount, '300');
    return scrollable;
  }

  testWidgets('an optional other-expenses amount is submitted when filled', (
    tester,
  ) async {
    final provider = _ReviewProvider();
    final scrollable = await openWithDestinationAmount(tester, provider);
    final other = find.widgetWithText(
      TextField,
      'Your whole-trip other expenses, optional (₱)',
    );
    await tester.scrollUntilVisible(other, 300, scrollable: scrollable);
    await tester.enterText(other, '120');
    await tester.scrollUntilVisible(
      find.text('Confirm amounts'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Confirm amounts'));
    await tester.pumpAndSettle();

    expect(
      (provider.submitted?['cost_allowances'] as List)
          .where((item) => item['category'] == 'other')
          .single,
      {'category': 'other', 'amount': '120.00'},
    );
  });

  testWidgets('a blank other-expenses box adds no allowance', (tester) async {
    final provider = _ReviewProvider();
    final scrollable = await openWithDestinationAmount(tester, provider);
    await tester.scrollUntilVisible(
      find.text('Confirm amounts'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Confirm amounts'));
    await tester.pumpAndSettle();

    expect(provider.submitted, isNotNull);
    expect(
      (provider.submitted?['cost_allowances'] as List).where(
        (item) => item['category'] == 'other',
      ),
      isEmpty,
    );
  });

  testWidgets('an invalid other-expenses amount blocks confirming', (
    tester,
  ) async {
    final provider = _ReviewProvider();
    final scrollable = await openWithDestinationAmount(tester, provider);
    final other = find.widgetWithText(
      TextField,
      'Your whole-trip other expenses, optional (₱)',
    );
    await tester.scrollUntilVisible(other, 300, scrollable: scrollable);
    await tester.enterText(other, 'abc');
    await tester.scrollUntilVisible(
      find.text('Confirm amounts'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Confirm amounts'));
    await tester.pumpAndSettle();

    expect(provider.submitted, isNull);
    expect(find.textContaining('other expenses'), findsWidgets);
  });
}
