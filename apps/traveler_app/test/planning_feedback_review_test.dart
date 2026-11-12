import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/planning_feedback.dart';
import 'package:lakbay_plus/models/trip.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/planner/chat_ai_options_sheet.dart';
import 'package:lakbay_plus/screens/planner/planning_feedback_dialog.dart';

class _FeedbackTripProvider extends TripProvider {
  final Trip _trip = Trip(
    id: 'ai-chat-55-2',
    title: 'Davao visit',
    destinationName: 'Davao City',
    dateRange: 'Flexible Dates',
    budget: 1500,
    imageUrl: '',
    itinerary: const <int, List<TripActivity>>{},
  );
  String feedbackStatus = 'needs_review';
  bool failFeedback = false;
  int saves = 0;
  final List<bool?> childChoices = [];

  @override
  Trip? get latestGeneratedTrip => _trip;

  @override
  int get chatPlanningRevision => 7;

  @override
  int? get chatSelectedOptionNumber => 2;

  @override
  List<Map<String, dynamic>> get chatAIOptions => [
    {
      'option_number': 2,
      'title': 'Davao visit',
      'summary': 'One day in Davao',
      'estimated_total_cost': '1400.00',
      'days': const [],
    },
  ];

  @override
  String? get errorMessage => failFeedback ? 'Feedback is unavailable.' : null;

  @override
  Future<PlanningFeedback?> reviewChatPlanningFeedback({
    bool? travelingWithChildren,
  }) async {
    childChoices.add(travelingWithChildren);
    if (failFeedback) return null;
    return PlanningFeedback(
      inputRevision: 7,
      status: feedbackStatus,
      travelingWithChildren: travelingWithChildren,
      findings: [
        PlanningFeedbackFinding(
          code: feedbackStatus == 'needs_details'
              ? 'trip_details_missing'
              : 'arrival_unverified',
          category: feedbackStatus == 'needs_details' ? 'data' : 'route',
          severity: feedbackStatus == 'needs_details' ? 'required' : 'review',
          message: feedbackStatus == 'needs_details'
              ? 'Complete the missing trip details.'
              : 'Visitor arrival point needs confirmation.',
          destinationIds: const [7],
        ),
        if (travelingWithChildren == true)
          const PlanningFeedbackFinding(
            code: 'child_suitability_review',
            category: 'suitability',
            severity: 'review',
            message: 'Check kid-friendly access before travel.',
            destinationIds: [7],
          ),
      ],
    );
  }

  @override
  Future<bool> addNewTrip(Trip trip) async {
    saves++;
    return true;
  }
}

void main() {
  test('malformed feedback cannot be treated as a clear review', () {
    expect(
      () => PlanningFeedback.fromJson({
        'input_revision': 7,
        'status': 'no_flagged_issues',
        'preview': <String, dynamic>{},
        'findings': [
          {
            'code': 'trip_details_missing',
            'category': 'data',
            'severity': 'required',
            'message': 'Complete the trip details.',
          },
        ],
      }),
      throwsFormatException,
    );
  });

  testWidgets('review warnings before saving and rerun child check', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final provider = _FeedbackTripProvider();
    var savedCallbacks = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAIOptionsSheet(
            provider: provider,
            onSaved: () => savedCallbacks++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Save selected itinerary'));
    await tester.pumpAndSettle();
    expect(find.byType(PlanningFeedbackDialog), findsOneWidget);
    expect(
      find.text('Visitor arrival point needs confirmation.'),
      findsOneWidget,
    );
    expect(provider.childChoices, [null]);

    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(provider.saves, 0);

    await tester.tap(find.text('Save selected itinerary'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Yes'));
    await tester.pumpAndSettle();
    expect(provider.childChoices, [null, null, true]);
    expect(
      find.text('Check kid-friendly access before travel.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Save with warnings'));
    await tester.pumpAndSettle();
    expect(provider.saves, 1);
    expect(savedCallbacks, 1);
  });

  testWidgets('required findings and failed checks do not save', (
    tester,
  ) async {
    final provider = _FeedbackTripProvider()..feedbackStatus = 'needs_details';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatAIOptionsSheet(provider: provider, onSaved: () {}),
        ),
      ),
    );
    await tester.tap(find.text('Save selected itinerary'));
    await tester.pumpAndSettle();
    expect(find.text('Complete the missing trip details.'), findsOneWidget);
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save itinerary'),
    );
    expect(save.onPressed, isNull);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(provider.saves, 0);

    provider.failFeedback = true;
    await tester.tap(find.text('Save selected itinerary'));
    await tester.pumpAndSettle();
    expect(find.text('Feedback is unavailable.'), findsOneWidget);
    expect(find.text('Retry check'), findsOneWidget);
    expect(provider.saves, 0);
  });
}
