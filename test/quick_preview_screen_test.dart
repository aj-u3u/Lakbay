import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/core/routes/app_routes.dart';
import 'package:lakbay_plus/core/theme/app_theme.dart';
import 'package:lakbay_plus/screens/auth/quick_preview_screen.dart';

void main() {
  testWidgets('preview introduces Lakbay+ and keeps sign up visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const QuickPreviewScreen(),
        routes: {
          AppRoutes.signup: (_) =>
              const Scaffold(body: Center(child: Text('Sign up page'))),
          AppRoutes.login: (_) =>
              const Scaffold(body: Center(child: Text('Sign in page'))),
          AppRoutes.destinationList: (_) =>
              const Scaffold(body: Center(child: Text('Destination list'))),
        },
      ),
    );

    expect(
      find.text('Ready to plan your next adventure?', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('Sign up to unlock the full interactive experience'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Sign Up'));
    await tester.pumpAndSettle();
    expect(find.text('Sign up page'), findsOneWidget);
  });

  testWidgets('guest can browse destinations from the photo', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const QuickPreviewScreen(),
        routes: {
          AppRoutes.destinationList: (_) =>
              const Scaffold(body: Center(child: Text('Destination list'))),
        },
      ),
    );

    final browsePhoto = find.byKey(const Key('browse_davao_destinations'));
    await tester.ensureVisible(browsePhoto);
    await tester.pumpAndSettle();
    await tester.tap(browsePhoto);
    await tester.pumpAndSettle();
    expect(find.text('Destination list'), findsOneWidget);
  });
}
