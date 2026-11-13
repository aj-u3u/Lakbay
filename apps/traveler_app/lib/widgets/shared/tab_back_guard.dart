import 'package:flutter/material.dart';

/// Makes the system back gesture/button behave sensibly in a tabbed shell: on any tab
/// other than Home it returns to Home; on Home it is allowed to leave (exit the app).
///
/// Without it, back from a tab pops the whole shell and reveals whatever route sits
/// beneath it, such as the signed-out landing page.
class TabBackGuard extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onGoHome;
  final Widget child;

  const TabBackGuard({
    super.key,
    required this.currentIndex,
    required this.onGoHome,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) onGoHome();
      },
      child: child,
    );
  }
}
