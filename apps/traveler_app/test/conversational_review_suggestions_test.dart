import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/conversational_review_sheet.dart';

class _SuggestionProvider extends TripProvider {
  final List<Map<String, dynamic>> allowances;
  _SuggestionProvider({this.allowances = const []});

  @override
  Map<String, dynamic> get chatPlanningState => {
    'destination_ids': <int>[7],
    'origin': {'label': 'Davao City'},
    'day_count': 2,
    'night_count': 1,
    'traveler_count': 2,
    'adult_count': 2,
    'child_ages': <int>[],
    'total_budget': '10000.00',
    'selected_transport_option_ids': <String>['car'],
    'cost_allowances': allowances,
  };

  @override
  Map<String, dynamic>? get chatPlanningPreview => {
    'destinations': [
      {'destination_id': 7, 'name': 'Beach 7'},
    ],
    'transport_options': [
      {'option_id': 'car', 'label': 'Car'},
    ],
    'activity_options': const [],
    'budget': {'missing_costs': []},
    'suggested_allowances': [
      {'category': 'transportation', 'amount': '2000.00'},
      {'category': 'food', 'amount': '2500.00'},
      {'category': 'accommodation', 'amount': '3000.00'},
      {'category': 'other', 'amount': '500.00'},
    ],
  };
}

Future<ScrollableState> _open(WidgetTester tester, TripProvider provider) async {
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
    find.byKey(const Key('suggest-amounts')),
    300,
    scrollable: scrollable,
  );
  return tester.state<ScrollableState>(scrollable);
}

String _text(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

void main() {
  testWidgets('suggest button fills empty amount boxes', (tester) async {
    await _open(tester, _SuggestionProvider());
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();

    expect(_text(tester, 'Your whole-trip transport allowance (₱)'), '2000');
    expect(_text(tester, 'Your whole-trip food amount (₱)'), '2500');
    expect(_text(tester, 'Your whole-trip lodging amount (₱)'), '3000');
  });

  testWidgets('suggest button never overwrites an amount the traveler set', (
    tester,
  ) async {
    await _open(
      tester,
      _SuggestionProvider(
        allowances: [
          {'category': 'food', 'amount': '900.00'},
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();

    expect(_text(tester, 'Your whole-trip food amount (₱)'), '900.00');
    expect(_text(tester, 'Your whole-trip transport allowance (₱)'), '2000');
  });
}
