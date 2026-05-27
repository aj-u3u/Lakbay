import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/buttons/custom_button.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({Key? key}) : super(key: key);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<Map<String, String>> _slides = [
    {
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
      'title': 'Explore Davao Region',
      'subtitle': 'From Pearl Farm to Mount Apo — your next adventure starts here.',
    },
    {
      'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=900&q=80',
      'title': 'AI-Powered Itineraries',
      'subtitle': 'Let Lakbay+ craft the perfect Davao trip plan just for you.',
    },
    {
      'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900&q=80',
      'title': 'Capture Your Memories',
      'subtitle': 'Journal every destination, share stories, relive adventures.',
    },
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Full-screen image carousel
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (i) => setState(() => _currentPage = i),
            itemBuilder: (_, i) => Image.network(
              _slides[i]['image']!,
              fit: BoxFit.cover,
              height: double.infinity,
              width: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.primaryBlue, AppTheme.secondaryGreen],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),

          // Dark gradient overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.78),
                  ],
                  stops: const [0.4, 1.0],
                ),
              ),
            ),
          ),

          // Logo overlay at top left
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                    boxShadow: AppConstants.premiumShadow,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/images/lakbay_logo.png', width: 22, height: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Lakbay+',
                        style: TextStyle(
                          color: AppTheme.primaryBlue,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Skip button
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                child: TextButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                  child: const Text('Skip', style: TextStyle(color: Colors.white70, fontSize: 15)),
                ),
              ),
            ),
          ),

          // Bottom content
          Positioned(
            left: AppConstants.spaceL,
            right: AppConstants.spaceL,
            bottom: 0,
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Page indicators
                  Row(
                    children: List.generate(_slides.length, (i) {
                      return AnimatedContainer(
                        duration: AppConstants.animDurationFast,
                        margin: const EdgeInsets.only(right: 6),
                        width: _currentPage == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == i ? AppTheme.secondaryGreen : Colors.white38,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: AppConstants.spaceL),

                  // Slide text
                  Text(
                    _slides[_currentPage]['title']!,
                    style: GoogleFonts.outfit(
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _slides[_currentPage]['subtitle']!,
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceXL),

                  // Buttons
                  CustomButton(
                    label: 'Get Started',
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.quickPreview),
                    variant: ButtonVariant.secondary,
                    width: double.infinity,
                    trailingIcon: Icons.arrow_forward_rounded,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  CustomButton(
                    label: 'I already have an account',
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                    variant: ButtonVariant.outlined,
                    width: double.infinity,
                  ),
                  const SizedBox(height: AppConstants.spaceXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
