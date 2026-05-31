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

import '../../services/api_service.dart';

class TransitHub {
  final String name;
  final LatLng coordinates;
  final String city;

  TransitHub({required this.name, required this.coordinates, required this.city});
}

final List<TransitHub> majorTransitHubs = [
  TransitHub(
    name: 'Davao Overland Transport Terminal (Ecoland)',
    coordinates: const LatLng(7.0528, 125.5962),
    city: 'Davao City',
  ),
  TransitHub(
    name: 'Panabo Public Terminal',
    coordinates: const LatLng(7.3079, 125.6811),
    city: 'Panabo',
  ),
  TransitHub(
    name: 'Tagum City Integrated Terminal',
    coordinates: const LatLng(7.4475, 125.8016),
    city: 'Tagum',
  ),
  TransitHub(
    name: 'Digos Overland Transport Terminal',
    coordinates: const LatLng(6.7554, 125.3524),
    city: 'Digos',
  ),
];

class DestinationDetailsScreen extends StatefulWidget {
  final Destination destination;
  final bool isFromRecommendation;
  const DestinationDetailsScreen({
    super.key,
    required this.destination,
    this.isFromRecommendation = false,
  });

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

  @override
  void initState() {
    super.initState();
    // Record lightweight view interaction immediately to update popularity metrics
    ApiService().recordInteraction(widget.destination.id, 'view');
    _checkPermissionAndGetLocation();
  }

  Future<void> _checkPermissionAndGetLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        _requestLocationAndRoute();
      }
    } catch (_) {}
  }


  double _getHubToDestCost(Destination dest, String city) {
    final options = dest.extra.transportOptions;
    if (options.isEmpty) return 0.0;
    for (final opt in options) {
      final from = (opt['from'] ?? '').toLowerCase();
      if (from.contains(city.toLowerCase()) || city.toLowerCase().contains(from)) {
        final cleanText = (opt['price'] ?? '0').replaceAll(RegExp(r'[^\d]'), '');
        return double.tryParse(cleanText) ?? 0.0;
      }
    }
    final cleanText = (options.first['price'] ?? '0').replaceAll(RegExp(r'[^\d]'), '');
    return double.tryParse(cleanText) ?? 0.0;
  }

  Map<String, dynamic> _calculateFirstMile(Position userPos) {
    TransitHub? nearestHub;
    double minDistanceInMeters = double.infinity;

    for (final hub in majorTransitHubs) {
      final double dist = Geolocator.distanceBetween(
        userPos.latitude,
        userPos.longitude,
        hub.coordinates.latitude,
        hub.coordinates.longitude,
      );
      if (dist < minDistanceInMeters) {
        minDistanceInMeters = dist;
        nearestHub = hub;
      }
    }

    final double distanceInKm = minDistanceInMeters / 1000.0;
    String vehicle = 'Jeepney';
    double estimatedCost = 15.0;
    String duration = '5 mins';

    if (distanceInKm < 1.0) {
      vehicle = 'Walking';
      estimatedCost = 0.0;
      duration = '${(distanceInKm * 12).toStringAsFixed(0)} mins';
    } else if (distanceInKm >= 1.0 && distanceInKm <= 4.0) {
      vehicle = 'Local Tricycle / Pedicab';
      estimatedCost = 25.0;
      duration = '8 - 10 mins';
    } else if (distanceInKm > 4.0 && distanceInKm <= 12.0) {
      vehicle = 'Jeepney / Commuter Multicab';
      estimatedCost = 45.0;
      duration = '15 - 25 mins';
    } else {
      vehicle = 'Local Taxi / Grab Car';
      estimatedCost = 150.0 + (distanceInKm * 15.0);
      duration = '${(distanceInKm * 2.2).toStringAsFixed(0)} mins';
    }

    return {
      'nearestHub': nearestHub ?? majorTransitHubs.first,
      'distance': distanceInKm,
      'vehicle': vehicle,
      'cost': estimatedCost,
      'duration': duration,
    };
  }

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

  List<MapEntry<String, String>> _getUnifiedActivityPrices(Destination dest) {
    final Map<String, String> unified = {};
    
    // 1. Add all explicit activity prices from extra
    dest.extra.activityPrices.forEach((key, value) {
      unified[key] = value;
    });
    
    // 2. For each activity in the destination, if it's not already in the map,
    // look up its price. If it is already represented, make sure it has the correct price.
    for (final activity in dest.activities) {
      bool exists = false;
      final lowerAct = activity.toLowerCase();
      for (final key in unified.keys) {
        final lowerKey = key.toLowerCase();
        if (lowerKey == lowerAct || lowerKey.contains(lowerAct) || lowerAct.contains(lowerKey)) {
          exists = true;
          break;
        }
      }
      
      if (!exists) {
        final price = _getActivityPrice(activity, dest);
        unified[activity] = price ?? 'Free';
      }
    }
    
    return unified.entries.toList();
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double displayCost = dest.estimatedCost;
    String labelText = 'Est. Cost';

    if (_userPosition != null) {
      final firstMile = _calculateFirstMile(_userPosition!);
      final hub = firstMile['nearestHub'] as TransitHub;
      final double firstCost = firstMile['cost'] as double;
      final double hubToDestCost = _getHubToDestCost(dest, hub.city);

      final cleanEntrance = dest.entranceFee.replaceAll(RegExp(r'[^\d]'), '');
      final double entranceFee = double.tryParse(cleanEntrance) ?? 0.0;

      final cleanEnv = dest.extra.environmentalFee.replaceAll(RegExp(r'[^\d]'), '');
      final double environmentalFee = double.tryParse(cleanEnv) ?? 0.0;

      displayCost = firstCost + hubToDestCost + entranceFee + environmentalFee;
      labelText = 'Your Cost';
    }

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
                onPressed: () {
                  final newSavedState = !_isSaved;
                  setState(() => _isSaved = newSavedState);
                  if (newSavedState) {
                    // Record save interaction in Postgres event log to boost popularity score
                    ApiService().recordInteraction(widget.destination.id, 'save');
                  }
                },
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
                      _infoBox(Icons.payments_outlined, '₱${displayCost.toStringAsFixed(0)}', labelText, AppTheme.secondaryGreen),
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
                  Builder(
                    builder: (context) {
                      final unifiedPrices = _getUnifiedActivityPrices(dest);
                      if (unifiedPrices.isEmpty) return const SizedBox.shrink();
                      
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: AppConstants.spaceXL),
                          Text('Activity Pricing', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          const SizedBox(height: AppConstants.spaceM),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: unifiedPrices.length,
                            separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spaceS),
                            itemBuilder: (context, index) {
                              final entry = unifiedPrices[index];
                              final key = entry.key;
                              final price = entry.value;
                              final isFree = price.toLowerCase().contains('free');
                              
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: AppConstants.spaceS + 2),
                                decoration: BoxDecoration(
                                  color: isDark ? Theme.of(context).cardColor : Colors.white,
                                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      isFree ? Icons.check_circle_outline_rounded : Icons.local_activity_rounded,
                                      color: isFree ? AppTheme.secondaryGreen : AppTheme.accentTeal,
                                      size: 18,
                                    ),
                                    const SizedBox(width: AppConstants.spaceM),
                                    Expanded(
                                      child: Text(
                                        key,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600, 
                                          fontSize: 13,
                                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: AppConstants.spaceM),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isFree
                                            ? AppTheme.secondaryGreen.withValues(alpha: 0.1)
                                            : AppTheme.accentTeal.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        price,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: isFree ? AppTheme.secondaryGreen : AppTheme.accentTeal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),

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
                            color: isDark ? Theme.of(context).cardColor : Colors.white,
                            borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
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
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.king_bed_rounded, color: AppTheme.primaryBlue, size: 22),
                              ),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 14, 
                                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Available for overnight stay', 
                                      style: TextStyle(
                                        fontSize: 11, 
                                        color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                      ),
                                    ),
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
                        children: dest.extra.mealInclusions.map((meal) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.restaurant_rounded, color: AppTheme.secondaryGreen, size: 16),
                                const SizedBox(width: AppConstants.spaceM),
                                Expanded(
                                  child: Text(
                                    meal, 
                                    style: TextStyle(
                                      fontSize: 13, 
                                      height: 1.4, 
                                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
                        children: dest.extra.travelNotes.map((note) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.lightbulb_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: AppConstants.spaceM),
                                Expanded(
                                  child: Text(
                                    note, 
                                    style: TextStyle(
                                      fontSize: 13, 
                                      height: 1.4, 
                                      color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
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
                      color: isDark ? Theme.of(context).cardColor : Colors.white,
                      borderRadius: BorderRadius.circular(AppConstants.radiusL),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.3)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
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
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                          child: Row(
                            children: [
                              Expanded(
                                child: _userPosition == null
                                    ? Text(
                                        'Visualize location & plan your route',
                                        style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
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
                      itemCount: dest.extra.transportOptions.length + (_userPosition != null ? 1 : 0),
                      separatorBuilder: (_, _) => const SizedBox(height: AppConstants.spaceS),
                      itemBuilder: (context, index) {
                        if (_userPosition != null && index == 0) {
                          final firstMile = _calculateFirstMile(_userPosition!);
                          final hub = firstMile['nearestHub'] as TransitHub;
                          final costText = firstMile['cost'] == 0.0 ? 'Free' : '₱${firstMile['cost'].toStringAsFixed(0)}';
                          final vehicle = firstMile['vehicle'] as String;
                          final distance = firstMile['distance'] as double;
                          final duration = firstMile['duration'] as String;

                          return Container(
                            padding: const EdgeInsets.all(AppConstants.spaceM),
                            decoration: BoxDecoration(
                              color: isDark ? Theme.of(context).cardColor : AppTheme.secondaryGreen.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(AppConstants.radiusL),
                              border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.3), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
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
                                    color: AppTheme.secondaryGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    vehicle.toLowerCase().contains('walking') 
                                        ? Icons.directions_walk_rounded 
                                        : vehicle.toLowerCase().contains('tricycle')
                                            ? Icons.motorcycle_rounded
                                            : Icons.directions_transit_rounded, 
                                    color: AppTheme.secondaryGreen, 
                                    size: 22
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              '📍 Doorstep to ${hub.city} Hub', 
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 13, 
                                                color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.secondaryGreen,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text('CUSTOM', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'Take $vehicle from your current location → ${hub.name} (${distance.toStringAsFixed(1)} km).',
                                        style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: AppConstants.spaceM),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      costText, 
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen, fontSize: 14)
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      duration, 
                                      style: TextStyle(fontSize: 10, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }

                        final actualIndex = _userPosition != null ? index - 1 : index;
                        final option = dest.extra.transportOptions[actualIndex];
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
                            color: isDark ? Theme.of(context).cardColor : Colors.white,
                            borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.withOpacity(0.3)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
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
                                  color: AppTheme.primaryBlue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(transportIcon, color: AppTheme.primaryBlue, size: 22),
                              ),
                              const SizedBox(width: AppConstants.spaceM),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle, 
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 13, 
                                        color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    if (from != null && to != null) ...[
                                      Row(
                                        children: [
                                          const Icon(Icons.navigation_rounded, size: 10, color: AppTheme.primaryBlue),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              '$from to $to',
                                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
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
                                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ] else ...[
                                      Text('Estimated average fare', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
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
                  if (!widget.isFromRecommendation) ...[
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
                        Navigator.of(context).pop();
                      },
                      variant: ButtonVariant.ghost,
                      width: double.infinity,
                      leadingWidget: const ImageIcon(AssetImage('assets/icons/ai_planner.png'), size: 18),
                    ),
                    const SizedBox(height: AppConstants.spaceXL),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddToTripBottomSheet(BuildContext context, Destination dest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
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
                        color: isDark ? Colors.grey[800] : Colors.grey.withOpacity(0.3),
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
                    style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                  ),
                  const SizedBox(height: AppConstants.spaceL),
                  
                  // Create New Trip Button
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.add_rounded, color: AppTheme.secondaryGreen, size: 24),
                    ),
                    title: Text(
                      'Create a New Trip',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                    ),
                    subtitle: Text('Start fresh with a brand new itinerary', style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight)),
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
                          style: TextStyle(fontSize: 13, color: isDark ? AppTheme.textSecondaryDark.withOpacity(0.8) : Colors.grey.withOpacity(0.8)),
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
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight),
                            ),
                            subtitle: Text(
                              '${trip.dateRange} • ${trip.itinerary.length} Days',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
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
                              ApiService().recordInteraction(dest.id, 'itinerary_add');
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              Text(
                'Where are you planning to go? Give your new adventure a sweet title!',
                style: TextStyle(fontSize: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight, height: 1.4),
              ),
              const SizedBox(height: AppConstants.spaceM),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Trip Name',
                  hintText: 'e.g. Davao Escapade 2026',
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

                final provider = context.read<TripProvider>();
                provider.addNewTrip(newTrip).then((success) {
                  if (mounted) {
                    Navigator.pop(dialogContext);
                    if (success) {
                      ApiService().recordInteraction(dest.id, 'itinerary_add');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('New Trip "$title" created and ${dest.name} added!'),
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
                });
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Text(
          label, 
          style: TextStyle(
            fontWeight: FontWeight.w600, 
            fontSize: 13, 
            color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
          ),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Color displayColor = color;
    if (color == const Color(0xFFFBBC04) || color == Colors.yellow || color == Colors.amber) {
      displayColor = isDark ? const Color(0xFFFBBC04) : Colors.amber[800]!;
    }
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppConstants.spaceM),
        decoration: BoxDecoration(
          color: displayColor.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppConstants.radiusL),
          border: Border.all(color: displayColor.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: displayColor, size: 22),
            const SizedBox(height: 5),
            Text(
              value, 
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: displayColor),
            ),
            Text(
              label, 
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10, 
                color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoSection(BuildContext ctx, String title, IconData icon, String content, Color color) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppConstants.spaceM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: color.withOpacity(0.2)),
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
                Text(
                  content, 
                  style: TextStyle(
                    fontSize: 13, 
                    color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight, 
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, IconData icon, bool isActive) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? Colors.grey[400]! : Colors.grey[700]!;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive ? AppTheme.secondaryGreen.withValues(alpha: 0.08) : inactiveColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
        border: Border.all(
          color: isActive ? AppTheme.secondaryGreen.withValues(alpha: 0.2) : inactiveColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isActive ? AppTheme.secondaryGreen : inactiveColor),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600,
            color: isActive ? AppTheme.secondaryGreen : inactiveColor,
          )),
        ],
      ),
    );
  }
}

