import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/core/routes/app_routes.dart';
import 'package:lakbay_plus/core/theme/app_theme.dart';
import 'package:lakbay_plus/models/destination.dart';
import 'package:lakbay_plus/providers/auth_provider.dart';
import 'package:lakbay_plus/providers/nav_provider.dart';
import 'package:lakbay_plus/providers/trip_provider.dart';
import 'package:lakbay_plus/screens/destinations/destination_details_screen.dart';
import 'package:lakbay_plus/services/api_service.dart';
import 'package:provider/provider.dart';

class _SignedInAuthProvider extends AuthProvider {
  @override
  bool get isAuthenticated => true;
}

void main() {
  testWidgets('destination preview explains guest actions on a small phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final originalBaseUrl = ApiService.baseUrl;
    ApiService.baseUrl = 'http://127.0.0.1:1/api/v1';
    addTearDown(() => ApiService.baseUrl = originalBaseUrl);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => TripProvider()),
          ChangeNotifierProvider(create: (_) => NavProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: DestinationDetailsScreen(
            destination: Destination.davaoDestinations[2],
          ),
          routes: {
            AppRoutes.signup: (_) =>
                const Scaffold(body: Center(child: Text('Sign up page'))),
          },
        ),
      ),
    );
    await tester.pump();

    expect(find.text('GOOD TO KNOW BEFORE YOU GO'), findsOneWidget);
    expect(find.text('See map & directions'), findsOneWidget);
    expect(find.text('Sign Up to Save'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('See map & directions'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('See map & directions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('See map & directions'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.text('Location & Route')).dy,
      inInclusiveRange(0, 640),
    );

    await tester.tap(find.text('Sign Up to Save'));
    await tester.pumpAndSettle();
    expect(find.text('Sign up page'), findsOneWidget);
  });

  testWidgets('Lakbay+ planner starts with the current destination', (
    tester,
  ) async {
    final originalBaseUrl = ApiService.baseUrl;
    ApiService.baseUrl = 'http://127.0.0.1:1/api/v1';
    addTearDown(() => ApiService.baseUrl = originalBaseUrl);

    final destination = Destination.davaoDestinations[2];
    final trips = TripProvider();
    final nav = NavProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>(
            create: (_) => _SignedInAuthProvider(),
          ),
          ChangeNotifierProvider<TripProvider>.value(value: trips),
          ChangeNotifierProvider<NavProvider>.value(value: nav),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          DestinationDetailsScreen(destination: destination),
                    ),
                  ),
                  child: const Text('Open destination'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open destination'));
    await tester.pumpAndSettle();
    final planButton = find.text('Plan this place');
    await tester.ensureVisible(planButton);
    await tester.pumpAndSettle();
    await tester.tap(planButton);
    await tester.pumpAndSettle();

    expect(trips.activePlanDestination?.id, destination.id);
    expect(nav.currentIndex, 1);
    expect(find.text('Open destination'), findsOneWidget);
  });
}
