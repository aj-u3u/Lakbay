import 'package:flutter/material.dart';
import '../widgets/shared/confirm_dialog.dart';

/// Global service for showing confirmation dialogs.
///
/// Returns `true` if the user confirmed, `false` or `null` if cancelled.
///
/// ## Usage
///
/// ```dart
/// // Delete a trip
/// final confirmed = await DialogService.deleteTrip(context);
/// if (confirmed == true) { /* proceed with deletion */ }
///
/// // Delete a memory
/// final confirmed = await DialogService.deleteMemory(context);
///
/// // Remove a group member
/// final confirmed = await DialogService.removeMember(context);
///
/// // Cancel a task
/// final confirmed = await DialogService.cancelTask(context);
///
/// // Leave a group trip
/// final confirmed = await DialogService.leaveTrip(context);
///
/// // Custom dialog
/// final confirmed = await DialogService.showConfirm(
///   context,
///   dialog: ConfirmDialog(
///     icon: Icons.logout_rounded,
///     iconColor: Colors.red,
///     title: 'Log Out?',
///     message: 'You will be signed out of your account.',
///     confirmLabel: 'Log Out',
///   ),
/// );
/// ```
class DialogService {
  /// Shows a [ConfirmDialog] and returns the user's response.
  ///
  /// Returns `true` if confirmed, `false`/`null` if cancelled or dismissed.
  static Future<bool?> showConfirm(
    BuildContext context, {
    required ConfirmDialog dialog,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.50),
      builder: (_) => dialog,
    );
  }

  // ── Convenience methods ─────────────────────────────────────────────────────

  /// Shows the "Delete Trip?" confirmation dialog.
  static Future<bool?> deleteTrip(BuildContext context) => showConfirm(
        context,
        dialog: ConfirmDialog.deleteTrip(),
      );

  /// Shows the "Delete Memory?" confirmation dialog.
  static Future<bool?> deleteMemory(BuildContext context) => showConfirm(
        context,
        dialog: ConfirmDialog.deleteMemory(),
      );

  /// Shows the "Remove Member?" confirmation dialog.
  static Future<bool?> removeMember(BuildContext context) => showConfirm(
        context,
        dialog: ConfirmDialog.removeMember(),
      );

  /// Shows the "Cancel Task?" confirmation dialog.
  static Future<bool?> cancelTask(BuildContext context) => showConfirm(
        context,
        dialog: ConfirmDialog.cancelTask(),
      );

  /// Shows the "Leave Trip?" confirmation dialog.
  static Future<bool?> leaveTrip(BuildContext context) => showConfirm(
        context,
        dialog: ConfirmDialog.leaveTrip(),
      );
}
