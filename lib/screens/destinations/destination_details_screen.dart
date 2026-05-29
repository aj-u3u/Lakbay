import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/destination.dart';
import '../../models/trip.dart';
import '../../providers/trip_provider.dart';
import '../../providers/nav_provider.dart';
import '../../widgets/buttons/custom_button.dart';

class DestinationDetailsScreen extends StatefulWidget {
  final Destination destination;
  const DestinationDetailsScreen({super.key, required this.destination});

  @override
  State<DestinationDetailsScreen> createState() => _DestinationDetailsScreenState();
}

class _DestinationDetailsScreenState extends State<DestinationDetailsScreen> {
  bool _isSaved = false;
  Position? _userPosition;
  bool _loadingLocation = false;
  String? _locationError;
  final MapController _mapController = MapController();
  double? _distanceToDestination;

  String? _getActivityPrice(String activityName, Destination dest) {
    final prices = dest.extra.activityPrices;
    
    // Try exact match first
    if (prices.containsKey(activityName)) {
      return prices[activityName];
    }
    
    // Try case-insensitive substring match
    final lowerName = activityName.toLowerCase();
    for (final entry in prices.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains(lowerName) || lowerName.contains(key)) {
        return entry.value;
      }
    }
    
    // Fallback mappings for robust presentation:
    if (lowerName.contains('hiking') || lowerName.contains('trekking') || lowerName.contains('walking') || lowerName.contains('climbing')) {
      if (prices.containsKey('General Guide')) return prices['General Guide'];
    }
    if (lowerName.contains('diving') && prices.containsKey('Scuba Diving')) return prices['Scuba Diving'];
    if (lowerName.contains('spa') && prices.containsKey('Mandaya Spa')) return prices['Mandaya Spa'];
    if (lowerName.contains('snorkeling') && prices.containsKey('Snorkeling Gear')) return prices['Snorkeling Gear'];
    if (lowerName.contains('surfing') && prices.containsKey('Surfboard Rental')) return prices['Surfboard Rental'];
    if (lowerName.contains('skimboarding') && prices.containsKey('Skimboard Rental')) return prices['Skimboard Rental'];
    if (lowerName.contains('camping') && prices.containsKey('Tent Pitching')) return prices['Tent Pitching'];
    
    return 'Free';
  }

  Future<void> _requestLocationAndRoute() async {
    setState(() {
      _loadingLocation = true;
      _locationError = null;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled. Please enable them in settings.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission was denied.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission is permanently denied. Please enable it in system settings.';
      }

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      final dest = widget.destination;
      double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        dest.latitude,
        dest.longitude,
      );

      setState(() {
        _userPosition = position;
        _distanceToDestination = distance / 1000; // in km
        _loadingLocation = false;
      });

      // Fit map bounds to show both user location and destination
      final bounds = LatLngBounds.fromPoints([
        LatLng(position.latitude, position.longitude),
        LatLng(dest.latitude, dest.longitude),
      ]);
      _mapController.fitCamera(CameraFit.bounds(
        bounds: bounds,
        padding: const EdgeInsets.all(50),
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _locationError = e.toString();
        _loadingLocation = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_locationError ?? 'Could not retrieve location'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 300,
            backgroundColor: AppTheme.primaryBlue,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: AnimatedSwitcher(
                  duration: AppConstants.animDurationFast,
                  child: Icon(
                    _isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
                    key: ValueKey(_isSaved),
                    color: Colors.white,
                  ),
                ),
                onPressed: () => setState(() => _isSaved = !_isSaved),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(dest.imageUrl, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppTheme.primaryBlue, AppTheme.secondaryGreen],
                        ),
                      ),
                      child: const Icon(Icons.landscape, size: 80, color: Colors.white30),
                    ),
                  ),
                  DecoratedBox(decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      stops: const [0.4, 1.0],
                    ),
                  )),
                  Positioned(
                    bottom: AppConstants.spaceL,
                    left: AppConstants.spaceL,
                    right: AppConstants.spaceL,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryGreen,
                            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                          ),
                          child: Text(dest.category, style: const TextStyle(
                            color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: AppConstants.spaceS),
                        Text(dest.name, style: GoogleFonts.outfit(
                          fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
                        Row(children: [
                          const Icon(Icons.location_on_rounded, color: AppTheme.secondaryGreen, size: 14),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              dest.location,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
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
                  // Quick info row
                  Row(
                    children: [
                      _infoBox(Icons.star_rounded, '${dest.rating}', 'Rating', const Color(0xFFFBBC04)),
                      const SizedBox(width: AppConstants.spaceM),
                      _infoBox(Icons.payments_outlined, '₱${dest.estimatedCost.toStringAsFixed(0)}', 'Est. Cost', AppTheme.secondaryGreen),
                      const SizedBox(width: AppConstants.spaceM),
                      _infoBox(Icons.schedule_rounded, dest.entranceFee, 'Entrance', AppTheme.primaryBlue),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceXL),

                  // Description
                  Text('About', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceS),
                  Text(dest.description, style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.6)),
                  const SizedBox(height: AppConstants.spaceXL),

                  // Operating hours
                  _infoSection(context, 'Operating Hours', Icons.access_time_rounded,
                    dest.operatingHours, AppTheme.accentTeal),
                  const SizedBox(height: AppConstants.spaceL),

                  // Activities
                  Text('Activities', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceM),
                  Wrap(
                    spacing: AppConstants.spaceS,
                    runSpacing: AppConstants.spaceS,
                    children: dest.activities.map((a) {
                      final price = _getActivityPrice(a, dest);
                      final isFree = price == null || price.toLowerCase().contains('free');
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                          border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check_circle_outline_rounded, size: 13, color: AppTheme.secondaryGreen),
                            const SizedBox(width: 5),
                            Text(a, style: const TextStyle(fontSize: 12, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: isFree
                                    ? AppTheme.secondaryGreen.withValues(alpha: 0.15)
                                    : AppTheme.primaryBlue.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isFree ? 'Free' : price,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: isFree ? AppTheme.secondaryGreen : AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: AppConstants.spaceXL),

                  // Accessibility badges
                  Text('Traveler Info', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceM),
                  Wrap(
                    spacing: AppConstants.spaceS,
                    runSpacing: AppConstants.spaceS,
                    children: [
                      _badge('Kid-Friendly', Icons.child_care_rounded, dest.isKidFriendly),
                      _badge('Wheelchair Access', Icons.accessible_rounded, dest.isWheelchairAccessible),
                      _badge('Pet-Friendly', Icons.pets_rounded, dest.isPetFriendly),
                      _badge('Senior-Friendly', Icons.elderly_rounded, dest.isElderlyFriendly),
                    ],
                  ),
                  const SizedBox(height: AppConstants.spaceXL),

                  // Fees & Rates
                  Text('Fees & Rates', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceM),
                  Container(
                    padding: const EdgeInsets.all(AppConstants.spaceM),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AppConstants.radiusL),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                    ),
                    child: Column(
                      children: [
                        _feeRow(Icons.confirmation_num_rounded, 'Entrance Fee', dest.entranceFee),
                        const Divider(height: 20, thickness: 1, color: Colors.black12),
                        _feeRow(Icons.eco_rounded, 'Environmental Fee', dest.extra.environmentalFee),
                        const Divider(height: 20, thickness: 1, color: Colors.black12),
                        _feeRow(Icons.hotel_rounded, 'Overnight Fee', dest.extra.overnightFee),
                      ],
                    ),
                  ),

                  // Activity Pricing
                  if (dest.extra.activityPrices.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceXL),
                    Text('Activity Pricing', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    const SizedBox(height: AppConstants.spaceM),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dest.extra.activityPrices.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spaceS),
                      itemBuilder: (context, index) {
                        final key = dest.extra.activityPrices.keys.elementAt(index);
                        final price = dest.extra.activityPrices[key]!;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: AppConstants.spaceS + 2),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppConstants.radiusM),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.local_activity_rounded, color: AppTheme.accentTeal, size: 18),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Text(
                                  key,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: AppConstants.spaceM),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentTeal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.accentTeal)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Accommodation Options
                  if (dest.extra.accommodationTypes.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceXL),
                    Text('Accommodation Options', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    const SizedBox(height: AppConstants.spaceM),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dest.extra.accommodationTypes.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spaceS),
                      itemBuilder: (context, index) {
                        final acc = dest.extra.accommodationTypes[index];
                        final type = acc['type'] ?? 'Standard Room';
                        final price = acc['price'] ?? 'Contact for rates';
                        return Container(
                          padding: const EdgeInsets.all(AppConstants.spaceM),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.king_bed_rounded, color: AppTheme.primaryBlue, size: 22),
                              ),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryLight)),
                                    const SizedBox(height: 2),
                                    const Text('Available for overnight stay', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                                  ],
                                ),
                              ),
                              Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryGreen)),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  // Meal Inclusions
                  if (dest.extra.mealInclusions.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceXL),
                    Text('Meal Inclusions', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    const SizedBox(height: AppConstants.spaceM),
                    Container(
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppConstants.radiusL),
                        border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: dest.extra.mealInclusions.map((meal) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.restaurant_rounded, color: AppTheme.secondaryGreen, size: 16),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Text(meal, style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimaryLight)),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],

                  // Travel Notes
                  if (dest.extra.travelNotes.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceXL),
                    Text('Travel Notes & Tips', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    const SizedBox(height: AppConstants.spaceM),
                    Container(
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: Colors.amber.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppConstants.radiusL),
                        border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: dest.extra.travelNotes.map((note) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 16),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Text(note, style: const TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textPrimaryLight)),
                              ),
                            ],
                          ),
                        )).toList(),
                      ),
                    ),
                  ],

                  // Location & Route Map
                  const SizedBox(height: AppConstants.spaceXL),
                  Text('Location & Route', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  const SizedBox(height: AppConstants.spaceM),
                  Container(
                    height: 280,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.radiusL),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Map Section
                        Expanded(
                          child: Stack(
                            children: [
                              FlutterMap(
                                mapController: _mapController,
                                options: MapOptions(
                                  initialCenter: LatLng(dest.latitude, dest.longitude),
                                  initialZoom: 13.0,
                                ),
                                children: [
                                  TileLayer(
                                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                    userAgentPackageName: 'com.lakbay.plus',
                                  ),
                                  if (_userPosition != null)
                                    PolylineLayer(
                                      polylines: [
                                        Polyline(
                                          points: [
                                            LatLng(_userPosition!.latitude, _userPosition!.longitude),
                                            LatLng(dest.latitude, dest.longitude),
                                          ],
                                          color: AppTheme.primaryBlue,
                                          strokeWidth: 4,
                                        ),
                                      ],
                                    ),
                                  MarkerLayer(
                                    markers: [
                                      // Destination Marker
                                      Marker(
                                        point: LatLng(dest.latitude, dest.longitude),
                                        width: 40,
                                        height: 40,
                                        child: const Icon(
                                          Icons.location_on_rounded,
                                          color: Colors.redAccent,
                                          size: 40,
                                        ),
                                      ),
                                      // User Location Marker
                                      if (_userPosition != null)
                                        Marker(
                                          point: LatLng(_userPosition!.latitude, _userPosition!.longitude),
                                          width: 40,
                                          height: 40,
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                                              shape: BoxShape.circle,
                                              border: Border.all(color: Colors.white, width: 2),
                                            ),
                                            child: const Center(
                                              child: Icon(
                                                Icons.my_location_rounded,
                                                color: AppTheme.primaryBlue,
                                                size: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              // Refresh / Recenter Controls Overlay
                              Positioned(
                                right: 10,
                                bottom: 10,
                                child: FloatingActionButton.small(
                                  heroTag: 'recenter_btn',
                                  onPressed: () {
                                    if (_userPosition != null) {
                                      final bounds = LatLngBounds.fromPoints([
                                        LatLng(_userPosition!.latitude, _userPosition!.longitude),
                                        LatLng(dest.latitude, dest.longitude),
                                      ]);
                                      _mapController.fitCamera(CameraFit.bounds(
                                        bounds: bounds,
                                        padding: const EdgeInsets.all(40),
                                      ));
                                    } else {
                                      _mapController.move(LatLng(dest.latitude, dest.longitude), 13.0);
                                    }
                                  },
                                  backgroundColor: Colors.white,
                                  child: const Icon(Icons.gps_fixed_rounded, color: AppTheme.primaryBlue),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Location Info Bar / Call-to-action
                        Container(
                          padding: const EdgeInsets.all(AppConstants.spaceM),
                          color: Colors.grey.withValues(alpha: 0.1),
                          child: Row(
                            children: [
                              Expanded(
                                child: _userPosition == null
                                    ? const Text(
                                        'Visualize location & plan your route',
                                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight),
                                      )
                                    : Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'Shortest Route to Destination',
                                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Distance: ${_distanceToDestination!.toStringAsFixed(1)} km away',
                                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen),
                                          ),
                                        ],
                                      ),
                              ),
                              _loadingLocation
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                                      ),
                                    )
                                  : TextButton.icon(
                                      onPressed: _requestLocationAndRoute,
                                      icon: Icon(
                                        _userPosition == null ? Icons.directions_rounded : Icons.refresh_rounded,
                                        size: 16,
                                        color: AppTheme.primaryBlue,
                                      ),
                                      label: Text(
                                        _userPosition == null ? 'Get Route' : 'Recalculate',
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                                      ),
                                    ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Transportation
                  if (dest.extra.transportOptions.isNotEmpty) ...[
                    const SizedBox(height: AppConstants.spaceXL),
                    Text('Transportation & Fare', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                    const SizedBox(height: AppConstants.spaceM),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: dest.extra.transportOptions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spaceS),
                      itemBuilder: (context, index) {
                        final option = dest.extra.transportOptions[index];
                        final vehicle = option['vehicle'] ?? 'Standard Transit';
                        final price = option['price'] ?? 'Varies';
                        final from = option['from'];
                        final to = option['to'];
                        final duration = option['duration'];
                        
                        // Decide which icon to show based on keywords
                        IconData transportIcon = Icons.directions_bus_rounded;
                        if (vehicle.toLowerCase().contains('taxi') || vehicle.toLowerCase().contains('grab')) {
                          transportIcon = Icons.local_taxi_rounded;
                        } else if (vehicle.toLowerCase().contains('ferry') || vehicle.toLowerCase().contains('boat') || vehicle.toLowerCase().contains('speedboat')) {
                          transportIcon = Icons.directions_boat_rounded;
                        } else if (vehicle.toLowerCase().contains('jeepney') || vehicle.toLowerCase().contains('van')) {
                          transportIcon = Icons.directions_transit_rounded;
                        } else if (vehicle.toLowerCase().contains('tricycle') || vehicle.toLowerCase().contains('habal') || vehicle.toLowerCase().contains('motorcycle')) {
                          transportIcon = Icons.motorcycle_rounded;
                        }
                        
                        return Container(
                          padding: const EdgeInsets.all(AppConstants.spaceM),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(transportIcon, color: AppTheme.primaryBlue, size: 22),
                              ),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(vehicle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryLight)),
                                    const SizedBox(height: 3),
                                    if (from != null && to != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.navigation_rounded, size: 10, color: AppTheme.primaryBlue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '$from to $to',
                                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppTheme.textSecondaryLight),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                    ],
                                    if (duration != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.timer_outlined, size: 10, color: AppTheme.accentTeal),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Duration: $duration',
                                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      const Text('Estimated average fare', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                                    ],
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppTheme.secondaryGreen)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                  const SizedBox(height: AppConstants.spaceXXL),

                  // Action buttons
                  CustomButton(
                    label: 'Add to My Trip',
                    onPressed: () => _showAddToTripBottomSheet(context, dest),
                    variant: ButtonVariant.primary,
                    width: double.infinity,
                    leadingIcon: Icons.add_location_rounded,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  CustomButton(
                    label: 'Plan with AI',
                    onPressed: () {
                      // Store the destination context in provider
                      context.read<TripProvider>().setActivePlanDestination(dest);
                      // Switch bottom nav to Planner tab (index 1)
                      context.read<NavProvider>().setIndex(1);
                      // Pop back to the navigation shell
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    variant: ButtonVariant.ghost,
                    width: double.infinity,
                    leadingIcon: Icons.psychology_rounded,
                  ),
                  const SizedBox(height: AppConstants.spaceXL),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToTripBottomSheet(BuildContext context, Destination dest) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer<TripProvider>(
          builder: (context, provider, _) {
            final trips = provider.userTrips;
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
                        color: Colors.grey.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  Text(
                    'Add to My Trip',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select a trip to add ${dest.name}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryLight),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  
                  // Create New Trip Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, color: AppTheme.secondaryGreen, size: 24),
                    ),
                    title: const Text(
                      'Create a New Trip',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimaryLight),
                    ),
                    subtitle: const Text('Start fresh with a brand new itinerary', style: TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight)),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showCreateTripDialog(context, dest);
                    },
                  ),
                  const Divider(height: 24, thickness: 1),

                  if (trips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceXL),
                      child: Center(
                        child: Text(
                          'No upcoming trips yet.\nCreate one to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 13, color: Colors.grey.withValues(alpha: 0.8)),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: trips.length,
                        separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spaceS),
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: Image.network(
                                  trip.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [AppTheme.primaryBlue, AppTheme.secondaryGreen],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              trip.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimaryLight),
                            ),
                            subtitle: Text(
                              '${trip.dateRange} • ${trip.itinerary.length} Days',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondaryLight),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey),
                            onTap: () {
                              final newActivity = TripActivity(
                                time: '10:00 AM',
                                title: 'Visit ${dest.name}',
                                description: 'Explore and experience the beauty of ${dest.name}.',
                                cost: dest.entranceFee,
                                location: dest.location,
                              );
                              
                              provider.addActivityToTrip(trip.id, newActivity);
                              Navigator.pop(sheetContext);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${dest.name} added to "${trip.title}"!'),
                                  backgroundColor: AppTheme.secondaryGreen,
                                ),
                              );
                            },
                          );
                        },
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

  void _showCreateTripDialog(BuildContext context, Destination dest) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Create New Trip',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Where are you planning to go? Give your new adventure a sweet title!',
                style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryLight, height: 1.4),
              ),
              const SizedBox(height: AppConstants.spaceM),
              TextField(
                controller: nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Trip Name',
                  hintText: 'e.g. Davao Escapade 2026',
                  labelStyle: const TextStyle(color: AppTheme.primaryBlue),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
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
                final title = nameController.text.trim();
                if (title.isEmpty) return;

                final newTrip = Trip(
                  id: 'trip-manual-${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  destinationName: dest.location,
                  dateRange: 'Flexible Dates',
                  budget: dest.estimatedCost,
                  imageUrl: dest.imageUrl,
                  itinerary: {
                    1: [
                      TripActivity(
                        time: '10:00 AM',
                        title: 'Visit ${dest.name}',
                        description: 'First stop of our adventure at ${dest.name}!',
                        cost: dest.entranceFee,
                        location: dest.location,
                      ),
                    ],
                  },
                );

                context.read<TripProvider>().addNewTrip(newTrip);
                Navigator.pop(dialogContext);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('New Trip "$title" created and ${dest.name} added!'),
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
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Widget _feeRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimaryLight)),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.secondaryGreen),
          ),
        ),
      ],
    );
  }

  Widget _infoBox(IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 5),
            Text(value, textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: color)),
            Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.textSecondaryLight)),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(BuildContext ctx, String title, IconData icon, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                const SizedBox(height: 4),
                Text(content, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondaryLight, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, IconData icon, bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.secondaryGreen.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
        border: Border.all(
          color: isActive ? AppTheme.secondaryGreen.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isActive ? AppTheme.secondaryGreen : Colors.grey),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.secondaryGreen : Colors.grey,
          )),
        ],
      ),
    );
  }
}

