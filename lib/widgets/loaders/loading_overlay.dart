import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// A full-screen modal loading overlay.
///
/// Displays a blurred dark overlay with an animated spinner and an optional
/// message. Blocks all user interaction until dismissed.
///
/// Usage:
/// ```dart
/// // Show
/// LoadingOverlay.show(context, message: 'Saving your trip...');
///
/// // Hide
/// LoadingOverlay.hide(context);
/// ```
class LoadingOverlay {
  static OverlayEntry? _entry;

  /// Shows the overlay. Call [hide] when the async operation completes.
  static void show(BuildContext context, {String message = 'Loading...'}) {
    if (_entry != null) return; // prevent double overlay

    _entry = OverlayEntry(
      builder: (_) => _LoadingOverlayWidget(message: message),
    );
    Overlay.of(context).insert(_entry!);
  }

  /// Hides the overlay.
  static void hide(BuildContext context) {
    _entry?.remove();
    _entry = null;
  }
}

class _LoadingOverlayWidget extends StatefulWidget {
  final String message;
  const _LoadingOverlayWidget({required this.message});

  @override
  State<_LoadingOverlayWidget> createState() => _LoadingOverlayWidgetState();
}

class _LoadingOverlayWidgetState extends State<_LoadingOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark scrim
            Container(color: Colors.black.withValues(alpha: 0.55)),
            // Center card
            Center(
              child: Container(
                width: 220,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceXL,
                  vertical: AppConstants.spaceXL,
                ),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.cardColorDark : Colors.white,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  border: Border.all(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SpinKitFadingCircle(
                      color: AppTheme.primaryBlue,
                      size: 48,
                    ),
                    const SizedBox(height: AppConstants.spaceL),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        height: 1.5,
                      ),
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
