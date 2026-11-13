import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lakbay_plus/widgets/shared/tab_back_guard.dart';

Future<void> _pumpShell(
  WidgetTester tester, {
  required int index,
  required VoidCallback onGoHome,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TabBackGuard(
                    currentIndex: index,
                    onGoHome: onGoHome,
                    child: const Scaffold(body: Text('SHELL')),
                  ),
                ),
              ),
              child: const Text('open shell'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open shell'));
  await tester.pumpAndSettle();
  expect(find.text('SHELL'), findsOneWidget);
}

void main() {
  testWidgets('back on another tab returns to Home and does not leave the shell', (
    tester,
  ) async {
    var wentHome = 0;
    await _pumpShell(tester, index: 2, onGoHome: () => wentHome++);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(wentHome, 1);
    expect(find.text('SHELL'), findsOneWidget); // still in the app
  });

  testWidgets('back on the Home tab is allowed to leave', (tester) async {
    var wentHome = 0;
    await _pumpShell(tester, index: 0, onGoHome: () => wentHome++);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(wentHome, 0);
    expect(find.text('SHELL'), findsNothing);
    expect(find.text('open shell'), findsOneWidget);
  });
}
