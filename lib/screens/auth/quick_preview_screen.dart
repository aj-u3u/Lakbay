import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../widgets/buttons/custom_button.dart';

/// An editorial introduction to Lakbay+ for travelers browsing as guests.
class QuickPreviewScreen extends StatelessWidget {
  const QuickPreviewScreen({super.key});

  void _browse(BuildContext context, [String? category]) {
    Navigator.pushNamed(
      context,
      AppRoutes.destinationList,
      arguments: category,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppConstants.spaceL,
                AppConstants.spaceS,
                AppConstants.spaceL,
                AppConstants.spaceXXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_rounded),
                        tooltip: 'Back',
                      ),
                      const SizedBox(width: AppConstants.spaceXS),
                      Expanded(
                        child: Text(
                          'LAKBAY+',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: isDark ? Colors.white : AppTheme.primaryBlue,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () =>
                            Navigator.pushNamed(context, AppRoutes.login),
                        child: const Text('Sign In'),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  _Eyebrow(label: 'DAVAO, YOUR WAY', isDark: isDark),
                  const SizedBox(height: AppConstants.spaceM),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Ready to plan your next '),
                        TextSpan(
                          text: 'adventure?',
                          style: const TextStyle(
                            color: AppTheme.secondaryGreen,
                          ),
                        ),
                      ],
                    ),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                      height: 1.08,
                      letterSpacing: -1.3,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Text(
                    'Meet Lakbay+. Find the Davao places that call to you, shape a trip around your days, and bring your people along.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  _EditorialHero(onTap: () => _browse(context)),
                  const SizedBox(height: AppConstants.spaceXL),
                  _Eyebrow(label: 'THE NEXT CHAPTER', isDark: isDark),
                  const SizedBox(height: AppConstants.spaceS),
                  Text(
                    'Make the journey yours.',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  const _PlanPanel(),
                  const SizedBox(height: AppConstants.spaceM),
                  const _TogetherPanel(),
                  const SizedBox(height: AppConstants.spaceXL),
                  Text(
                    'Where would you go first?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  Text(
                    'Take a look around Davao before you create an account.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Wrap(
                    spacing: AppConstants.spaceS,
                    runSpacing: AppConstants.spaceS,
                    children: [
                      _BrowseChip(
                        label: 'Beaches',
                        icon: Icons.waves_rounded,
                        onTap: () => _browse(context, 'Beach'),
                      ),
                      _BrowseChip(
                        label: 'Adventure',
                        icon: Icons.terrain_rounded,
                        onTap: () => _browse(context, 'Adventure'),
                      ),
                      _BrowseChip(
                        label: 'Nature',
                        icon: Icons.forest_rounded,
                        onTap: () => _browse(context, 'Nature'),
                      ),
                      _BrowseChip(
                        label: 'Culture',
                        icon: Icons.museum_rounded,
                        onTap: () => _browse(context, 'Culture'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(top: BorderSide(color: theme.dividerColor)),
          ),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spaceL,
                  AppConstants.spaceS,
                  AppConstants.spaceL,
                  AppConstants.spaceS,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Sign up to unlock the full interactive experience',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceS),
                    CustomButton(
                      label: 'Sign Up',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.signup),
                      width: double.infinity,
                      trailingIcon: Icons.arrow_forward_rounded,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  final String label;
  final bool isDark;

  const _Eyebrow({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 20, height: 2, color: AppTheme.secondaryGreen),
        const SizedBox(width: AppConstants.spaceS),
        Flexible(
          child: Text(
            label,
            style: TextStyle(
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditorialHero extends StatelessWidget {
  final VoidCallback onTap;

  const _EditorialHero({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Browse Davao destinations',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        child: Material(
          color: AppTheme.primaryBlue,
          child: InkWell(
            key: const Key('browse_davao_destinations'),
            onTap: onTap,
            child: SizedBox(
              height: 280,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/destinations/dahican_beach.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const ColoredBox(color: AppTheme.primaryBlue),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x000D1F1F), Color(0xD90D1F1F)],
                        stops: [0.24, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: AppConstants.spaceM,
                    left: AppConstants.spaceM,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceM,
                        vertical: AppConstants.spaceS,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusCircular,
                        ),
                      ),
                      child: const Text(
                        '01  /  DISCOVER',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppConstants.spaceL,
                    right: AppConstants.spaceL,
                    bottom: AppConstants.spaceL,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'DAHICAN BEACH · DAVAO ORIENTAL',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: AppConstants.spaceS),
                              Text(
                                'Find the places worth going for.',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      height: 1.1,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        const CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.white,
                          child: Icon(
                            Icons.arrow_outward_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '02  /  PLAN',
            style: TextStyle(
              color: Color(0xFFFFD3B3),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          const Text(
            'A trip shaped around you.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          const Text(
            'Tell Lakbay+ what you love. AI helps turn your time and interests into an itinerary.',
            style: TextStyle(color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: AppConstants.spaceL),
          Container(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppConstants.radiusM),
              border: Border.all(color: Colors.white24),
            ),
            child: const Column(
              children: [
                _PlanStop(
                  icon: Icons.wb_sunny_outlined,
                  label: 'YOUR PACE',
                  value: 'A day that fits',
                ),
                SizedBox(height: AppConstants.spaceM),
                _PlanStop(
                  icon: Icons.route_rounded,
                  label: 'YOUR ROUTE',
                  value: 'Stops that connect',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanStop extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PlanStop({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFFFFD3B3), size: 20),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const Icon(Icons.check_circle_rounded, color: Colors.white70, size: 18),
      ],
    );
  }
}

class _TogetherPanel extends StatelessWidget {
  const _TogetherPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.cardColorDark : const Color(0xFFFFF0E5),
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '03  /  TOGETHER',
            style: TextStyle(
              color: AppTheme.secondaryGreen,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            'Better when everyone is in.',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            'Keep group plans, shared tasks, and travel memories in one place.',
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppConstants.spaceL),
          Row(
            children: [
              const _PersonDot(color: AppTheme.primaryBlue),
              Transform.translate(
                offset: Offset(-8, 0),
                child: const _PersonDot(color: AppTheme.secondaryGreen),
              ),
              Transform.translate(
                offset: Offset(-16, 0),
                child: const _PersonDot(color: AppTheme.accentTeal),
              ),
              Expanded(
                child: Text(
                  'Plan it. Share it. Remember it.',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonDot extends StatelessWidget {
  final Color color;

  const _PersonDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 19,
      backgroundColor: Theme.of(context).colorScheme.surface,
      child: CircleAvatar(
        radius: 16,
        backgroundColor: color,
        child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

class _BrowseChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _BrowseChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      onPressed: onTap,
      avatar: Icon(icon, size: 18, color: AppTheme.primaryBlue),
      label: Text(label),
    );
  }
}
