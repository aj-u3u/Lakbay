import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/chat_ai_options_sheet.dart';

Map<String, dynamic> _option(int number, String title, String total, {bool over = false}) => {
  'option_number': number,
  'title': title,
  'summary': 'Summary for $title.',
  'estimated_total_cost': total,
  'is_over_budget': over,
  'quality_warnings': <String>[],
  'days': [
    {
      'day': 1,
      'title': 'Day one',
      'summary': 'Start.',
      'activities': [
        {'time': '9:00', 'title': 'Swim', 'description': 'Beach time.', 'estimated_cost': '200.00'},
      ],
    },
  ],
};

class _SheetProvider extends TripProvider {
  int? selected;
  final List<int> selections = [];

  @override
  List<Map<String, dynamic>> get chatAIOptions => [
    _option(1, 'Cheap and cheerful', '4000.00'),
    _option(2, 'All the sights', '9000.00'),
    _option(3, 'Splurge weekend', '15000.00', over: true),
  ];

  @override
  int? get chatSelectedOptionNumber => selected;

  @override
  Map<String, dynamic>? get chatPlanningPreview => {
    'whole_trip_budget': '10000.00',
    'destinations': [
      {'destination_id': 7, 'name': 'Beach 7'},
    ],
  };

  @override
  bool selectChatAIOption(int optionNumber) {
    selections.add(optionNumber);
    selected = optionNumber;
    notifyListeners();
    return true;
  }
}

Future<void> _open(WidgetTester tester, _SheetProvider provider) async {
  tester.view.physicalSize = const Size(900, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ChatAIOptionsSheet(provider: provider, onSaved: () {}),
      ),
    ),
  );
}

void main() {
  testWidgets('the detailed planner shows each option as a comparison card', (
    tester,
  ) async {
    final provider = _SheetProvider();
    await _open(tester, provider);

    for (final number in [1, 2, 3]) {
      expect(find.byKey(Key('itinerary-card-$number')), findsOneWidget);
    }
    expect(find.text('Cheap and cheerful'), findsOneWidget);
    expect(find.text('₱4,000'), findsOneWidget);
    expect(find.text('₱6,000 under budget'), findsOneWidget);
    expect(find.text('₱5,000 over budget'), findsOneWidget);
    expect(find.text('Best value'), findsOneWidget); // option 1: cheapest within budget
    expect(find.text('Most to do'), findsNothing); // every option has one activity
    // Choose-then-save: the card button selects; one button below saves.
    expect(find.text('Select this itinerary'), findsNWidgets(3));
    expect(find.text('Save this itinerary'), findsNothing);
    expect(find.text('Save selected itinerary'), findsOneWidget);
  });

  testWidgets('tapping Select marks that card as selected', (tester) async {
    final provider = _SheetProvider();
    await _open(tester, provider);

    await tester.tap(find.byKey(const Key('itinerary-save-2')));
    await tester.pumpAndSettle();

    expect(provider.selections, [2]);
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Select this itinerary'), findsNWidgets(2));
  });
}
