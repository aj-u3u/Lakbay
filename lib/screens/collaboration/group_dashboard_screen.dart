import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/trip.dart';
import '../../models/destination.dart';
import '../../providers/trip_provider.dart';

class GroupDashboardScreen extends StatefulWidget {
  final Trip? trip;
  const GroupDashboardScreen({super.key, this.trip});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  // Members List State
  late List<Map<String, String>> _members;

  // Contributions Tracker State — seeded from members in initState
  late List<Map<String, dynamic>> _contributions;

  // Notes Editing State
  bool _isEditingNotes = false;
  late TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    final trip = widget.trip;
    if (trip != null && trip.members.isNotEmpty) {
      // Real members from saved trip data
      _members = List<Map<String, String>>.from(
        trip.members.map((m) => Map<String, String>.from(m)),
      );
    } else if (trip != null && trip.isGroup) {
      // Seed placeholder slots from numTravelers
      _members = List.generate(trip.numTravelers, (i) => {
        'name': i == 0 ? 'You (Organizer)' : 'Traveler ${i + 1}',
        'role': i == 0 ? 'Organizer' : 'Member',
        'avatar': '',
      });
    } else {
      _members = [];
    }

    // Seed contributions from member list (all start at 0/Unpaid)
    _contributions = _members.map<Map<String, dynamic>>((m) => {
      'name': m['name']!,
      'amount': 0.0,
      'status': 'Unpaid',
    }).toList();

    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Trip _getTrip(BuildContext context) {
    if (widget.trip != null) {
      // Find updated version in provider if exists to maintain sync
      final trips = context.watch<TripProvider>().userTrips;
      final found = trips.firstWhere((t) => t.id == widget.trip!.id, orElse: () => widget.trip!);
      return found;
    }
    final trips = context.watch<TripProvider>().userTrips;
    return trips.isNotEmpty ? trips.first : Trip.mockTrips[0];
  }

  @override
  Widget build(BuildContext context) {
    final activeTrip = _getTrip(context);
    final totalStops = activeTrip.itinerary.values.fold<int>(0, (sum, list) => sum + list.length);
    final isGroup = activeTrip.isGroup;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;

    // Load active notes
    if (!_isEditingNotes && _notesController.text != activeTrip.notes) {
      _notesController.text = activeTrip.notes;
    }

    // Lookup dynamic destination info based on title or destinationName
    final provider = Provider.of<TripProvider>(context);
    final destinations = provider.destinations.isNotEmpty 
        ? provider.destinations 
        : Destination.davaoDestinations;

    final matchedDest = destinations.firstWhere(
      (d) => activeTrip.destinationName.toLowerCase().contains(d.name.toLowerCase()) || 
             d.name.toLowerCase().contains(activeTrip.destinationName.toLowerCase()) ||
             activeTrip.title.toLowerCase().contains(d.name.toLowerCase()),
      orElse: () {
        if (activeTrip.destinationName.toLowerCase().contains('samal') || activeTrip.title.toLowerCase().contains('samal')) {
          return destinations.firstWhere((d) => d.id == 8, orElse: () => destinations.first);
        } else if (activeTrip.destinationName.toLowerCase().contains('eden') || activeTrip.title.toLowerCase().contains('eden')) {
          return destinations.firstWhere((d) => d.id == 1, orElse: () => destinations.first);
        }
        return destinations.isNotEmpty ? destinations.first : Destination.davaoDestinations.first;
      },
    );

    final destExtra = matchedDest.extra;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isGroup ? 'Group Dashboard' : 'Trip Details',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note_rounded, size: 28),
            onPressed: () => _showEditTripDetailsDialog(context, activeTrip),
            tooltip: 'Edit Trip Details',
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded, color: AppTheme.secondaryGreen),
            onPressed: () => _showDigitalReceiptModal(context, activeTrip, matchedDest, destExtra),
            tooltip: 'Export PDF Receipt',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(AppConstants.spaceM),
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                color: AppTheme.primaryBlue,
                image: DecorationImage(
                  image: NetworkImage(activeTrip.imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.55),
                    BlendMode.darken,
                  ),
                ),
                borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                boxShadow: AppConstants.premiumShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Icon(
                        isGroup ? Icons.group_work_rounded : Icons.flight_takeoff_rounded,
                        color: Colors.white70,
                        size: 28,
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isGroup ? AppTheme.secondaryGreen : AppTheme.primaryBlue,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white38),
                        ),
                        child: Text(
                          isGroup ? 'Group Trip (${activeTrip.numTravelers})' : 'Solo Trip',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
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

            // Contextual Content
            if (isGroup) ...[
              // Expandable Members Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Members', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    Text(
                      _members.any((m) => m['avatar']!.isEmpty)
                          ? 'Tap a slot to name them ✏️'
                          : 'Tap to remove',
                      style: GoogleFonts.outfit(fontSize: 12, color: secondaryTextColor, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
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
                            GestureDetector(
                              onTap: () {
                                final shareLink = 'https://lakbay.app/join/${activeTrip.id}';
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Simulated invite link copied: $shareLink 🔗'),
                                    backgroundColor: AppTheme.secondaryGreen,
                                    duration: const Duration(seconds: 4),
                                    action: SnackBarAction(
                                      label: 'OK',
                                      textColor: Colors.white,
                                      onPressed: () {},
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                width: 56, height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3), width: 2),
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.07),
                                ),
                                child: const Icon(Icons.person_add_rounded, color: AppTheme.primaryBlue),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text('Invite', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                          ],
                        ),
                      );
                    }
                    final m = _members[i];
                    final isPlaceholder = m['avatar']!.isEmpty;
                    final initials = (m['name'] ?? '?').trim().isNotEmpty
                        ? (m['name']!.trim().split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join()).toUpperCase()
                        : '?';
                    final avatarColors = [
                      AppTheme.primaryBlue, AppTheme.secondaryGreen, AppTheme.accentTeal,
                      Colors.orange, Colors.purple, Colors.redAccent,
                    ];
                    final memberColor = avatarColors[i % avatarColors.length];
                    return Padding(
                      padding: const EdgeInsets.only(right: AppConstants.spaceM),
                      child: GestureDetector(
                        onTap: () => isPlaceholder
                            ? _renameMember(i)
                            : _confirmRemoveMember(i),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                isPlaceholder
                                    ? Container(
                                        width: 56, height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: memberColor.withValues(alpha: 0.15),
                                          border: Border.all(color: memberColor.withValues(alpha: 0.4), width: 2),
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials,
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: memberColor,
                                            ),
                                          ),
                                        ),
                                      )
                                    : ClipOval(
                                        child: Image.network(m['avatar']!, width: 56, height: 56, fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 56, height: 56,
                                            color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                                            child: Center(
                                              child: Text(
                                                initials,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                              ),
                                            ),
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
                                if (isPlaceholder)
                                  Positioned(
                                    bottom: 0, right: 0,
                                    child: Container(
                                      width: 18, height: 18,
                                      decoration: BoxDecoration(
                                        color: memberColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.edit_rounded, size: 10, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 60,
                              child: Text(
                                m['name']!,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: isPlaceholder ? memberColor : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppConstants.spaceL),

              // Group Pricing / Budget Split Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Text('Budget Split & Expenses', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                padding: const EdgeInsets.all(AppConstants.spaceL),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.pie_chart_outline_rounded, color: AppTheme.secondaryGreen),
                        const SizedBox(width: 8),
                        Text('Group split summary', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.primaryBlue)),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _splitMetric('Total Budget', '₱${activeTrip.budget.toStringAsFixed(0)}'),
                        _splitMetric('Travelers', '${activeTrip.numTravelers} people'),
                        _splitMetric('Per-Person Share', '₱${(activeTrip.budget / activeTrip.numTravelers).toStringAsFixed(0)}', isPrimary: true),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.spaceL),

              // Group Contribution Tracker
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Contribution Tracker', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    TextButton.icon(
                      onPressed: () => _showAddContributionDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Payment'),
                      style: TextButton.styleFrom(foregroundColor: AppTheme.secondaryGreen),
                    )
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceS),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  boxShadow: AppConstants.cardShadow,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _contributions.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final c = _contributions[index];
                    final personalTargetShare = activeTrip.budget / activeTrip.numTravelers;
                    final diff = c['amount'] - personalTargetShare;
                    final isSettled = diff >= 0;

                    final warningColor = isDark ? Colors.orange[300]! : Colors.orange[800]!;
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSettled ? AppTheme.secondaryGreen.withValues(alpha: 0.1) : warningColor.withValues(alpha: 0.1),
                        child: Text(c['name']![0], style: TextStyle(color: isSettled ? AppTheme.secondaryGreen : warningColor, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(c['name']!, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(
                        isSettled 
                          ? 'Fully Contributed (Excess: ₱${diff.toStringAsFixed(0)})' 
                          : 'Owes: ₱${(-diff).toStringAsFixed(0)}',
                        style: TextStyle(fontSize: 11, color: isSettled ? AppTheme.secondaryGreen : warningColor),
                      ),
                      trailing: Text(
                        '₱${c['amount'].toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppConstants.spaceXL),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Text('Collaboration & Tasks', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                child: Row(
                  children: [
                    Expanded(
                      child: _accessCard(context, 'Tasks', Icons.checklist_rounded,
                        AppTheme.secondaryGreen, () => Navigator.pushNamed(context, AppRoutes.groupTasks, arguments: activeTrip)),
                    ),
                    const SizedBox(width: AppConstants.spaceM),
                    Expanded(
                      child: _accessCard(context, 'Shared Memories', Icons.photo_album_rounded,
                        AppTheme.accentTeal, () => Navigator.pushNamed(context, AppRoutes.groupMemories, arguments: activeTrip)),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // Solo Specific Modules

              // Destination cost list vs custom budget
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Text('Destination Cost Breakdown', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                padding: const EdgeInsets.all(AppConstants.spaceL),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.15)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Accurate pricing from ${matchedDest.name}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    _costBreakdownRow('Entrance Fee', matchedDest.entranceFee),
                    if (destExtra.activityPrices.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      _costBreakdownRow('Activity Fees', destExtra.activityPrices.entries.map((e) => '${e.key}: ${e.value}').join(', ')),
                    ],
                    const SizedBox(height: 6),
                    _costBreakdownRow('Est. Accommodations', destExtra.overnightFee),
                    const SizedBox(height: 6),
                    _costBreakdownRow('Est. Local Meals', matchedDest.id == 8 ? 'Included in Resort' : '₱150 - ₱400 per meal'),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.spaceL),

              // Personal Budget Tracker & Spending Chart
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Text('Personal Budget Tracker', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                padding: const EdgeInsets.all(AppConstants.spaceL),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.25)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.payments_rounded, color: AppTheme.secondaryGreen, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Estimated vs. Actual Spend Chart',
                          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.secondaryGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Total Budget', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                            const SizedBox(height: 2),
                            Text('₱${activeTrip.budget.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Base Destination Est.', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                            const SizedBox(height: 2),
                            Text('₱${matchedDest.estimatedCost.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Safe Margin', style: TextStyle(fontSize: 11, color: secondaryTextColor)),
                            const SizedBox(height: 2),
                            Text('₱${(activeTrip.budget - matchedDest.estimatedCost).toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.secondaryGreen)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    // Progress bar comparing spending
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                      child: LinearProgressIndicator(
                        value: matchedDest.estimatedCost / activeTrip.budget,
                        minHeight: 8,
                        backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Base cost', style: TextStyle(fontSize: 10, color: secondaryTextColor)),
                        Text('Uses ${(matchedDest.estimatedCost / activeTrip.budget * 100).toStringAsFixed(0)}% of budget', style: TextStyle(fontSize: 10, color: secondaryTextColor)),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: AppConstants.spaceXL),

              // Notes Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Text('Personal Notes', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(height: AppConstants.spaceM),
              _buildNotesWidget(activeTrip),

              const SizedBox(height: AppConstants.spaceXL),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
                child: Text('Itinerary & Memories', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
                child: Row(
                  children: [
                    Expanded(
                      child: _accessCard(context, 'View Itinerary', Icons.map_rounded,
                        AppTheme.primaryBlue, () {
                          Navigator.pushNamed(
                            context,
                            AppRoutes.plannerResults,
                            arguments: activeTrip,
                          );
                        }),
                    ),
                    const SizedBox(width: AppConstants.spaceM),
                    Expanded(
                      child: _accessCard(context, 'Personal Memories', Icons.photo_library_rounded,
                        AppTheme.accentTeal, () {
                          Navigator.pushNamed(context, AppRoutes.groupMemories, arguments: activeTrip);
                        }),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppConstants.spaceXXL),
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

  Widget _splitMetric(String label, String value, {bool isPrimary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 10, color: secondaryTextColor)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: isPrimary ? 16 : 14,
            color: isPrimary ? AppTheme.secondaryGreen : AppTheme.primaryBlue
          ),
        ),
      ],
    );
  }

  Widget _costBreakdownRow(String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: secondaryTextColor)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue)),
          ),
        ],
      ),
    );
  }

  Widget _accessCard(BuildContext ctx, String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceL),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

  Widget _buildNotesWidget(Trip activeTrip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteBgColor = (isDark ? Colors.amber[900]! : Colors.amber).withValues(alpha: isDark ? 0.12 : 0.06);
    final noteBorderColor = (isDark ? Colors.amber[300]! : Colors.amber).withValues(alpha: 0.25);
    final noteIconColor = isDark ? Colors.amber[300]! : Colors.amber;
    final noteTextColor = isDark ? Colors.amber[300]! : Colors.amber[800]!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: noteBgColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        border: Border.all(color: noteBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.note_alt_rounded, color: noteIconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Trip Notes & Reminders',
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14, color: noteTextColor),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  _isEditingNotes ? Icons.check_circle_rounded : Icons.edit_rounded,
                  size: 20,
                  color: _isEditingNotes ? AppTheme.secondaryGreen : Colors.grey,
                ),
                onPressed: () {
                  if (_isEditingNotes) {
                    final updated = activeTrip.copyWith(notes: _notesController.text);
                    Provider.of<TripProvider>(context, listen: false).updateTrip(updated);
                    setState(() => _isEditingNotes = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notes saved persistently!'), backgroundColor: AppTheme.secondaryGreen),
                    );
                  } else {
                    setState(() => _isEditingNotes = true);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          _isEditingNotes
              ? TextField(
                  controller: _notesController,
                  maxLines: null,
                  style: const TextStyle(fontSize: 13, height: 1.4),
                  decoration: const InputDecoration(
                    hintText: 'Add notes for this trip...',
                    border: InputBorder.none,
                  ),
                )
              : Text(
                  activeTrip.notes.isEmpty
                      ? 'Write down packaging lists, reservation details, and personal goals for this amazing adventure...'
                      : activeTrip.notes,
                  style: TextStyle(
                    fontSize: 12, 
                    height: 1.4, 
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight
                  ),
                ),
        ],
      ),
    );
  }

  // Confirmation dialog organizer role for removing members
  void _confirmRemoveMember(int index) {
    final memberName = _members[index]['name'];
    if (_members[index]['role'] == 'Organizer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove the trip Organizer!'), backgroundColor: Colors.red),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove Member?', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text('Are you sure you want to remove $memberName from this group trip? They will lose access.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              setState(() {
                _members.removeAt(index);
                if (index < _contributions.length) {
                  _contributions.removeAt(index);
                }
              });
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$memberName removed successfully.'), backgroundColor: AppTheme.secondaryGreen),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Dialog to name a placeholder traveler slot
  void _renameMember(int index) {
    final nameController = TextEditingController(
      text: _members[index]['name'],
    );
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Name this Traveler',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Traveler Name',
            border: OutlineInputBorder(),
            hintText: 'Enter member\'s name',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                setState(() {
                  _members[index] = {
                    ..._members[index],
                    'name': name,
                    // Keep avatar empty; use initials
                  };
                  // Keep contribution name in sync
                  if (index < _contributions.length) {
                    _contributions[index]['name'] = name;
                  }
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Traveler named "$name" ✓'),
                    backgroundColor: AppTheme.secondaryGreen,
                  ),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Dialog to manually add payments to group contributions
  void _showAddContributionDialog(BuildContext context) {
    final nameController = TextEditingController();
    final amountController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Add Contribution Payment', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Traveler Name', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount Contributed (₱)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () {
              final amount = double.tryParse(amountController.text) ?? 0.0;
              if (nameController.text.isNotEmpty && amount > 0) {
                setState(() {
                  _contributions.add({
                    'name': nameController.text,
                    'amount': amount,
                    'status': 'Paid',
                  });
                });
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Payment registered successfully.'), backgroundColor: AppTheme.secondaryGreen),
                );
              }
            },
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Standard dialog to edit basic trip details
  void _showEditTripDetailsDialog(BuildContext context, Trip activeTrip) {
    final titleCtrl = TextEditingController(text: activeTrip.title);
    final datesCtrl = TextEditingController(text: activeTrip.dateRange);
    final budgetCtrl = TextEditingController(text: activeTrip.budget.toStringAsFixed(0));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Trip Details', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Trip Title', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: datesCtrl,
                decoration: const InputDecoration(labelText: 'Date Range', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Budget (₱)', border: OutlineInputBorder()),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            onPressed: () {
              final newBudget = double.tryParse(budgetCtrl.text) ?? activeTrip.budget;
              final updated = activeTrip.copyWith(
                title: titleCtrl.text,
                dateRange: datesCtrl.text,
                budget: newBudget,
              );
              Provider.of<TripProvider>(context, listen: false).updateTrip(updated);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Trip details saved successfully.'), backgroundColor: AppTheme.secondaryGreen),
              );
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Interactive Digital PDF Receipt Modal Simulation
  void _showDigitalReceiptModal(BuildContext context, Trip activeTrip, Destination dest, DestinationExtra extra) {
    double totalEst = dest.estimatedCost;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            bool isDownloading = false;
            double progress = 0.0;

            void runDownloadProgress() async {
              setModalState(() {
                isDownloading = true;
                progress = 0.0;
              });

              for (int i = 1; i <= 10; i++) {
                await Future.delayed(const Duration(milliseconds: 150));
                setModalState(() {
                  progress = i * 0.1;
                });
              }

              if (!context.mounted) return;
              Navigator.pop(ctx); // Close receipt sheet
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('PDF Receipt exported successfully to Downloads! 📄✅'),
                  backgroundColor: AppTheme.secondaryGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final secondaryTextColor = isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight;
            final sheetBgColor = Theme.of(context).colorScheme.surface;

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: sheetBgColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Pull-down handle
                  Center(
                    child: Container(
                      width: 50, height: 5,
                      decoration: BoxDecoration(color: isDark ? Colors.grey[700] : Colors.grey[300], borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Itemized Travel Receipt',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transaction ID: LKB-${activeTrip.id.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: secondaryTextColor, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 16),
                  
                  // Receipt Body (Skeumorphic white receipt strip with dashed borders)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'LAKBAY+ TRAVEL RECEIPT',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.5, color: Colors.grey[700]),
                            ),
                            const Divider(thickness: 1.5, height: 24),
                            _receiptLine('Destination', activeTrip.destinationName),
                            _receiptLine('Travel Dates', activeTrip.dateRange),
                            _receiptLine('Travel Type', activeTrip.isGroup ? 'Group Trip (${activeTrip.numTravelers} Pax)' : 'Solo Trip'),
                            const Divider(thickness: 1, height: 24),
                            
                            // Itemized costs
                            _receiptLine('1. Base Entrance Fee', dest.entranceFee),
                            if (extra.activityPrices.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text('2. Activity Fees:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[600])),
                              ...extra.activityPrices.entries.map((e) => Padding(
                                padding: const EdgeInsets.only(left: 12.0, top: 2),
                                child: _receiptLine('• ${e.key}', e.value),
                              )),
                            ],
                            const SizedBox(height: 6),
                            _receiptLine('3. Accommodation', extra.overnightFee),
                            const SizedBox(height: 6),
                            _receiptLine('4. Transport Estimate', extra.transportOptions.isNotEmpty ? extra.transportOptions.first['price']! : 'Varies'),
                            
                            const Divider(thickness: 2, height: 32),
                            _receiptLine('Estimated Trip Base Cost', '₱${totalEst.toStringAsFixed(0)}', isBold: true),
                            _receiptLine('Your Custom Saved Budget', '₱${activeTrip.budget.toStringAsFixed(0)}', isBold: true),
                            
                            if (activeTrip.isGroup) ...[
                              const SizedBox(height: 6),
                              _receiptLine('Cost Share Per Traveler', '₱${(activeTrip.budget / activeTrip.numTravelers).toStringAsFixed(0)}', isBold: true),
                            ],
                            
                            const SizedBox(height: 30),
                            // Simulated Stamp
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.green, width: 3),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'LAKBAY+ APPROVED',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    letterSpacing: 1.2
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Actions
                  isDownloading
                      ? Column(
                          children: [
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey[200],
                              valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.secondaryGreen),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Generating PDF Receipt... ${(progress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.primaryBlue),
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: runDownloadProgress,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(
                            'Download PDF Receipt',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _receiptLine(String left, String right, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              left,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: isBold ? AppTheme.primaryBlue : Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppTheme.secondaryGreen : AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }
}
