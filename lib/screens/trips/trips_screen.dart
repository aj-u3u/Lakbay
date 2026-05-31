import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/trip_provider.dart';
import '../../providers/nav_provider.dart';
import '../../models/trip.dart';
import '../../widgets/loaders/loading_indicator.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _selectedFilter = 'All'; // 'All', 'Solo', 'Group'

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

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

  void _showCreateTripOptions(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
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
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceL),
              Text(
                'Plan a New Adventure',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
              const SizedBox(height: AppConstants.spaceM),
              
              // Option 1: Manual Trip
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.edit_note_rounded, color: AppTheme.primaryBlue, size: 24),
                ),
                title: Text(
                  'Manual Trip',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Create a customized trip manually with your own details',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const _CreateTripBottomSheet(),
                  );
                },
              ),
              const Divider(),
              
              // Option 2: AI Planner
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.secondaryGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const ImageIcon(AssetImage('assets/icons/ai_planner.png'), color: AppTheme.secondaryGreen, size: 24),
                ),
                title: Text(
                  'AI Trip Planner',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Let our intelligent chatbot map out a custom itinerary',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  context.read<NavProvider>().setIndex(1); // Swaps tab to Planner
                },
              ),
              const Divider(),
              
              // Option 3: Join via Link
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.link_rounded, color: Colors.amber, size: 24),
                ),
                title: Text(
                  'Join via Link',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                  ),
                ),
                subtitle: Text(
                  'Paste a shared group link to join an existing group itinerary',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showJoinLinkDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showJoinLinkDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController linkController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Join Group Trip',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Paste the shared group invite link below to sync this trip to your dashboard.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppConstants.spaceM),
              TextField(
                controller: linkController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Invite Link',
                  hintText: 'e.g. lakbay://trip/join?code=123',
                  labelStyle: const TextStyle(color: AppTheme.primaryBlue),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: AppTheme.primaryBlue),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                final link = linkController.text.trim();
                if (link.isEmpty) return;

                Navigator.pop(dialogContext);
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Successfully joined the group trip! syncing... 👥'),
                    backgroundColor: AppTheme.secondaryGreen,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.secondaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Join'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChipsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filters = [
      {'label': 'All', 'icon': Icons.space_dashboard_rounded},
      {'label': 'Solo', 'icon': Icons.backpack_rounded},
      {'label': 'Group', 'icon': Icons.people_alt_rounded},
    ];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceS, horizontal: AppConstants.spaceM),
      color: Theme.of(context).colorScheme.surface,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: filters.map((f) {
            final label = f['label'] as String;
            final icon = f['icon'] as IconData;
            final isSelected = _selectedFilter == label;

            return Padding(
              padding: const EdgeInsets.only(right: AppConstants.spaceS),
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedFilter = label;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryBlue
                        : (isDark ? Colors.grey.withOpacity(0.1) : Colors.grey.withOpacity(0.06)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryBlue
                          : (isDark ? Colors.grey.withOpacity(0.2) : Colors.grey.withOpacity(0.15)),
                      width: 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ]
                        : null,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icon,
                        size: 14,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        label == 'All' ? 'All Trips' : (label == 'Solo' ? 'Solo Trips' : 'Group Trips'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Colors.white
                              : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Trips', style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryBlue)),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildFilterChipsSection(),
          Expanded(
            child: Consumer<TripProvider>(
              builder: (_, provider, _) {
                if (provider.isLoading) return const LoadingIndicator(message: 'Loading your trips...');
                
                final trips = provider.userTrips;
                
                List<Trip> filterByStyle(List<Trip> list) {
                  if (_selectedFilter == 'Solo') {
                    return list.where((t) => !t.isGroup).toList();
                  } else if (_selectedFilter == 'Group') {
                    return list.where((t) => t.isGroup).toList();
                  }
                  return list;
                }

                final upcomingTrips = filterByStyle(trips.where((t) => !_isTripCompleted(t)).toList());
                final completedTrips = filterByStyle(trips.where((t) => _isTripCompleted(t)).toList());

                return TabBarView(
                  controller: _tabCtrl,
                  children: [
                    upcomingTrips.isEmpty
                        ? _buildEmptyState(
                            _selectedFilter == 'All' ? 'No upcoming trips' : 'No upcoming $_selectedFilter trips',
                            Icons.flight_takeoff_rounded,
                            'Plan a new trip to get started!')
                        : _buildTripList(upcomingTrips),
                    completedTrips.isEmpty
                        ? _buildEmptyState(
                            _selectedFilter == 'All' ? 'No completed trips yet' : 'No completed $_selectedFilter trips yet',
                            Icons.check_circle_outline,
                            'Complete a trip to see it here.')
                        : _buildTripList(completedTrips),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTripOptions(context),
        backgroundColor: AppTheme.secondaryGreen,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildTripList(List<Trip> trips) {
    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      itemCount: trips.length,
      itemBuilder: (_, i) => _TripCard(trip: trips[i]),
    );
  }

  Widget _buildEmptyState(String title, IconData icon, String subtitle) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: AppTheme.primaryBlue.withOpacity(0.2)),
          const SizedBox(height: AppConstants.spaceM),
          Text(title, style: GoogleFonts.outfit(
            fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue.withOpacity(0.5))),
          const SizedBox(height: AppConstants.spaceS),
          Text(subtitle, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55), fontSize: 13)),
        ],
      ),
    );
  }
}

enum TripStatus { upcoming, active, completed }

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  TripStatus _getTripStatus(Trip trip) {
    if (trip.dateRange.contains('Flexible') || trip.dateRange.contains('AI Generated')) {
      return TripStatus.upcoming;
    }
    try {
      final parts = trip.dateRange.split(RegExp(r'\s*[-–]\s*'));
      if (parts.isEmpty) return TripStatus.upcoming;
      
      final startDateStr = parts[0].trim();
      final endDateStr = parts.length > 1 ? parts[1].trim() : parts[0].trim();
      
      final months = {
        'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
        'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12
      };
      
      DateTime? parseDate(String dateStr) {
        final cleanStr = dateStr.toLowerCase().replaceAll(',', '');
        final strParts = cleanStr.split(RegExp(r'\s+'));
        if (strParts.length >= 3) {
          final month = months[strParts[0].substring(0, 3)] ?? 1;
          final day = int.tryParse(strParts[1]) ?? 1;
          final year = int.tryParse(strParts[2]) ?? DateTime.now().year;
          return DateTime(year, month, day);
        }
        return null;
      }
      
      final startDate = parseDate(startDateStr);
      final endDate = parseDate(endDateStr);
      
      if (startDate != null && endDate != null) {
        final now = DateTime.now();
        final todayMidnight = DateTime(now.year, now.month, now.day);
        final endMidnight = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        final startMidnight = DateTime(startDate.year, startDate.month, startDate.day, 0, 0, 0);
        
        if (todayMidnight.isAfter(endMidnight)) {
          return TripStatus.completed;
        } else if (todayMidnight.isBefore(startMidnight)) {
          return TripStatus.upcoming;
        } else {
          return TripStatus.active;
        }
      }
    } catch (_) {}
    return TripStatus.upcoming;
  }

  Widget _buildStatusChip(TripStatus status) {
    switch (status) {
      case TripStatus.active:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.secondaryGreen, // Coral
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              PulsingDot(),
              SizedBox(width: 5),
              Text(
                'Active',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case TripStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'Completed',
            style: GoogleFonts.outfit(
              color: Colors.white70,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case TripStatus.upcoming:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBlue, width: 1.5),
          ),
          child: const Text(
            'Upcoming',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }

  Widget _buildTravelTypePill(bool isGroup) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGroup ? Icons.people_alt_rounded : Icons.person_rounded,
            size: 10,
            color: Colors.white70,
          ),
          const SizedBox(width: 4),
          Text(
            isGroup ? 'Group' : 'Solo',
            style: GoogleFonts.outfit(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCircle({
    String? imageAsset,
    IconData? icon,
    required VoidCallback onTap,
  }) {
    return ClipOval(
      child: Material(
        color: Colors.white.withValues(alpha: 0.18),
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 32,
            height: 32,
            child: Center(
              child: imageAsset != null
                  ? ImageIcon(
                      AssetImage(imageAsset),
                      size: 15,
                      color: Colors.white,
                    )
                  : Icon(
                      icon,
                      size: 15,
                      color: Colors.white,
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _getTripStatus(trip);

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.groupDashboard,
          arguments: trip,
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
        height: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          boxShadow: AppConstants.cardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background image
              Image.network(
                trip.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey[900],
                  child: const Center(
                    child: Icon(
                      Icons.landscape_rounded,
                      color: Colors.white30,
                      size: 40,
                    ),
                  ),
                ),
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.1),
                      Colors.black.withValues(alpha: 0.4),
                      Colors.black.withValues(alpha: 0.85),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              // Content overlay
              Padding(
                padding: const EdgeInsets.all(AppConstants.spaceL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      trip.title,
                      style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            offset: const Offset(0, 1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 11,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${trip.dateRange}  ·  ₱${trip.budget.toStringAsFixed(0)}',
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Left side chips
                        Row(
                          children: [
                            _buildStatusChip(status),
                            const SizedBox(width: 8),
                            _buildTravelTypePill(trip.isGroup),
                          ],
                        ),
                        // Right side actions
                        Row(
                          children: [
                            _buildActionCircle(
                              imageAsset: 'assets/icons/ai_planner.png',
                              onTap: () {
                                context.read<TripProvider>().discussTripWithAI(trip);
                                context.read<NavProvider>().setIndex(1);
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildActionCircle(
                              icon: Icons.arrow_forward_rounded,
                              onTap: () {
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.groupDashboard,
                                  arguments: trip,
                                );
                              },
                            ),
                          ],
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
}

class _CreateTripBottomSheet extends StatefulWidget {
  const _CreateTripBottomSheet();

  @override
  State<_CreateTripBottomSheet> createState() => _CreateTripBottomSheetState();
}

class _CreateTripBottomSheetState extends State<_CreateTripBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _destController = TextEditingController();
  final _budgetController = TextEditingController();

  DateTimeRange? _selectedDateRange;
  int _selectedImageIndex = 0;
  bool _isGroup = false;

  final List<Map<String, String>> _coverImages = [
    {
      'name': 'Beach 🏖️',
      'url': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?w=800&q=80'
    },
    {
      'name': 'Mountain ⛰️',
      'url': 'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?w=800&q=80'
    },
    {
      'name': 'City 🏙️',
      'url': 'https://images.unsplash.com/photo-1477959858617-67f85cf4f1df?w=800&q=80'
    },
    {
      'name': 'Forest 🌲',
      'url': 'https://images.unsplash.com/photo-1441974231531-c6227db76b6e?w=800&q=80'
    },
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _destController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  Future<void> _selectDates() async {
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: todayMidnight,
      lastDate: todayMidnight.add(const Duration(days: 365 * 2)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppTheme.textPrimaryLight,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
    }
  }

  String _formatDate(DateTime dt) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
  }

  String get _dateRangeText {
    if (_selectedDateRange == null) return 'Select Dates';
    return '${_formatDate(_selectedDateRange!.start)} - ${_formatDate(_selectedDateRange!.end)}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDateRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a date range for your trip!'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final budgetVal = double.tryParse(_budgetController.text) ?? 5000.0;
    
    final newTrip = Trip(
      id: 'trip-${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text.trim(),
      destinationName: _destController.text.trim(),
      dateRange: _dateRangeText,
      budget: budgetVal,
      imageUrl: _coverImages[_selectedImageIndex]['url']!,
      isGroup: _isGroup,
      numTravelers: _isGroup ? 4 : 1,
      itinerary: {
        1: [
          TripActivity(
            time: '09:00 AM',
            title: 'Welcome to ${_destController.text.trim()}!',
            description: 'First day of your amazing adventure.',
            cost: 'Free',
            location: _destController.text.trim(),
          )
        ]
      },
    );

    // Show loading indicator or block UI
    final provider = context.read<TripProvider>();
    final success = await provider.addNewTrip(newTrip);
    
    if (!mounted) return;
    
    if (success) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Trip "${newTrip.title}" successfully created! ✈️'),
          backgroundColor: AppTheme.secondaryGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.errorMessage ?? 'Failed to save trip. Please try again.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.spaceL,
        right: AppConstants.spaceL,
        top: AppConstants.spaceL,
        bottom: AppConstants.spaceL + bottomInset,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Plan a New Adventure',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceM),
              TextFormField(
                controller: _titleController,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Trip Name',
                  hintText: 'e.g. Samal Summer Getaway',
                  prefixIcon: const Icon(Icons.edit_road_rounded, color: AppTheme.primaryBlue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter a trip name' : null,
              ),
              const SizedBox(height: AppConstants.spaceM),
              TextFormField(
                controller: _destController,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Where to?',
                  hintText: 'e.g. Samal Island, Davao del Norte',
                  prefixIcon: const Icon(Icons.location_on_rounded, color: AppTheme.primaryBlue, size: 20),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                  ),
                ),
                validator: (val) => val == null || val.trim().isEmpty ? 'Enter a destination' : null,
              ),
              const SizedBox(height: AppConstants.spaceM),
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _selectDates,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.withOpacity(0.5)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primaryBlue),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Dates', style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedDateRange == null ? 'Select Dates' : _dateRangeText,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedDateRange == null ? FontWeight.normal : FontWeight.bold,
                                      color: _selectedDateRange == null ? Colors.grey : (isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceM),
                  Expanded(
                    child: TextFormField(
                      controller: _budgetController,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                      ),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Budget (PHP)',
                        hintText: 'e.g. 15000',
                        prefixIcon: const Icon(Icons.payments_rounded, color: AppTheme.primaryBlue, size: 20),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: AppTheme.primaryBlue, width: 2),
                        ),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Enter budget';
                        if (double.tryParse(val) == null) return 'Enter valid number';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceL),
              Text(
                'Travel Type',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppConstants.spaceS),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Solo Travel')),
                      selected: !_isGroup,
                      onSelected: (val) {
                        if (val) setState(() => _isGroup = false);
                      },
                      selectedColor: AppTheme.primaryBlue.withOpacity(0.12),
                      checkmarkColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        color: !_isGroup ? AppTheme.primaryBlue : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppConstants.spaceM),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Group Travel')),
                      selected: _isGroup,
                      onSelected: (val) {
                        if (val) setState(() => _isGroup = true);
                      },
                      selectedColor: AppTheme.secondaryGreen.withOpacity(0.12),
                      checkmarkColor: AppTheme.secondaryGreen,
                      labelStyle: TextStyle(
                        color: _isGroup ? AppTheme.secondaryGreen : (isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceL),
              Text(
                'Choose a Cover Style',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
              ),
              const SizedBox(height: AppConstants.spaceS),
              SizedBox(
                height: 75,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _coverImages.length,
                  itemBuilder: (context, idx) {
                    final item = _coverImages[idx];
                    final isSelected = _selectedImageIndex == idx;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedImageIndex = idx),
                      child: Container(
                        width: 100,
                        margin: const EdgeInsets.only(right: AppConstants.spaceM),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                            width: 2.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primaryBlue.withOpacity(0.3),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  )
                                ]
                              : [],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Image.network(item['url']!, fit: BoxFit.cover),
                              Container(color: Colors.black26),
                              Center(
                                child: Text(
                                  item['name']!,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppConstants.spaceXL),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.flight_takeoff_rounded, size: 20),
                      SizedBox(width: 8),
                      Text('Start Planning', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
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
