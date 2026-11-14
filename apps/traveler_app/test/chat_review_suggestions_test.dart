import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/destination.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/chat_plan_review_sheet.dart';

/// Mimics the server: suggestions depend on the saved night count and budget.
class _DetailedProvider extends TripProvider {
  int nights;
  String? budget;
  Map<String, dynamic>? lastChanges;
  final List<Map<String, dynamic>> allowances;

  _DetailedProvider({
    this.nights = 0,
    this.budget = '10000.00',
    this.allowances = const [],
  });

  @override
  List<Destination> get destinations => [Destination.davaoDestinations.first];

  @override
  Map<String, dynamic> get chatPlanningState => {
    'destination_ids': <int>[1],
    'origin': {'label': 'Davao City'},
    'day_count': 2,
    'night_count': nights,
    'traveler_count': 2,
    'adult_count': 2,
    'child_ages': <int>[],
    'total_budget': budget,
    'selected_transport_option_ids': <String>['car'],
    'cost_allowances': allowances,
  };

  @override
  Future<bool> updateChatPlanning(Map<String, dynamic> changes) async {
    lastChanges = changes;
    nights = (changes['night_count'] as int?) ?? nights;
    notifyListeners();
    return true;
  }

  @override
  Map<String, dynamic>? get chatPlanningPreview => {
    'destinations': [
      {'destination_id': 1, 'name': 'Eden Nature Park & Resort'},
    ],
    'transport_options': [
      {'option_id': 'car', 'label': 'Car'},
    ],
    'activity_options': const [],
    'budget': {'missing_costs': []},
    'suggested_allowances': budget == null
        ? const []
        : nights > 0
        ? [
            {'category': 'transportation', 'amount': '2000.00'},
            {'category': 'food', 'amount': '2500.00'},
            {'category': 'accommodation', 'amount': '3000.00'},
            {'category': 'other', 'amount': '500.00'},
          ]
        : [
            {'category': 'transportation', 'amount': '2500.00'},
            {'category': 'food', 'amount': '3000.00'},
          ],
  };
}

Future<Finder> _open(WidgetTester tester, TripProvider provider) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ChatPlanReviewSheet(provider: provider)),
    ),
  );
  await tester.pumpAndSettle();
  final scrollable = find
      .descendant(
        of: find.byType(ChatPlanReviewSheet),
        matching: find.byType(Scrollable),
      )
      .first;
  await tester.scrollUntilVisible(
    find.byKey(const Key('suggest-amounts')),
    300,
    scrollable: scrollable,
  );
  await tester.ensureVisible(find.byKey(const Key('suggest-amounts')));
  await tester.pumpAndSettle();
  return scrollable;
}

String _text(WidgetTester tester, String label) => tester
    .widget<TextField>(find.widgetWithText(TextField, label))
    .controller!
    .text;

const _transport = 'All transport and transfers (₱)';
const _food = 'Whole-trip food (₱)';
const _lodging = 'Whole-trip accommodation, if overnight (₱)';
const _other = 'Whole-trip other expenses, optional (₱)';

void main() {
  testWidgets('detailed planner suggest button fills empty boxes', (
    tester,
  ) async {
    await _open(tester, _DetailedProvider(nights: 1));
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();

    expect(_text(tester, _transport), '2000');
    expect(_text(tester, _food), '2500');
    expect(_text(tester, _lodging), '3000');
    expect(_text(tester, _other), '500');
  });

  testWidgets('changing nights in the sheet then suggesting adds lodging', (
    tester,
  ) async {
    final provider = _DetailedProvider();
    final scrollable = await _open(tester, provider);
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();
    expect(_text(tester, _lodging), isEmpty);

    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Nights (confirm)'),
      -300,
      scrollable: scrollable,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Nights (confirm)'),
      '1',
    );
    await tester.scrollUntilVisible(
      find.byKey(const Key('suggest-amounts')),
      300,
      scrollable: scrollable,
    );
    await tester.ensureVisible(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();

    expect(provider.lastChanges, {'night_count': 1});
    expect(_text(tester, _lodging), '3000');
    expect(_text(tester, _transport), '2000');
  });

  testWidgets('suggest button never overwrites an amount the traveler set', (
    tester,
  ) async {
    await _open(
      tester,
      _DetailedProvider(
        nights: 1,
        allowances: [
          {'category': 'food', 'amount': '900.00'},
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();

    expect(_text(tester, _food), '900.00');
    expect(_text(tester, _transport), '2000');
  });

  testWidgets('without a budget the button asks for one', (tester) async {
    await _open(tester, _DetailedProvider(nights: 1, budget: null));
    await tester.tap(find.byKey(const Key('suggest-amounts')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Enter a whole-trip budget'), findsOneWidget);
  });
}
