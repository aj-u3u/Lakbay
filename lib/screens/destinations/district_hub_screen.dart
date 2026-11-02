import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/destination.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/cards/destination_card.dart';

class DistrictHubScreen extends StatefulWidget {
  final String districtName;
  final String heroImageUrl;
  final Color accentColor;

  const DistrictHubScreen({
    super.key,
    required this.districtName,
    required this.heroImageUrl,
    required this.accentColor,
  });

  @override
  State<DistrictHubScreen> createState() => _DistrictHubScreenState();
}

class _DistrictHubScreenState extends State<DistrictHubScreen> {
  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Nature',
    'Beach',
    'Mountain',
    'Urban',
    'Culture',
    'Wildlife',
    'Adventure',
  ];

  List<Destination> _getFiltered(List<Destination> all) {
    final districtDests = all
        .where((d) => d.district == widget.districtName)
        .toList();
    if (_selectedCategory == 'All') return districtDests;
    return districtDests
        .where(
          (d) => d.category.toLowerCase().contains(
            _selectedCategory.toLowerCase(),
          ),
        )
        .toList();
  }

  List<Destination> _getTopRated(List<Destination> all) {
    final districtDests = all
        .where((d) => d.district == widget.districtName)
        .toList();
    final sorted = List<Destination>.from(districtDests)
      ..sort((a, b) => b.rating.compareTo(a.rating));
    return sorted.take(6).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final allDests = provider.destinations;
    if (provider.catalogLoading && !provider.catalogLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (provider.catalogError != null) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.districtName)),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(provider.catalogError!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: context.read<TripProvider>().refreshDestinations,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _getFiltered(allDests);
    final topRated = _getTopRated(allDests);
    final totalCount = allDests
        .where((d) => d.district == widget.districtName)
        .length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // ── Hero Header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            stretch: true,
            backgroundColor: widget.accentColor,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: CircleAvatar(
                backgroundColor: Colors.black26,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              stretchModes: const [
                StretchMode.zoomBackground,
                StretchMode.blurBackground,
              ],
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Hero image
                  Image.network(
                    widget.heroImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        Container(color: widget.accentColor),
                  ),
                  // Gradient overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.72),
                        ],
                        stops: const [0.0, 0.50, 1.0],
                      ),
                    ),
                  ),
                  // Bottom text info
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Province badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Davao Region',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        // District name
                        Text(
                          widget.districtName,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        // Stats row
                        Row(
                          children: [
                            const Icon(
                              Icons.place_rounded,
                              color: Colors.white70,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$totalCount destinations to explore',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
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

          // ── Category Filter Row ───────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _CategoryFilterDelegate(
              child: Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM,
                  ),
                  itemCount: _categories.length,
                  itemBuilder: (_, i) {
                    final cat = _categories[i];
                    final isSelected = cat == _selectedCategory;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat),
                      child: AnimatedContainer(
                        duration: AppConstants.animDurationFast,
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? widget.accentColor
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? widget.accentColor
                                : (isDark ? Colors.white24 : Colors.black12),
                          ),
                        ),
                        child: Text(
                          cat,
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
                  },
                ),
              ),
            ),
          ),

          // ── Top Things To Do Section ──────────────────────────────────────
          if (_selectedCategory == 'All' && topRated.isNotEmpty)
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppConstants.spaceL),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceM,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Top Things To Do',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: widget.accentColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '⭐ Best Rated',
                            style: TextStyle(
                              fontSize: 11,
                              color: widget.accentColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  SizedBox(
                    height: 240,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceM,
                      ),
                      itemCount: topRated.length,
                      itemBuilder: (context, i) {
                        final dest = topRated[i];
                        return Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: DestinationCard(
                            destination: dest,
                            width: 170,
                            height: 240,
                            onTap: () => Navigator.pushNamed(
                              context,
                              AppRoutes.destinationDetail,
                              arguments: dest,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppConstants.spaceM,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 20,
                          decoration: BoxDecoration(
                            color: widget.accentColor,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'All Attractions',
                          style: GoogleFonts.outfit(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceS),
                ],
              ),
            ),

          // ── Section header when category filter is active ─────────────────
          if (_selectedCategory != 'All')
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppConstants.spaceM,
                  AppConstants.spaceL,
                  AppConstants.spaceM,
                  AppConstants.spaceS,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: widget.accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$_selectedCategory in ${widget.districtName}',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Destination Grid ──────────────────────────────────────────────
          filtered.isEmpty
              ? SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          size: 56,
                          color: widget.accentColor.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No $_selectedCategory spots found',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Try a different category',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppConstants.spaceM,
                    0,
                    AppConstants.spaceM,
                    AppConstants.spaceM,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.72,
                          crossAxisSpacing: AppConstants.spaceM,
                          mainAxisSpacing: AppConstants.spaceM,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => DestinationCard(
                        destination: filtered[i],
                        width: double.infinity,
                        height: double.infinity,
                        onTap: () => Navigator.pushNamed(
                          context,
                          AppRoutes.destinationDetail,
                          arguments: filtered[i],
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),

          const SliverToBoxAdapter(
            child: SizedBox(height: AppConstants.spaceXL),
          ),
        ],
      ),
    );
  }
}

// ── Sliver delegate for sticky category filter ────────────────────────────────
class _CategoryFilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _CategoryFilterDelegate({required this.child});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate old) => true;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
}
