import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/destination.dart';
import 'package:lakbay_plus/widgets/cards/itinerary_option_card.dart';

Map<String, dynamic> _option({
  int number = 1,
  String total = '6462.00',
  bool over = false,
  int activities = 3,
  List<String> warnings = const [],
}) => {
  'option_number': number,
  'title': 'Relaxed beach weekend',
  'summary': 'Two easy days around Samal with time to swim.',
  'estimated_total_cost': total,
  'is_over_budget': over,
  'quality_warnings': warnings,
  'days': [
    {
      'day': 1,
      'title': 'Arrival',
      'summary': 'Settle in and see the beach.',
      'activities': [
        for (var i = 0; i < activities - 1; i++)
          {
            'time': '${9 + i}:00',
            'title': 'Activity $i',
            'description': 'Description $i',
            'estimated_cost': i == 0 ? '500.00' : '0.00',
          },
      ],
    },
    {
      'day': 2,
      'title': 'Island hopping',
      'summary': 'Boat day.',
      'activities': [
        {
          'time': '8:00',
          'title': 'Boat tour',
          'description': 'Half-day boat tour.',
          'estimated_cost': '1200.00',
        },
      ],
    },
  ],
};

Future<void> _show(
  WidgetTester tester,
  Widget card,
) async {
  tester.view.physicalSize = const Size(800, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: card)),
    ),
  );
}

void main() {
  group('peso', () {
    test('formats whole pesos with thousands separators', () {
      expect(ItineraryOptionCard.peso('6462.00'), '₱6,462');
      expect(ItineraryOptionCard.peso('1234567.89'), '₱1,234,568');
      expect(ItineraryOptionCard.peso(500), '₱500');
      expect(ItineraryOptionCard.peso(0), '₱0');
    });

    test('shows a dash when the amount is missing or not a number', () {
      expect(ItineraryOptionCard.peso(null), '₱—');
      expect(ItineraryOptionCard.peso('n/a'), '₱—');
    });
  });

  group('badgesFor', () {
    test('cheapest within-budget option is "Best value"; most activities is "Most to do"',
        () {
      final options = [
        _option(number: 1, total: '5000.00', activities: 3),
        _option(number: 2, total: '7000.00', activities: 6),
        _option(number: 3, total: '2000.00', over: true, activities: 4),
      ];
      final badges = ItineraryOptionCard.badgesFor(options);

      // Option 3 is cheapest but over budget, so it cannot be "Best value".
      expect(badges[1], ['Best value']);
      expect(badges[2], ['Most to do']);
      expect(badges.containsKey(3), isFalse);
    });

    test('accepts the List<Map<String, dynamic>> the planner screen passes', () {
      final typed = <Map<String, dynamic>>[
        _option(number: 1, total: '5000.00', activities: 3),
        _option(number: 2, total: '7000.00', activities: 6),
      ];
      final badges = ItineraryOptionCard.badgesFor(typed);

      expect(badges[1], ['Best value']);
      expect(badges[2], ['Most to do']);
    });

    test('a single option or exact ties get no badge', () {
      expect(ItineraryOptionCard.badgesFor([_option()]), isEmpty);
      final tied = ItineraryOptionCard.badgesFor([
        _option(number: 1, total: '5000.00', activities: 3),
        _option(number: 2, total: '5000.00', activities: 3),
      ]);
      expect(tied, isEmpty);
    });
  });

  testWidgets('shows the title, places, facts and price with an under-budget chip', (
    tester,
  ) async {
    await _show(
      tester,
      ItineraryOptionCard(
        option: _option(),
        destinations: const [
          ItineraryCardDestination(name: 'Samal Island Beach'),
          ItineraryCardDestination(name: 'Eden Nature Park'),
        ],
        wholeTripBudget: 10000,
        badges: const ['Best value'],
      ),
    );

    expect(find.text('Relaxed beach weekend'), findsOneWidget);
    expect(find.text('Samal Island Beach, Eden Nature Park'), findsOneWidget);
    expect(find.textContaining('Two easy days around Samal'), findsOneWidget);
    expect(find.text('2 days'), findsOneWidget);
    expect(find.text('3 activities'), findsOneWidget);
    expect(find.text('2 stops'), findsOneWidget);
    expect(find.text('Best value'), findsOneWidget);
    expect(find.text('AI draft estimate'), findsOneWidget);
    expect(find.byKey(const Key('itinerary-price-1')), findsOneWidget);
    expect(find.text('₱6,462'), findsOneWidget);
    expect(find.text('₱3,538 under budget'), findsOneWidget);
  });

  testWidgets('an over-budget option shows the overage and a red badge', (
    tester,
  ) async {
    await _show(
      tester,
      ItineraryOptionCard(
        option: _option(total: '13000.00', over: true),
        wholeTripBudget: 10000,
      ),
    );

    expect(find.text('₱13,000'), findsOneWidget);
    expect(find.text('₱3,000 over budget'), findsOneWidget);
    expect(find.text('Over budget'), findsOneWidget); // the photo badge
    expect(find.textContaining('under budget'), findsNothing);
  });

  testWidgets('without a known budget it still flags an over-budget option', (
    tester,
  ) async {
    await _show(
      tester,
      ItineraryOptionCard(option: _option(over: true)),
    );

    expect(find.byKey(const Key('itinerary-budget-chip-1')), findsNothing);
    expect(find.text('Over budget'), findsWidgets);
  });

  testWidgets('the day-by-day plan is collapsed until opened', (tester) async {
    await _show(
      tester,
      ItineraryOptionCard(
        option: _option(warnings: const ['Opening hours are not verified.']),
      ),
    );

    expect(find.text('Day 1: Arrival'), findsNothing);
    expect(find.text('1 thing to check'), findsOneWidget);

    await tester.tap(find.text('Day-by-day plan'));
    await tester.pumpAndSettle();

    expect(find.text('Day 1: Arrival'), findsOneWidget);
    expect(find.text('Day 2: Island hopping'), findsOneWidget);
    expect(find.text('Boat tour'), findsOneWidget);
    expect(find.text('₱1,200'), findsOneWidget); // an activity's own estimate
    expect(find.text('Things to check'), findsOneWidget);
    expect(find.text('Opening hours are not verified.'), findsOneWidget);
  });

  testWidgets('a selected card says so and a custom action label is used', (
    tester,
  ) async {
    await _show(
      tester,
      ItineraryOptionCard(
        option: _option(),
        actionLabel: 'Select this itinerary',
      ),
    );
    expect(find.text('Select this itinerary'), findsOneWidget);
    expect(find.text('Selected'), findsNothing);

    await _show(
      tester,
      ItineraryOptionCard(
        option: _option(),
        actionLabel: 'Select this itinerary',
        selected: true,
      ),
    );
    expect(find.text('Selected'), findsOneWidget);
    expect(find.text('Select this itinerary'), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  test('contextFrom reads places, photos and budget from the preview', () {
    final catalog = <Destination>[
      Destination.fromJson({
        'destination_id': 7,
        'name': 'Beach 7',
        'image_url': 'assets/seven.jpg',
      }),
    ];
    final context = ItineraryOptionCard.contextFrom(
      {
        'whole_trip_budget': '12500.00',
        'destinations': [
          {'destination_id': 7, 'name': 'Beach 7'},
          {'destination_id': 8, 'name': 'No photo'},
        ],
      },
      catalog,
    );

    expect(context.destinations.map((d) => d.name), ['Beach 7', 'No photo']);
    expect(context.destinations[0].imageUrl, 'assets/seven.jpg');
    expect(context.destinations[1].imageUrl, isNull);
    expect(context.budget, 12500.0);

    final empty = ItineraryOptionCard.contextFrom(null, const []);
    expect(empty.destinations, isEmpty);
    expect(empty.budget, isNull);
  });

  testWidgets('Save calls back, and is disabled while another request runs', (
    tester,
  ) async {
    var saved = 0;
    await _show(
      tester,
      ItineraryOptionCard(option: _option(), onSelect: () => saved++),
    );
    await tester.tap(find.text('Save this itinerary'));
    expect(saved, 1);

    await _show(
      tester,
      ItineraryOptionCard(option: _option(), busy: true, onSelect: () => saved++),
    );
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('itinerary-save-1')),
    );
    expect(button.onPressed, isNull);
    expect(saved, 1);
  });
}
