import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/destination.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/chat_plan_review_sheet.dart';

class _ChatReviewProvider extends TripProvider {
  Map<String, dynamic>? submitted;

  @override
  List<Destination> get destinations => [Destination.davaoDestinations.first];

  @override
  Map<String, dynamic> get chatPlanningState => {
    'destination_ids': <int>[1],
    'origin': {'label': 'Davao City'},
    'day_count': 1,
    'night_count': 0,
    'traveler_count': 1,
    'adult_count': 1,
    'child_ages': <int>[],
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
      {'destination_id': 1, 'name': 'Eden Nature Park & Resort'},
    ],
    'transport_options': [
      {'option_id': 'car', 'label': 'Car'},
    ],
    'activity_options': [
      {
        'option_id': 'activity:1:0123456789abcdef',
        'destination_id': 1,
        'label': 'Hiking',
      },
    ],
    'budget': {'missing_costs': []},
  };

  @override
  Future<bool> updateChatPlanning(Map<String, dynamic> changes) async {
    submitted = changes;
    return true;
  }
}

void main() {
  testWidgets('chat review includes activity in destination allowance', (
    tester,
  ) async {
    const activityId = 'activity:1:0123456789abcdef';
    final provider = _ChatReviewProvider();
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
    await tester.tap(
      find.byKey(const ValueKey('activity-cost-method-$activityId')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Included in destination allowance').last);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Review estimate'),
      300,
      scrollable: scrollable,
    );
    await tester.tap(find.text('Review estimate'));
    await tester.pumpAndSettle();

    expect(provider.submitted?['selected_activity_option_ids'], [activityId]);
    final allowances = provider.submitted?['cost_allowances'] as List;
    expect(allowances.firstWhere((item) => item['category'] == 'destination'), {
      'category': 'destination',
      'destination_id': 1,
      'amount': '300.00',
      'includes_activity_option_ids': [activityId],
    });
    expect(allowances.where((item) => item['category'] == 'activity'), isEmpty);
  });
}
