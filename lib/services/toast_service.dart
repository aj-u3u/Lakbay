import 'package:flutter/material.dart';
import '../widgets/shared/toast_notification.dart';

/// Global service to display premium toast/snackbar notifications.
///
/// Usage from any screen:
/// ```dart
/// ToastService.show(context, 'Trip saved.', type: ToastType.success);
/// ToastService.show(context, 'Upload failed.', type: ToastType.error);
/// ToastService.show(context, 'AI is loading...', type: ToastType.info);
/// ```
///
/// Toasts auto-dismiss after 3 seconds and support swipe-to-dismiss.
/// Multiple calls queue and each is shown above the bottom navigation bar.
class ToastService {
  // Internal queue to avoid overlap stacking
  static final List<OverlayEntry> _queue = [];
  static bool _isShowing = false;

  /// Shows a toast notification above the bottom navigation bar.
  ///
  /// [message]   — Text to display.
  /// [type]      — [ToastType.success], [ToastType.error], or [ToastType.info].
  /// [duration]  — Auto-dismiss duration (default: 3 seconds).
  static void show(
    BuildContext context,
    String message, {
    ToastType type = ToastType.success,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);

    late OverlayEntry entry;

    void dismiss() {
      if (entry.mounted) {
        entry.remove();
        _queue.remove(entry);
      }
      _isShowing = false;
      _processQueue();
    }

    entry = OverlayEntry(
      builder: (ctx) => Positioned(
        // Place above bottom nav (approx 80dp clearance)
        bottom: MediaQuery.of(ctx).padding.bottom + 80,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: ToastNotification(
            message: message,
            type: type,
            onDismiss: dismiss,
          ),
        ),
      ),
    );

    _queue.add(entry);

    if (!_isShowing) {
      _processQueue(overlay: overlay, duration: duration, onDismiss: dismiss);
    }
  }

  static void _processQueue({
    OverlayState? overlay,
    Duration? duration,
    VoidCallback? onDismiss,
  }) {
    if (_queue.isEmpty) {
      _isShowing = false;
      return;
    }

    _isShowing = true;
    final entry = _queue.first;

    if (overlay != null) {
      overlay.insert(entry);
    }

    Future.delayed(duration ?? const Duration(seconds: 3), () {
      if (entry.mounted) {
        entry.remove();
        _queue.remove(entry);
      }
      _isShowing = false;
      _processQueue();
    });
  }
}
