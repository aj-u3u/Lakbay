import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// A compact inline spinner for use next to text fields or result labels.
///
/// Usage:
/// ```dart
/// // Inline next to a budget result field
/// Row(
///   children: [
///     Text('Estimated Total:'),
///     SizedBox(width: 8),
///     if (isCalculating) InlineLoader(),
///     if (!isCalculating) Text('₱3,400'),
///   ],
/// )
/// ```
class InlineLoader extends StatelessWidget {
  /// Size of the spinner (default: 18)
  final double size;

  /// Color of the spinner (defaults to AppTheme.primaryBlue)
  final Color? color;

  const InlineLoader({
    super.key,
    this.size = 18,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: SpinKitRing(
        color: color ?? AppTheme.primaryBlue,
        size: size,
        lineWidth: 2.0,
      ),
    );
  }
}

/// An animated upload progress bar with percentage label.
///
/// Displays a linear progress track with the current percentage and a label.
///
/// Usage:
/// ```dart
/// UploadProgressBar(
///   progress: _uploadProgress, // 0.0 to 1.0
///   label: 'Uploading memory...',
/// )
/// ```
class UploadProgressBar extends StatelessWidget {
  /// Upload progress from 0.0 (0%) to 1.0 (100%)
  final double progress;

  /// Optional label shown above the bar
  final String label;

  const UploadProgressBar({
    super.key,
    required this.progress,
    this.label = 'Uploading...',
  });

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).clamp(0.0, 100.0).toInt();

    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
              Text(
                '$percent%',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: AppTheme.primaryBlue,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceS),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: progress),
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              builder: (_, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor:
                    AppTheme.primaryBlue.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.primaryBlue,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An AI generation spinner with a pulsing message.
///
/// Use this specifically during AI itinerary generation.
///
/// Usage:
/// ```dart
/// AiGeneratingLoader(message: 'Generating your itinerary...')
/// ```
class AiGeneratingLoader extends StatefulWidget {
  final String message;
  const AiGeneratingLoader({
    super.key,
    this.message = 'Generating your itinerary...',
  });

  @override
  State<AiGeneratingLoader> createState() => _AiGeneratingLoaderState();
}

class _AiGeneratingLoaderState extends State<AiGeneratingLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;
  int _dotCount = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulse = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);

    // Animate the trailing dots "..." for the label
    _ctrl.addStatusListener((status) {
      if (status == AnimationStatus.forward && mounted) {
        setState(() {
          _dotCount = (_dotCount % 3) + 1;
        });
      }
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dots = '.' * _dotCount;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _pulse,
          builder: (_, child) => Transform.scale(
            scale: 0.92 + (_pulse.value * 0.08),
            child: child,
          ),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.primaryBlue,
                  AppTheme.accentTeal,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.4),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: AppConstants.spaceL),
        Text(
          '${widget.message.replaceAll('.', '')}$dots',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryBlue,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppConstants.spaceS),
        Text(
          'This may take a few moments',
          style: Theme.of(context).textTheme.bodyMedium,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
