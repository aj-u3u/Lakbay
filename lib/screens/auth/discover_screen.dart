import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/buttons/custom_button.dart';

/// The Get Started / landing page shown after the splash screen.
///
/// Features:
/// - Full-screen image carousel with 4-second autoplay
/// - Smooth PageView slide transitions with swipe support
/// - Animated pill dot indicators (active = wide + colored, inactive = small)
/// - Gradient overlay: dark-to-transparent for text legibility
/// - Slide text fades in on page change
/// - Logo badge at top left
/// - "Get Started" → Create Account, "Log In" → Login Page
/// - Fade-in animation on first load (300ms ease-in)
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen>
    with SingleTickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _autoplayTimer;

  // ── Fade-in on page load ──────────────────────────────────────────────────
  late AnimationController _loadCtrl;
  late Animation<double> _loadFade;

  // ── Text cross-fade on slide change ──────────────────────────────────────
  double _textOpacity = 1.0;

  final List<Map<String, String>> _slides = [
    {
      'image':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
      'title': 'Explore Davao Region',
      'subtitle':
          'From Pearl Farm to Mount Apo — your next adventure starts here.',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=900&q=80',
      'title': 'AI-Powered Itineraries',
      'subtitle':
          'Let Lakbay+ craft the perfect Davao trip plan just for you.',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900&q=80',
      'title': 'Capture Your Memories',
      'subtitle':
          'Journal every destination, share stories, relive adventures.',
    },
    {
      'image':
          'https://images.unsplash.com/photo-1552728089-57bdde30beb3?w=900&q=80',
      'title': 'Discover Hidden Gems',
      'subtitle':
          'Uncover the best of all 6 Davao districts — beautifully off the beaten path.',
    },
  ];

  @override
  void initState() {
    super.initState();

    // Load fade-in
    _loadCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..forward();
    _loadFade = CurvedAnimation(parent: _loadCtrl, curve: Curves.easeIn);

    // Start autoplay
    _startAutoplay();
  }

  void _startAutoplay() {
    _autoplayTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentPage + 1) % _slides.length;
      _pageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    // Fade out → update → fade in for text cross-fade
    setState(() => _textOpacity = 0.0);
    Future.delayed(const Duration(milliseconds: 180), () {
      if (!mounted) return;
      setState(() {
        _currentPage = index;
        _textOpacity = 1.0;
      });
    });
  }

  @override
  void dispose() {
    _autoplayTimer?.cancel();
    _pageController.dispose();
    _loadCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: FadeTransition(
        opacity: _loadFade,
        child: Stack(
          children: [
            // ── Full-screen autoplay image carousel ──────────────────────
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (_, i) => Image.network(
                _slides[i]['image']!,
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity,
                // Preload next image to avoid blank flash
                cacheWidth: size.width.toInt(),
                errorBuilder: (_, _, _) => Container(
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

            // ── Gradient overlay: top slightly dark, bottom 60% dark ─────
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.12),
                      Colors.black.withValues(alpha: 0.82),
                    ],
                    stops: const [0.35, 1.0],
                  ),
                ),
              ),
            ),

            // ── Logo badge — top left ────────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppConstants.radiusCircular),
                      boxShadow: AppConstants.premiumShadow,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Image.asset(
                          'assets/images/lakbay_logo.png',
                          width: 22,
                          height: 22,
                        ),
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

            // ── Skip button — top right ──────────────────────────────────
            SafeArea(
              child: Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  child: TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.login),
                    child: const Text(
                      'Log In',
                      style: TextStyle(color: Colors.white70, fontSize: 15),
                    ),
                  ),
                ),
              ),
            ),

            // ── Bottom content: dots + text + CTA buttons ────────────────
            Positioned(
              left: AppConstants.spaceL,
              right: AppConstants.spaceL,
              bottom: 0,
              child: SafeArea(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dot indicators
                    _DotIndicators(
                      count: _slides.length,
                      current: _currentPage,
                    ),
                    const SizedBox(height: AppConstants.spaceL),

                    // Slide title + subtitle with cross-fade
                    AnimatedOpacity(
                      opacity: _textOpacity,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
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
                        ],
                      ),
                    ),

                    const SizedBox(height: AppConstants.spaceXL),

                    // "Get Started" → Create Account (primary filled — spec)
                    CustomButton(
                      label: 'Get Started',
                      onPressed: () =>
                          Navigator.pushNamed(context, AppRoutes.quickPreview),
                      variant: ButtonVariant.primary,
                      width: double.infinity,
                      trailingIcon: Icons.arrow_forward_rounded,
                    ),
                    const SizedBox(height: AppConstants.spaceM),

                    // "Log In" → Login Page (outlined, white on dark bg)
                    _OutlinedWhiteButton(
                      label: 'Log In',
                      onPressed: () => Navigator.pushReplacementNamed(
                          context, AppRoutes.login),
                    ),
                    const SizedBox(height: AppConstants.spaceXL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Animated dot indicators
// ─────────────────────────────────────────────────────────────────────────────

class _DotIndicators extends StatelessWidget {
  final int count;
  final int current;

  const _DotIndicators({required this.count, required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: AppConstants.animDurationFast,
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(right: 6),
          // Active dot is wide pill; inactive is a small circle
          width: isActive ? 28 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isActive
                ? Colors.white
                : Colors.white.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// White outlined button — for use on dark carousel background
// ─────────────────────────────────────────────────────────────────────────────

/// Full-width outlined button with white border/text for the dark carousel bg.
class _OutlinedWhiteButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _OutlinedWhiteButton({
    required this.label,
    required this.onPressed,
  });

  @override
  State<_OutlinedWhiteButton> createState() => _OutlinedWhiteButtonState();
}

class _OutlinedWhiteButtonState extends State<_OutlinedWhiteButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          width: double.infinity,
          height: 52,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.70),
              width: 1.5,
            ),
          ),
          child: const Text(
            'Log In',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }
}
