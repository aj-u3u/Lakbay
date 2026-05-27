import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../models/trip.dart';

class PlannerResultsScreen extends StatelessWidget {
  final int durationDays;
  const PlannerResultsScreen({Key? key, required this.durationDays}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (_, provider, __) {
        final trip = provider.latestGeneratedTrip ?? Trip.mockTrips.first;
        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: AppTheme.primaryBlue,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  title: Text('Your AI Itinerary', style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(trip.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: AppTheme.primaryBlue)),
                      DecoratedBox(decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, AppTheme.primaryBlue.withOpacity(0.9)],
                        ),
                      )),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceL),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Trip summary card
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceL),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [AppTheme.secondaryGreen.withOpacity(0.1), AppTheme.accentTeal.withOpacity(0.05)],
                          ),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                          border: Border.all(color: AppTheme.secondaryGreen.withOpacity(0.25)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.psychology_rounded, color: AppTheme.secondaryGreen, size: 18),
                                const SizedBox(width: 8),
                                Text('AI Generated', style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen, fontSize: 13)),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                                  ),
                                  child: Text('${trip.itinerary.length} Days',
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppConstants.spaceM),
                            Text(trip.title, style: GoogleFonts.outfit(
                              fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.location_on_rounded, color: AppTheme.textSecondaryLight, size: 14),
                              const SizedBox(width: 4),
                              Text(trip.destinationName,
                                style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 13)),
                            ]),
                            const SizedBox(height: AppConstants.spaceM),
                            Row(
                              children: [
                                _infoChip(Icons.payments_rounded, '₱${trip.budget.toStringAsFixed(0)} Budget'),
                                const SizedBox(width: AppConstants.spaceS),
                                _infoChip(Icons.calendar_month_rounded, trip.dateRange),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceXL),

                      Text('Day-by-Day Itinerary', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      const SizedBox(height: AppConstants.spaceM),
                    ],
                  ),
                ),
              ),

              // Day-by-day list
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, dayIndex) {
                    final dayNum = dayIndex + 1;
                    final activities = trip.itinerary[dayNum] ?? [];
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(AppConstants.spaceL, 0, AppConstants.spaceL, AppConstants.spaceL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                            ),
                            child: Text('Day $dayNum', style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ),
                          const SizedBox(height: AppConstants.spaceM),
                          ...activities.map((activity) => _buildActivityTile(activity)).toList(),
                        ],
                      ),
                    );
                  },
                  childCount: trip.itinerary.length,
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceXL),
                  child: Column(
                    children: [
                      CustomButton(
                        label: 'Save to My Trips',
                        onPressed: () {
                          context.read<TripProvider>().saveGeneratedTrip();
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Itinerary saved to your trips!'),
                              backgroundColor: AppTheme.secondaryGreen),
                          );
                        },
                        variant: ButtonVariant.primary,
                        width: double.infinity,
                        leadingIcon: Icons.bookmark_add_rounded,
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      CustomButton(
                        label: 'Regenerate',
                        onPressed: () => Navigator.pop(context),
                        variant: ButtonVariant.outlined,
                        width: double.infinity,
                        leadingIcon: Icons.refresh_rounded,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActivityTile(TripActivity activity) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(activity.time, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen)),
              ),
            ],
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                boxShadow: AppConstants.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(activity.title, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 4),
                  Text(activity.description, style: const TextStyle(
                    fontSize: 12, color: AppTheme.textSecondaryLight, height: 1.4)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 12, color: AppTheme.textSecondaryLight),
                    const SizedBox(width: 3),
                    Expanded(child: Text(activity.location,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight))),
                    Text(activity.cost, style: const TextStyle(
                      fontSize: 12, color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold)),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.primaryBlue.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppTheme.primaryBlue),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
