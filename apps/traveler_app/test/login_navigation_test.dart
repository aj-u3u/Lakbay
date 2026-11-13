import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lakbay_plus/core/routes/app_routes.dart';
import 'package:lakbay_plus/providers/auth_provider.dart';
import 'package:lakbay_plus/providers/nav_provider.dart';
import 'package:lakbay_plus/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

class _AcceptingAuth extends AuthProvider {
  @override
  Future<bool> login(String email, String password) async => true;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets(
    'signing in from the guest pages leaves nothing underneath the app, so Back cannot '
    'reveal the signed-out landing page',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthProvider>.value(value: _AcceptingAuth()),
            ChangeNotifierProvider<NavProvider>(create: (_) => NavProvider()),
          ],
          child: MaterialApp(
            initialRoute: '/guest',
            routes: {
              '/guest': (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.quickPreview),
                    child: const Text('guest landing'),
                  ),
                ),
              ),
              AppRoutes.quickPreview: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
                    child: const Text('quick preview'),
                  ),
                ),
              ),
              AppRoutes.login: (_) => const LoginScreen(),
              AppRoutes.navShell: (_) => const Scaffold(body: Text('APP SHELL')),
            },
          ),
        ),
      );

      // The real path: landing -> quick preview -> login -> signed in.
      await tester.tap(find.text('guest landing'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('quick preview'));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'dummy@example.com');
      await tester.enterText(fields.at(1), 'password123');
      await tester.ensureVisible(find.text('Sign In').last);
      await tester.tap(find.text('Sign In').last);
      await tester.pumpAndSettle();

      expect(find.text('APP SHELL'), findsOneWidget);
      final navigator = Navigator.of(tester.element(find.text('APP SHELL')));
      expect(navigator.canPop(), isFalse, reason: 'guest pages must not remain underneath');

      await tester.binding.handlePopRoute(); // Android back / the arrow
      await tester.pumpAndSettle();
      expect(find.text('guest landing'), findsNothing);
      expect(find.text('quick preview'), findsNothing);
    },
  );
}
