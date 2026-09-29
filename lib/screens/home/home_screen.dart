import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/destination.dart';
import '../../providers/trip_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nav_provider.dart';
import '../../widgets/shared/section_header.dart';
import '../../widgets/cards/destination_card.dart';
import '../../widgets/cards/promo_card.dart';
import '../../models/planner_draft.dart';
import '../../services/api_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();
  String _selectedCategory = 'All';
  final PageController _promoPageCtrl = PageController();
  int _currentPromoPage = 0;
  Timer? _promoTimer;

  // Search & filter states
  String _searchQuery = '';
  String _selectedDistrict = 'All';
  String _sortBy = 'Popularity';

  // Suggestions states
  final _searchFocusNode = FocusNode();
  OverlayEntry? _suggestionsOverlayEntry;
  final LayerLink _layerLink = LayerLink();

  // Dual-Engine backend popularity & recommendation states
  List<Destination> _popularDestinations = [];
  List<Destination> _recommendedDestinations = [];
  bool _loadingPopular = false;
  bool _loadingRecommended = false;

  List<Map<String, String>> _getSuggestions(List<Destination> allDests) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return [];

    final List<Map<String, String>> matches = [];

    // 1. Match districts
    final districts = [
      'Davao City',
      'Davao del Norte',
      'Davao del Sur',
      'Davao Oriental',
      'Davao de Oro',
      'Davao Occidental',
    ];
    for (final dist in districts) {
      if (dist.toLowerCase().contains(query)) {
        matches.add({'name': dist, 'type': 'district'});
      }
    }

    // 2. Match destinations
    for (final dest in allDests) {
      if (dest.name.toLowerCase().contains(query)) {
        matches.add({
          'name': dest.name,
          'type': 'destination',
          'subtitle': dest.location,
        });
      }
    }

    return matches;
  }



  final List<Map<String, dynamic>> _promoSlides = [
    {
      'id': 8,
      'title': 'Pearl Farm\nBeach Resort',
      'subtitle': 'Samal Island, Davao del Norte',
      'image':
          'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
    },
    {
      'id': 15,
      'title': 'Dahican Beach\nSurf Paradise',
      'subtitle': 'Mati City, Davao Oriental',
      'image':
          'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=900&q=80',
    },
    {
      'id': 12,
      'title': 'Mount Apo\nNational Park',
      'subtitle': 'Digos City, Davao del Sur',
      'image':
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900&q=80',
    },
  ];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onSearchFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TripProvider>().loadInitialData();
      _fetchRealDestinations();
    });
    _startPromoTimer();
  }

  void _fetchRealDestinations() async {
    if (!mounted) return;
    setState(() {
      _loadingPopular = true;
      _loadingRecommended = true;
    });

    try {
      final popular = await ApiService().fetchPopularDestinations(limit: 10);
      if (mounted) {
        setState(() {
          _popularDestinations = popular;
          _loadingPopular = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingPopular = false);
    }

    try {
      final recommended = await ApiService().fetchRecommendedDestinations(
        limit: 6,
      );
      if (mounted) {
        setState(() {
          _recommendedDestinations = recommended;
          _loadingRecommended = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingRecommended = false);
    }
  }

  void _onSearchFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchQuery.trim().isNotEmpty) {
      _showOverlay();
    } else {
      _hideOverlay();
    }
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchCtrl.text;
      if (_searchQuery.isNotEmpty) {
        _selectedCategory = 'All';
      }
    });

    if (_searchFocusNode.hasFocus && _searchQuery.trim().isNotEmpty) {
      if (_suggestionsOverlayEntry == null) {
        _showOverlay();
      } else {
        _suggestionsOverlayEntry!.markNeedsBuild();
      }
    } else {
      _hideOverlay();
    }
  }

  void _startPromoTimer() {
    _promoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final nextPage = (_currentPromoPage + 1) % _promoSlides.length;
      _promoPageCtrl.animateToPage(
        nextPage,
        duration: AppConstants.animDurationMedium,
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _hideOverlay();
    _searchCtrl.removeListener(_onSearchChanged);
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    _promoTimer?.cancel();
    _promoPageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Destination> _filteredDestinations(List<Destination> allDests) {
    var list = allDests;

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      list = list.where((d) {
        final query = _searchQuery.toLowerCase();
        return d.name.toLowerCase().contains(query) ||
            d.location.toLowerCase().contains(query) ||
            d.district.toLowerCase().contains(query) ||
            d.category.toLowerCase().contains(query);
      }).toList();
    }

    // Filter by selected category
    if (_selectedCategory != 'All') {
      list = list
          .where(
            (d) => d.category.toLowerCase().contains(
              _selectedCategory.toLowerCase(),
            ),
          )
          .toList();
    }

    // Filter by selected district / province
    if (_selectedDistrict != 'All') {
      list = list.where((d) => d.district == _selectedDistrict).toList();
    }

    // Sort the list
    if (_sortBy == 'Rating') {
      list.sort((a, b) => b.rating.compareTo(a.rating));
    } else if (_sortBy == 'Cost: Low to High') {
      list.sort((a, b) => a.estimatedCost.compareTo(b.estimatedCost));
    } else if (_sortBy == 'Cost: High to Low') {
      list.sort((a, b) => b.estimatedCost.compareTo(a.estimatedCost));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TripProvider>();
    final allDests = provider.destinations.isNotEmpty
        ? provider.destinations
        : Destination.davaoDestinations;
    final filtered = _filteredDestinations(allDests);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          // Gradient header
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
                ),
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(32),
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + AppConstants.spaceM,
                left: AppConstants.spaceL,
                right: AppConstants.spaceL,
                bottom: AppConstants.spaceXL,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            ClipOval(
                              child: Image.asset(
                                'assets/images/lakbay_logo.png',
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spaceM),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(
                                  builder: (context) {
                                    final firstName =
                                        context
                                            .watch<AuthProvider>()
                                            .userProfile
                                            ?.displayName
                                            .split(' ')
                                            .first ??
                                        'Traveler';

                                    final hour = DateTime.now().hour;
                                    String greeting;
                                    if (hour < 12) {
                                      greeting = 'Good Morning';
                                    } else if (hour < 17) {
                                      greeting = 'Good Afternoon';
                                    } else {
                                      greeting = 'Good Evening';
                                    }

                                    return Text(
                                      '$greeting, $firstName 👋',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        color: Colors.white60,
                                      ),
                                    );
                                  },
                                ),
                                Text(
                                  'Discover Davao',
                                  style: GoogleFonts.outfit(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.notifications,
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.notifications_outlined,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            if (provider.unreadNotificationCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 2,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 18,
                                    minHeight: 18,
                                  ),
                                  child: Center(
                                    child: Text(
                                      provider.unreadNotificationCount > 9
                                          ? '9+'
                                          : provider.unreadNotificationCount
                                                .toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  // Search bar container with Google Maps-style autocomplete overlay target
                  CompositedTransformTarget(
                    link: _layerLink,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusL,
                        ),
                        boxShadow: AppConstants.premiumShadow,
                      ),
                      child: TextField(
                        controller: _searchCtrl,
                        focusNode: _searchFocusNode,
                        onSubmitted: (val) {
                          setState(() {
                            _searchQuery = val;
                            _hideOverlay();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: 'Search destinations in Davao...',
                          hintStyle: TextStyle(
                            color: AppTheme.textSecondaryLight.withValues(
                              alpha: 0.6,
                            ),
                            fontSize: 14,
                          ),
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            color: AppTheme.primaryBlue,
                          ),
                          suffixIcon: GestureDetector(
                            onTap: _showFilterBottomSheet,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryGreen,
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusM,
                                ),
                              ),
                              child: const Icon(
                                Icons.tune_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Continue Planning Widget (only displayed if incomplete draft trip exists)
          if (provider.activeDraft != null)
            _buildContinuePlanningSliver(context, provider.activeDraft!),

          // ── Davao Context Strip ──────────────────────────────────────────
          SliverToBoxAdapter(
            child: _buildDavaoContextStrip(context),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppConstants.spaceL),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM,
                  ),
                  child: Text(
                    'AI Mood Suggestions ✨',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM,
                    vertical: 4,
                  ),
                  child: Text(
                    'Tap a mood to start planning your perfect itinerary instantly',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceS),
                SizedBox(
                  height: 52,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceM,
                    ),
                    children: [
                      _buildMoodTile(context, 'Adventure', '🏔️', 'Suggest an adventure trip in Davao Region.'),
                      _buildMoodTile(context, 'Relaxation', '🌿', 'Suggest a relaxation trip in Davao Region.'),
                      _buildMoodTile(context, 'Family', '👨', 'Suggest a family trip in Davao Region.'),
                      _buildMoodTile(context, 'Beach', '🌊', 'Suggest a beach trip in Davao Region.'),
                      _buildMoodTile(context, 'Nature', '🌲', 'Suggest a nature trip in Davao Region.'),
                      _buildMoodTile(context, 'Culture', '🏙️', 'Suggest a cultural trip in Davao Region.'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Featured promo carousel
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppConstants.spaceL),
                SectionHeader(
                  title: '🔥 Trending in Davao',
                  onActionPressed: () =>
                      Navigator.pushNamed(context, AppRoutes.destinationList),
                ),
                const SizedBox(height: AppConstants.spaceS),
                SizedBox(
                  height: 196,
                  child: PageView.builder(
                    controller: _promoPageCtrl,
                    itemCount: _promoSlides.length,
                    onPageChanged: (i) => setState(() => _currentPromoPage = i),
                    itemBuilder: (_, i) {
                      final s = _promoSlides[i];
                      return PromoCard(
                        title: s['title'] as String,
                        subtitle: s['subtitle'] as String,
                        imageUrl: s['image'] as String,
                        onTap: () {
                          final destId = s['id'] as int;
                          final dest = allDests.firstWhere(
                            (d) => d.id == destId,
                            orElse: () => allDests.firstWhere((d) => d.id == 8),
                          );
                          Navigator.pushNamed(
                            context,
                            AppRoutes.destinationDetail,
                            arguments: dest,
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppConstants.spaceS),
                // Dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_promoSlides.length, (i) {
                    final isActive = i == _currentPromoPage;
                    return AnimatedContainer(
                      duration: AppConstants.animDurationFast,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: isActive ? 22 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppTheme.primaryBlue
                            : AppTheme.primaryBlue.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusCircular,
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Dual-Engine Recommendations and Global Popular Leaderboard or Search Results
          SliverToBoxAdapter(
            child:
                _searchQuery.isEmpty &&
                    _selectedCategory == 'All' &&
                    _selectedDistrict == 'All'
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildRecommendedSection(context),
                      _buildPopularLeaderboardSection(context),
                    ],
                  )
                : Column(
                    children: [
                      const SizedBox(height: AppConstants.spaceL),
                      SectionHeader(
                        title: 'Search Results',
                        onActionPressed: () => Navigator.pushNamed(
                          context,
                          AppRoutes.destinationList,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceS),
                      SizedBox(
                        height: 290,
                        child: filtered.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: 0.05,
                                        ),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.search_off_rounded,
                                        size: 40,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No destinations found',
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Try adjusting your search or filters',
                                      style: TextStyle(
                                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppConstants.spaceM,
                                ),
                                itemCount: filtered.length,
                                itemBuilder: (_, i) => DestinationCard(
                                  destination: filtered[i],
                                  onTap: () => Navigator.pushNamed(
                                    context,
                                    AppRoutes.destinationDetail,
                                    arguments: filtered[i],
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
          ),


          const SliverToBoxAdapter(
            child: SizedBox(height: AppConstants.spaceXL),
          ),
        ],
      ),
    );
  }



  // District data: name, representative image URL, accent color
  static const List<Map<String, dynamic>> _districtData = [
    {
      'name': 'Davao City',
      'image': 'https://images.unsplash.com/photo-1506905925346-21bda4d32df4?w=600&q=80',
      'accent': Color(0xFF0D7377),
    },
    {
      'name': 'Davao del Norte',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=600&q=80',
      'accent': Color(0xFF1A6B3A),
    },
    {
      'name': 'Davao del Sur',
      'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=600&q=80',
      'accent': Color(0xFF2C5364),
    },
    {
      'name': 'Davao Oriental',
      'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=600&q=80',
      'accent': Color(0xFF16213E),
    },
    {
      'name': 'Davao de Oro',
      'image': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=600&q=80',
      'accent': Color(0xFF355C7D),
    },
    {
      'name': 'Davao Occidental',
      'image': 'https://images.unsplash.com/photo-1518020382113-a7e8fc38eac9?w=600&q=80',
      'accent': Color(0xFF6A3093),
    },
  ];

  // ── Davao Context Strip ───────────────────────────────────────────────────
  Widget _buildDavaoContextStrip(BuildContext context) {
    final month = DateTime.now().month;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Davao season logic (Davao is largely typhoon-free year-round)
    final String season;
    final String weatherIcon;
    final String tip;
    final Color stripColor;

    if (month >= 3 && month <= 5) {
      season = 'Summer Season';
      weatherIcon = '☀️';
      tip = 'Ideal for beach trips & outdoor adventures in Davao Region';
      stripColor = const Color(0xFFF4A261);
    } else if (month >= 6 && month <= 9) {
      season = 'Green Season';
      weatherIcon = '🌦️';
      tip = 'Lush landscapes — perfect for nature trails & waterfalls';
      stripColor = const Color(0xFF2D6A4F);
    } else if (month >= 10 && month <= 11) {
      season = 'Harvest Season';
      weatherIcon = '🌤️';
      tip = 'Peak travel season — festivals, fairs & cooler weather';
      stripColor = const Color(0xFF457B9D);
    } else {
      season = 'Cool Season';
      weatherIcon = '🌬️';
      tip = 'Comfortable temps — great for highland hikes & cultural tours';
      stripColor = const Color(0xFF1D3557);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppConstants.spaceM, AppConstants.spaceM, AppConstants.spaceM, 0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              stripColor.withValues(alpha: isDark ? 0.35 : 0.12),
              stripColor.withValues(alpha: isDark ? 0.18 : 0.05),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: stripColor.withValues(alpha: isDark ? 0.40 : 0.25),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Text(weatherIcon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Davao Region',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: stripColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          season,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: stripColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tip,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
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

  Widget _buildRecommendedSection(BuildContext context) {
    final allDests = context.read<TripProvider>().destinations.isNotEmpty
        ? context.read<TripProvider>().destinations
        : Destination.davaoDestinations;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spaceL),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📍 Browse by Province',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'Pick a district and start planning your itinerary',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.destinationList),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.secondaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 190,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
              ),
              itemCount: _districtData.length,
              itemBuilder: (context, index) {
                final district = _districtData[index];
                final districtName = district['name'] as String;
                final imageUrl = district['image'] as String;
                final accentColor = district['accent'] as Color;
                final count = allDests
                    .where((d) => d.district == districtName)
                    .length;
                return _buildDistrictCategoryCard(
                  context,
                  districtName: districtName,
                  imageUrl: imageUrl,
                  accentColor: accentColor,
                  count: count,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictCategoryCard(
    BuildContext context, {
    required String districtName,
    required String imageUrl,
    required Color accentColor,
    required int count,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.districtHub,
          arguments: {
            'districtName': districtName,
            'heroImageUrl': imageUrl,
            'accentColor': accentColor,
          },
        );
      },
      child: Container(
        width: 140,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Full background image
              Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: accentColor,
                  child: const Icon(
                    Icons.landscape_rounded,
                    size: 48,
                    color: Colors.white38,
                  ),
                ),
              ),
              // Subtle bottom gradient only — like Klook
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                      stops: const [0.0, 0.45, 0.75, 1.0],
                    ),
                  ),
                ),
              ),
              // Bottom text: district name + spot count
              Positioned(
                left: 10,
                right: 10,
                bottom: 10,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      districtName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      count > 0
                          ? '$count ${count == 1 ? 'destination' : 'destinations'}'
                          : 'Explore',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
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

  Widget _buildPopularLeaderboardSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loadingPopular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spaceL),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceM,
            ),
            child: SectionHeader(
              title: 'Popular Destinations 🔥',
              onActionPressed: () {},
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          SizedBox(
            height: 290,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceM,
              ),
              itemCount: 3,
              itemBuilder: (_, _) => _buildShimmerCard(context),
            ),
          ),
        ],
      );
    }

    if (_popularDestinations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.spaceL),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⭐ Top-Rated Attractions',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'Davao Region\'s most celebrated destinations',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.destinationList),
                child: const Text(
                  'View All',
                  style: TextStyle(
                    color: AppTheme.secondaryGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceS),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.spaceM,
            ),
            itemCount: _popularDestinations.length,
            itemBuilder: (context, index) {
              final dest = _popularDestinations[index];
              return _buildPopularLeaderboardCard(context, dest, index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPopularLeaderboardCard(
    BuildContext context,
    Destination dest,
    int index,
  ) {
    final isTrending =
        dest.trendingStatus == 'high' || dest.trendingStatus == 'rising';

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.destinationDetail,
          arguments: dest,
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: AppConstants.spaceM),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          boxShadow: AppConstants.premiumShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          child: Stack(
            children: [
              // Hero Image
              Positioned.fill(
                child: Destination.loadImage(
                  dest.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.landscape,
                      size: 60,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
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
                        Colors.black.withValues(alpha: 0.1),
                        Colors.black.withValues(alpha: 0.3),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                      stops: const [0.2, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // Leaderboard Rank Badge (Hidden from UI as requested)
              // Positioned(
              //   top: AppConstants.spaceM,
              //   left: AppConstants.spaceM,
              //   child: Container(
              //     width: 32,
              //     height: 32,
              //     decoration: BoxDecoration(
              //       gradient: LinearGradient(colors: rankColors),
              //       shape: BoxShape.circle,
              //       boxShadow: [
              //         BoxShadow(
              //           color: rankColors.first.withValues(alpha: 0.4),
              //           blurRadius: 6,
              //           offset: const Offset(0, 3),
              //         ),
              //       ],
              //       border: Border.all(color: Colors.white, width: 1.5),
              //     ),
              //     child: Center(
              //       child: Text(
              //         '#${index + 1}',
              //         style: const TextStyle(
              //           color: Colors.white,
              //           fontSize: 12,
              //           fontWeight: FontWeight.bold,
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
              // Trending Hot Badge
              if (isTrending)
                Positioned(
                  top: AppConstants.spaceM,
                  right: AppConstants.spaceM,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          color: Colors.white,
                          size: 10,
                        ),
                        SizedBox(width: 2),
                        Text(
                          'HOT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                // Simple Rating Badge
                Positioned(
                  top: AppConstants.spaceM,
                  right: AppConstants.spaceM,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusCircular,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: Color(0xFFFBBC04),
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          dest.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Bottom Details
              Positioned(
                bottom: AppConstants.spaceM,
                left: AppConstants.spaceM,
                right: AppConstants.spaceM,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dest.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppTheme.secondaryGreen,
                          size: 11,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            dest.district,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if ((dest.popularityScore * 100).round() > 0) ...[
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.white30,
                                  width: 0.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.trending_up_rounded,
                                    color: Colors.white,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 3),
                                  Flexible(
                                    child: Text(
                                      '${(dest.popularityScore * 100).toStringAsFixed(0)} pts',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        // Mini fee badge
                        Flexible(
                          child: Text(
                            dest.entranceFee.toLowerCase().contains('free')
                                ? 'Free Entry'
                                : dest.entranceFee,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.secondaryGreen,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildShimmerCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 220,
      margin: const EdgeInsets.only(right: AppConstants.spaceM),
      decoration: BoxDecoration(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(
              AppTheme.primaryBlue.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDistrictBentoGrid(BuildContext context, List<Destination> allDests) {
    final districts = [
      {
        'name': 'Davao City',
        'mood': 'Urban Culture & Heritage',
        'image': 'https://images.unsplash.com/photo-1542601906990-b4d3fb778b09?w=800&q=80',
      },
      {
        'name': 'Davao del Norte',
        'mood': 'Adventure Gateways',
        'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      },
      {
        'name': 'Davao Oriental',
        'mood': 'Coastal Escapes',
        'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
      },
      {
        'name': 'Davao del Sur',
        'mood': 'Mountain Retreats',
        'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
      },
      {
        'name': 'Davao de Oro',
        'mood': 'Wilderness & Rivers',
        'image': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800&q=80',
      },
      {
        'name': 'Davao Occidental',
        'mood': 'Hidden Coastal Gems',
        'image': 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
      },
    ];

    return Column(
      children: [
        _buildBentoCard(context, districts[0], allDests, isHero: true),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildBentoCard(context, districts[1], allDests)),
            const SizedBox(width: 12),
            Expanded(child: _buildBentoCard(context, districts[2], allDests)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildBentoCard(context, districts[3], allDests)),
            const SizedBox(width: 12),
            Expanded(child: _buildBentoCard(context, districts[4], allDests)),
          ],
        ),
        const SizedBox(height: 12),
        _buildBentoCard(context, districts[5], allDests, isFullWidth: true),
      ],
    );
  }

  Widget _buildBentoCard(
    BuildContext context, 
    Map<String, dynamic> district, 
    List<Destination> allDests, 
    {bool isHero = false, bool isFullWidth = false}
  ) {
    final name = district['name'] as String;
    final mood = district['mood'] as String;
    final image = district['image'] as String;
    
    // Set heights: hero is 360.0, secondary cards are 140.0
    final height = isHero ? 360.0 : 140.0;
    final int count = allDests.where((d) => d.district == name).length;

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.destinationList,
          arguments: name,
        );
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: Destination.loadImage(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stackTrace) {
                    return Container(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                      child: const Icon(Icons.image_not_supported_rounded, color: AppTheme.primaryBlue),
                    );
                  },
                ),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: isHero 
                        ? [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.2),
                            Colors.black.withValues(alpha: 0.5),
                            Colors.black.withValues(alpha: 0.85),
                          ]
                        : [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.75),
                          ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: isHero ? 24 : 12,
                left: isHero ? 24 : 12,
                right: isHero ? 24 : 12,
                child: isHero
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    height: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  '$name · Urban & Culture',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white.withValues(alpha: 0.8),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.white24),
                                  ),
                                  child: Text(
                                    '$count ${count == 1 ? "destination" : "destinations"}',
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryGreen,
                              borderRadius: BorderRadius.circular(99),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.secondaryGreen.withValues(alpha: 0.3),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Explore',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  mood,
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$count ${count == 1 ? "dest" : "dests"}',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
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

  void _showFilterBottomSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget buildChoiceChip(
              String text,
              bool isSelected,
              VoidCallback onTap,
            ) {
              return GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: AppConstants.animDurationFast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : (isDark ? Colors.white10 : Colors.white),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : (isDark ? Colors.white12 : Colors.black12),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              minChildSize: 0.5,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppConstants.spaceL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white24 : Colors.black12,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Filters & Sort',
                            style: GoogleFonts.outfit(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                _selectedDistrict = 'All';
                                _sortBy = 'Popularity';
                                _selectedCategory = 'All';
                              });
                              setState(() {});
                            },
                            child: const Text(
                              'Reset All',
                              style: TextStyle(
                                color: AppTheme.secondaryGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      const SizedBox(height: 12),

                      // Sort Order
                      Text(
                        'Sort By',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              'Popularity',
                              'Rating',
                              'Cost: Low to High',
                              'Cost: High to Low',
                            ].map((sort) {
                              return buildChoiceChip(sort, _sortBy == sort, () {
                                setModalState(() => _sortBy = sort);
                                setState(() {});
                              });
                            }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // District / Province
                      Text(
                        'District / Province',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              'All',
                              'Davao City',
                              'Davao del Norte',
                              'Davao del Sur',
                              'Davao Oriental',
                              'Davao de Oro',
                              'Davao Occidental',
                            ].map((dist) {
                              return buildChoiceChip(
                                dist,
                                _selectedDistrict == dist,
                                () {
                                  setModalState(() => _selectedDistrict = dist);
                                  setState(() {});
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Theme Type
                      Text(
                        'Theme Type',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? AppTheme.textPrimaryDark
                              : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children:
                            [
                              'All',
                              'Nature',
                              'Beach',
                              'Mountain',
                              'Urban',
                              'Culture',
                              'Wildlife',
                              'Food',
                              'Adventure',
                              'Relaxation',
                            ].map((theme) {
                              return buildChoiceChip(
                                theme,
                                _selectedCategory == theme,
                                () {
                                  setModalState(
                                    () => _selectedCategory = theme,
                                  );
                                  setState(() {});
                                },
                              );
                            }).toList(),
                      ),
                      const SizedBox(height: 24),

                      // Apply button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusL,
                              ),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  void _showOverlay() {
    if (_suggestionsOverlayEntry != null) {
      _suggestionsOverlayEntry!.remove();
      _suggestionsOverlayEntry = null;
    }
    _suggestionsOverlayEntry = _createSuggestionsOverlay();
    Overlay.of(context).insert(_suggestionsOverlayEntry!);
  }

  void _hideOverlay() {
    if (_suggestionsOverlayEntry != null) {
      try {
        _suggestionsOverlayEntry!.remove();
      } catch (_) {}
      _suggestionsOverlayEntry = null;
    }
  }

  OverlayEntry _createSuggestionsOverlay() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return OverlayEntry(
      builder: (context) {
        final allDests = context.read<TripProvider>().destinations.isNotEmpty
            ? context.read<TripProvider>().destinations
            : Destination.davaoDestinations;
        final list = _getSuggestions(allDests);
        if (list.isEmpty) return const SizedBox.shrink();

        return CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width:
                  MediaQuery.of(context).size.width - (AppConstants.spaceL * 2),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(maxHeight: 250),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: list.length,
                      itemBuilder: (context, index) {
                        final item = list[index];
                        final isDistrict = item['type'] == 'district';
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isDistrict
                                ? AppTheme.primaryBlue.withValues(alpha: 0.08)
                                : AppTheme.secondaryGreen.withValues(alpha: 0.08),
                            child: Icon(
                              isDistrict
                                  ? Icons.location_on_rounded
                                  : Icons.place_rounded,
                              color: isDistrict
                                  ? AppTheme.primaryBlue
                                  : AppTheme.secondaryGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item['name']!,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark
                                  ? AppTheme.textPrimaryDark
                                  : AppTheme.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            isDistrict
                                ? 'District / Province'
                                : item['subtitle']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark
                                  ? AppTheme.textSecondaryDark
                                  : AppTheme.textSecondaryLight,
                            ),
                          ),
                          onTap: () {
                            if (isDistrict) {
                              setState(() {
                                _selectedDistrict = item['name']!;
                                _searchCtrl.clear();
                                _searchQuery = '';
                                _searchFocusNode.unfocus();
                              });
                            } else {
                              final dest = Destination.davaoDestinations
                                  .firstWhere((d) => d.name == item['name']);
                              setState(() {
                                _searchFocusNode.unfocus();
                              });
                              Navigator.pushNamed(
                                context,
                                AppRoutes.destinationDetail,
                                arguments: dest,
                              );
                            }
                            _hideOverlay();
                          },
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContinuePlanningSliver(
    BuildContext context,
    PlannerDraft draft,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.spaceM,
          AppConstants.spaceL,
          AppConstants.spaceM,
          0,
        ),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spaceM),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.secondaryGreen.withValues(alpha: 0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Destination Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: Destination.loadImage(
                    draft.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      child: const Icon(
                        Icons.place_rounded,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              // Card Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue Planning: ${draft.destinationName} ✈️',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      draft.progressText,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              // "Continue" Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.secondaryGreen,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                ),
                onPressed: () {
                  context.read<NavProvider>().setIndex(
                    1,
                  ); // Navigates to Planner tab
                },
                child: Text(
                  'Resume',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMoodTile(
    BuildContext context,
    String label,
    String emoji,
    String prompt,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        context.read<TripProvider>().setActivePlanningMoodPrompt(prompt);
        context.read<NavProvider>().setIndex(1);
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : AppTheme.primaryBlue.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white10
                : AppTheme.primaryBlue.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppTheme.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

