import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:final_adminlakbay/screens/login_screen.dart';
import 'package:final_adminlakbay/widgets/app_shell.dart';
import 'package:final_adminlakbay/widgets/admin_widgets.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    adminHasUnsavedChanges.value = false;
    adminIsSaving.value = false;
  });

  testWidgets('invalid sign-in shows actionable validation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData(), home: const LoginScreen()),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'invalid-email');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow workspace uses a drawer and stays within viewport', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: const AppShell(child: Center(child: Text('Workspace content'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Workspace content'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
    expect(find.text('Destinations'), findsOneWidget);
    expect(find.text('Market Rates'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact desktop navigation has no layout overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 900);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(),
        home: const AppShell(child: Center(child: Text('Workspace content'))),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open navigation'), findsNothing);
    expect(find.byTooltip('Destinations'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
