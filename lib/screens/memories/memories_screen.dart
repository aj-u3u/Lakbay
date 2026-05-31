import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import 'opened_album_screen.dart';

class MemoriesScreen extends StatelessWidget {
  const MemoriesScreen({super.key});

  // Canonical district list for grouping
  static const List<String> _canonicalDistricts = [
    'Samal Island',
    'Davao City',
    'Mount Apo',
    'Davao Oriental',
    'Davao del Sur',
    'Davao del Norte',
    'Davao de Oro',
  ];

  // Mock completed trips seeded for first-time impression
  // Only show mock data if userTrips has zero completed trips
  // TODO: Remove seed data once real completed trips flow from backend
  static final List<Trip> _fallbackMockCompletedTrips = [
    Trip(
      id: 'mock-comp-samal',
      title: 'Island Garden Escape',
      destinationName: 'Samal Island, Davao del Norte',
      dateRange: 'May 10 - May 12, 2026',
      budget: 18000.0,
      imageUrl: 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
      isGroup: true,
      numTravelers: 3,
      members: [
        {'name': 'You (Organizer)', 'role': 'Organizer', 'avatar': ''},
        {'name': 'Arjane', 'role': 'Member', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80'},
        {'name': 'Bea', 'role': 'Member', 'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&q=80'},
      ],
      memories: [
        {
          'id': 'mock-mem-s1',
          'user': 'You',
          'avatar': '',
          'time': 'May 10, 2026',
          'caption': 'Checking in! The overwater bungalows are gorgeous.',
          'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80',
          'location': 'Pearl Farm Resort',
        },
        {
          'id': 'mock-mem-s2',
          'user': 'Arjane',
          'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
          'time': 'May 11, 2026',
          'caption': 'Giant clam sanctuary snorkeling! So many colors 🐠',
          'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
          'location': 'Coral Garden Reef',
        },
        {
          'id': 'mock-mem-s3',
          'user': 'Bea',
          'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&q=80',
          'time': 'May 12, 2026',
          'caption': 'Chasing waterfalls at Hagimit! The water is freezing!',
          'image': 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80',
          'location': 'Hagimit Falls',
        },
      ],
      itinerary: {},
    ),
    Trip(
      id: 'mock-comp-davao',
      title: 'City Highlands & Night Market',
      destinationName: 'Davao City Proper',
      dateRange: 'April 15 - April 16, 2026',
      budget: 6500.0,
      imageUrl: 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
      isGroup: false,
      numTravelers: 1,
      members: [],
      memories: [
        {
          'id': 'mock-mem-d1',
          'user': 'You',
          'avatar': '',
          'time': 'April 15, 2026',
          'caption': 'Pine forest walks up in Toril. Smells amazing!',
          'image': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80',
          'location': 'Eden Nature Park',
        },
        {
          'id': 'mock-mem-d2',
          'user': 'You',
          'avatar': '',
          'time': 'April 16, 2026',
          'caption': 'Met the majestic national bird at the sanctuary!',
          'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=800&q=80',
          'location': 'Philippine Eagle Center',
        },
      ],
      itinerary: {},
    ),
    Trip(
      id: 'mock-comp-mati',
      title: 'Surfing Dahican Beach',
      destinationName: 'Mati, Davao Oriental',
      dateRange: 'March 18 - March 20, 2026',
      budget: 8000.0,
      imageUrl: 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
      isGroup: false,
      numTravelers: 1,
      members: [],
      memories: [
        {
          'id': 'mock-mem-m1',
          'user': 'You',
          'avatar': '',
          'time': 'March 18, 2026',
          'caption': 'First attempt at skimboarding! Caught a mini wave 🏄‍♂️',
          'image': 'https://images.unsplash.com/photo-1506929562872-bb421503ef21?w=800&q=80',
          'location': 'Dahican Beach',
        },
      ],
      itinerary: {},
    ),
  ];

  // Helper to extract the destination/district group name cleanly
  String _getDestinationGroup(String destName) {
    final lower = destName.toLowerCase();
    for (final district in _canonicalDistricts) {
      if (lower.contains(district.toLowerCase())) {
        return district;
      }
    }
    if (destName.contains(',')) {
      return destName.split(',')[0].trim();
    }
    return destName;
  }

  // Completion check replicating the logic in trips_screen.dart
  bool _isTripCompleted(Trip trip) {
    if (trip.dateRange.contains('Flexible') || trip.dateRange.contains('AI Generated')) {
      return false; // Drafts/flexible are upcoming
    }
    try {
      final parts = trip.dateRange.split(RegExp(r'\s*[-–]\s*'));
      final String endDateStr = parts.length > 1 ? parts[1].trim() : parts[0].trim();
      
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      
      final cleanStr = endDateStr.toLowerCase().replaceAll(',', '');
      final strParts = cleanStr.split(RegExp(r'\s+'));
      if (strParts.length >= 3) {
        final month = months[strParts[0].substring(0, 3)] ?? 1;
        final day = int.tryParse(strParts[1]) ?? 1;
        final year = int.tryParse(strParts[2]) ?? DateTime.now().year;
        final endDate = DateTime(year, month, day, 23, 59, 59);
        return endDate.isBefore(DateTime.now());
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Memories',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: AppTheme.primaryBlue,
          ),
        ),
      ),
      body: Consumer<TripProvider>(
        builder: (context, provider, child) {
          // Filter completed user trips
          final completedTrips = provider.userTrips.where((t) => _isTripCompleted(t)).toList();

          // Apply guard: Only show mock data if userTrips has zero completed trips
          // TODO: Remove seed data once real completed trips flow from backend
          final displayTrips = completedTrips.isEmpty ? _fallbackMockCompletedTrips : completedTrips;

          // Group display trips by destination district
          final groupedTrips = <String, List<Trip>>{};
          for (final trip in displayTrips) {
            final groupName = _getDestinationGroup(trip.destinationName);
            groupedTrips.putIfAbsent(groupName, () => []).add(trip);
          }

          // Calculate Dynamic Stats
          final totalMemories = displayTrips.fold<int>(0, (sum, t) => sum + t.memories.length);
          final totalTrips = displayTrips.length;
          final totalDistricts = groupedTrips.keys.length;

          return CustomScrollView(
            slivers: [
              // Stats banner card
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  child: Container(
                    padding: const EdgeInsets.all(AppConstants.spaceL),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
                      ),
                      borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                      boxShadow: AppConstants.premiumShadow,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _statItem('$totalMemories', 'Memories'),
                        Container(width: 1, height: 36, color: Colors.white24),
                        _statItem('$totalTrips', 'Trips'),
                        Container(width: 1, height: 36, color: Colors.white24),
                        _statItem('$totalDistricts', 'Districts'),
                      ],
                    ),
                  ),
                ),
              ),

              // Title Section Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppConstants.spaceM, AppConstants.spaceM, AppConstants.spaceM, 0),
                  child: Text(
                    'Travel Bookshelf',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ),

              // Bookshelf Lists
              if (groupedTrips.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Your travel album is empty.',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final districtName = groupedTrips.keys.elementAt(index);
                      final districtTrips = groupedTrips[districtName]!;
                      return _buildBookshelfRow(context, districtName, districtTrips);
                    },
                    childCount: groupedTrips.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppConstants.spaceXL)),
            ],
          );
        },
      ),
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBookshelfRow(BuildContext context, String districtName, List<Trip> trips) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(top: AppConstants.spaceM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shelf Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: AppConstants.spaceS),
            child: Row(
              children: [
                const Icon(Icons.folder_shared_rounded, color: AppTheme.primaryBlue, size: 20),
                const SizedBox(width: 8),
                Text(
                  districtName,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(${trips.length})',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),

          // Album row container
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              itemCount: trips.length,
              itemBuilder: (context, idx) {
                return _buildAlbumCard(context, trips[idx]);
              },
            ),
          ),

          // Wood shelf divider bar
          Container(
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF8B6914), // warm wood brown
              borderRadius: BorderRadius.circular(4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  offset: const Offset(0, 3),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(BuildContext context, Trip trip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Determine album cover: first memory image URL, or fallback to trip hero image URL
    final coverUrl = trip.memories.isNotEmpty
        ? (trip.memories.first['image'] as String? ?? trip.imageUrl)
        : trip.imageUrl;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OpenedAlbumScreen(trip: trip),
          ),
        );
      },
      child: Container(
        width: 130,
        margin: const EdgeInsets.only(right: AppConstants.spaceM, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Album cover image
            Expanded(
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      boxShadow: AppConstants.cardShadow,
                      image: DecorationImage(
                        image: NetworkImage(coverUrl),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  // Dark shadow gradient on bottom of cover
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                      ),
                    ),
                  ),
                  // Solo/Group Indicator chip on cover
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            trip.isGroup ? Icons.people_rounded : Icons.person_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            trip.isGroup ? 'Group' : 'Solo',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            // Album Title
            Text(
              trip.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            // Date subtitle
            Text(
              trip.dateRange.split('-')[0].trim(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 10,
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
