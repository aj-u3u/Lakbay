import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// Visual style for the confirm button.
enum ConfirmButtonStyle {
  /// Red destructive button (delete, remove, leave).
  destructive,

  /// Muted / warning button (cancel task).
  warning,
}

/// A premium animated confirmation dialog for destructive or irreversible actions.
///
/// Always shows a cancel/keep option and a clearly styled action button.
/// Never call this directly — use [DialogService.showConfirm] instead.
///
/// ## Factory constructors
///
/// ```dart
/// // Delete a trip
/// ConfirmDialog.deleteTrip()
///
/// // Delete a memory
/// ConfirmDialog.deleteMemory()
///
/// // Remove a group member
/// ConfirmDialog.removeMember()
///
/// // Cancel a task
/// ConfirmDialog.cancelTask()
///
/// // Leave a group trip
/// ConfirmDialog.leaveTrip()
/// ```
class ConfirmDialog extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final ConfirmButtonStyle confirmStyle;

  const ConfirmDialog({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    this.cancelLabel = 'Cancel',
    required this.confirmLabel,
    this.confirmStyle = ConfirmButtonStyle.destructive,
  });

  // ── Factory constructors ──────────────────────────────────────────────────

  /// "Delete Trip?" — permanently deletes the trip and all its data.
  factory ConfirmDialog.deleteTrip() => const ConfirmDialog(
        icon: Icons.delete_forever_rounded,
        iconColor: Color(0xFFD32F2F),
        title: 'Delete Trip?',
        message:
            'This will permanently delete the trip and all its data.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        confirmStyle: ConfirmButtonStyle.destructive,
      );

  /// "Delete Memory?" — removes a photo from memories.
  factory ConfirmDialog.deleteMemory() => const ConfirmDialog(
        icon: Icons.photo_camera_back_rounded,
        iconColor: Color(0xFFD32F2F),
        title: 'Delete Memory?',
        message: 'This photo will be removed from your memories.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Delete',
        confirmStyle: ConfirmButtonStyle.destructive,
      );

  /// "Remove Member?" — removes a person from the group trip.
  factory ConfirmDialog.removeMember() => const ConfirmDialog(
        icon: Icons.person_remove_rounded,
        iconColor: Color(0xFFD32F2F),
        title: 'Remove Member?',
        message: 'This person will lose access to the group trip.',
        cancelLabel: 'Cancel',
        confirmLabel: 'Remove',
        confirmStyle: ConfirmButtonStyle.destructive,
      );

  /// "Cancel Task?" — marks a task as cancelled.
  factory ConfirmDialog.cancelTask() => const ConfirmDialog(
        icon: Icons.cancel_schedule_send_rounded,
        iconColor: Color(0xFF8B4E1A),
        title: 'Cancel Task?',
        message: 'This task will be marked as cancelled.',
        cancelLabel: 'Keep',
        confirmLabel: 'Cancel Task',
        confirmStyle: ConfirmButtonStyle.warning,
      );

  /// "Leave Trip?" — removes the user from the group trip.
  factory ConfirmDialog.leaveTrip() => const ConfirmDialog(
        icon: Icons.exit_to_app_rounded,
        iconColor: Color(0xFFD32F2F),
        title: 'Leave Trip?',
        message: 'You will lose access to this group trip.',
        cancelLabel: 'Stay',
        confirmLabel: 'Leave',
        confirmStyle: ConfirmButtonStyle.destructive,
      );

  @override
  State<ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<ConfirmDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Color get _confirmColor {
    switch (widget.confirmStyle) {
      case ConfirmButtonStyle.destructive:
        return const Color(0xFFD32F2F);
      case ConfirmButtonStyle.warning:
        return const Color(0xFF8B4E1A);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceXL,
          ),
          child: Container(
            padding: const EdgeInsets.all(AppConstants.spaceXL),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardColorDark : AppTheme.cardColorLight,
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              border: Border.all(
                color: widget.iconColor.withValues(alpha: 0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 32,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Icon ───────────────────────────────────────────────────
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.iconColor.withValues(alpha: 0.10),
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.22),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 34,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceL),

                // ── Title ──────────────────────────────────────────────────
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceS),

                // ── Message ────────────────────────────────────────────────
                Text(
                  widget.message,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: AppConstants.spaceXL),

                // ── Buttons ────────────────────────────────────────────────
                Row(
                  children: [
                    // Cancel / Keep / Stay
                    Expanded(
                      child: _DialogButton(
                        label: widget.cancelLabel,
                        onPressed: () => Navigator.of(context).pop(false),
                        isOutlined: true,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceM),
                    // Confirm action (destructive/warning)
                    Expanded(
                      child: _DialogButton(
                        label: widget.confirmLabel,
                        onPressed: () => Navigator.of(context).pop(true),
                        isOutlined: false,
                        color: _confirmColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Internal button widget
// ─────────────────────────────────────────────────────────────────────────────

class _DialogButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final bool isOutlined;
  final Color color;

  const _DialogButton({
    required this.label,
    required this.onPressed,
    required this.isOutlined,
    required this.color,
  });

  @override
  State<_DialogButton> createState() => _DialogButtonState();
}

class _DialogButtonState extends State<_DialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.isOutlined
                ? (isDark
                    ? AppTheme.cardColorDark
                    : const Color(0xFFF0F5F5))
                : widget.color,
            borderRadius:
                BorderRadius.circular(AppConstants.radiusCircular),
            border: widget.isOutlined
                ? Border.all(
                    color: widget.color.withValues(alpha: 0.35),
                    width: 1.2,
                  )
                : null,
            boxShadow: widget.isOutlined
                ? null
                : [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.28),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.outfit(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: widget.isOutlined ? widget.color : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
