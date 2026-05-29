import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../models/destination.dart';
import '../../widgets/buttons/custom_button.dart';

/// Sneak Peek / Discover Page — Bento-style layout.
///
/// Shown to unauthenticated users as a premium preview of Lakbay+ content.
/// Layout (per spec):
///   [ LARGE CARD — Featured Destination (full width) ]
///   [ MEDIUM — Adventure ]  [ MEDIUM — Beach ]
///   [ SMALL — Rating ]  [ SMALL — Budget ]  [ SMALL — AI Pick ]
///   [ MEDIUM — Nature ]  [ MEDIUM — Culture ]
class QuickPreviewScreen extends StatefulWidget {
  const QuickPreviewScreen({super.key});

  @override
  State<QuickPreviewScreen> createState() => _QuickPreviewScreenState();
}

class _QuickPreviewScreenState extends State<QuickPreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  // Feature destination (highest rated)
  late Destination _featured;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    final all = Destination.davaoDestinations;
    _featured = all.reduce((a, b) => a.rating >= b.rating ? a : b);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _navigateToCategory(String category) {
    Navigator.pushNamed(
      context,
      AppRoutes.destinationList,
      arguments: category == 'All' ? null : category,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.primaryBlue,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Discover Davao',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),

            // ── Lock banner ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spaceM,
                  AppConstants.spaceM,
                  AppConstants.spaceM,
                  0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppTheme.secondaryGreen.withValues(alpha: 0.12),
                        AppTheme.accentTeal.withValues(alpha: 0.06),
                      ],
                    ),
                    borderRadius:
                        BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(
                        color:
                            AppTheme.secondaryGreen.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lock_outline_rounded,
                          color: AppTheme.secondaryGreen),
                      const SizedBox(width: AppConstants.spaceM),
                      Expanded(
                        child: Text(
                          'Sign up to unlock full details, AI planning, and trip management.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: AppTheme.primaryBlue,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // ── Bento Grid ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: AppConstants.spaceS),

                    // ── Row 1: Large featured card (full width) ───────────
                    _BentoLargeCard(
                      destination: _featured,
                      onTap: () => _navigateToCategory('All'),
                    ),
                    const SizedBox(height: AppConstants.spaceS),

                    // ── Row 2: Two medium cards (Adventure + Beach) ───────
                    Row(
                      children: [
                        Expanded(
                          child: _BentoMediumCard(
                            category: 'Adventure',
                            emoji: '🏔️',
                            accentColor: const Color(0xFF2E7D32),
                            imageUrl:
                                'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600&q=80',
                            destinationCount: _countCategory('Adventure'),
                            onTap: () => _navigateToCategory('Adventure'),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        Expanded(
                          child: _BentoMediumCard(
                            category: 'Beach',
                            emoji: '🌊',
                            accentColor: const Color(0xFF0277BD),
                            imageUrl:
                                'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80',
                            destinationCount: _countCategory('Beach'),
                            onTap: () => _navigateToCategory('Beach'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceS),

                    // ── Row 3: Three small badge cards ────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _BentoSmallCard(
                            icon: Icons.star_rounded,
                            label: 'Top Rated',
                            value: '4.8★',
                            color: const Color(0xFFF57F17),
                            onTap: () => _navigateToCategory('All'),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        Expanded(
                          child: _BentoSmallCard(
                            icon: Icons.savings_rounded,
                            label: 'Budget Pick',
                            value: 'From ₱40',
                            color: const Color(0xFF1A6B3A),
                            onTap: () => _navigateToCategory('Nature'),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        Expanded(
                          child: _BentoSmallCard(
                            icon: Icons.auto_awesome_rounded,
                            label: 'AI Pick',
                            value: 'For You',
                            color: AppTheme.primaryBlue,
                            onTap: () => Navigator.pushNamed(
                                context, AppRoutes.signup),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceS),

                    // ── Row 4: Two medium cards (Nature + Culture) ────────
                    Row(
                      children: [
                        Expanded(
                          child: _BentoMediumCard(
                            category: 'Nature',
                            emoji: '🌲',
                            accentColor: const Color(0xFF388E3C),
                            imageUrl:
                                'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&q=80',
                            destinationCount: _countCategory('Nature'),
                            onTap: () => _navigateToCategory('Nature'),
                          ),
                        ),
                        const SizedBox(width: AppConstants.spaceS),
                        Expanded(
                          child: _BentoMediumCard(
                            category: 'Culture',
                            emoji: '🏛️',
                            accentColor: const Color(0xFF6A1B9A),
                            imageUrl:
                                'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
                            destinationCount: _countCategory('Culture'),
                            onTap: () => _navigateToCategory('Culture'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // ── CTA section ───────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceXL),
                child: Column(
                  children: [
                    Text(
                      'Create an account to unlock all destinations.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                          fontSize: 14,
                          color: AppTheme.textSecondaryLight),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    CustomButton(
                      label: 'Create Account',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.signup),
                      variant: ButtonVariant.primary,
                      width: double.infinity,
                      leadingIcon: Icons.person_add_rounded,
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    CustomButton(
                      label: 'Log In',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.login),
                      variant: ButtonVariant.outlined,
                      width: double.infinity,
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

  int _countCategory(String category) {
    return Destination.davaoDestinations
        .where((d) =>
            d.category.toLowerCase().contains(category.toLowerCase()))
        .length;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Large Card — Featured Destination (full width, 220px)
// ─────────────────────────────────────────────────────────────────────────────

class _BentoLargeCard extends StatefulWidget {
  final Destination destination;
  final VoidCallback onTap;

  const _BentoLargeCard({required this.destination, required this.onTap});

  @override
  State<_BentoLargeCard> createState() => _BentoLargeCardState();
}

class _BentoLargeCardState extends State<_BentoLargeCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 220,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo
                Image.network(
                  widget.destination.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  ),
                ),
                // Dark gradient bottom 50%
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                        stops: const [0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                // "Featured" pill
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryGreen,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusCircular),
                    ),
                    child: Text(
                      '⭐ Featured',
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // Bottom content
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.destination.name,
                        style: GoogleFonts.outfit(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.location_on,
                              color: AppTheme.secondaryGreen, size: 13),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              widget.destination.district,
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFFBBC04), size: 14),
                          const SizedBox(width: 3),
                          Text(
                            widget.destination.rating.toStringAsFixed(1),
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(
                              AppConstants.radiusCircular),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.40)),
                        ),
                        child: Text(
                          'Explore →',
                          style: GoogleFonts.outfit(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Medium Card — Category (140px height)
// ─────────────────────────────────────────────────────────────────────────────

class _BentoMediumCard extends StatefulWidget {
  final String category;
  final String emoji;
  final Color accentColor;
  final String imageUrl;
  final int destinationCount;
  final VoidCallback onTap;

  const _BentoMediumCard({
    required this.category,
    required this.emoji,
    required this.accentColor,
    required this.imageUrl,
    required this.destinationCount,
    required this.onTap,
  });

  @override
  State<_BentoMediumCard> createState() => _BentoMediumCardState();
}

class _BentoMediumCardState extends State<_BentoMediumCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 140,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  widget.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                      color:
                          widget.accentColor.withValues(alpha: 0.2)),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.70),
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.emoji} ${widget.category}',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${widget.destinationCount} destinations',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: Colors.white70,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small Card — Badge/stat (80px height)
// ─────────────────────────────────────────────────────────────────────────────

class _BentoSmallCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;

  const _BentoSmallCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });

  @override
  State<_BentoSmallCard> createState() => _BentoSmallCardState();
}

class _BentoSmallCardState extends State<_BentoSmallCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: 80,
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.22),
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, color: widget.color, size: 22),
              const SizedBox(height: 4),
              Text(
                widget.value,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: widget.color,
                ),
              ),
              Text(
                widget.label,
                style: GoogleFonts.outfit(
                  fontSize: 10,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
