import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// A shimmering skeleton loader that mimics real content shapes.
///
/// Use these to replace empty areas while content is loading.
/// Each variant matches the shape and proportions of its real counterpart.
///
/// ## Available Variants
///
/// ### Notification list skeleton
/// ```dart
/// SkeletonNotificationList(count: 4)
/// ```
///
/// ### Trip card skeleton
/// ```dart
/// SkeletonTripCard()
/// ```
///
/// ### Destination card skeleton
/// ```dart
/// SkeletonDestinationCard()
/// ```
///
/// ### Generic skeleton block
/// ```dart
/// SkeletonBlock(width: double.infinity, height: 48)
/// ```

// ─────────────────────────────────────────────────────────────────────────────
// Internal shimmer animation base
// ─────────────────────────────────────────────────────────────────────────────
class _ShimmerBase extends StatefulWidget {
  final Widget child;
  const _ShimmerBase({required this.child});

  @override
  State<_ShimmerBase> createState() => _ShimmerBaseState();
}

class _ShimmerBaseState extends State<_ShimmerBase>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? AppTheme.cardColorDark
        : const Color(0xFFE8EFEF);
    final highlightColor = isDark
        ? AppTheme.primaryBlue.withValues(alpha: 0.12)
        : const Color(0xFFCFDFDF);

    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => ShaderMask(
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [baseColor, highlightColor, baseColor],
          stops: [
            (_anim.value - 0.3).clamp(0.0, 1.0),
            _anim.value.clamp(0.0, 1.0),
            (_anim.value + 0.3).clamp(0.0, 1.0),
          ],
        ).createShader(bounds),
        child: widget.child,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Primitive: Rounded skeleton block
// ─────────────────────────────────────────────────────────────────────────────

/// A single skeleton rectangle — use as a building block.
class SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBlock({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = AppConstants.radiusS,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ShimmerBase(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.cardColorDark : const Color(0xFFE8EFEF),
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification list skeleton
// ─────────────────────────────────────────────────────────────────────────────

/// Mimics a notification list item — icon circle + two lines of text.
/// Wrap [count] times for a full skeleton list.
class SkeletonNotificationList extends StatelessWidget {
  final int count;
  const SkeletonNotificationList({super.key, this.count = 4});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        count,
        (_) => Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spaceM,
            vertical: AppConstants.spaceS,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon circle
              SkeletonBlock(width: 44, height: 44, borderRadius: 22),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    const SkeletonBlock(height: 14),
                    const SizedBox(height: AppConstants.spaceS),
                    SkeletonBlock(
                        width: MediaQuery.of(context).size.width * 0.55,
                        height: 12),
                    const SizedBox(height: AppConstants.spaceS),
                    SkeletonBlock(
                        width: MediaQuery.of(context).size.width * 0.28,
                        height: 10),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Trip card skeleton
// ─────────────────────────────────────────────────────────────────────────────

/// Mimics a trip card — hero image area, title, subtitle, tags.
class SkeletonTripCard extends StatelessWidget {
  const SkeletonTripCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceM,
        vertical: AppConstants.spaceS,
      ),
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero image area
          const SkeletonBlock(height: 140, borderRadius: AppConstants.radiusL),
          const SizedBox(height: AppConstants.spaceM),
          // Title
          const SkeletonBlock(height: 18),
          const SizedBox(height: AppConstants.spaceS),
          // Subtitle
          SkeletonBlock(
              width: MediaQuery.of(context).size.width * 0.5, height: 13),
          const SizedBox(height: AppConstants.spaceM),
          // Tags row
          Row(
            children: [
              const SkeletonBlock(width: 60, height: 24, borderRadius: 12),
              const SizedBox(width: AppConstants.spaceS),
              const SkeletonBlock(width: 80, height: 24, borderRadius: 12),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Destination card skeleton
// ─────────────────────────────────────────────────────────────────────────────

/// Mimics a horizontal destination card — square photo + title + subtitle.
class SkeletonDestinationCard extends StatelessWidget {
  const SkeletonDestinationCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 180,
      margin: const EdgeInsets.only(right: AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBlock(height: 130, borderRadius: AppConstants.radiusL),
          const SizedBox(height: AppConstants.spaceS),
          const SkeletonBlock(height: 14),
          const SizedBox(height: 4),
          const SkeletonBlock(width: 100, height: 12),
        ],
      ),
    );
  }
}
