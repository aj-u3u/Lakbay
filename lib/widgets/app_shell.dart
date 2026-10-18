import 'package:flutter/material.dart';
import 'sidebar.dart';
import 'topbar.dart';

/// One authoritative navigation shell for all admin workspaces.
class AppShell extends StatelessWidget {
  final Widget child;

  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final persistentNavigation = constraints.maxWidth >= 1024;
        final compactNavigation = constraints.maxWidth < 1280;
        return Scaffold(
          drawer: persistentNavigation
              ? null
              : const Drawer(width: 280, child: Sidebar(isCollapsed: false)),
          body: Row(
            children: [
              if (persistentNavigation) Sidebar(isCollapsed: compactNavigation),
              Expanded(
                child: Column(
                  children: [
                    Builder(
                      builder: (shellContext) => Topbar(
                        onMenuPressed: persistentNavigation
                            ? null
                            : () => Scaffold.of(shellContext).openDrawer(),
                      ),
                    ),
                    Expanded(child: SafeArea(top: false, child: child)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
