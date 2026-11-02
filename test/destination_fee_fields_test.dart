import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/widgets/inputs/destination_fee_fields.dart';

void main() {
  testWidgets('age-based destination fees require every child rule', (
    tester,
  ) async {
    final key = GlobalKey<DestinationFeeFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DestinationFeeFields(
              key: key,
              destinationId: 42,
              childAges: const [4, 10],
            ),
          ),
        ),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Whole-trip destination allowance (₱)'),
      '400',
    );
    expect(key.currentState!.validatedSelection()!.allowance, {
      'category': 'destination',
      'destination_id': 42,
      'amount': '400.00',
    });

    await tester.tap(
      find.byKey(const ValueKey('destination-fee-mode-42-allowance')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adult and child fees').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Adult fee per person (₱)'),
      '100',
    );
    expect(key.currentState!.validatedSelection(), isNull);
    await tester.pump();
    expect(find.text('Choose a fee rule for every child age.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('destination-42-age-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Free').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('destination-42-age-10')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Half price').last);
    await tester.pumpAndSettle();

    final selection = key.currentState!.validatedSelection()!;
    expect(selection.allowance, isNull);
    expect(selection.ageRule, {
      'category': 'destination',
      'reference_id': 'destination:42',
      'adult_unit_amount': '100.00',
      'child_bands': [
        {'min_age': 4, 'max_age': 4, 'rate': 'free'},
        {'min_age': 10, 'max_age': 10, 'rate': 'half'},
      ],
    });
  });

  testWidgets('reopens age rules and removes rates for an edited child age', (
    tester,
  ) async {
    final key = GlobalKey<DestinationFeeFieldsState>();
    Widget screen(List<int> ages) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: DestinationFeeFields(
            key: key,
            destinationId: 7,
            childAges: ages,
            initialAgeRule: const {
              'category': 'destination',
              'reference_id': 'destination:7',
              'adult_unit_amount': '80.00',
              'child_bands': [
                {'min_age': 4, 'max_age': 4, 'rate': 'free'},
                {'min_age': 10, 'max_age': 10, 'rate': 'full'},
              ],
            },
          ),
        ),
      ),
    );

    await tester.pumpWidget(screen(const [4, 10]));
    expect(
      key.currentState!.validatedSelection()!.ageRule!['child_bands'],
      hasLength(2),
    );

    await tester.pumpWidget(screen(const [10, 12]));
    expect(key.currentState!.validatedSelection(), isNull);
    await tester.pump();
    expect(find.text('Choose a fee rule for every child age.'), findsOneWidget);
  });

  testWidgets('keeps entered fees when the review sheet scrolls to submit', (
    tester,
  ) async {
    final key = GlobalKey<DestinationFeeFieldsState>();
    DestinationFeeSelection? submitted;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            children: [
              DestinationFeeFields(
                key: key,
                destinationId: 42,
                childAges: const [10],
              ),
              const SizedBox(height: 1600),
              FilledButton(
                key: const ValueKey('submit-fees'),
                onPressed: () =>
                    submitted = key.currentState?.validatedSelection(),
                child: const Text('Submit fees'),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Whole-trip destination allowance (₱)'),
      '250',
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('submit-fees')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.byKey(const ValueKey('submit-fees')));
    expect(submitted?.allowance?['amount'], '250.00');
  });
}
