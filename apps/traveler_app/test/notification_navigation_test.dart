import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:lakbay_plus/core/routes/app_routes.dart';
import 'package:lakbay_plus/models/app_notification.dart';
import 'package:lakbay_plus/models/trip.dart';
import 'package:lakbay_plus/providers/nav_provider.dart';
import 'package:lakbay_plus/screens/notifications/notifications_screen.dart';

void main() {
  testWidgets('AI plan notifications return to the planner tab', (
    tester,
  ) async {
    final navProvider = NavProvider();
    var navShellRoutesCreated = 0;
    final notification = AppNotification(
      id: 'plan-1',
      title: 'Plan ready',
      body: 'Your itinerary is ready.',
      time: 'Just now',
      icon: '⚡',
      isNew: true,
      type: NotificationType.aiPlan,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: navProvider,
        child: MaterialApp(
          initialRoute: AppRoutes.splash,
          onGenerateRoute: (settings) {
            if (settings.name == AppRoutes.splash ||
                settings.name == AppRoutes.navShell) {
              navShellRoutesCreated++;
            }
            return _testRoute(settings, navProvider, notification, const []);
          },
        ),
      ),
    );
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open notice'));
    await tester.pumpAndSettle();

    expect(navProvider.currentIndex, 1);
    expect(find.text('Current tab: 1'), findsOneWidget);
    expect(find.text('Open notice'), findsNothing);
    expect(navShellRoutesCreated, 1);
  });

  testWidgets('collaboration notifications open their matching trip', (
    tester,
  ) async {
    final navProvider = NavProvider();
    final trip = Trip.mockTrips.first;
    final notification = AppNotification(
      id: 'task-1',
      title: 'Task updated',
      body: 'A task changed.',
      time: 'Just now',
      icon: '✅',
      isNew: true,
      type: NotificationType.taskComplete,
      tripId: trip.id,
    );

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: navProvider,
        child: MaterialApp(
          initialRoute: AppRoutes.navShell,
          onGenerateRoute: (settings) =>
              _testRoute(settings, navProvider, notification, [trip]),
        ),
      ),
    );
    await tester.tap(find.text('Open notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open notice'));
    await tester.pumpAndSettle();

    expect(find.text('Opened tasks for ${trip.title}'), findsOneWidget);
  });
}

Route<dynamic> _testRoute(
  RouteSettings settings,
  NavProvider navProvider,
  AppNotification notification,
  List<Trip> trips,
) {
  if (settings.name == AppRoutes.navShell ||
      settings.name == AppRoutes.splash) {
    return MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            Consumer<NavProvider>(
              builder: (_, nav, _) => Text('Current tab: ${nav.currentIndex}'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pushNamed(context, AppRoutes.notifications),
              child: const Text('Open notifications'),
            ),
          ],
        ),
      ),
    );
  }
  if (settings.name == AppRoutes.notifications) {
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => handleNotificationTap(
            context,
            notification,
            markAsRead: () {},
            trips: trips,
          ),
          child: const Text('Open notice'),
        ),
      ),
    );
  }
  if (settings.name == AppRoutes.groupTasks) {
    final trip = settings.arguments as Trip;
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => Scaffold(body: Text('Opened tasks for ${trip.title}')),
    );
  }
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => const Scaffold(body: Text('Unknown route')),
  );
}
