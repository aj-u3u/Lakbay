import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_widgets.dart';

class Sidebar extends StatelessWidget {
  final bool isCollapsed;
  final VoidCallback? onToggleCollapse;

  const Sidebar({super.key, required this.isCollapsed, this.onToggleCollapse});

  static const _items = [
    (
      label: 'Overview',
      route: '/dashboard',
      icon: Icons.space_dashboard_outlined,
    ),
    (label: 'Destinations', route: '/destinations', icon: Icons.place_outlined),
    (
      label: 'Place review',
      route: '/destination-candidates',
      icon: Icons.fact_check_outlined,
    ),
    (
      label: 'Market Rates',
      route: '/market-rates',
      icon: Icons.payments_outlined,
    ),
    (label: 'User Accounts', route: '/users', icon: Icons.people_outline),
    (
      label: 'Reviews & Feedback',
      route: '/reviews',
      icon: Icons.rate_review_outlined,
    ),
    (label: 'Trip Information', route: '/trips', icon: Icons.route_outlined),
  ];

  Future<void> _navigate(BuildContext context, String route) async {
    final currentRoute = ModalRoute.of(context)?.settings.name;
    if (currentRoute == route) {
      Scaffold.maybeOf(context)?.closeDrawer();
      return;
    }
    if (!await confirmAdminNavigation(context) || !context.mounted) return;
    Scaffold.maybeOf(context)?.closeDrawer();
    Navigator.pushReplacementNamed(context, route);
  }

  Future<void> _signOut(BuildContext context) async {
    if (!await confirmAdminNavigation(context) || !context.mounted) return;
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
      // The local session is still cleared by the API logout finally block.
    } finally {
      api.close();
      adminIsSaving.value = false;
      if (navigator.mounted) {
        navigator.pushNamedAndRemoveUntil('/login', (_) => false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    return Container(
      width: isCollapsed ? 80 : 248,
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(right: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                isCollapsed ? 16 : 20,
                24,
                isCollapsed ? 16 : 20,
                24,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Image.asset(
                      'assets/images/lakbay_logo.png',
                      fit: BoxFit.contain,
                      semanticLabel: 'Lakbay logo',
                      errorBuilder: (_, _, _) => Icon(
                        Icons.explore_outlined,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  if (!isCollapsed) ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lakbay+', style: theme.textTheme.titleLarge),
                          Text(
                            'Admin workspace',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (!isCollapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'WORKSPACE',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  for (final item in _items)
                    _NavigationItem(
                      label: item.label,
                      icon: item.icon,
                      isCollapsed: isCollapsed,
                      isSelected: currentRoute == item.route,
                      onTap: () => _navigate(context, item.route),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 12),
                  _NavigationItem(
                    label: 'Settings',
                    icon: Icons.settings_outlined,
                    isCollapsed: isCollapsed,
                    isSelected: currentRoute == '/settings',
                    onTap: () => _navigate(context, '/settings'),
                  ),
                  _NavigationItem(
                    label: 'Sign out',
                    icon: Icons.logout_outlined,
                    isCollapsed: isCollapsed,
                    isSelected: false,
                    onTap: () => _signOut(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavigationItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isCollapsed;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavigationItem({
    required this.label,
    required this.icon,
    required this.isCollapsed,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: isCollapsed ? label : '',
        child: Semantics(
          selected: isSelected,
          button: true,
          label: isCollapsed ? label : null,
          child: Material(
            color: isSelected
                ? theme.colorScheme.primary.withValues(alpha: 0.09)
                : Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: isSelected
                  ? BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    )
                  : BorderSide.none,
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isCollapsed ? 16 : 12,
                    vertical: 12,
                  ),
                  child: Row(
                    mainAxisAlignment: isCollapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: [
                      Icon(icon, color: color, size: 22),
                      if (!isCollapsed) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: color,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
