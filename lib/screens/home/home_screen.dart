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
      'Davao Occidental'
    ];
    for (final dist in districts) {
      if (dist.toLowerCase().contains(query)) {
        matches.add({
          'name': dist,
          'type': 'district',
        });
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

  final List<String> _categories = [
    'All',
    'Nature',
    'Beach',
    'Mountain',
    'Urban',
    'Culture',
    'Wildlife',
    'Food',
    'Adventure',
    'Relaxation'
  ];

  final List<Map<String, dynamic>> _promoSlides = [
    {
      'id': 8,
      'title': 'Pearl Farm\nBeach Resort',
      'subtitle': 'Samal Island, Davao del Norte',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
    },
    {
      'id': 15,
      'title': 'Dahican Beach\nSurf Paradise',
      'subtitle': 'Mati City, Davao Oriental',
      'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=900&q=80',
    },
    {
      'id': 12,
      'title': 'Mount Apo\nNational Park',
      'subtitle': 'Digos City, Davao del Sur',
      'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=900&q=80',
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
      final recommended = await ApiService().fetchRecommendedDestinations(limit: 6);
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
      list = list.where((d) => d.category.toLowerCase().contains(_selectedCategory.toLowerCase())).toList();
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
    final provider = context.watch<TripProvider>();
    final allDests = provider.destinations.isNotEmpty ? provider.destinations : Destination.davaoDestinations;
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
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
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
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(6),
                              child: Image.asset(
                                'assets/images/lakbay_logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: AppConstants.spaceM),
                              Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Builder(builder: (context) {
                                  final firstName = context
                                      .watch<AuthProvider>()
                                      .userProfile
                                      ?.displayName
                                      .split(' ')
                                      .first ?? 'Traveler';
                                  return Text(
                                    'Good Morning, $firstName 👋',
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, color: Colors.white60));
                                }),
                                Text('Discover Davao', style: GoogleFonts.outfit(
                                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pushNamed(context, AppRoutes.notifications),
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
                              child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
                            ),
                            if (provider.unreadNotificationCount > 0)
                              Positioned(
                                right: -4,
                                top: -4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
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
                                          : provider.unreadNotificationCount.toString(),
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
                        borderRadius: BorderRadius.circular(AppConstants.radiusL),
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
                          hintStyle: TextStyle(color: AppTheme.textSecondaryLight.withValues(alpha: 0.6), fontSize: 14),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue),
                          suffixIcon: GestureDetector(
                            onTap: _showFilterBottomSheet,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryGreen,
                                borderRadius: BorderRadius.circular(AppConstants.radiusM),
                              ),
                              child: const Icon(Icons.tune_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 14),
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

          // Categories
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: AppConstants.spaceL),
              child: SizedBox(
                height: 40,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() {
                        _selectedCategory = cat;
                        _searchCtrl.clear();
                        _searchQuery = '';
                      }),
                      child: AnimatedContainer(
                        duration: AppConstants.animDurationFast,
                        margin: const EdgeInsets.only(right: AppConstants.spaceS),
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: AppConstants.spaceS),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondaryLight.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(cat, style: TextStyle(
                          color: isSelected ? Colors.white : AppTheme.textSecondaryLight,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 13,
                        )),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Featured promo carousel
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppConstants.spaceL),
                SectionHeader(
                  title: 'Featured',
                  onActionPressed: () => Navigator.pushNamed(context, AppRoutes.destinationList),
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
                        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Dual-Engine Recommendations and Global Popular Leaderboard or Search Results
          SliverToBoxAdapter(
            child: _searchQuery.isEmpty && _selectedCategory == 'All' && _selectedDistrict == 'All'
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
                        onActionPressed: () => Navigator.pushNamed(context, AppRoutes.destinationList),
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
                                        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.search_off_rounded, size: 40, color: AppTheme.primaryBlue),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'No destinations found',
                                      style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Try adjusting your search or filters',
                                      style: TextStyle(color: AppTheme.textSecondaryLight, fontSize: 12),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
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

          // District Bento Explorer
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppConstants.spaceXL),
                  SectionHeader(
                    title: 'Explore Districts',
                    onActionPressed: () => Navigator.pushNamed(context, AppRoutes.destinationList),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                  Padding(
                    padding: const EdgeInsets.only(left: 4.0),
                    child: Text(
                      'Encourage exploration of all 6 districts within the Davao Region',
                      style: GoogleFonts.outfit(
                        color: AppTheme.textSecondaryLight.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  _buildDistrictBentoGrid(context, allDests),
                ],
              ),
            ),
          ),

          // AI Mood Suggestions
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppConstants.spaceXL),
                SectionHeader(
                  title: 'AI Mood Suggestions 🤖',
                  onActionPressed: () {
                    context.read<NavProvider>().setIndex(1);
                  },
                ),
                const SizedBox(height: AppConstants.spaceS),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                  child: Text(
                    'Select a mood to start planning your perfect Davao adventure instantly',
                    style: GoogleFonts.outfit(
                      color: AppTheme.textSecondaryLight.withValues(alpha: 0.8),
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                    children: [
                      _buildMoodTile(context, '🏔️ Adventure', const Color(0xFFE8F5E9), const Color(0xFF2E7D32)),
                      _buildMoodTile(context, '🌿 Relaxation', const Color(0xFFE0F2F1), const Color(0xFF00796B)),
                      _buildMoodTile(context, '👨‍👩‍👧 Family', const Color(0xFFF3E5F5), const Color(0xFF6A1B9A)),
                      _buildMoodTile(context, '🌊 Beach', const Color(0xFFE1F5FE), const Color(0xFF0288D1)),
                      _buildMoodTile(context, '🌲 Nature', const Color(0xFFF1F8E9), const Color(0xFF558B2F)),
                      _buildMoodTile(context, '🏙️ Culture', const Color(0xFFFFF3E0), const Color(0xFFE65100)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spaceXL)),
        ],
      ),
    );
  }

  Widget _buildMoodTile(BuildContext context, String mood, Color bgColor, Color textColor) {
    return GestureDetector(
      onTap: () {
        final pureMood = mood.substring(3).trim(); // Remove emoji
        final tripProv = context.read<TripProvider>();
        final navProv = context.read<NavProvider>();
        
        tripProv.setActivePlanningMoodPrompt("Suggest a $pureMood trip in Davao Region.");
        navProv.setIndex(1); // Navigate to Planner Page (Index 1)
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: textColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: textColor.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Center(
          child: Text(
            mood,
            style: GoogleFonts.outfit(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecommendedSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loadingRecommended) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spaceL),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
            child: SectionHeader(title: 'Recommended For You ✨', onActionPressed: () {}),
          ),
          const SizedBox(height: AppConstants.spaceS),
          SizedBox(
            height: 290,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              itemCount: 3,
              itemBuilder: (_, _) => _buildShimmerCard(context),
            ),
          ),
        ],
      );
    }

    if (_recommendedDestinations.isEmpty) {
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
                    'Recommended For You ✨',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'AI-curated travel experiences tailored for you',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.destinationList),
                child: const Text('View All', style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceS),
        SizedBox(
          height: 310,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
            itemCount: _recommendedDestinations.length,
            itemBuilder: (context, index) {
              final dest = _recommendedDestinations[index];
              return _buildRecommendedCard(context, dest);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedCard(BuildContext context, Destination dest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Extract a nice personalized tag from matchReasons
    String matchTag = "AI Pick";
    if (dest.matchReasons.isNotEmpty) {
      matchTag = dest.matchReasons.values.first;
    } else {
      matchTag = "Matches Profile";
    }

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.destinationDetail,
          arguments: dest,
        );
      },
      child: Container(
        width: 230,
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
                child: Image.network(
                  dest.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.primaryBlue.withOpacity(0.15),
                    child: const Icon(Icons.landscape, size: 60, color: AppTheme.primaryBlue),
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
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.85),
                      ],
                      stops: const [0.2, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
              // For You Badge
              if (matchTag != "Matches Profile")
                Positioned(
                  top: AppConstants.spaceM,
                  left: AppConstants.spaceM,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.secondaryGreen, AppTheme.accentTeal],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.secondaryGreen.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, color: Colors.white, size: 10),
                        const SizedBox(width: 4),
                        Text(
                          matchTag,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Rating Badge
              Positioned(
                top: AppConstants.spaceM,
                right: AppConstants.spaceM,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFFFBBC04), size: 12),
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
              // Content details
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(color: Colors.black45, blurRadius: 4),
                        ],
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, color: AppTheme.secondaryGreen, size: 12),
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryGreen.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'From ${dest.entranceFee}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        // Micro tag for matching category
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: Colors.white24, width: 0.5),
                          ),
                          child: Text(
                            dest.category,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 8,
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

  Widget _buildPopularLeaderboardSection(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_loadingPopular) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spaceL),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
            child: SectionHeader(title: 'Popular Destinations 🔥', onActionPressed: () {}),
          ),
          const SizedBox(height: AppConstants.spaceS),
          SizedBox(
            height: 290,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
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
                    'Popular Destinations 🔥',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  Text(
                    'Davao Region\'s highest rated and trending places',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.destinationList),
                child: const Text('View All', style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppConstants.spaceS),
        SizedBox(
          height: 300,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
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

  Widget _buildPopularLeaderboardCard(BuildContext context, Destination dest, int index) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Choose rank background gradient and border color
    List<Color> rankColors = [AppTheme.primaryBlue, AppTheme.accentTeal];
    if (index == 0) {
      rankColors = [const Color(0xFFFFD700), const Color(0xFFFFA500)]; // Gold
    } else if (index == 1) {
      rankColors = [const Color(0xFFC0C0C0), const Color(0xFF808080)]; // Silver
    } else if (index == 2) {
      rankColors = [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
    }

    final isTrending = dest.trendingStatus == 'high' || dest.trendingStatus == 'rising';

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
                child: Image.network(
                  dest.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.primaryBlue.withOpacity(0.15),
                    child: const Icon(Icons.landscape, size: 60, color: AppTheme.primaryBlue),
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
                        Colors.black.withOpacity(0.1),
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.85),
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
              //           color: rankColors.first.withOpacity(0.4),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 10),
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
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: Color(0xFFFBBC04), size: 12),
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
                        const Icon(Icons.location_on_rounded, color: AppTheme.secondaryGreen, size: 11),
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
                        if ((dest.popularityScore * 100).round() > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withOpacity(0.85),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white30, width: 0.5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.trending_up_rounded, color: Colors.white, size: 10),
                                const SizedBox(width: 3),
                                Text(
                                  '${(dest.popularityScore * 100).toStringAsFixed(0)} pts',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        // Mini fee badge
                        Text(
                          dest.entranceFee.toLowerCase().contains('free') ? 'Free Entry' : dest.entranceFee.split(' ').first,
                          style: const TextStyle(
                            color: AppTheme.secondaryGreen,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
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
        color: isDark ? Colors.white10 : Colors.black.withOpacity(0.04),
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
      ),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue.withOpacity(0.4)),
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
        'height': 160.0,
      },
      {
        'name': 'Davao del Norte',
        'mood': 'Adventure Gateways',
        'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
        'height': 140.0,
      },
      {
        'name': 'Davao Oriental',
        'mood': 'Coastal Escapes',
        'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
        'height': 140.0,
      },
      {
        'name': 'Davao del Sur',
        'mood': 'Mountain Retreats',
        'image': 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?w=800&q=80',
        'height': 140.0,
      },
      {
        'name': 'Davao de Oro',
        'mood': 'Wilderness & Rivers',
        'image': 'https://images.unsplash.com/photo-1540555700478-4be289fbecef?w=800&q=80',
        'height': 140.0,
      },
      {
        'name': 'Davao Occidental',
        'mood': 'Hidden Coastal Gems',
        'image': 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
        'height': 120.0,
      },
    ];

    return Column(
      children: [
        _buildBentoCard(context, districts[0], allDests),
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
        _buildBentoCard(context, districts[5], allDests),
      ],
    );
  }

  Widget _buildBentoCard(BuildContext context, Map<String, dynamic> district, List<Destination> allDests) {
    final name = district['name'] as String;
    final mood = district['mood'] as String;
    final image = district['image'] as String;
    final height = district['height'] as double;

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
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.network(
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
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.35),
                        Colors.black.withValues(alpha: 0.75),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 14,
                right: 14,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      mood,
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withValues(alpha: 0.95),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$count ${count == 1 ? "destination" : "destinations"}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
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
            Widget buildChoiceChip(String text, bool isSelected, VoidCallback onTap) {
              return GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: AppConstants.animDurationFast,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? AppTheme.primaryBlue 
                        : (isDark ? Colors.white10 : Colors.white),
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryBlue : (isDark ? Colors.white12 : Colors.black12),
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  child: Text(
                    text,
                    style: TextStyle(
                      color: isSelected 
                          ? Colors.white 
                          : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
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
                              style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold),
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
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
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
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          'All',
                          'Davao City',
                          'Davao del Norte',
                          'Davao del Sur',
                          'Davao Oriental',
                          'Davao de Oro',
                          'Davao Occidental',
                        ].map((dist) {
                          return buildChoiceChip(dist, _selectedDistrict == dist, () {
                            setModalState(() => _selectedDistrict = dist);
                            setState(() {});
                          });
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Theme Type
                      Text(
                        'Theme Type',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
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
                          return buildChoiceChip(theme, _selectedCategory == theme, () {
                            setModalState(() => _selectedCategory = theme);
                            setState(() {});
                          });
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
                              borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            ),
                          ),
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Apply Filters',
                            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
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
              width: MediaQuery.of(context).size.width - (AppConstants.spaceL * 2),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                color: Theme.of(context).colorScheme.surface,
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
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
                                ? AppTheme.primaryBlue.withOpacity(0.08)
                                : AppTheme.secondaryGreen.withOpacity(0.08),
                            child: Icon(
                              isDistrict ? Icons.location_on_rounded : Icons.place_rounded,
                              color: isDistrict ? AppTheme.primaryBlue : AppTheme.secondaryGreen,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            item['name']!,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            isDistrict ? 'District / Province' : item['subtitle']!,
                            style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
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
                              final dest = Destination.davaoDestinations.firstWhere(
                                (d) => d.name == item['name'],
                              );
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

  Widget _buildContinuePlanningSliver(BuildContext context, PlannerDraft draft) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppConstants.spaceM, AppConstants.spaceL, AppConstants.spaceM, 0),
        child: Container(
          padding: const EdgeInsets.all(AppConstants.spaceM),
          decoration: BoxDecoration(
            color: isDark ? Theme.of(context).cardColor : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppTheme.secondaryGreen.withOpacity(0.15),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                  child: Image.network(
                    draft.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.primaryBlue.withOpacity(0.1),
                      child: const Icon(Icons.place_rounded, color: AppTheme.primaryBlue),
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
                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                onPressed: () {
                  context.read<NavProvider>().setIndex(1); // Navigates to Planner tab
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
}
