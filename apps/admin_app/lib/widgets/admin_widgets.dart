import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

final ValueNotifier<bool> adminHasUnsavedChanges = ValueNotifier(false);
final ValueNotifier<bool> adminIsSaving = ValueNotifier(false);

/// Shared guard for navigation outside the current destination editor.
Future<bool> confirmAdminNavigation(BuildContext context) async {
  if (adminIsSaving.value) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Please wait for the current change to finish.'),
      ),
    );
    return false;
  }
  if (!adminHasUnsavedChanges.value) return true;
  final discard = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Discard changes?'),
      content: const Text(
        'This record has unsaved changes. Leave this page and discard them?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Keep editing'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Discard changes'),
        ),
      ],
    ),
  );
  if (discard == true) adminHasUnsavedChanges.value = false;
  return discard == true;
}

class AdminPage extends StatelessWidget {
  final Widget child;

  const AdminPage({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final gutter = constraints.maxWidth >= 1024
            ? 32.0
            : constraints.maxWidth >= 600
            ? 24.0
            : 16.0;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(gutter, 28, gutter, 40),
          child: child,
        );
      },
    );
  }
}

class AdminPageHeader extends StatelessWidget {
  final String title;
  final String description;
  final Widget? action;

  const AdminPageHeader({
    super.key,
    required this.title,
    required this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.headlineMedium),
        ),
        const SizedBox(height: 6),
        Text(
          description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading,
              if (action != null) ...[const SizedBox(height: 16), action!],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: heading),
            if (action != null) ...[const SizedBox(width: 24), action!],
          ],
        );
      },
    );
  }
}

class AdminPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const AdminPanel({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border.all(color: theme.dividerColor),
        borderRadius: BorderRadius.circular(16),
      ),
      // A transparent Material lets list rows and ink effects inside the panel paint
      // correctly; without it Flutter's debug build rejects a ListTile that sits
      // inside this colored box.
      child: Material(type: MaterialType.transparency, child: child),
    );
  }
}

class AdminMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool isError;

  const AdminMessage({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isError ? theme.colorScheme.error : theme.colorScheme.primary;
    return AdminPanel(
      child: Semantics(
        liveRegion: isError,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

class AdminBadge extends StatelessWidget {
  final String label;
  final Color? color;

  const AdminBadge({super.key, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tint =
        color ??
        (theme.brightness == Brightness.dark
            ? AppTheme.darkAccent
            : AppTheme.actionPrimary);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(color: tint),
      ),
    );
  }
}
