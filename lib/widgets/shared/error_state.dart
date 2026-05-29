import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_error.dart';

/// A full-page error state widget with icon, message, and an action button.
///
/// Use factory constructors that match the [AppError] types:
///
/// ```dart
/// // No internet
/// ErrorState.noInternet(onRetry: () => refetch())
///
/// // AI unavailable
/// ErrorState.aiUnavailable(onRetry: () => regenerate())
///
/// // Upload failed
/// ErrorState.uploadFailed(onRetry: () => reUpload())
///
/// // Session expired
/// ErrorState.sessionExpired(onLogIn: () => Navigator.pushNamed(ctx, '/login'))
///
/// // From an AppError object
/// ErrorState.fromAppError(
///   error,
///   onAction: () => handleRetry(),
/// )
/// ```
class ErrorState extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const ErrorState({
    super.key,
    required this.icon,
    required this.message,
    this.iconColor = const Color(0xFF8B1A2A),
    this.actionLabel,
    this.onAction,
  });

  // ── Factory constructors ────────────────────────────────────────────────────

  /// No internet connection error.
  factory ErrorState.noInternet({VoidCallback? onRetry}) => ErrorState(
        icon: Icons.wifi_off_rounded,
        iconColor: const Color(0xFF8B4E1A),
        message: 'No connection. Check your network and try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );

  /// AI / Gemini service unavailable.
  factory ErrorState.aiUnavailable({VoidCallback? onRetry}) => ErrorState(
        icon: Icons.auto_awesome_rounded,
        iconColor: AppTheme.primaryBlue,
        message: 'AI is temporarily unavailable. Try again shortly.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );

  /// Photo or file upload failed.
  factory ErrorState.uploadFailed({VoidCallback? onRetry}) => ErrorState(
        icon: Icons.cloud_off_rounded,
        iconColor: const Color(0xFF8B1A2A),
        message: 'Upload failed. Please try a smaller image.',
        actionLabel: 'Try Again',
        onAction: onRetry,
      );

  /// User session expired — action routes to login.
  factory ErrorState.sessionExpired({VoidCallback? onLogIn}) => ErrorState(
        icon: Icons.lock_clock_rounded,
        iconColor: const Color(0xFF6B3A8B),
        message: 'Your session has expired. Please log in again.',
        actionLabel: 'Log In',
        onAction: onLogIn,
      );

  /// Generic fallback error.
  factory ErrorState.generic({String? message, VoidCallback? onRetry}) =>
      ErrorState(
        icon: Icons.error_outline_rounded,
        iconColor: const Color(0xFF8B1A2A),
        message: message ?? 'Something went wrong. Please try again.',
        actionLabel: 'Retry',
        onAction: onRetry,
      );

  /// Builds an [ErrorState] from a typed [AppError] object.
  factory ErrorState.fromAppError(AppError error, {VoidCallback? onAction}) {
    final IconData icon;
    final Color iconColor;

    switch (error.type) {
      case AppErrorType.noInternet:
        icon = Icons.wifi_off_rounded;
        iconColor = const Color(0xFF8B4E1A);
      case AppErrorType.aiUnavailable:
        icon = Icons.auto_awesome_rounded;
        iconColor = AppTheme.primaryBlue;
      case AppErrorType.uploadFailed:
        icon = Icons.cloud_off_rounded;
        iconColor = const Color(0xFF8B1A2A);
      case AppErrorType.missingInput:
        icon = Icons.edit_off_rounded;
        iconColor = const Color(0xFF8B1A2A);
      case AppErrorType.sessionExpired:
        icon = Icons.lock_clock_rounded;
        iconColor = const Color(0xFF6B3A8B);
      case AppErrorType.generic:
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFF8B1A2A);
    }

    return ErrorState(
      icon: icon,
      iconColor: iconColor,
      message: error.userMessage,
      actionLabel: error.actionLabel,
      onAction: onAction,
    );
  }

  @override
  State<ErrorState> createState() => _ErrorStateState();
}

class _ErrorStateState extends State<ErrorState>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _shakeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // Subtle horizontal shake on entry
    _shakeAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -6), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -6, end: 6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 6, end: -4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -4, end: 4), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 4, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceXL,
            vertical: AppConstants.spaceXXL,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Shaking icon container ──────────────────────────────────
              AnimatedBuilder(
                animation: _shakeAnim,
                builder: (_, child) => Transform.translate(
                  offset: Offset(_shakeAnim.value, 0),
                  child: child,
                ),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.iconColor.withValues(alpha: 0.10),
                    border: Border.all(
                      color: widget.iconColor.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.iconColor.withValues(alpha: 0.18),
                        blurRadius: 24,
                        spreadRadius: 2,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    widget.icon,
                    size: 44,
                    color: widget.iconColor,
                  ),
                ),
              ),

              const SizedBox(height: AppConstants.spaceXL),

              // ── Error message ───────────────────────────────────────────
              Text(
                widget.message,
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
                  height: 1.5,
                ),
              ),

              // ── Action button ───────────────────────────────────────────
              if (widget.actionLabel != null && widget.onAction != null) ...[
                const SizedBox(height: AppConstants.spaceXL),
                _ErrorActionButton(
                  label: widget.actionLabel!,
                  color: widget.iconColor,
                  onPressed: widget.onAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Inline field error label
// ─────────────────────────────────────────────────────────────────────────────

/// An inline validation error label shown beneath a form field.
///
/// Matches the spec: highlight with red + label "This field is required."
///
/// Usage:
/// ```dart
/// Column(
///   crossAxisAlignment: CrossAxisAlignment.start,
///   children: [
///     TextFormField(...),
///     if (hasError) const InlineFieldError('This field is required.'),
///   ],
/// )
/// ```
class InlineFieldError extends StatelessWidget {
  final String message;

  const InlineFieldError(
    this.message, {
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 13,
            color: Color(0xFFE53935),
          ),
          const SizedBox(width: 4),
          Text(
            message,
            style: GoogleFonts.outfit(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFFE53935),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Action button
// ─────────────────────────────────────────────────────────────────────────────

class _ErrorActionButton extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ErrorActionButton({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_ErrorActionButton> createState() => _ErrorActionButtonState();
}

class _ErrorActionButtonState extends State<_ErrorActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceXL,
            vertical: 14,
          ),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.30),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Text(
            widget.label,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
