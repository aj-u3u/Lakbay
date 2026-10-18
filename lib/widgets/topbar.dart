import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import 'admin_widgets.dart';

class Topbar extends StatelessWidget implements PreferredSizeWidget {
  final VoidCallback? onMenuPressed;

  const Topbar({super.key, this.onMenuPressed});

  @override
  Size get preferredSize => const Size.fromHeight(64);

  Future<void> _accountAction(BuildContext context, String action) async {
    if (ModalRoute.of(context)?.settings.name == action) return;
    if (!await confirmAdminNavigation(context) || !context.mounted) return;
    if (action == '/login') {
      final navigator = Navigator.of(context, rootNavigator: true);
      adminIsSaving.value = true;
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => const PopScope(
            canPop: false,
            child: AlertDialog(
              title: Text('Signing out'),
              content: Row(
                children: [
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 16),
                  Expanded(child: Text('Closing your session…')),
                ],
              ),
            ),
          ),
        ),
      );
      final api = ApiService();
      try {
        await api.logout();
      } catch (_) {
        // Local credentials are cleared even if revocation cannot reach the API.
      } finally {
        api.close();
        adminIsSaving.value = false;
        if (navigator.mounted) {
          navigator.pushNamedAndRemoveUntil('/login', (_) => false);
        }
      }
      return;
    }
    if (ModalRoute.of(context)?.settings.name != action) {
      Navigator.pushReplacementNamed(context, action);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) => Row(
          children: [
            if (onMenuPressed != null) ...[
              IconButton(
                onPressed: onMenuPressed,
                icon: const Icon(Icons.menu_rounded),
                tooltip: 'Open navigation',
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                onMenuPressed == null ? 'Admin workspace' : 'Lakbay+ Admin',
                style: theme.textTheme.titleSmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            ValueListenableBuilder<ThemeMode>(
              valueListenable: themeNotifier,
              builder: (context, mode, _) => IconButton(
                tooltip: mode == ThemeMode.dark
                    ? 'Switch to light theme'
                    : 'Switch to dark theme',
                onPressed: () => setAdminTheme(
                  mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark,
                ),
                icon: Icon(
                  mode == ThemeMode.dark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                ),
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Admin account menu',
              onSelected: (action) => _accountAction(context, action),
              itemBuilder: (_) => const [
                PopupMenuItem(value: '/profile', child: Text('My profile')),
                PopupMenuItem(
                  value: '/settings',
                  child: Text('Workspace settings'),
                ),
                PopupMenuDivider(),
                PopupMenuItem(value: '/login', child: Text('Sign out')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: theme.colorScheme.primary.withValues(
                        alpha: 0.1,
                      ),
                      child: Icon(
                        Icons.person_outline,
                        color: theme.colorScheme.primary,
                        size: 21,
                      ),
                    ),
                    if (constraints.maxWidth >= 580) ...[
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 132,
                        child: FutureBuilder<String>(
                          future: SessionManager.instance.getName(),
                          builder: (context, snapshot) => Text(
                            snapshot.data ?? 'Admin account',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Icon(
                      Icons.expand_more,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
