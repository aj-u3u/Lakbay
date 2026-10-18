import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/theme/app_theme.dart';
import 'widgets/app_shell.dart';
import 'services/session_manager.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/destinations_screen.dart';
import 'screens/market_rates_screen.dart';
import 'screens/users_screen.dart';
import 'screens/reviews_screen.dart';
import 'screens/trips_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/profile_screen.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

Future<void> setAdminTheme(ThemeMode mode) async {
  themeNotifier.value = mode;
  final preferences = await SharedPreferences.getInstance();
  await preferences.setString('admin_theme', mode.name);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final savedTheme = preferences.getString('admin_theme');
  themeNotifier.value = ThemeMode.values.firstWhere(
    (mode) => mode.name == savedTheme,
    orElse: () => ThemeMode.light,
  );
  runApp(const LakbayAdminApp());
}

class LakbayAdminApp extends StatelessWidget {
  final String initialRoute;
  const LakbayAdminApp({super.key, this.initialRoute = '/login'});

  Route<dynamic> _route(RouteSettings settings) {
    final arguments = settings.arguments;
    final destination = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : null;
    final page = switch (settings.name) {
      '/login' => const LoginScreen(),
      '/destinations' => DestinationsScreen(initialDestination: destination),
      '/market-rates' => const MarketRatesScreen(),
      '/transport' => const MarketRatesScreen(initialTab: 1),
      '/accommodation' => const MarketRatesScreen(),
      '/activities' || '/meals' => const DestinationsScreen(),
      '/users' => const UsersScreen(),
      '/reviews' => const ReviewsScreen(),
      '/trips' => const TripsScreen(),
      '/settings' => const SettingsScreen(),
      '/profile' => const ProfileScreen(),
      _ => const DashboardScreen(),
    };
    return MaterialPageRoute(
      settings: settings,
      builder: (_) => settings.name == '/login'
          ? page
          : _AdminSessionGate(child: AppShell(child: page)),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: themeNotifier,
    builder: (context, mode, _) => MaterialApp(
      title: 'Lakbay+ Admin',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: mode,
      debugShowCheckedModeBanner: false,
      initialRoute: initialRoute,
      onGenerateInitialRoutes: (route) => [_route(RouteSettings(name: route))],
      onGenerateRoute: _route,
    ),
  );
}

class _AdminSessionGate extends StatefulWidget {
  final Widget child;
  const _AdminSessionGate({required this.child});
  @override
  State<_AdminSessionGate> createState() => _AdminSessionGateState();
}

class _AdminSessionGateState extends State<_AdminSessionGate> {
  late final Future<bool> _session = SessionManager.instance.isLoggedIn();
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      return snapshot.data == true ? widget.child : const LoginScreen();
    },
  );
}
