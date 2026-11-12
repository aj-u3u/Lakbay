import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/widgets/inputs/activity_selection_fields.dart';

const activityId = 'activity:7:0123456789abcdef';
const mealId = 'activity:7:fedcba9876543210';
const destinations = [
  {'destination_id': 7, 'name': 'Beach 7'},
];
const options = [
  {'option_id': activityId, 'destination_id': 7, 'label': 'Kayaking'},
  {'option_id': mealId, 'destination_id': 7, 'label': 'Dining'},
];

void main() {
  testWidgets('a selected activity needs an explicit whole-trip amount', (
    tester,
  ) async {
    final key = GlobalKey<ActivitySelectionFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivitySelectionFields(
              key: key,
              destinations: destinations,
              options: options,
              initialSelectedIds: const [],
              initialAllowances: const [],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('activity-select-$activityId')));
    await tester.pumpAndSettle();
    expect(
      key.currentState!.validatedSelection(destinationAllowanceIds: {7}),
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('activity-amount-$activityId')),
      '125.5',
    );
    final selection = key.currentState!.validatedSelection(
      destinationAllowanceIds: {7},
    )!;
    expect(selection.selectedIds, [activityId]);
    expect(selection.activityAllowances, [
      {'category': 'activity', 'option_id': activityId, 'amount': '125.50'},
    ]);
    await tester.tap(find.byKey(const ValueKey('activity-select-$activityId')));
    await tester.pumpAndSettle();
    expect(
      key.currentState!
          .validatedSelection(destinationAllowanceIds: {7})!
          .selectedIds,
      isEmpty,
    );
  });

  testWidgets('included activities cannot overlap an age-priced destination', (
    tester,
  ) async {
    final key = GlobalKey<ActivitySelectionFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivitySelectionFields(
              key: key,
              destinations: destinations,
              options: options,
              initialSelectedIds: const [activityId, mealId],
              initialAllowances: const [
                {
                  'category': 'destination',
                  'destination_id': 7,
                  'amount': '300.00',
                  'includes_activity_option_ids': [activityId],
                },
                {
                  'category': 'food',
                  'amount': '200.00',
                  'includes_activity_option_ids': [mealId],
                },
              ],
            ),
          ),
        ),
      ),
    );
    expect(
      key.currentState!.validatedSelection(destinationAllowanceIds: {}),
      isNull,
    );
    final selection = key.currentState!.validatedSelection(
      destinationAllowanceIds: {7},
    )!;
    expect(selection.selectedIds, [activityId, mealId]);
    expect(selection.activityAllowances, isEmpty);
    expect(selection.destinationInclusions, {
      7: [activityId],
    });
    expect(selection.foodInclusions, [mealId]);
  });

  testWidgets('traveler can switch an activity between cost coverage methods', (
    tester,
  ) async {
    final key = GlobalKey<ActivitySelectionFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActivitySelectionFields(
              key: key,
              destinations: destinations,
              options: [options.first],
              initialSelectedIds: const [],
              initialAllowances: const [],
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('activity-select-$activityId')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('activity-cost-method-$activityId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Included in destination allowance').last);
    await tester.pumpAndSettle();
    expect(
      key.currentState!
          .validatedSelection(destinationAllowanceIds: {7})!
          .destinationInclusions,
      {
        7: [activityId],
      },
    );
    await tester.tap(
      find.byKey(const ValueKey('activity-cost-method-$activityId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Included in food allowance').last);
    await tester.pumpAndSettle();
    final foodSelection = key.currentState!.validatedSelection(
      destinationAllowanceIds: {},
    )!;
    expect(foodSelection.foodInclusions, [activityId]);
    expect(foodSelection.destinationInclusions, isEmpty);
    expect(foodSelection.activityAllowances, isEmpty);
  });

  testWidgets('unavailable saved activity must be removed', (tester) async {
    final key = GlobalKey<ActivitySelectionFieldsState>();
    Widget screen(List<Map> available) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: ActivitySelectionFields(
            key: key,
            destinations: destinations,
            options: available,
            initialSelectedIds: const [activityId],
            initialAllowances: const [
              {
                'category': 'activity',
                'option_id': activityId,
                'amount': '50.00',
              },
            ],
          ),
        ),
      ),
    );
    await tester.pumpWidget(screen(options));
    expect(
      key.currentState!
          .validatedSelection(destinationAllowanceIds: {7})!
          .activityAllowances
          .single['amount'],
      '50.00',
    );
    await tester.pumpWidget(screen(const []));
    expect(
      key.currentState!.validatedSelection(destinationAllowanceIds: {7}),
      isNull,
    );
    await tester.pump();
    expect(
      find.text('Previously selected activity is unavailable'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Remove unavailable activity $activityId'));
    await tester.pumpAndSettle();
    expect(
      key.currentState!
          .validatedSelection(destinationAllowanceIds: {7})!
          .selectedIds,
      isEmpty,
    );
  });
}
