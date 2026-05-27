import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';

class GroupDashboardScreen extends StatelessWidget {
  final Trip? trip;
  const GroupDashboardScreen({Key? key, this.trip}) : super(key: key);

  static const _members = [
    {'name': 'Arjane', 'role': 'Organizer', 'avatar': 'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80'},
    {'name': 'Bea', 'role': 'Member', 'avatar': 'https://images.unsplash.com/photo-1517841905240-472988babdf9?w=100&q=80'},
    {'name': 'Carlo', 'role': 'Member', 'avatar': 'https://images.unsplash.com/photo-1539571696357-5a69c17a67c6?w=100&q=80'},
    {'name': 'Dana', 'role': 'Member', 'avatar': 'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=100&q=80'},
  ];

  Trip _getTrip(BuildContext context) {
    if (trip != null) return trip!;
    final trips = context.read<TripProvider>().userTrips;
    return trips.isNotEmpty ? trips.first : Trip.mockTrips[0];
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = _getTrip(context);
    final totalStops = activeTrip.itinerary.values.fold<int>(0, (sum, list) => sum + list.length);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Trip Dashboard', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppConstants.spaceM),
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(activeTrip.imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.55),
                    BlendMode.darken,
                  ),
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                boxShadow: AppConstants.premiumShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.flight_takeoff_rounded, color: Colors.white70, size: 28),
                  const SizedBox(height: AppConstants.spaceM),
                  Text('${activeTrip.title} 🏖️', style: GoogleFonts.outfit(
                    fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('${activeTrip.dateRange} • ${activeTrip.destinationName}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: AppConstants.spaceL),
                  Row(
                    children: [
                      _statChip('${activeTrip.itinerary.length}', activeTrip.itinerary.length == 1 ? 'Day' : 'Days'),
                      const SizedBox(width: AppConstants.spaceM),
                      _statChip('$totalStops', totalStops == 1 ? 'Stop' : 'Stops'),
                      const SizedBox(width: AppConstants.spaceM),
                      _statChip('₱${activeTrip.budget >= 1000 ? '${(activeTrip.budget / 1000).toStringAsFixed(0)}K' : activeTrip.budget.toStringAsFixed(0)}', 'Budget'),
                    ],
                  ),
                ],
              ),
            ),

            // Members section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
              child: Text('Members', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
            ),
            const SizedBox(height: AppConstants.spaceM),
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                itemCount: _members.length + 1,
                itemBuilder: (_, i) {
                  if (i == _members.length) {
                    return Padding(
                      padding: const EdgeInsets.only(right: AppConstants.spaceM),
                      child: Column(
                        children: [
                          Container(
                            width: 56, height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3), width: 2),
                              color: AppTheme.primaryBlue.withOpacity(0.07),
                            ),
                            child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(height: 6),
                          const Text('Invite', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                        ],
                      ),
                    );
                  }
                  final m = _members[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: AppConstants.spaceM),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            ClipOval(
                              child: Image.network(m['avatar']!, width: 56, height: 56, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 56, height: 56,
                                  color: AppTheme.secondaryGreen.withOpacity(0.2),
                                  child: const Icon(Icons.person, color: AppTheme.primaryBlue),
                                )),
                            ),
                            if (m['role'] == 'Organizer')
                              Positioned(
                                bottom: 0, right: 0,
                                child: Container(
                                  width: 18, height: 18,
                                  decoration: const BoxDecoration(
                                    color: AppTheme.secondaryGreen,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.star_rounded, size: 11, color: Colors.white),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(m['name']!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: AppConstants.spaceXL),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
              child: Text('Quick Access', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
            ),
            const SizedBox(height: AppConstants.spaceM),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
              child: Row(
                children: [
                  Expanded(
                    child: _accessCard(context, 'Tasks', Icons.checklist_rounded,
                      AppTheme.secondaryGreen, () => Navigator.pushNamed(context, AppRoutes.groupTasks)),
                  ),
                  const SizedBox(width: AppConstants.spaceM),
                  Expanded(
                    child: _accessCard(context, 'Shared Memories', Icons.photo_album_rounded,
                      AppTheme.accentTeal, () => Navigator.pushNamed(context, AppRoutes.groupMemories)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppConstants.spaceXL),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
      ],
    );
  }

  Widget _accessCard(BuildContext ctx, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: AppConstants.spaceM),
            Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
