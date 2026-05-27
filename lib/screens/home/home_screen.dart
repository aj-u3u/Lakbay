import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/destination.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/shared/section_header.dart';
import '../../widgets/cards/destination_card.dart';
import '../../widgets/cards/promo_card.dart';
import '../../widgets/inputs/custom_input_field.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

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
  bool _showSuggestions = false;
  OverlayEntry? _suggestionsOverlayEntry;
  final LayerLink _layerLink = LayerLink();

  List<Map<String, String>> get _suggestions {
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
    for (final dest in Destination.davaoDestinations) {
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

  final List<Map<String, String>> _promoSlides = [
    {
      'title': 'Pearl Farm\nBeach Resort',
      'subtitle': 'Samal Island, Davao del Norte',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=900&q=80',
    },
    {
      'title': 'Dahican Beach\nSurf Paradise',
      'subtitle': 'Mati City, Davao Oriental',
      'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=900&q=80',
    },
    {
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
    });
    _startPromoTimer();
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

  List<Destination> get _filteredDestinations {
    var list = Destination.davaoDestinations;

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
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
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
                                    color: Colors.black.withOpacity(0.08),
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
                                Text('Good Morning 👋', style: GoogleFonts.outfit(
                                  fontSize: 13, color: Colors.white60)),
                                Text('Discover Davao', style: GoogleFonts.outfit(
                                  fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _showNotificationsBottomSheet,
                        child: Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white24),
                          ),
                          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 22),
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
                          hintStyle: TextStyle(color: AppTheme.textSecondaryLight.withOpacity(0.6), fontSize: 14),
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
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondaryLight.withOpacity(0.3),
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
                SectionHeader(title: 'Featured', onActionPressed: () {}),
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
                        title: s['title']!,
                        subtitle: s['subtitle']!,
                        imageUrl: s['image']!,
                        onTap: () => Navigator.pushNamed(context, AppRoutes.destinationList),
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
                            : AppTheme.primaryBlue.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),

          // Popular destinations
          SliverToBoxAdapter(
            child: Column(
              children: [
                const SizedBox(height: AppConstants.spaceL),
                SectionHeader(
                  title: 'Popular Destinations',
                  onActionPressed: () => Navigator.pushNamed(context, AppRoutes.destinationList),
                ),
                const SizedBox(height: AppConstants.spaceS),
                 SizedBox(
                  height: 290,
                  child: _filteredDestinations.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withOpacity(0.05),
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
                          itemCount: _filteredDestinations.length,
                          itemBuilder: (_, i) => DestinationCard(
                            destination: _filteredDestinations[i],
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.destinationDetail,
                              arguments: _filteredDestinations[i],
                            ),
                          ),
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

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
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
                    color: isSelected ? AppTheme.primaryBlue : Colors.white,
                    borderRadius: BorderRadius.circular(99),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryBlue : Colors.black12,
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
                      color: isSelected ? Colors.white : AppTheme.textSecondaryLight,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }

            Widget buildFilterSwitch(String title, bool val, ValueChanged<bool> onChanged) {
              return SwitchListTile.adaptive(
                title: Text(
                  title,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: AppTheme.textPrimaryLight),
                ),
                value: val,
                activeColor: AppTheme.secondaryGreen,
                contentPadding: EdgeInsets.zero,
                onChanged: onChanged,
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
                            color: Colors.black12,
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
                          color: AppTheme.textPrimaryLight,
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
                          color: AppTheme.textPrimaryLight,
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
                          color: AppTheme.textPrimaryLight,
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

  void _showNotificationsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (context) {
        final List<Map<String, String>> notifications = [
          {
            'title': 'Gemini AI Planner Ready',
            'body': 'Draft itinerary for Samal Island is ready for review.',
            'time': '10 mins ago',
            'icon': '⚡',
            'isNew': 'true',
          },
          {
            'title': 'New Group Invitation',
            'body': 'Carlo invited you to join "Mount Apo Expedition ⛰️"',
            'time': '2 hours ago',
            'icon': '👥',
            'isNew': 'true',
          },
          {
            'title': 'Weather Alert',
            'body': 'Sunny conditions expected today in Pearl Farm Beach Resort.',
            'time': '5 hours ago',
            'icon': '☀️',
            'isNew': 'false',
          },
        ];

        return Container(
          padding: const EdgeInsets.all(AppConstants.spaceL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Notifications',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Notifications marked as read'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Text(
                      'Mark all as read',
                      style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final item = notifications[index];
                    final isNew = item['isNew'] == 'true';
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: isNew ? AppTheme.primaryBlue.withOpacity(0.04) : Colors.transparent,
                        borderRadius: BorderRadius.circular(AppConstants.radiusM),
                        border: Border.all(
                          color: isNew ? AppTheme.primaryBlue.withOpacity(0.12) : Colors.black12,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isNew ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.black.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                            child: Text(item['icon']!, style: const TextStyle(fontSize: 18)),
                          ),
                          const SizedBox(width: AppConstants.spaceM),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      item['title']!,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: AppTheme.textPrimaryLight,
                                      ),
                                    ),
                                    Text(
                                      item['time']!,
                                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['body']!,
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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
    return OverlayEntry(
      builder: (context) {
        final list = _suggestions;
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
                color: Colors.white,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(color: Colors.black12),
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
                              color: AppTheme.textPrimaryLight,
                            ),
                          ),
                          subtitle: Text(
                            isDistrict ? 'District / Province' : item['subtitle']!,
                            style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight),
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
}
