import 'package:flutter/material.dart';
import '../../models/destination.dart';
import '../../models/trip.dart';
import '../../screens/auth/splash_screen.dart';
import '../../screens/auth/discover_screen.dart';
import '../../screens/auth/quick_preview_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/signup_screen.dart';
import '../../screens/auth/forgot_password_screen.dart';
import '../../screens/navigation/main_navigation.dart';
import '../../screens/destinations/destination_list_screen.dart';
import '../../screens/destinations/destination_details_screen.dart';
import '../../screens/planner/planner_results_screen.dart';
import '../../screens/collaboration/group_dashboard_screen.dart';
import '../../screens/collaboration/tasks_screen.dart';
import '../../screens/collaboration/shared_memories_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/destinations/district_hub_screen.dart';

class AppRoutes {
  static const String splash = '/';
  static const String discover = '/discover';
  static const String quickPreview = '/quick-preview';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';
  static const String navShell = '/nav-shell';
  static const String destinationList = '/destination-list';
  static const String destinationDetail = '/destination-detail';
  static const String plannerResults = '/planner-results';
  static const String groupDashboard = '/group-dashboard';
  static const String groupTasks = '/group-tasks';
  static const String groupMemories = '/group-memories';
  static const String notifications = '/notifications';
  static const String districtHub = '/district-hub';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case splash:
        return MaterialPageRoute(builder: (_) => const SplashScreen());
      case discover:
        return MaterialPageRoute(builder: (_) => const DiscoverScreen());
      case quickPreview:
        return MaterialPageRoute(builder: (_) => const QuickPreviewScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case signup:
        return MaterialPageRoute(builder: (_) => const SignupScreen());
      case forgotPassword:
        return MaterialPageRoute(builder: (_) => const ForgotPasswordScreen());
      case navShell:
        return MaterialPageRoute(builder: (_) => const MainNavigation());
      case destinationList:
        final filter = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => DestinationListScreen(initialFilter: filter),
        );
      case destinationDetail:
        final destination = settings.arguments as Destination;
        return MaterialPageRoute(
          builder: (_) => DestinationDetailsScreen(destination: destination),
        );
      case plannerResults:
        if (settings.arguments is Trip) {
          final trip = settings.arguments as Trip;
          return MaterialPageRoute(
            builder: (_) => PlannerResultsScreen(
              durationDays: trip.itinerary.length,
              trip: trip,
            ),
          );
        } else {
          final tripDuration = settings.arguments as int? ?? 3;
          return MaterialPageRoute(
            builder: (_) => PlannerResultsScreen(durationDays: tripDuration),
          );
        }
      case groupDashboard:
        final trip = settings.arguments as Trip?;
        return MaterialPageRoute(builder: (_) => GroupDashboardScreen(trip: trip));
      case groupTasks:
        final trip = settings.arguments as Trip?;
        return MaterialPageRoute(builder: (_) => GroupTasksScreen(trip: trip));
      case groupMemories:
        final trip = settings.arguments as Trip?;
        return MaterialPageRoute(builder: (_) => SharedMemoriesScreen(trip: trip));
      case notifications:
        return MaterialPageRoute(builder: (_) => const NotificationsScreen());
      case districtHub:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => DistrictHubScreen(
            districtName: args['districtName'] as String,
            heroImageUrl: args['heroImageUrl'] as String,
            accentColor: args['accentColor'] as Color,
          ),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
