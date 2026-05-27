import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/trip_provider.dart';
import '../../models/trip.dart';
import '../../widgets/loaders/loading_indicator.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({Key? key}) : super(key: key);

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showCreateTripBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _CreateTripBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text('My Trips', style: GoogleFonts.outfit(
          fontWeight: FontWeight.bold, fontSize: 24, color: AppTheme.primaryBlue)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded, color: AppTheme.secondaryGreen, size: 28),
            onPressed: () => _showCreateTripBottomSheet(context),
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppTheme.primaryBlue,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textSecondaryLight,
          labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
          ],
        ),
      ),
      body: Consumer<TripProvider>(
        builder: (_, provider, __) {
          if (provider.isLoading) return const LoadingIndicator(message: 'Loading your trips...');
          final trips = provider.userTrips;
          return TabBarView(
            controller: _tabCtrl,
            children: [
              trips.isEmpty
                  ? _buildEmptyState('No upcoming trips', Icons.flight_takeoff_rounded, 'Plan a new trip to get started!')
                  : _buildTripList(trips),
              _buildEmptyState('No active trips', Icons.map_outlined, 'Your current active trip will appear here.'),
              _buildEmptyState('No completed trips yet', Icons.check_circle_outline, 'Complete a trip to see it here.'),
            ],
          );
        },
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
          Text(subtitle, style: const TextStyle(color: AppTheme.textSecondaryLight, fontSize: 13)),
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  final Trip trip;
  const _TripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
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
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
          boxShadow: AppConstants.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.network(trip.imageUrl, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(color: AppTheme.primaryBlue.withOpacity(0.15))),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title, style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryBlue)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded, size: 13, color: AppTheme.textSecondaryLight),
                    const SizedBox(width: 3),
                    Text(trip.destinationName,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight)),
                  ]),
                  const SizedBox(height: AppConstants.spaceM),
                  Row(
                    children: [
                      _chip(Icons.calendar_today_rounded, trip.dateRange),
                      const Spacer(),
                      _chip(Icons.payments_rounded, '₱${trip.budget.toStringAsFixed(0)}'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 12, color: AppTheme.secondaryGreen),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
      ],
    );
  }
}

class _CreateTripBottomSheet extends StatefulWidget {
  const _CreateTripBottomSheet({Key? key}) : super(key: key);

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
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 2)),
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

  void _submit() {
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

    context.read<TripProvider>().addNewTrip(newTrip);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Trip "${newTrip.title}" successfully created! ✈️'),
        backgroundColor: AppTheme.secondaryGreen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.only(
        left: AppConstants.spaceL,
        right: AppConstants.spaceL,
        top: AppConstants.spaceL,
        bottom: AppConstants.spaceL + bottomInset,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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
                style: const TextStyle(fontSize: 14),
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
                style: const TextStyle(fontSize: 14),
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
                                      color: _selectedDateRange == null ? Colors.grey : AppTheme.textPrimaryLight,
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
                      style: const TextStyle(fontSize: 14),
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
                'Choose a Cover Style',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimaryLight,
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
