import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../models/destination.dart';
import '../../widgets/buttons/custom_button.dart';

/// Sneak Peek / Discover Page — Clean, premium preview of Lakbay+ content.
///
/// Designed to be consistent with the application's overall design system
/// (Outfit typography, standard brand colors, card shapes, and overlays).
class QuickPreviewScreen extends StatefulWidget {
  const QuickPreviewScreen({super.key});

  @override
  State<QuickPreviewScreen> createState() => _QuickPreviewScreenState();
}

class _QuickPreviewScreenState extends State<QuickPreviewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fadeAnim;

  // Featured destination (highest rated)
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // App Bar
            SliverAppBar(
              pinned: true,
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(1),
                child: Container(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  height: 1,
                ),
              ),
              leading: IconButton(
                icon: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : AppTheme.primaryBlue,
                  size: 18,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Discover Davao',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              centerTitle: true,
            ),

            // Lock Banner
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
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_outline_rounded,
                        color: AppTheme.secondaryGreen,
                        size: 20,
                      ),
                      const SizedBox(width: AppConstants.spaceM),
                      Expanded(
                        child: Text(
                          'Sign up to unlock full interactive details, custom AI planning, and collaborative travel management.',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Main Content Area
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section: Featured Destination
                    Text(
                      'Featured Destination',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Featured Card
                    _buildFeaturedCard(context),

                    const SizedBox(height: 28),

                    // Section: Travel Index (Quick stats)
                    Text(
                      'At A Glance',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Stats Row
                    _buildStatsRow(context),

                    const SizedBox(height: 28),

                    // Section: Categories Grid
                    Text(
                      'Explore by Category',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Category Cards Grid
                    Row(
                      children: [
                        Expanded(
                          child: _buildCategoryCard(
                            context,
                            category: 'Adventure',
                            emoji: '🏔️',
                            imageUrl: 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600&q=80',
                            onTap: () => _navigateToCategory('Adventure'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCategoryCard(
                            context,
                            category: 'Beach',
                            emoji: '🌊',
                            imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80',
                            onTap: () => _navigateToCategory('Beach'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildCategoryCard(
                            context,
                            category: 'Nature',
                            emoji: '🌲',
                            imageUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&q=80',
                            onTap: () => _navigateToCategory('Nature'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildCategoryCard(
                            context,
                            category: 'Culture',
                            emoji: '🏛️',
                            imageUrl: 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=600&q=80',
                            onTap: () => _navigateToCategory('Culture'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Bottom CTA Section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceXL),
                child: Column(
                  children: [
                    Text(
                      'Ready to plan your next adventure?',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create an account to build custom AI itineraries, log expenses, split bills, and save your travel memories forever.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    CustomButton(
                      label: 'Create Free Account',
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                      variant: ButtonVariant.primary,
                      width: double.infinity,
                      leadingIcon: Icons.person_add_rounded,
                    ),
                    const SizedBox(height: 12),
                    CustomButton(
                      label: 'Sign In',
                      onPressed: () => Navigator.pushNamed(context, AppRoutes.login),
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

  Widget _buildFeaturedCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            Destination.loadImage(
              _featured.imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppTheme.primaryBlue.withValues(alpha: 0.15),
              ),
            ),
            
            // Gradient Overlay
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3),
                      Colors.black.withValues(alpha: 0.8),
                    ],
                  ),
                ),
              ),
            ),
            
            // "Featured" Tag
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '★ Featured',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            
            // Text and button contents
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _featured.name,
                          style: GoogleFonts.outfit(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              color: AppTheme.secondaryGreen,
                              size: 13,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _featured.district,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              color: Color(0xFFFBBC04),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${_featured.rating.toStringAsFixed(1)} Rating',
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // Explore Button
                  GestureDetector(
                    onTap: () => _navigateToCategory('All'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white30),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Explore',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 14,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.star_rounded,
            value: '${_featured.rating}★',
            label: 'Highest Rating',
            color: const Color(0xFFFBBC04),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.savings_rounded,
            value: '₱40+',
            label: 'Budget Entries',
            color: const Color(0xFF2E7D32),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.auto_awesome_rounded,
            value: 'Instant',
            label: 'AI Planning',
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    required String category,
    required String emoji,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final int count = Destination.davaoDestinations
        .where((d) => d.category.toLowerCase().contains(category.toLowerCase()))
        .length;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 130,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              Destination.loadImage(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                ),
              ),
              
              // Gradient Overlay
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                        Colors.black.withValues(alpha: 0.8),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Content overlay
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$emoji $category',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$count ${count == 1 ? "destination" : "destinations"}',
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
    );
  }
}
