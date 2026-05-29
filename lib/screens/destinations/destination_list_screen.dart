import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/destination.dart';
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
  final _filters = ['All', 'Nature', 'Beach', 'Mountain', 'Urban', 'Culture', 'Wildlife', 'Adventure'];

  @override
  void initState() {
    super.initState();
    // Use initialFilter if provided, else default to 'All'
    _selectedFilter = widget.initialFilter ?? 'All';
  }

  List<Destination> _getFiltered(List<Destination> all) {
    if (_selectedFilter == 'All') return all;
    // Check if the filter matches a district name
    final isDistrict = all.any((d) => d.district.toLowerCase() == _selectedFilter.toLowerCase());
    if (isDistrict) {
      return all.where((d) => d.district.toLowerCase() == _selectedFilter.toLowerCase()).toList();
    }
    return all.where((d) =>
      d.category.toLowerCase().contains(_selectedFilter.toLowerCase())).toList();
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
    final allDestinations = provider.destinations.isNotEmpty
        ? provider.destinations
        : Destination.davaoDestinations; // fallback to local mocks
    final filtered = _getFiltered(allDestinations);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 160,
            backgroundColor: AppTheme.primaryBlue,
            title: Text('Discover Davao', style: GoogleFonts.outfit(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
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
                    padding: const EdgeInsets.fromLTRB(AppConstants.spaceL, 56, AppConstants.spaceL, 0),
                    child: Text('${allDestinations.length} destinations across 5 provinces',
                      style: GoogleFonts.outfit(color: Colors.white60, fontSize: 13)),
                  ),
                ),
              ),
            ),
          ),

          // Filter chips
          SliverPersistentHeader(
            pinned: true,
            delegate: _FilterDelegate(
              child: Container(
                color: Theme.of(context).colorScheme.surface,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM, vertical: AppConstants.spaceS),
                  itemCount: _displayFilters.length,
                  itemBuilder: (_, i) {
                    final f = _displayFilters[i];
                    final isSelected = f == _selectedFilter;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedFilter = f),
                      child: AnimatedContainer(
                        duration: AppConstants.animDurationFast,
                        margin: const EdgeInsets.only(right: AppConstants.spaceS),
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                          borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.textSecondaryLight.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(f, style: TextStyle(
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

          // Loading state
          if (provider.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
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

          const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spaceXL)),
        ],
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
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) => true;
  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) => child;
}
