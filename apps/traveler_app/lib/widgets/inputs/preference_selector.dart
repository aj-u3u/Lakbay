import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';

class PreferenceSelector extends StatelessWidget {
  final List<String> options;
  final List<String> selected;
  final ValueChanged<String> onToggle;

  const PreferenceSelector({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    return Wrap(
      spacing: AppConstants.spaceS,
      runSpacing: AppConstants.spaceS,
      children: options.map((option) {
        final isSelected = selected.contains(option);
        return GestureDetector(
          onTap: () => onToggle(option),
          child: AnimatedContainer(
            duration: AppConstants.animDurationFast,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceM,
              vertical: AppConstants.spaceS,
            ),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
              borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
              border: Border.all(
                color: isSelected ? AppTheme.primaryBlue : secondaryTextColor.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            child: Text(
              option,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : secondaryTextColor,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

