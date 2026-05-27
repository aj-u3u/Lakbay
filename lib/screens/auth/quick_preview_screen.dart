import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../models/destination.dart';
import '../../widgets/buttons/custom_button.dart';

class QuickPreviewScreen extends StatelessWidget {
  const QuickPreviewScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final previews = Destination.davaoDestinations.take(4).toList();

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            stretch: true,
            backgroundColor: AppTheme.primaryBlue,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'Popular in Davao',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=900&q=80',
                    fit: BoxFit.cover,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppTheme.primaryBlue.withOpacity(0.85),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spaceM),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.secondaryGreen.withOpacity(0.12),
                          AppTheme.accentTeal.withOpacity(0.06),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusL),
                      border: Border.all(color: AppTheme.secondaryGreen.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.lock_outline_rounded, color: AppTheme.secondaryGreen),
                        const SizedBox(width: AppConstants.spaceM),
                        Expanded(
                          child: Text(
                            'Sign up to unlock full destination details, plan trips, and access the AI itinerary planner.',
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
                  const SizedBox(height: AppConstants.spaceL),

                  Text(
                    'Sneak Peek',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                ],
              ),
            ),
          ),

          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final dest = previews[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spaceM,
                    0,
                    AppConstants.spaceM,
                    AppConstants.spaceM,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                          boxShadow: AppConstants.cardShadow,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Image.network(
                                  dest.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    color: AppTheme.primaryBlue.withOpacity(0.15),
                                    child: const Icon(Icons.landscape, color: AppTheme.primaryBlue, size: 48),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topRight,
                                      end: Alignment.bottomLeft,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withOpacity(0.6),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: AppConstants.spaceM,
                                left: AppConstants.spaceM,
                                right: AppConstants.spaceM,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      dest.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, color: AppTheme.secondaryGreen, size: 13),
                                        const SizedBox(width: 4),
                                        Text(
                                          dest.location,
                                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                                        ),
                                        const Spacer(),
                                        const Icon(Icons.star, color: Color(0xFFFBBC04), size: 14),
                                        const SizedBox(width: 3),
                                        Text(
                                          dest.rating.toStringAsFixed(1),
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              // Blur lock overlay for unauthenticated preview
                              if (index > 1)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                                      color: Colors.black.withOpacity(0.55),
                                    ),
                                    child: const Center(
                                      child: Icon(Icons.lock_rounded, color: Colors.white60, size: 36),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              childCount: previews.length,
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppConstants.spaceXL),
              child: Column(
                children: [
                  Text(
                    'Create a free account to unlock all destinations.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondaryLight),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  CustomButton(
                    label: 'Create Free Account',
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.signup),
                    variant: ButtonVariant.primary,
                    width: double.infinity,
                    leadingIcon: Icons.person_add_rounded,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  CustomButton(
                    label: 'Log In',
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
    );
  }
}
