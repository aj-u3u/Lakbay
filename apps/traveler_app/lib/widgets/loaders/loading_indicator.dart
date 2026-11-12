import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

/// A full-page centered loading spinner
class LoadingIndicator extends StatelessWidget {
  final String? message;
  const LoadingIndicator({super.key, this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SpinKitFoldingCube(
            color: AppTheme.secondaryGreen,
            size: 40.0,
          ),
          if (message != null) ...[
            const SizedBox(height: AppConstants.spaceL),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A shimmer skeleton card placeholder for loading lists
class ShimmerCard extends StatefulWidget {
  final double width;
  final double height;

  const ShimmerCard({super.key, this.width = double.infinity, this.height = 120});

  @override
  State<ShimmerCard> createState() => _ShimmerCardState();
}

class _ShimmerCardState extends State<ShimmerCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (_, _) => Container(
        width: widget.width,
        height: widget.height,
        margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          color: AppTheme.primaryBlue.withValues(alpha: _animation.value * 0.08),
          border: Border.all(
            color: AppTheme.primaryBlue.withValues(alpha: 0.06),
          ),
        ),
      ),
    );
  }
}
