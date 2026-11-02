import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:final_adminlakbay/screens/destination_editor.dart';
import 'package:final_adminlakbay/services/api_service.dart';
import 'package:final_adminlakbay/widgets/admin_widgets.dart';

const _destination = <String, dynamic>{
  'destination_id': 12,
  'name': 'Eden Nature Park',
  'description': 'Original traveler description',
  'district': 'Davao City',
  'location': 'Toril',
  'category': 'Nature',
  'lat': 7.01,
  'lng': 125.43,
  'activities': 'Hiking, guided walks',
  'estimated_cost': '1500.00',
  'entrance_fee': 'PHP 150 / person',
  'overnight_fee': 'PHP 2500 / night',
  'is_kid_friendly': true,
  'family_friendly': true,
  'is_active': true,
  'created_at': '2026-10-01T00:00:00Z',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adminHasUnsavedChanges.value = false;
    adminIsSaving.value = false;
  });

  testWidgets('saving a renamed destination only patches the changed field', (
    tester,
  ) async {
    final requests = <http.Request>[];
    Map<String, dynamic>? saved;
    final api = _api((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({..._destination, 'name': 'Eden Mountain Park'}),
        200,
      );
    });
    addTearDown(api.close);
    await _pumpEditor(tester, api, onSaved: (value) => saved = value);
    await _enter(tester, 'Destination name *', 'Eden Mountain Park');
    expect(adminHasUnsavedChanges.value, isTrue);

    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save destination'),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'PATCH');
    expect(requests.single.url.path, '/api/v1/destinations/12');
    expect(jsonDecode(requests.single.body), {'name': 'Eden Mountain Park'});
    expect(saved?['activities'], _destination['activities']);
    expect(saved?['entrance_fee'], _destination['entrance_fee']);
    expect(saved?['family_friendly'], isTrue);
    expect(adminHasUnsavedChanges.value, isFalse);
    expect(adminIsSaving.value, isFalse);
    expect(find.text('Saved destination'), findsOneWidget);
  });

  testWidgets(
    'invalid coordinates and excessive decimal precision prevent requests',
    (tester) async {
      var requests = 0;
      final api = _api((request) async {
        requests++;
        return http.Response(jsonEncode(_destination), 200);
      });
      addTearDown(api.close);
      await _pumpEditor(tester, api);
      await _enter(tester, 'Latitude *', '91');
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save destination'),
      );
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(find.text('Use a value between -90.0 and 90.0.'), findsOneWidget);
      expect(find.byType(DestinationEditor), findsOneWidget);
      expect(adminIsSaving.value, isFalse);

      await _enter(tester, 'Latitude *', '7.02');
      await _enter(tester, 'Estimated cost (PHP)', '1500.001');
      await _tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save destination'),
      );
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(
        find.text('Enter 0 to 99,999,999.99 with at most two decimal places.'),
        findsOneWidget,
      );
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Estimated cost (PHP)'),
      );
      expect(field.controller!.text, '1500.001');
      expect(adminHasUnsavedChanges.value, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('blank cost clears an existing estimate', (tester) async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({..._destination, 'estimated_cost': null}),
        200,
      );
    });
    addTearDown(api.close);
    await _pumpEditor(tester, api);
    await _enter(tester, 'Estimated cost (PHP)', '');
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save destination'),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body), {'estimated_cost': null});
  });

  testWidgets('zero cost is sent as a known zero', (tester) async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({..._destination, 'estimated_cost': '0.00'}),
        200,
      );
    });
    addTearDown(api.close);
    await _pumpEditor(tester, api);
    await _enter(tester, 'Estimated cost (PHP)', '0');
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save destination'),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(jsonDecode(requests.single.body), {'estimated_cost': '0'});
  });

  testWidgets('new destination leaves unknown cost as null', (tester) async {
    final requests = <http.Request>[];
    final api = _api((request) async {
      requests.add(request);
      return http.Response(
        jsonEncode({..._destination, 'estimated_cost': null}),
        201,
      );
    });
    addTearDown(api.close);
    await _pumpEditor(tester, api, destination: null);
    await _enter(tester, 'Destination name *', 'New Park');
    await _enter(tester, 'Latitude *', '7.01');
    await _enter(tester, 'Longitude *', '125.43');
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save destination'),
    );
    await tester.pumpAndSettle();

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect((jsonDecode(requests.single.body) as Map)['estimated_cost'], isNull);
  });

  testWidgets('dirty Cancel keeps entered values until discard is confirmed', (
    tester,
  ) async {
    var cancelled = 0;
    var requests = 0;
    final api = _api((request) async {
      requests++;
      return http.Response(jsonEncode(_destination), 200);
    });
    addTearDown(api.close);
    await _pumpEditor(tester, api, onCancel: () => cancelled++);
    await _enter(tester, 'Destination name *', 'A changed destination');

    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();

    expect(cancelled, 0);
    expect(adminHasUnsavedChanges.value, isTrue);
    final name = tester.widget<TextFormField>(
      find.widgetWithText(TextFormField, 'Destination name *'),
    );
    expect(name.controller!.text, 'A changed destination');

    await _tapVisible(tester, find.widgetWithText(OutlinedButton, 'Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();

    expect(cancelled, 1);
    expect(requests, 0);
    expect(find.byType(DestinationEditor), findsNothing);
    expect(find.text('Returned to destination'), findsOneWidget);
    expect(adminHasUnsavedChanges.value, isFalse);
  });

  testWidgets('pending save blocks navigation until its response completes', (
    tester,
  ) async {
    final response = Completer<http.Response>();
    var requests = 0;
    final api = _api((request) {
      requests++;
      return response.future;
    });
    addTearDown(api.close);
    await _pumpEditor(tester, api);
    await _enter(tester, 'Destination name *', 'Saving a changed destination');
    await _tapVisible(
      tester,
      find.widgetWithText(FilledButton, 'Save destination'),
    );
    await tester.pump();

    expect(requests, 1);
    expect(adminIsSaving.value, isTrue);
    final allowed = await confirmAdminNavigation(
      tester.element(find.byType(DestinationEditor)),
    );
    await tester.pump();
    expect(allowed, isFalse);
    expect(
      find.text('Please wait for the current change to finish.'),
      findsOneWidget,
    );
    expect(
      tester
          .widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Cancel'))
          .onPressed,
      isNull,
    );
    expect(adminHasUnsavedChanges.value, isTrue);

    response.complete(
      http.Response(
        jsonEncode({..._destination, 'name': 'Saving a changed destination'}),
        200,
      ),
    );
    await tester.pumpAndSettle();
    expect(adminIsSaving.value, isFalse);
    expect(adminHasUnsavedChanges.value, isFalse);
    expect(
      await confirmAdminNavigation(tester.element(find.byType(Scaffold))),
      isTrue,
    );
    expect(find.text('Saved destination'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

ApiService _api(Future<http.Response> Function(http.Request) handler) =>
    ApiService(
      client: MockClient(handler),
      tokenProvider: () async => 'test-access',
      apiBaseUrl: 'http://lakbay.test/api/v1',
    );

Future<void> _pumpEditor(
  WidgetTester tester,
  ApiService api, {
  Map<String, dynamic>? destination = _destination,
  ValueChanged<Map<String, dynamic>>? onSaved,
  VoidCallback? onCancel,
}) async {
  tester.view.physicalSize = const Size(1200, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  var open = true;
  var result = '';
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: open
              ? DestinationEditor(
                  api: api,
                  destination: destination,
                  onSaved: (record) {
                    onSaved?.call(record);
                    setState(() {
                      open = false;
                      result = 'Saved destination';
                    });
                  },
                  onCancel: () {
                    onCancel?.call();
                    setState(() {
                      open = false;
                      result = 'Returned to destination';
                    });
                  },
                )
              : Text(result),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String label, String value) async {
  final field = find.widgetWithText(TextFormField, label);
  await tester.ensureVisible(field);
  await tester.enterText(field, value);
  await tester.pump();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}
