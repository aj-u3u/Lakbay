import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

enum ButtonVariant { primary, secondary, outlined, ghost }

class CustomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final ButtonVariant variant;
  final bool isLoading;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final double? width;

  const CustomButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = ButtonVariant.primary,
    this.isLoading = false,
    this.leadingIcon,
    this.trailingIcon,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color bgColor;
    Color fgColor;
    BorderSide borderSide;

    switch (variant) {
      case ButtonVariant.secondary:
        bgColor = AppTheme.secondaryGreen;
        fgColor = Colors.white;
        borderSide = BorderSide.none;
        break;
      case ButtonVariant.outlined:
        bgColor = Colors.transparent;
        fgColor = theme.colorScheme.primary;
        borderSide = BorderSide(color: theme.colorScheme.primary, width: 1.5);
        break;
      case ButtonVariant.ghost:
        bgColor = theme.colorScheme.primary.withValues(alpha: 0.08);
        fgColor = theme.colorScheme.primary;
        borderSide = BorderSide.none;
        break;
      case ButtonVariant.primary:
        bgColor = AppTheme.primaryBlue;
        fgColor = Colors.white;
        borderSide = BorderSide.none;
    }

    final bool isButtonDisabled = onPressed == null || isLoading;
    if (isButtonDisabled) {
      bgColor = theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.grey.shade300;
      fgColor = theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.24)
          : Colors.grey.shade500;
      borderSide = BorderSide.none;
    }

    return SizedBox(
      width: width,
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: variant == ButtonVariant.primary ? 3 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            side: borderSide,
          ),
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
        ),
        child: isLoading
            ? SpinKitThreeBounce(
                color: fgColor,
                size: 18.0,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (leadingIcon != null) ...[
                    Icon(leadingIcon, size: 18),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: fgColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (trailingIcon != null) ...[
                    const SizedBox(width: 8),
                    Icon(trailingIcon, size: 18),
                  ],
                ],
              ),
      ),
    );
  }
}
