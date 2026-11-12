import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// A premium empty-state widget shown when a list or section has no content.
///
/// Always includes a contextual icon, title message, optional subtitle, and
/// an optional CTA button to guide the user to the next action.
///
/// ## Ready-made factory constructors
///
/// ```dart
/// // Trips page — no trips yet
/// EmptyState.trips(onPlanTrip: () => Navigator.push(...))
///
/// // Memories page — no photos yet
/// EmptyState.memories(onUpload: () => pickImage())
///
/// // Notifications — all caught up
/// EmptyState.notifications()
///
/// // Group tasks — no tasks yet
/// EmptyState.tasks(onAddTask: () => showTaskSheet())
/// ```
///
/// ## Custom usage
///
/// ```dart
/// EmptyState(
///   icon: Icons.search_off_rounded,
///   iconColor: AppTheme.primaryBlue,
///   title: 'No results found.',
///   subtitle: 'Try a different search term.',
///   ctaLabel: 'Clear Search',
///   onCta: () => clearSearch(),
/// )
/// ```
class EmptyState extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? ctaLabel;
  final VoidCallback? onCta;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor = AppTheme.primaryBlue,
    this.subtitle,
    this.ctaLabel,
    this.onCta,
  });

  // ── Factory constructors ────────────────────────────────────────────────────

  /// Empty state for the Trips page.
  factory EmptyState.trips({VoidCallback? onPlanTrip}) => EmptyState(
        icon: Icons.luggage_rounded,
        iconColor: AppTheme.primaryBlue,
        title: 'No trips yet.',
        subtitle: 'Start planning your adventure.',
        ctaLabel: 'Plan a Trip',
        onCta: onPlanTrip,
      );

  /// Empty state for the Memories page.
  factory EmptyState.memories({VoidCallback? onUpload}) => EmptyState(
        icon: Icons.photo_album_rounded,
        iconColor: const Color(0xFFD66F29), // secondaryGreen (cocoa)
        title: 'No memories yet.',
        subtitle: 'Capture your first moment.',
        ctaLabel: 'Upload Memory',
        onCta: onUpload,
      );

  /// Empty state for the Notifications page.
  factory EmptyState.notifications() => const EmptyState(
        icon: Icons.notifications_none_rounded,
        iconColor: AppTheme.accentTeal,
        title: "You're all caught up!",
        subtitle: "We'll notify you when something new happens.",
      );

  /// Empty state for the Group Tasks section.
  factory EmptyState.tasks({VoidCallback? onAddTask}) => EmptyState(
        icon: Icons.checklist_rounded,
        iconColor: const Color(0xFF1A6B3A), // success green
        title: 'No tasks assigned yet.',
        subtitle: 'Add tasks and assign them to group members.',
        ctaLabel: 'Add Task',
        onCta: onAddTask,
      );

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState>
    with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _floatAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scaleAnim = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut),
    );

    // Subtle floating loop for the icon
    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(
        parent: AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 2000),
        )..repeat(reverse: true),
        curve: Curves.easeInOut,
      ),
    );
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
      child: ScaleTransition(
        scale: _scaleAnim,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceXL,
              vertical: AppConstants.spaceXXL,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Floating icon container ─────────────────────────────────
                AnimatedBuilder(
                  animation: _floatAnim,
                  builder: (_, child) => Transform.translate(
                    offset: Offset(0, _floatAnim.value),
                    child: child,
                  ),
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.iconColor.withValues(alpha: 0.12),
                      border: Border.all(
                        color: widget.iconColor.withValues(alpha: 0.20),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: widget.iconColor.withValues(alpha: 0.15),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      widget.icon,
                      size: 46,
                      color: widget.iconColor,
                    ),
                  ),
                ),

                const SizedBox(height: AppConstants.spaceXL),

                // ── Title ────────────────────────────────────────────────────
                Text(
                  widget.title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppTheme.textPrimaryDark
                        : AppTheme.textPrimaryLight,
                    height: 1.3,
                  ),
                ),

                // ── Subtitle ─────────────────────────────────────────────────
                if (widget.subtitle != null) ...[
                  const SizedBox(height: AppConstants.spaceS),
                  Text(
                    widget.subtitle!,
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
                ],

                // ── CTA button ───────────────────────────────────────────────
                if (widget.ctaLabel != null && widget.onCta != null) ...[
                  const SizedBox(height: AppConstants.spaceXL),
                  _EmptyStateCta(
                    label: widget.ctaLabel!,
                    color: widget.iconColor,
                    onPressed: widget.onCta!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CTA Button
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyStateCta extends StatefulWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _EmptyStateCta({
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  State<_EmptyStateCta> createState() => _EmptyStateCtaState();
}

class _EmptyStateCtaState extends State<_EmptyStateCta> {
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
                color: widget.color.withValues(alpha: 0.35),
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
