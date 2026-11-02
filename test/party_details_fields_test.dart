import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/widgets/inputs/party_details_fields.dart';

void main() {
  testWidgets('collects adults and one age per child', (tester) async {
    final key = GlobalKey<PartyDetailsFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartyDetailsFields(key: key, initialAdultCount: 2),
          ),
        ),
      ),
    );

    expect(key.currentState!.validatedState(2), {
      'adult_count': 2,
      'child_ages': <int>[],
    });
    await tester.tap(find.text('Add child'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Adults'), '1');
    await tester.enterText(find.widgetWithText(TextField, 'Child 1 age'), '9');
    expect(key.currentState!.validatedState(2), {
      'adult_count': 1,
      'child_ages': <int>[9],
    });
    await tester.tap(find.byTooltip('Remove child 1'));
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, 'Adults'), '2');
    expect(key.currentState!.validatedState(2), {
      'adult_count': 2,
      'child_ages': <int>[],
    });
  });

  testWidgets('reopens saved adult and child ages', (tester) async {
    final key = GlobalKey<PartyDetailsFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PartyDetailsFields(
            key: key,
            initialAdultCount: 1,
            initialChildAges: const [4, 10],
          ),
        ),
      ),
    );

    expect(key.currentState!.validatedState(3), {
      'adult_count': 1,
      'child_ages': <int>[4, 10],
    });
  });

  testWidgets('rejects missing ages and mismatched totals before submission', (
    tester,
  ) async {
    final key = GlobalKey<PartyDetailsFieldsState>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PartyDetailsFields(key: key, initialAdultCount: 2),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Add child'));
    await tester.pump();
    expect(key.currentState!.validatedState(2), isNull);
    await tester.pump();
    expect(find.text('Enter each child’s age from 0 to 17.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'Child 1 age'), '18');
    expect(key.currentState!.validatedState(2), isNull);
    await tester.enterText(find.widgetWithText(TextField, 'Child 1 age'), '8');
    expect(key.currentState!.validatedState(2), isNull);
    await tester.pump();
    expect(
      find.text('Adults and children must add up to 2 travelers.'),
      findsOneWidget,
    );
  });
}
