import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/models/chat_planning_session.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/services/api_service.dart';

void main() {
  test('stale previews cannot replace newer traveler edits', () {
    final planning = ChatPlanningSession()..reset();
    final oldRevision = planning.revision;
    planning.edit({
      'destination_ids': <int>[7],
    });
    expect(
      planning.acceptPreview({
        'input_revision': oldRevision,
        'state': {
          'destination_ids': <int>[1],
        },
      }, oldRevision),
      isFalse,
    );
    expect(planning.destinationIds, [7]);
  });

  group('chat planning HTTP contract', () {
    late HttpServer server;
    late String originalBaseUrl;
    late ApiService api;
    Map<String, dynamic> Function(Map<String, dynamic>)? chatReply;
    final requests = <String, Map<String, dynamic>>{};

    setUp(() async {
      requests.clear();
      chatReply = null;
      originalBaseUrl = ApiService.baseUrl;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      ApiService.baseUrl = 'http://127.0.0.1:${server.port}/api/v1';
      api = ApiService.testing()..setToken('test-token');
      server.listen((request) async {
        final path = request.uri.path;
        final body =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        requests[path] = body;
        Object response;
        var status = 200;
        if (path == '/api/v1/planning/preview') {
          final state = body['state'] as Map<String, dynamic>;
          response = _preview(state, body['input_revision'] as int);
        } else if (path == '/api/v1/planning/feedback') {
          response = {
            'input_revision': body['input_revision'],
            'traveling_with_children': body['traveling_with_children'],
            'status': 'needs_review',
            'findings': [
              {
                'code': 'arrival_unverified',
                'category': 'route',
                'severity': 'review',
                'message': 'Visitor arrival point needs confirmation.',
                'destination_ids': [7],
              },
            ],
            'preview': _preview(
              body['state'] as Map<String, dynamic>,
              body['input_revision'] as int,
            ),
          };
        } else if (path == '/api/v1/ai/chat') {
          final state = body['planning_state'] as Map<String, dynamic>;
          response =
              chatReply?.call(body) ??
              {
                'chat_response': 'I can help plan Davao.',
                'planning': {
                  'input_revision': body['input_revision'],
                  'update_status': 'no_change',
                  'preview': _preview(state, body['input_revision'] as int),
                  'recommendation_total_candidates': 5,
                  'recommendations': [
                    for (var id = 7; id <= 11; id++)
                      {
                        'destination_id': id,
                        'name': 'Beach $id',
                        'district': 'Davao Oriental',
                        'category': 'beach',
                        'estimated_cost': '300.00',
                        'reasons': ['Matches preferred destination category.'],
                      },
                  ],
                },
              };
        } else if (path == '/api/v1/ai/itineraries/generate') {
          response = {
            'selected_generation_run_id': 55,
            'planning_preview': _preview(
              body['planning_state'] as Map<String, dynamic>,
              body['input_revision'] as int,
            ),
            'options': [
              {
                'option_number': 2,
                'title': 'Davao visit',
                'summary': 'One day in Davao',
                'estimated_total_cost': '1400.00',
                'days': [
                  {
                    'day': 1,
                    'title': 'Explore',
                    'activities': [
                      {
                        'time': '09:00',
                        'title': 'Visit the park',
                        'description': 'Walk around',
                        'estimated_cost': '100.00',
                        'destination_id': 7,
                      },
                    ],
                  },
                ],
              },
            ],
          };
        } else if (path == '/api/v1/trips/from-ai-option') {
          status = 201;
          response = {
            'trip_id': 101,
            'title': 'Davao visit',
            'total_budget': '1500.00',
            'traveler_count': 1,
            'destinations': [
              {'destination_id': 7, 'name': 'Davao Park'},
            ],
            'itinerary_days': [],
          };
        } else {
          status = 404;
          response = {'detail': 'missing'};
        }
        request.response
          ..statusCode = status
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(response));
        await request.response.close();
      });
    });

    tearDown(() async {
      ApiService.baseUrl = originalBaseUrl;
      await server.close(force: true);
    });

    test(
      'chat carries state and revision; incomplete costs block generation',
      () async {
        final provider = TripProvider(apiService: api)..startChatPlanning();
        expect(await provider.sendFreeFormChat('Plan a trip'), isTrue);
        final chat = requests['/api/v1/ai/chat']!;
        expect(chat['planning_state'], isA<Map>());
        expect(chat['input_revision'], provider.chatPlanningRevision);
        expect(provider.latestChatResponse, 'I can help plan Davao.');
        expect(provider.chatSuggestions, hasLength(5));
        expect(provider.chatSuggestions.first.id, 7);
        expect(provider.canGenerateChatPlan, isFalse);
        expect(await provider.generateChatItinerary(), isFalse);
        expect(
          requests.containsKey('/api/v1/ai/itineraries/generate'),
          isFalse,
        );
      },
    );

    test('reviewed plan generates and saves exact AI option', () async {
      final provider = TripProvider(apiService: api)..startChatPlanning();
      expect(
        await provider.updateChatPlanning({
          'origin': {'label': 'Davao City'},
          'destination_ids': <int>[7],
          'total_budget': '1500.00',
          'traveler_count': 2,
          'adult_count': 1,
          'child_ages': <int>[9],
          'day_count': 1,
          'night_count': 0,
          'return_to_origin': true,
          'selected_transport_option_ids': <String>['mode:personal_vehicle'],
          'cost_allowances': [
            {
              'category': 'destination',
              'destination_id': 7,
              'amount': '300.00',
            },
            {'category': 'transportation', 'amount': '200.00'},
            {'category': 'food', 'amount': '400.00'},
          ],
        }),
        isTrue,
      );
      expect(provider.canGenerateChatPlan, isTrue);
      expect(await provider.generateChatItinerary(), isTrue);
      final generate = requests['/api/v1/ai/itineraries/generate']!;
      expect(generate['destination_ids'], [7]);
      expect(generate['planning_state']['cost_allowances'], hasLength(3));
      expect(generate['planning_state']['adult_count'], 1);
      expect(generate['planning_state']['child_ages'], [9]);
      expect(provider.latestGeneratedTrip!.id, 'ai-chat-55-2');
      final feedback = await provider.reviewChatPlanningFeedback(
        travelingWithChildren: true,
      );
      expect(feedback?.status, 'needs_review');
      expect(feedback?.findings.single.code, 'arrival_unverified');
      expect(requests['/api/v1/planning/feedback'], {
        'state': provider.chatPlanningState,
        'input_revision': provider.chatPlanningRevision,
        'traveling_with_children': true,
      });
      expect(await provider.saveGeneratedTrip(), isTrue);
      expect(requests['/api/v1/trips/from-ai-option'], {
        'generation_run_id': 55,
        'option_number': 2,
      });
      expect(provider.userTrips.single.id, '101');
    });

    test(
      'destination age rule reaches preview and AI without an allowance',
      () async {
        final provider = TripProvider(apiService: api)..startChatPlanning();
        expect(
          await provider.updateChatPlanning({
            'origin': {'label': 'Davao City'},
            'destination_ids': <int>[7],
            'total_budget': '1500.00',
            'traveler_count': 2,
            'adult_count': 1,
            'child_ages': <int>[10],
            'day_count': 1,
            'night_count': 0,
            'return_to_origin': true,
            'selected_transport_option_ids': <String>['mode:personal_vehicle'],
            'age_pricing_rules': [
              {
                'category': 'destination',
                'reference_id': 'destination:7',
                'adult_unit_amount': '100.00',
                'child_bands': [
                  {'min_age': 10, 'max_age': 10, 'rate': 'half'},
                ],
              },
            ],
            'cost_allowances': [
              {'category': 'transportation', 'amount': '200.00'},
              {'category': 'food', 'amount': '400.00'},
            ],
          }),
          isTrue,
        );
        final preview = requests['/api/v1/planning/preview']!;
        expect(preview['state']['age_pricing_rules'], hasLength(1));
        expect(preview['state']['cost_allowances'], hasLength(2));
        expect(provider.canGenerateChatPlan, isTrue);

        expect(await provider.generateChatItinerary(), isTrue);
        final generate = requests['/api/v1/ai/itineraries/generate']!;
        expect(generate['planning_state']['age_pricing_rules'], hasLength(1));
        expect(generate['planning_state']['child_ages'], [10]);
        expect(generate['planning_state']['cost_allowances'], hasLength(2));
      },
    );

    test('selected activity and confirmed cost reach preview and AI', () async {
      const activityId = 'activity:7:0123456789abcdef';
      final provider = TripProvider(apiService: api)..startChatPlanning();
      expect(
        await provider.updateChatPlanning({
          'origin': {'label': 'Davao City'},
          'destination_ids': <int>[7],
          'total_budget': '1500.00',
          'traveler_count': 1,
          'day_count': 1,
          'night_count': 0,
          'return_to_origin': true,
          'selected_transport_option_ids': <String>['mode:personal_vehicle'],
          'selected_activity_option_ids': <String>[activityId],
          'cost_allowances': [
            {
              'category': 'destination',
              'destination_id': 7,
              'amount': '300.00',
            },
            {
              'category': 'activity',
              'option_id': activityId,
              'amount': '50.00',
            },
            {'category': 'transportation', 'amount': '200.00'},
            {'category': 'food', 'amount': '400.00'},
          ],
        }),
        isTrue,
      );
      final previewState =
          requests['/api/v1/planning/preview']!['state'] as Map;
      expect(previewState['selected_activity_option_ids'], [activityId]);
      expect(provider.canGenerateChatPlan, isTrue);

      expect(await provider.generateChatItinerary(), isTrue);
      final generationState =
          requests['/api/v1/ai/itineraries/generate']!['planning_state'] as Map;
      expect(generationState['selected_activity_option_ids'], [activityId]);
      expect(
        (generationState['cost_allowances'] as List)
            .where((item) => item['category'] == 'activity')
            .single['amount'],
        '50.00',
      );
    });

    test(
      'partial chat update clears itinerary from the previous plan',
      () async {
        final provider = TripProvider(apiService: api)..startChatPlanning();
        expect(
          await provider.updateChatPlanning({
            'origin': {'label': 'Davao City'},
            'destination_ids': <int>[7],
            'total_budget': '1500.00',
            'traveler_count': 1,
            'day_count': 1,
            'night_count': 0,
            'return_to_origin': true,
            'selected_transport_option_ids': <String>['mode:personal_vehicle'],
            'cost_allowances': [
              {
                'category': 'destination',
                'destination_id': 7,
                'amount': '300.00',
              },
              {'category': 'transportation', 'amount': '200.00'},
              {'category': 'food', 'amount': '400.00'},
            ],
          }),
          isTrue,
        );
        expect(await provider.generateChatItinerary(), isTrue);
        expect(provider.chatAIOptions, isNotEmpty);
        expect(provider.latestGeneratedTrip, isNotNull);

        chatReply = (body) {
          final updatedState = {
            ...body['planning_state'] as Map<String, dynamic>,
            'total_budget': '2000.00',
          };
          return {
            'chat_response':
                'I changed the budget; please clarify the destination.',
            'planning': {
              'input_revision': body['input_revision'],
              'update_status': 'needs_clarification',
              'state_updates': {'total_budget': '2000.00'},
              'preview': _preview(updatedState, body['input_revision'] as int),
              'recommendations': [],
            },
          };
        };
        expect(
          await provider.sendFreeFormChat('Raise my budget to 2000'),
          isTrue,
        );
        expect(provider.chatPlanningState['total_budget'], '2000.00');
        expect(provider.chatAIOptions, isEmpty);
        expect(provider.latestGeneratedTrip, isNull);
      },
    );

    test(
      'changing selected destinations clears stale prices and choices',
      () async {
        final provider = TripProvider(apiService: api)..startChatPlanning();
        expect(
          await provider.updateChatPlanning({
            'destination_ids': <int>[7],
            'traveler_count': 2,
            'adult_count': 1,
            'child_ages': <int>[8],
            'age_pricing_rules': [
              {
                'category': 'destination',
                'reference_id': 'destination:7',
                'adult_unit_amount': '100.00',
                'child_bands': [
                  {'min_age': 8, 'max_age': 8, 'rate': 'half'},
                ],
              },
            ],
            'selected_transport_option_ids': <String>['mode:personal_vehicle'],
            'cost_allowances': [
              {
                'category': 'destination',
                'destination_id': 7,
                'amount': '300.00',
              },
              {'category': 'transportation', 'amount': '200.00'},
              {'category': 'food', 'amount': '400.00'},
            ],
          }),
          isTrue,
        );
        expect(await provider.setChatDestinationIds([7, 8]), isTrue);
        expect(provider.chatPlanningState['destination_ids'], [7, 8]);
        expect(provider.chatPlanningState['cost_allowances'], isEmpty);
        expect(provider.chatPlanningState['adult_count'], 1);
        expect(provider.chatPlanningState['child_ages'], [8]);
        expect(provider.chatPlanningState['age_pricing_rules'], isEmpty);
        expect(
          provider.chatPlanningState['selected_transport_option_ids'],
          isEmpty,
        );
        expect(provider.canGenerateChatPlan, isFalse);
      },
    );
  });
}

Map<String, dynamic> _preview(Map<String, dynamic> state, int revision) {
  final ids = (state['destination_ids'] as List? ?? const [])
      .whereType<int>()
      .toList();
  final activityIds =
      (state['selected_activity_option_ids'] as List? ?? const [])
          .whereType<String>()
          .toList();
  final allowances = (state['cost_allowances'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  final rules = (state['age_pricing_rules'] as List? ?? const [])
      .whereType<Map>()
      .toList();
  final complete =
      ids.isNotEmpty &&
      ids.every(
        (id) =>
            allowances.any(
              (item) =>
                  item['category'] == 'destination' &&
                  item['destination_id'] == id,
            ) ||
            rules.any(
              (item) =>
                  item['category'] == 'destination' &&
                  item['reference_id'] == 'destination:$id',
            ),
      ) &&
      allowances.any((item) => item['category'] == 'transportation') &&
      allowances.any((item) => item['category'] == 'food') &&
      activityIds.every(
        (id) => allowances.any(
          (item) =>
              (item['category'] == 'activity' && item['option_id'] == id) ||
              (item['category'] == 'destination' ||
                      item['category'] == 'food') &&
                  (item['includes_activity_option_ids'] as List? ?? const [])
                      .contains(id),
        ),
      );
  return {
    'input_revision': revision,
    'state': state,
    'destinations': [
      for (final id in ids) {'destination_id': id, 'name': 'Beach $id'},
    ],
    'budget': {
      'completeness': complete ? 'complete' : 'partial',
      'fit': complete ? 'fits_estimate' : 'undetermined',
      'total_estimate': complete ? '900.00' : null,
      'missing_costs': complete
          ? []
          : [
              {'message': 'Add cost assumptions'},
            ],
    },
    'missing_inputs': complete ? ['origin.coordinates'] : ['destination_ids'],
    'selection_problems': [],
  };
}
