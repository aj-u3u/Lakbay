import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lakbay_plus/providers/auth_provider.dart';
import 'package:lakbay_plus/providers/nav_provider.dart';
import 'package:lakbay_plus/screens/auth/login_screen.dart';
import 'package:provider/provider.dart';

class _SlowAuthProvider extends AuthProvider {
  final Completer<bool> result = Completer<bool>();

  @override
  Future<bool> login(String email, String password) => result.future;
}

const _wakeNote = 'Waking up the server';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('explains a slow sign-in after a few seconds, then clears', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _SlowAuthProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<NavProvider>(create: (_) => NavProvider()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'dummy@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.ensureVisible(find.text('Sign In').last);
    await tester.tap(find.text('Sign In').last);
    await tester.pump();

    // Quick sign-ins never show the note.
    await tester.pump(const Duration(seconds: 5));
    expect(find.textContaining(_wakeNote), findsNothing);

    // Still waiting after 6 seconds: the server is probably waking up.
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining(_wakeNote), findsOneWidget);

    // The note disappears once the sign-in finishes (here: fails).
    auth.result.complete(false);
    await tester.pump();
    expect(find.textContaining(_wakeNote), findsNothing);
  });

  testWidgets('a fast sign-in never shows the wake-up note', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final auth = _SlowAuthProvider();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthProvider>.value(value: auth),
          ChangeNotifierProvider<NavProvider>(create: (_) => NavProvider()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'dummy@example.com');
    await tester.enterText(fields.at(1), 'password123');
    await tester.ensureVisible(find.text('Sign In').last);
    await tester.tap(find.text('Sign In').last);
    await tester.pump();

    auth.result.complete(false);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 10));

    expect(find.textContaining(_wakeNote), findsNothing);
  });
}
