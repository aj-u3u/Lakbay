import 'package:flutter/material.dart';

class AppConstants {
  // Spacing & Padding
  static const double spaceXS = 4.0;
  static const double spaceS = 8.0;
  static const double spaceM = 16.0;
  static const double spaceL = 24.0;
  static const double spaceXL = 32.0;
  static const double spaceXXL = 48.0;

  // Border Radii
  static const double radiusS = 8.0;
  static const double radiusM = 12.0;
  static const double radiusL = 20.0;
  static const double radiusXL = 24.0;
  static const double radiusCircular = 99.0;

  // Elevations
  static const double elevationLow = 2.0;
  static const double elevationMedium = 6.0;
  static const double elevationHigh = 12.0;

  // Shadows
  static List<BoxShadow> get premiumShadow => [
        BoxShadow(
          color: const Color(0xFF0A2540).withValues(alpha: 0.06),
          blurRadius: 16.0,
          offset: const Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: const Color(0xFF0F2942).withValues(alpha: 0.08),
          blurRadius: 12.0,
          offset: const Offset(0, 4),
        ),
      ];

  // Duration Constants
  static const Duration animDurationFast = Duration(milliseconds: 200);
  static const Duration animDurationMedium = Duration(milliseconds: 400);
}

