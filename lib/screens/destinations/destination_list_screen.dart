import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/destination.dart';
import '../../models/grouped_destinations.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/cards/destination_card.dart';

class DestinationListScreen extends StatefulWidget {
  /// Optional pre-selected filter category (e.g. 'Beach', 'Nature').
  /// When provided the list opens already filtered to that category.
  final String? initialFilter;

  const DestinationListScreen({super.key, this.initialFilter});

  @override
  State<DestinationListScreen> createState() => _DestinationListScreenState();
}

class _DestinationListScreenState extends State<DestinationListScreen> {
  late String _selectedFilter;
  final _filters = [
    'All',
    'Nature',
    'Beach',
    'Mountain',
    'Urban',
    'Culture',
    'Wildlife',
    'Adventure',
  ];
  bool _isGroupedByRegion = false;

  @override
  void initState() {
    super.initState();
    // Use initialFilter if provided, else default to 'All'
    _selectedFilter = widget.initialFilter ?? 'All';
  }

  List<Destination> _getFiltered(List<Destination> all) {
    if (_selectedFilter == 'All') return all;
    // Check if the filter matches a district name
    final isDistrict = all.any(
      (d) => d.district.toLowerCase() == _selectedFilter.toLowerCase(),
    );
    if (isDistrict) {
      return all
          .where(
            (d) => d.district.toLowerCase() == _selectedFilter.toLowerCase(),
          )
          .toList();
    }
    return all
        .where(
          (d) =>
              d.category.toLowerCase().contains(_selectedFilter.toLowerCase()),
        )
        .toList();
  }

  List<String> get _displayFilters {
    final list = List<String>.from(_filters);
    if (_selectedFilter != 'All' && !_filters.contains(_selectedFilter)) {
      list.insert(1, _selectedFilter);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();
    final allDestinations = provider.destinations;
    final filtered = _getFiltered(allDestinations);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: context.read<TripProvider>().refreshDestinations,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 160,
              backgroundColor: AppTheme.primaryBlue,
              title: Text(
                'Discover Davao',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  tooltip: 'Refresh destinations',
                  onPressed: provider.catalogLoading
                      ? null
                      : context.read<TripProvider>().refreshDestinations,
                ),
                IconButton(
                  icon: Icon(
                    _isGroupedByRegion
                        ? Icons.grid_view_rounded
                        : Icons.map_outlined,
                    color: Colors.white,
                  ),
                  tooltip: _isGroupedByRegion
                      ? 'Switch to Grid View'
                      : 'Group by Province',
                  onPressed: () {
                    setState(() {
                      _isGroupedByRegion = !_isGroupedByRegion;
                    });
                  },
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppConstants.spaceL,
                        56,
                        AppConstants.spaceL,
                        0,
                      ),
                      child: Text(
                        '${allDestinations.length} destinations',
                        style: GoogleFonts.outfit(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Filter chips
            if (!_isGroupedByRegion)
              SliverPersistentHeader(
                pinned: true,
                delegate: _FilterDelegate(
                  child: Container(
                    color: Theme.of(context).colorScheme.surface,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.spaceM,
                        vertical: AppConstants.spaceS,
                      ),
                      itemCount: _displayFilters.length,
                      itemBuilder: (_, i) {
                        final f = _displayFilters[i];
                        final isSelected = f == _selectedFilter;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedFilter = f),
                          child: AnimatedContainer(
                            duration: AppConstants.animDurationFast,
                            margin: const EdgeInsets.only(
                              right: AppConstants.spaceS,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppConstants.spaceM,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primaryBlue
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusCircular,
                              ),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryBlue
                                    : AppTheme.textSecondaryLight.withValues(
                                        alpha: 0.3,
                                      ),
                              ),
                            ),
                            child: Text(
                              f,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.white
                                    : AppTheme.textSecondaryLight,
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

            // Loading state
            if (provider.catalogLoading && !provider.catalogLoaded)
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.catalogError != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppConstants.spaceXL),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          provider.catalogOffline
                              ? Icons.wifi_off_rounded
                              : Icons.error_outline_rounded,
                          size: 42,
                        ),
                        const SizedBox(height: AppConstants.spaceM),
                        Text(
                          provider.catalogOffline
                              ? 'You are offline'
                              : 'Destinations could not be loaded',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: AppConstants.spaceS),
                        Text(
                          provider.catalogError!,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppConstants.spaceM),
                        FilledButton.icon(
                          onPressed: context
                              .read<TripProvider>()
                              .refreshDestinations,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else if (allDestinations.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text('No destinations are available yet.'),
                ),
              )
            // Grouped by Province/District
            else if (_isGroupedByRegion)
              SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final List<GroupedDestinations> groupedList =
                      provider.groupedDestinations;
                  if (groupedList.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(AppConstants.spaceXL),
                      child: Center(
                        child: Text('No grouped destinations available.'),
                      ),
                    );
                  }
                  final groupedItem = groupedList[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppConstants.spaceM,
                          AppConstants.spaceL,
                          AppConstants.spaceM,
                          AppConstants.spaceS,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  groupedItem.district,
                                  style: GoogleFonts.outfit(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${groupedItem.count} spots',
                                    style: GoogleFonts.outfit(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Avg Listed Cost: ${groupedItem.averageCost == null ? 'Not listed' : '₱${groupedItem.averageCost!.toStringAsFixed(0)}'} • Rating: ⭐ ${groupedItem.averageRating.toStringAsFixed(1)}',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                color:
                                    Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: 240,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppConstants.spaceM,
                          ),
                          itemCount: groupedItem.destinations.length,
                          itemBuilder: (context, cardIndex) {
                            final dest = groupedItem.destinations[cardIndex];
                            return Padding(
                              padding: const EdgeInsets.only(
                                right: AppConstants.spaceM,
                              ),
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
                    ],
                  );
                }, childCount: provider.groupedDestinations.length),
              )
            // Destination grid
            else
              SliverPadding(
                padding: const EdgeInsets.all(AppConstants.spaceM),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
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
      ),
    );
  }
}

class _FilterDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  _FilterDelegate({required this.child});

  @override
  double get minExtent => 52;
  @override
  double get maxExtent => 52;
  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => child;
}
