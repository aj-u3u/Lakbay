import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../models/destination.dart';
import '../../models/catalog_rate.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/trip_provider.dart';
import '../../providers/nav_provider.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../core/routes/app_routes.dart';

import '../../services/api_service.dart';

bool _isValidCoordinate(double lat, double lng) =>
    lat.isFinite && lng.isFinite && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;

class TransitHub {
  final String name;
  final LatLng coordinates;
  final String city;

  TransitHub({
    required this.name,
    required this.coordinates,
    required this.city,
  });
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
  State<DestinationDetailsScreen> createState() =>
      _DestinationDetailsScreenState();
}

class _DestinationDetailsScreenState extends State<DestinationDetailsScreen> {
  late Destination _destination;
  List<CatalogRate> _accommodations = [];
  List<CatalogRate> _transportations = [];
  bool _catalogLoading = true;
  String? _catalogError;
  bool _catalogOffline = false;
  int _catalogRequest = 0;
  Position? _userPosition;
  bool _loadingLocation = false;
  String? _locationError;
  final MapController _mapController = MapController();
  double? _distanceToDestination;
  List<LatLng> _roadGeometryPoints = [];
  Map<String, dynamic>? _trafficSummary;
  StreamSubscription<Position>? _positionStreamSubscription;
  List<Destination> _nearbyDestinations = [];
  bool _loadingNearby = false;
  late final Future<Map<String, dynamic>?> _weatherFuture;
  final GlobalKey _mapSectionKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _destination = widget.destination;
    _refreshCatalog();
    _weatherFuture = ApiService().fetchDestinationWeather(
      widget.destination.id,
    );
    // Record lightweight view interaction immediately to update popularity metrics
    ApiService().recordInteraction(widget.destination.id, 'view');
    _checkPermissionAndGetLocation();
    _fetchNearbyPlaces();
  }

  Future<void> _refreshCatalog() async {
    if (!widget.destination.isCatalogRecord) {
      setState(() => _catalogLoading = false);
      return;
    }
    final request = ++_catalogRequest;
    setState(() {
      _catalogLoading = true;
      _catalogError = null;
      _catalogOffline = false;
    });
    try {
      final api = ApiService();
      final destination = await api.fetchDestination(widget.destination.id);
      final rates = await Future.wait<List<CatalogRate>>([
        api.fetchAccommodationRates(destination.id),
        api.fetchTransportationRates(destination.id),
      ]);
      if (!mounted || request != _catalogRequest) return;
      setState(() {
        _destination = destination;
        _accommodations = rates[0];
        _transportations = rates[1];
        _catalogLoading = false;
      });
    } on CatalogException catch (error) {
      if (!mounted || request != _catalogRequest) return;
      setState(() {
        _accommodations = [];
        _transportations = [];
        _catalogError = error.message;
        _catalogOffline = error.isOffline;
        _catalogLoading = false;
      });
    } catch (_) {
      if (!mounted || request != _catalogRequest) return;
      setState(() {
        _accommodations = [];
        _transportations = [];
        _catalogError = 'Destination details could not be read.';
        _catalogLoading = false;
      });
    }
  }

  Future<void> _fetchNearbyPlaces() async {
    if (!mounted) return;
    setState(() {
      _loadingNearby = true;
    });
    try {
      final list = await ApiService().fetchNearbyDestinations(
        widget.destination.id,
        radiusKm: 15.0,
        limit: 6,
        sameCategory: true,
      );
      if (mounted) {
        setState(() {
          _nearbyDestinations = list;
          _loadingNearby = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingNearby = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  void _startLocationTracking() {
    _positionStreamSubscription?.cancel();
    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // Updates when user moves at least 10 meters
    );

    _positionStreamSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (Position position) {
            if (!mounted) return;

            setState(() {
              _userPosition = position;

              // Dynamically update straight-line distance if geometry isn't changing
              final dest = widget.destination;
              _distanceToDestination =
                  Geolocator.distanceBetween(
                    position.latitude,
                    position.longitude,
                    dest.latitude,
                    dest.longitude,
                  ) /
                  1000.0; // in km
            });
          },
          onError: (error) {
            debugPrint("Real-time location stream error: $error");
          },
        );
  }

  Future<void> _checkPermissionAndGetLocation() async {
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        _requestLocationAndRoute(fitMapCamera: false);
      }
    } catch (_) {}
  }

  double _getHubToDestCost(Destination dest, String city) {
    final options = dest.extra.transportOptions;
    if (options.isEmpty) return 0.0;
    for (final opt in options) {
      final from = (opt['from'] ?? '').toLowerCase();
      if (from.contains(city.toLowerCase()) ||
          city.toLowerCase().contains(from)) {
        final cleanText = (opt['price'] ?? '0').replaceAll(
          RegExp(r'[^\d]'),
          '',
        );
        return double.tryParse(cleanText) ?? 0.0;
      }
    }
    final cleanText = (options.first['price'] ?? '0').replaceAll(
      RegExp(r'[^\d]'),
      '',
    );
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

  Color _trafficColor(String level) {
    switch (level) {
      case 'severe':
        return Colors.redAccent;
      case 'heavy':
        return Colors.deepOrange;
      case 'moderate':
        return Colors.amber[700]!;
      default:
        return AppTheme.secondaryGreen;
    }
  }

  Widget _buildTrafficSummaryBanner(bool isDark) {
    final traffic = _trafficSummary;
    if (traffic == null) return const SizedBox.shrink();

    final level = traffic['traffic_level']?.toString() ?? 'unknown';
    final live = traffic['live_duration_minutes']?.toString() ?? '--';
    final delay = traffic['delay_minutes']?.toString() ?? '0';
    final advisory = traffic['advisory']?.toString() ?? '';
    final color = _trafficColor(level);

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.traffic_rounded, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live traffic: ${level.toUpperCase()} • ETA $live min • Delay $delay min',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.primaryBlue,
                  ),
                ),
                if (advisory.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    advisory,
                    style: GoogleFonts.outfit(
                      fontSize: 11,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
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
    if (lowerName.contains('hiking') ||
        lowerName.contains('trekking') ||
        lowerName.contains('walking') ||
        lowerName.contains('climbing')) {
      if (prices.containsKey('General Guide')) return prices['General Guide'];
    }
    if (lowerName.contains('diving') && prices.containsKey('Scuba Diving')) {
      return prices['Scuba Diving'];
    }
    if (lowerName.contains('spa') && prices.containsKey('Mandaya Spa')) {
      return prices['Mandaya Spa'];
    }
    if (lowerName.contains('snorkeling') &&
        prices.containsKey('Snorkeling Gear')) {
      return prices['Snorkeling Gear'];
    }
    if (lowerName.contains('surfing') &&
        prices.containsKey('Surfboard Rental')) {
      return prices['Surfboard Rental'];
    }
    if (lowerName.contains('skimboarding') &&
        prices.containsKey('Skimboard Rental')) {
      return prices['Skimboard Rental'];
    }
    if (lowerName.contains('camping') && prices.containsKey('Tent Pitching')) {
      return prices['Tent Pitching'];
    }

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
        if (lowerKey == lowerAct ||
            lowerKey.contains(lowerAct) ||
            lowerAct.contains(lowerKey)) {
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

  Future<void> _requestLocationAndRoute({bool fitMapCamera = true}) async {
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

      final destinationsList = <Map<String, dynamic>>[
        {
          "destination_id": dest.id,
          "name": dest.name,
          "lat": dest.latitude,
          "lng": dest.longitude,
        },
      ];

      List<LatLng> roadPoints = [];
      Map<String, dynamic>? trafficSummary;
      try {
        final response = !dest.isCatalogRecord
            ? null
            : await ApiService().optimizeRoute(
                destinations: destinationsList,
                startLat: position.latitude,
                startLng: position.longitude,
                startName: 'Your Location',
                returnToStart: false,
              );
        final trafficRaw = response?['traffic'];
        trafficSummary = trafficRaw is Map
            ? trafficRaw.cast<String, dynamic>()
            : null;

        if (response != null && response['geometry'] != null) {
          final geometry = response['geometry'];
          if (geometry['coordinates'] != null) {
            final List<dynamic> coords = geometry['coordinates'];
            roadPoints = coords.map((c) {
              final double lng = (c[0] as num).toDouble();
              final double lat = (c[1] as num).toDouble();
              return LatLng(lat, lng);
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching road route on details screen: $e');
        trafficSummary = null;
      }

      setState(() {
        _userPosition = position;
        _distanceToDestination = distance / 1000; // in km
        _roadGeometryPoints = roadPoints;
        _trafficSummary = trafficSummary;
        _loadingLocation = false;
      });

      if (fitMapCamera &&
          _isValidCoordinate(position.latitude, position.longitude) &&
          _isValidCoordinate(dest.latitude, dest.longitude)) {
        // Fit map bounds to show both user location and destination
        final bounds = LatLngBounds.fromPoints([
          LatLng(position.latitude, position.longitude),
          LatLng(dest.latitude, dest.longitude),
        ]);
        _mapController.fitCamera(
          CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(50)),
        );
      }

      // Start continuous location tracking
      _startLocationTracking();
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

  void _openPlannerFor(Destination destination) {
    if (!context.read<AuthProvider>().isAuthenticated) {
      Navigator.pushNamed(context, AppRoutes.signup);
      return;
    }

    context.read<TripProvider>().setActivePlanDestination(destination);
    context.read<NavProvider>().setIndex(1);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  void _addToTrip(Destination destination) {
    if (!context.read<AuthProvider>().isAuthenticated) {
      Navigator.pushNamed(context, AppRoutes.signup);
      return;
    }
    _showAddToTripBottomSheet(context, destination);
  }

  void _scrollToMap() {
    final mapContext = _mapSectionKey.currentContext;
    if (mapContext == null) return;
    Scrollable.ensureVisible(
      mapContext,
      duration: AppConstants.animDurationMedium,
      curve: Curves.easeInOut,
      alignment: 0.08,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_catalogLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_catalogError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Destination')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppConstants.spaceXL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _catalogOffline
                      ? Icons.wifi_off_rounded
                      : Icons.error_outline_rounded,
                  size: 42,
                ),
                const SizedBox(height: AppConstants.spaceM),
                Text(_catalogError!, textAlign: TextAlign.center),
                const SizedBox(height: AppConstants.spaceM),
                FilledButton.icon(
                  onPressed: _refreshCatalog,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    final dest = _destination;
    final accommodationTypes = dest.isCatalogRecord
        ? _accommodations
              .map(
                (rate) => {
                  'id': rate.id.toString(),
                  'type': '${rate.title} · ${rate.subtitle}',
                  'price': rate.priceWithUnit,
                },
              )
              .toList()
        : dest.extra.accommodationTypes;
    final transportOptions = dest.isCatalogRecord
        ? _transportations
              .map(
                (rate) => {
                  'id': rate.id.toString(),
                  'vehicle': rate.title,
                  'from': rate.routeFrom ?? '',
                  'to': rate.routeTo ?? '',
                  'price': rate.priceWithUnit,
                  'duration': rate.durationMinutes == null
                      ? ''
                      : '${rate.durationMinutes} min',
                },
              )
              .toList()
        : dest.extra.transportOptions;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    double? displayCost = dest.estimatedCost;
    String labelText = 'Estimated cost';

    if (_userPosition != null && !dest.isCatalogRecord) {
      final firstMile = _calculateFirstMile(_userPosition!);
      final hub = firstMile['nearestHub'] as TransitHub;
      final double firstCost = firstMile['cost'] as double;
      final double hubToDestCost = _getHubToDestCost(dest, hub.city);

      final cleanEntrance = dest.entranceFee.replaceAll(RegExp(r'[^\d]'), '');
      final double entranceFee = double.tryParse(cleanEntrance) ?? 0.0;

      final cleanEnv = dest.extra.environmentalFee.replaceAll(
        RegExp(r'[^\d]'),
        '',
      );
      final double environmentalFee = double.tryParse(cleanEnv) ?? 0.0;

      displayCost = firstCost + hubToDestCost + entranceFee + environmentalFee;
      labelText = 'Estimated cost from you';
    }

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _refreshCatalog,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 350,
              backgroundColor: AppTheme.primaryBlue,
              leading: IconButton(
                tooltip: 'Back to destinations',
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  onPressed: _refreshCatalog,
                  tooltip: 'Refresh destination and rates',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
                Consumer<TripProvider>(
                  builder: (context, tripProvider, _) {
                    final isSaved = tripProvider.isBookmarked(dest.id);
                    return TextButton.icon(
                      icon: PulseHeartIcon(isSaved: isSaved),
                      label: Text(isSaved ? 'Saved' : 'Save'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.black38,
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        if (!context.read<AuthProvider>().isAuthenticated) {
                          Navigator.pushNamed(context, AppRoutes.signup);
                          return;
                        }
                        final success = await tripProvider.toggleBookmark(
                          dest.id,
                        );
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).clearSnackBars();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? (isSaved
                                        ? 'Removed ${dest.name} from Wishlist'
                                        : 'Saved ${dest.name} to Wishlist! ❤️')
                                  : (tripProvider.errorMessage ??
                                        'Could not update your wishlist.'),
                            ),
                            duration: const Duration(seconds: 2),
                            backgroundColor: success
                                ? (isSaved
                                      ? Colors.grey[800]
                                      : AppTheme.secondaryGreen)
                                : Colors.redAccent,
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(width: AppConstants.spaceS),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Stack(
                  fit: StackFit.expand,
                  children: [
                    Destination.loadImage(
                      dest.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primaryBlue,
                              AppTheme.secondaryGreen,
                            ],
                          ),
                        ),
                        child: const Icon(
                          Icons.landscape,
                          size: 80,
                          color: Colors.white30,
                        ),
                      ),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.36),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.82),
                          ],
                          stops: const [0, 0.35, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: AppConstants.spaceL,
                      left: AppConstants.spaceL,
                      right: AppConstants.spaceL,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LAKBAY+ FIELD GUIDE  /  DAVAO REGION',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.3,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceS),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.secondaryGreen,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusCircular,
                              ),
                            ),
                            child: Text(
                              dest.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceS),
                          Text(
                            dest.name,
                            style: GoogleFonts.outfit(
                              fontSize: 29,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1.1,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: AppConstants.spaceS),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on_rounded,
                                color: AppTheme.secondaryGreen,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  dest.location,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
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

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.spaceL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTravelEssentials(
                      dest,
                      displayCost: displayCost,
                      costLabel: labelText,
                    ),
                    if (!widget.isFromRecommendation) ...[
                      const SizedBox(height: AppConstants.spaceM),
                      _buildLakbayPlanPrompt(dest),
                    ],
                    const SizedBox(height: AppConstants.spaceL),

                    _buildWeatherCard(),
                    const SizedBox(height: AppConstants.spaceXL),

                    // Description
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceS),
                    Text(
                      dest.description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: AppConstants.spaceXL),

                    // Operating hours
                    _infoSection(
                      context,
                      'Operating Hours',
                      Icons.access_time_rounded,
                      dest.operatingHours,
                      AppTheme.accentTeal,
                    ),
                    const SizedBox(height: AppConstants.spaceL),

                    // Activities
                    Text(
                      'Activities',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Wrap(
                      spacing: AppConstants.spaceS,
                      runSpacing: AppConstants.spaceS,
                      children: dest.activities.map((a) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusCircular,
                            ),
                            border: Border.all(
                              color: AppTheme.primaryBlue.withValues(
                                alpha: 0.2,
                              ),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 13,
                                color: AppTheme.secondaryGreen,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                a,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.primaryBlue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppConstants.spaceXL),

                    // Accessibility badges
                    Text(
                      'Traveler Info',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Wrap(
                      spacing: AppConstants.spaceS,
                      runSpacing: AppConstants.spaceS,
                      children: [
                        _badge(
                          'Kid-Friendly',
                          Icons.child_care_rounded,
                          dest.isKidFriendly,
                        ),
                        _badge(
                          'Wheelchair Access',
                          Icons.accessible_rounded,
                          dest.isWheelchairAccessible,
                        ),
                        _badge(
                          'Pet-Friendly',
                          Icons.pets_rounded,
                          dest.isPetFriendly,
                        ),
                        _badge(
                          'Senior-Friendly',
                          Icons.elderly_rounded,
                          dest.isElderlyFriendly,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppConstants.spaceXL),

                    // Fees & Rates
                    Text(
                      'Fees & Rates',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Container(
                      padding: const EdgeInsets.all(AppConstants.spaceM),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusL,
                        ),
                        border: Border.all(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Column(
                        children: [
                          _feeRow(
                            Icons.confirmation_num_rounded,
                            'Entrance Fee',
                            dest.entranceFee,
                          ),
                          const Divider(
                            height: 20,
                            thickness: 1,
                            color: Colors.black12,
                          ),
                          _feeRow(
                            Icons.eco_rounded,
                            'Environmental Fee',
                            dest.extra.environmentalFee,
                          ),
                          const Divider(
                            height: 20,
                            thickness: 1,
                            color: Colors.black12,
                          ),
                          _feeRow(
                            Icons.hotel_rounded,
                            'Overnight Fee',
                            dest.extra.overnightFee,
                          ),
                        ],
                      ),
                    ),

                    // Activity Pricing
                    Builder(
                      builder: (context) {
                        final unifiedPrices = _getUnifiedActivityPrices(dest);
                        if (unifiedPrices.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: AppConstants.spaceXL),
                            Text(
                              'Activity Pricing',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryBlue,
                                  ),
                            ),
                            const SizedBox(height: AppConstants.spaceM),
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: unifiedPrices.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(height: AppConstants.spaceS),
                              itemBuilder: (context, index) {
                                final entry = unifiedPrices[index];
                                final key = entry.key;
                                final price = entry.value;
                                final isFree = price.toLowerCase().contains(
                                  'free',
                                );

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppConstants.spaceM,
                                    vertical: AppConstants.spaceS + 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Theme.of(context).cardColor
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(
                                      AppConstants.radiusM,
                                    ),
                                    border: Border.all(
                                      color: isDark
                                          ? Colors.white10
                                          : Colors.grey.withValues(alpha: 0.3),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isFree
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.local_activity_rounded,
                                        color: isFree
                                            ? AppTheme.secondaryGreen
                                            : AppTheme.accentTeal,
                                        size: 18,
                                      ),
                                      const SizedBox(
                                        width: AppConstants.spaceM,
                                      ),
                                      Expanded(
                                        child: Text(
                                          key,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 13,
                                            color: isDark
                                                ? AppTheme.textPrimaryDark
                                                : AppTheme.textPrimaryLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(
                                        width: AppConstants.spaceM,
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isFree
                                              ? AppTheme.secondaryGreen
                                                    .withValues(alpha: 0.1)
                                              : AppTheme.accentTeal.withValues(
                                                  alpha: 0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          price,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            color: isFree
                                                ? AppTheme.secondaryGreen
                                                : AppTheme.accentTeal,
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
                    if (accommodationTypes.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Accommodation Options',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: accommodationTypes.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppConstants.spaceS),
                        itemBuilder: (context, index) {
                          final acc = accommodationTypes[index];
                          final type = acc['type'] ?? 'Standard Room';
                          final price = acc['price'] ?? 'Contact for rates';
                          return Container(
                            padding: const EdgeInsets.all(AppConstants.spaceM),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Theme.of(context).cardColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusL,
                              ),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white12
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.king_bed_rounded,
                                        color: AppTheme.primaryBlue,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: AppConstants.spaceM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            type,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                              color: isDark
                                                  ? AppTheme.textPrimaryDark
                                                  : AppTheme.textPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Rate ID ${acc['id']} · Available for overnight stay',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark
                                                  ? AppTheme.textSecondaryDark
                                                  : AppTheme.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppConstants.spaceS),
                                Text(
                                  price,
                                  textAlign: TextAlign.end,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.secondaryGreen,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],

                    // Meal Inclusions
                    if (dest.extra.mealInclusions.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Meal Inclusions',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceM),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryGreen.withValues(
                            alpha: 0.08,
                          ),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusL,
                          ),
                          border: Border.all(
                            color: AppTheme.secondaryGreen.withValues(
                              alpha: 0.2,
                            ),
                          ),
                        ),
                        child: Column(
                          children: dest.extra.mealInclusions.map((meal) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.restaurant_rounded,
                                    color: AppTheme.secondaryGreen,
                                    size: 16,
                                  ),
                                  const SizedBox(width: AppConstants.spaceM),
                                  Expanded(
                                    child: Text(
                                      meal,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark
                                            ? AppTheme.textPrimaryDark
                                            : AppTheme.textPrimaryLight,
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
                      Text(
                        'Travel Notes & Tips',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceM),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusL,
                          ),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          children: dest.extra.travelNotes.map((note) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4.0,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.lightbulb_rounded,
                                    color: Colors.amber,
                                    size: 16,
                                  ),
                                  const SizedBox(width: AppConstants.spaceM),
                                  Expanded(
                                    child: Text(
                                      note,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.4,
                                        color: isDark
                                            ? AppTheme.textPrimaryDark
                                            : AppTheme.textPrimaryLight,
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
                    Text(
                      'Location & Route',
                      key: _mapSectionKey,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const SizedBox(height: AppConstants.spaceM),
                    Container(
                      height: 280,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Theme.of(context).cardColor
                            : Colors.white,
                        borderRadius: BorderRadius.circular(
                          AppConstants.radiusL,
                        ),
                        border: Border.all(
                          color: isDark
                              ? Colors.white10
                              : Colors.grey.withValues(alpha: 0.3),
                        ),
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
                                    initialCenter: LatLng(
                                      dest.latitude,
                                      dest.longitude,
                                    ),
                                    initialZoom: 16.5,
                                  ),
                                  children: [
                                    TileLayer(
                                      urlTemplate:
                                          AppConstants
                                                  .mapboxAccessToken
                                                  .isEmpty ||
                                              AppConstants.mapboxAccessToken ==
                                                  'YOUR_MAPBOX_ACCESS_TOKEN'
                                          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                                          : 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=${AppConstants.mapboxAccessToken}',
                                      userAgentPackageName: 'com.lakbay.plus',
                                    ),
                                    if (_userPosition != null &&
                                        _roadGeometryPoints.length >= 2)
                                      PolylineLayer(
                                        polylines: [
                                          Polyline(
                                            points: _roadGeometryPoints,
                                            color: AppTheme.primaryBlue,
                                            strokeWidth: 4,
                                          ),
                                        ],
                                      ),
                                    MarkerLayer(
                                      markers: [
                                        // Destination Marker
                                        Marker(
                                          point: LatLng(
                                            dest.latitude,
                                            dest.longitude,
                                          ),
                                          width: 40,
                                          height: 40,
                                          child: const Icon(
                                            Icons.location_on_rounded,
                                            color: Colors.redAccent,
                                            size: 40,
                                          ),
                                        ),
                                        if (dest.routeReady &&
                                            dest.arrivalLatitude != null &&
                                            dest.arrivalLongitude != null)
                                          Marker(
                                            point: LatLng(
                                              dest.arrivalLatitude!,
                                              dest.arrivalLongitude!,
                                            ),
                                            width: 38,
                                            height: 38,
                                            child: const Tooltip(
                                              message:
                                                  'Reviewed visitor arrival point',
                                              child: Icon(
                                                Icons.directions_rounded,
                                                color: AppTheme.primaryBlue,
                                                size: 34,
                                              ),
                                            ),
                                          ),
                                        // Nearby Place Markers
                                        ..._nearbyDestinations.map((nearby) {
                                          return Marker(
                                            point: LatLng(
                                              nearby.latitude,
                                              nearby.longitude,
                                            ),
                                            width: 36,
                                            height: 36,
                                            child: GestureDetector(
                                              onTap: () {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) =>
                                                        DestinationDetailsScreen(
                                                          destination: nearby,
                                                        ),
                                                  ),
                                                );
                                              },
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color:
                                                      AppTheme.secondaryGreen,
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: Colors.white,
                                                    width: 2,
                                                  ),
                                                  boxShadow: const [
                                                    BoxShadow(
                                                      color: Colors.black26,
                                                      blurRadius: 4,
                                                      offset: Offset(0, 2),
                                                    ),
                                                  ],
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.place_rounded,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        }),
                                        // User Location Marker
                                        if (_userPosition != null)
                                          Marker(
                                            point: LatLng(
                                              _userPosition!.latitude,
                                              _userPosition!.longitude,
                                            ),
                                            width: 40,
                                            height: 40,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: AppTheme.primaryBlue
                                                    .withValues(alpha: 0.2),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
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
                                    tooltip: 'Center map on this destination',
                                    onPressed: () {
                                      if (_userPosition != null &&
                                          _isValidCoordinate(_userPosition!.latitude, _userPosition!.longitude) &&
                                          _isValidCoordinate(dest.latitude, dest.longitude)) {
                                        final bounds = LatLngBounds.fromPoints([
                                          LatLng(
                                            _userPosition!.latitude,
                                            _userPosition!.longitude,
                                          ),
                                          LatLng(dest.latitude, dest.longitude),
                                        ]);
                                        _mapController.fitCamera(
                                          CameraFit.bounds(
                                            bounds: bounds,
                                            padding: const EdgeInsets.all(40),
                                          ),
                                        );
                                      } else {
                                        _mapController.move(
                                          LatLng(dest.latitude, dest.longitude),
                                          13.0,
                                        );
                                      }
                                    },
                                    backgroundColor: Colors.white,
                                    child: const Icon(
                                      Icons.gps_fixed_rounded,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Location Info Bar / Call-to-action
                          Container(
                            padding: const EdgeInsets.all(AppConstants.spaceM),
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.grey.withValues(alpha: 0.1),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _userPosition == null
                                      ? Text(
                                          dest.routeReady
                                              ? 'Blue pin: visitor arrival • Red pin: attraction'
                                              : 'Attraction pin shown. Confirm arrival before travel.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? AppTheme.textSecondaryDark
                                                : AppTheme.textSecondaryLight,
                                          ),
                                        )
                                      : Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dest.routeReady
                                                  ? 'Route preview to visitor arrival'
                                                  : 'Route preview to attraction',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.primaryBlue,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Distance: ${_distanceToDestination!.toStringAsFixed(1)} km away',
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                                color: AppTheme.secondaryGreen,
                                              ),
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
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppTheme.primaryBlue,
                                              ),
                                        ),
                                      )
                                    : TextButton.icon(
                                        onPressed: () =>
                                            _requestLocationAndRoute(
                                              fitMapCamera: true,
                                            ),
                                        icon: Icon(
                                          _userPosition == null
                                              ? Icons.directions_rounded
                                              : Icons.refresh_rounded,
                                          size: 16,
                                          color: AppTheme.primaryBlue,
                                        ),
                                        label: Text(
                                          _userPosition == null
                                              ? 'Get directions'
                                              : 'Recalculate',
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryBlue,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                          if (_trafficSummary != null)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: _buildTrafficSummaryBanner(isDark),
                            ),
                        ],
                      ),
                    ),

                    // Transportation
                    if (transportOptions.isNotEmpty) ...[
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Transportation & Fare',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount:
                            transportOptions.length +
                            (_userPosition != null && !dest.isCatalogRecord
                                ? 1
                                : 0),
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppConstants.spaceS),
                        itemBuilder: (context, index) {
                          if (_userPosition != null &&
                              !dest.isCatalogRecord &&
                              index == 0) {
                            final firstMile = _calculateFirstMile(
                              _userPosition!,
                            );
                            final hub = firstMile['nearestHub'] as TransitHub;
                            final costText = firstMile['cost'] == 0.0
                                ? 'Free'
                                : '₱${firstMile['cost'].toStringAsFixed(0)}';
                            final vehicle = firstMile['vehicle'] as String;
                            final distance = firstMile['distance'] as double;
                            final duration = firstMile['duration'] as String;

                            return Container(
                              padding: const EdgeInsets.all(
                                AppConstants.spaceM,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Theme.of(context).cardColor
                                    : AppTheme.secondaryGreen.withValues(
                                        alpha: 0.06,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusL,
                                ),
                                border: Border.all(
                                  color: AppTheme.secondaryGreen.withValues(
                                    alpha: 0.3,
                                  ),
                                  width: 1.5,
                                ),
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
                                      color: AppTheme.secondaryGreen.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      vehicle.toLowerCase().contains('walking')
                                          ? Icons.directions_walk_rounded
                                          : vehicle.toLowerCase().contains(
                                              'tricycle',
                                            )
                                          ? Icons.motorcycle_rounded
                                          : Icons.directions_transit_rounded,
                                      color: AppTheme.secondaryGreen,
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(width: AppConstants.spaceM),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
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
                                                  color: isDark
                                                      ? AppTheme.textPrimaryDark
                                                      : AppTheme
                                                            .textPrimaryLight,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 5,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppTheme.secondaryGreen,
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: const Text(
                                                'CUSTOM',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 8,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Take $vehicle from your current location → ${hub.name} (${distance.toStringAsFixed(1)} km).',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? AppTheme.textSecondaryDark
                                                : AppTheme.textSecondaryLight,
                                          ),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.secondaryGreen,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        duration,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: isDark
                                              ? AppTheme.textSecondaryDark
                                              : AppTheme.textSecondaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }

                          final actualIndex =
                              _userPosition != null && !dest.isCatalogRecord
                              ? index - 1
                              : index;
                          final option = transportOptions[actualIndex];
                          final vehicle =
                              option['vehicle'] ?? 'Standard Transit';
                          final price = option['price'] ?? 'Varies';
                          final from = option['from'];
                          final to = option['to'];
                          final duration = option['duration'];

                          // Decide which icon to show based on keywords
                          IconData transportIcon = Icons.directions_bus_rounded;
                          if (vehicle.toLowerCase().contains('taxi') ||
                              vehicle.toLowerCase().contains('grab')) {
                            transportIcon = Icons.local_taxi_rounded;
                          } else if (vehicle.toLowerCase().contains('ferry') ||
                              vehicle.toLowerCase().contains('boat') ||
                              vehicle.toLowerCase().contains('speedboat')) {
                            transportIcon = Icons.directions_boat_rounded;
                          } else if (vehicle.toLowerCase().contains(
                                'jeepney',
                              ) ||
                              vehicle.toLowerCase().contains('van')) {
                            transportIcon = Icons.directions_transit_rounded;
                          } else if (vehicle.toLowerCase().contains(
                                'tricycle',
                              ) ||
                              vehicle.toLowerCase().contains('habal') ||
                              vehicle.toLowerCase().contains('motorcycle')) {
                            transportIcon = Icons.motorcycle_rounded;
                          }

                          return Container(
                            padding: const EdgeInsets.all(AppConstants.spaceM),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Theme.of(context).cardColor
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(
                                AppConstants.radiusL,
                              ),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white10
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.primaryBlue.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        transportIcon,
                                        color: AppTheme.primaryBlue,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: AppConstants.spaceM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            vehicle,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: isDark
                                                  ? AppTheme.textPrimaryDark
                                                  : AppTheme.textPrimaryLight,
                                            ),
                                          ),
                                          if (dest.isCatalogRecord)
                                            Text(
                                              'Rate ID ${option['id']}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark
                                                    ? AppTheme.textSecondaryDark
                                                    : AppTheme
                                                          .textSecondaryLight,
                                              ),
                                            ),
                                          const SizedBox(height: 3),
                                          if (from != null && to != null) ...[
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.navigation_rounded,
                                                  size: 10,
                                                  color: AppTheme.primaryBlue,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    '$from to $to',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: isDark
                                                          ? AppTheme
                                                                .textSecondaryDark
                                                          : AppTheme
                                                                .textSecondaryLight,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                          ],
                                          if (duration != null &&
                                              duration.isNotEmpty) ...[
                                            Row(
                                              children: [
                                                const Icon(
                                                  Icons.timer_outlined,
                                                  size: 10,
                                                  color: AppTheme.accentTeal,
                                                ),
                                                const SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    'Duration: $duration',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: isDark
                                                          ? AppTheme
                                                                .textSecondaryDark
                                                          : AppTheme
                                                                .textSecondaryLight,
                                                    ),
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppConstants.spaceS),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.secondaryGreen.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      price,
                                      textAlign: TextAlign.end,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                        color: AppTheme.secondaryGreen,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      _buildNearbyCarousel(),
                    ],
                    const SizedBox(height: AppConstants.spaceXL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: EdgeInsets.only(
          left: AppConstants.spaceL,
          right: AppConstants.spaceL,
          top: AppConstants.spaceM,
          bottom: AppConstants.spaceM + MediaQuery.of(context).padding.bottom,
        ),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -4),
            ),
          ],
          border: Border(
            top: BorderSide(
              color: isDark
                  ? Colors.white10
                  : Colors.grey.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        child: CustomButton(
          label: context.watch<AuthProvider>().isAuthenticated
              ? 'Add to My Trip'
              : 'Sign Up to Save',
          onPressed: () => _addToTrip(dest),
          variant: ButtonVariant.secondary, // Coral background color
          width: double.infinity,
        ),
      ),
    );
  }

  void _showAddToTripBottomSheet(BuildContext pageContext, Destination dest) {
    final isDark = Theme.of(pageContext).brightness == Brightness.dark;
    showModalBottomSheet(
      context: pageContext,
      backgroundColor: Theme.of(pageContext).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Consumer<TripProvider>(
          builder: (_, provider, _) {
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
                        color: isDark
                            ? Colors.grey[800]
                            : Colors.grey.withValues(alpha: 0.3),
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
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                    ),
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
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppTheme.secondaryGreen,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      'Create a New Trip',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.textPrimaryLight,
                      ),
                    ),
                    subtitle: Text(
                      'Start fresh with a brand new itinerary',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.grey,
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _showCreateTripDialog(pageContext, dest);
                    },
                  ),
                  const Divider(height: 24, thickness: 1),

                  if (trips.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppConstants.spaceXL,
                      ),
                      child: Center(
                        child: Text(
                          'No upcoming trips yet.\nCreate one to get started!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? AppTheme.textSecondaryDark.withValues(
                                    alpha: 0.8,
                                  )
                                : Colors.grey.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: trips.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppConstants.spaceS),
                        itemBuilder: (context, index) {
                          final trip = trips[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 50,
                                height: 50,
                                child: Destination.loadImage(
                                  trip.imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppTheme.primaryBlue,
                                          AppTheme.secondaryGreen,
                                        ],
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: isDark
                                    ? AppTheme.textPrimaryDark
                                    : AppTheme.textPrimaryLight,
                              ),
                            ),
                            subtitle: Text(
                              '${trip.dateRange} • ${trip.itinerary.length} Days',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.chevron_right_rounded,
                              color: Colors.grey,
                            ),
                            onTap: () {
                              final newActivity = TripActivity(
                                time: '10:00 AM',
                                title: 'Visit ${dest.name}',
                                description:
                                    'Explore and experience the beauty of ${dest.name}.'
                                    '${dest.activities.isNotEmpty ? ' Suggested activities: ${dest.activities.join(", ")}.' : ''}',
                                cost: dest.entranceFee,
                                location: dest.location,
                              );

                              provider.addActivityToTrip(trip.id, newActivity);
                              ApiService().recordInteraction(
                                dest.id,
                                'itinerary_add',
                              );
                              Navigator.pop(sheetContext);

                              ScaffoldMessenger.of(pageContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '${dest.name} added to "${trip.title}"!',
                                  ),
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
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Where are you planning to go? Give your new adventure a sweet title!',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.textSecondaryDark
                      : AppTheme.textSecondaryLight,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppConstants.spaceM),
              TextField(
                controller: nameController,
                autofocus: true,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.textPrimaryDark
                      : AppTheme.textPrimaryLight,
                ),
                decoration: InputDecoration(
                  labelText: 'Trip Name',
                  hintText: 'e.g. Davao Escapade 2026',
                  labelStyle: const TextStyle(color: AppTheme.primaryBlue),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.3),
                    ),
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
                  budget: dest.estimatedCost ?? 0.0,
                  notes: dest.estimatedCost == null
                      ? 'Destination cost is not listed. Set a trip budget after confirming rates.'
                      : '',
                  imageUrl: dest.imageUrl,
                  itinerary: {
                    1: [
                      TripActivity(
                        time: '10:00 AM',
                        title: 'Visit ${dest.name}',
                        description:
                            'First stop of our adventure at ${dest.name}!'
                            '${dest.activities.isNotEmpty ? ' Suggested activities: ${dest.activities.join(", ")}.' : ''}',
                        cost: dest.entranceFee,
                        location: dest.location,
                      ),
                    ],
                  },
                );

                final provider = context.read<TripProvider>();
                provider.addNewTrip(newTrip).then((success) {
                  if (mounted && context.mounted && dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                    if (success) {
                      ApiService().recordInteraction(dest.id, 'itinerary_add');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'New Trip "$title" created and ${dest.name} added!',
                          ),
                          backgroundColor: AppTheme.secondaryGreen,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            provider.errorMessage ??
                                'Failed to save trip. Please try again.',
                          ),
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
            color: AppTheme.primaryBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryBlue, size: 18),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: isDark
                  ? AppTheme.textPrimaryDark
                  : AppTheme.textPrimaryLight,
            ),
          ),
        ),
        const SizedBox(width: AppConstants.spaceM),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppTheme.secondaryGreen,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTravelEssentials(
    Destination destination, {
    required double? displayCost,
    required String costLabel,
  }) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
        border: Border.all(color: theme.dividerColor),
        boxShadow: AppConstants.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GOOD TO KNOW BEFORE YOU GO',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.primaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          _essentialLine(
            Icons.star_rounded,
            'Traveler rating',
            destination.rating > 0
                ? '${destination.rating.toStringAsFixed(1)} out of 5'
                : 'Not rated yet',
          ),
          Divider(color: theme.dividerColor),
          _essentialLine(
            Icons.payments_outlined,
            costLabel,
            displayCost == null
                ? 'Cost not listed'
                : '₱${displayCost.toStringAsFixed(0)}',
          ),
          Divider(color: theme.dividerColor),
          _essentialLine(
            Icons.confirmation_number_outlined,
            'Entrance fee',
            destination.entranceFee.trim().isEmpty
                ? 'Check before visiting'
                : destination.entranceFee,
          ),
          const SizedBox(height: AppConstants.spaceS),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _scrollToMap,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('See map & directions'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceS,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _essentialLine(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.secondaryGreen, size: 20),
          const SizedBox(width: AppConstants.spaceS),
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          const SizedBox(width: AppConstants.spaceS),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLakbayPlanPrompt(Destination destination) {
    final isAuthenticated = context.watch<AuthProvider>().isAuthenticated;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppConstants.radiusL),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.route_rounded,
                color: Color(0xFFFFD2B0),
                size: 20,
              ),
              const SizedBox(width: AppConstants.spaceS),
              Expanded(
                child: Text(
                  'LAKBAY+ TRIP STARTER',
                  style: const TextStyle(
                    color: Color(0xFFFFD2B0),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          const Text(
            'One stop. A whole journey.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            isAuthenticated
                ? 'Start an AI itinerary with ${destination.name} already selected.'
                : 'Create an account to plan around ${destination.name}, save places, and travel together.',
            style: const TextStyle(color: Colors.white, height: 1.45),
          ),
          const SizedBox(height: AppConstants.spaceM),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _openPlannerFor(destination),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(
                isAuthenticated ? 'Plan this place' : 'Sign Up to Plan',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white70),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                  vertical: AppConstants.spaceM,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _weatherFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusL),
              border: Border.all(
                color: AppTheme.accentTeal.withValues(alpha: 0.2),
              ),
            ),
            child: const LinearProgressIndicator(minHeight: 2),
          );
        }

        final weather = snapshot.data;
        if (weather == null) return const SizedBox.shrink();

        final current = weather['current'] is Map
            ? (weather['current'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final condition = current['condition'] is Map
            ? (current['condition'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final days = weather['days'] is List
            ? weather['days'] as List
            : const [];
        final temp = _weatherNumber(current['temp_c']);
        final feelsLike = _weatherNumber(current['feels_like_c']);
        final rainChance = days.isNotEmpty && days.first is Map
            ? _weatherInt((days.first as Map)['rain_chance_percent'])
            : null;
        final main = condition['main']?.toString() ?? 'Weather';
        final description = condition['description']?.toString() ?? main;

        return Container(
          padding: const EdgeInsets.all(AppConstants.spaceM),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusL),
            border: Border.all(
              color: AppTheme.accentTeal.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    _weatherIcon(main),
                    color: AppTheme.accentTeal,
                    size: 24,
                  ),
                  const SizedBox(width: AppConstants.spaceM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weather',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppTheme.textPrimaryDark
                                : AppTheme.primaryBlue,
                          ),
                        ),
                        Text(
                          description,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.textSecondaryDark
                                : AppTheme.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (temp != null)
                    Text(
                      '${temp.toStringAsFixed(0)} C',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                        color: AppTheme.accentTeal,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceM),
              Row(
                children: [
                  Expanded(
                    child: _weatherMetric(
                      'Feels',
                      feelsLike == null
                          ? '--'
                          : '${feelsLike.toStringAsFixed(0)} C',
                    ),
                  ),
                  Expanded(
                    child: _weatherMetric(
                      'Rain',
                      rainChance == null ? '--' : '$rainChance%',
                    ),
                  ),
                  Expanded(
                    child: _weatherMetric(
                      'Wind',
                      current['wind_speed_mps'] == null
                          ? '--'
                          : '${_weatherNumber(current['wind_speed_mps'])?.toStringAsFixed(1)} m/s',
                    ),
                  ),
                ],
              ),
              if ((current['advisory'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: AppConstants.spaceM),
                Text(
                  current['advisory'].toString(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _weatherMetric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  IconData _weatherIcon(String condition) {
    final lower = condition.toLowerCase();
    if (lower.contains('thunder')) return Icons.thunderstorm_rounded;
    if (lower.contains('rain') || lower.contains('drizzle')) {
      return Icons.umbrella_rounded;
    }
    if (lower.contains('cloud')) return Icons.cloud_rounded;
    if (lower.contains('clear')) return Icons.wb_sunny_rounded;
    if (lower.contains('wind')) return Icons.air_rounded;
    return Icons.thermostat_rounded;
  }

  double? _weatherNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int? _weatherInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.round();
    if (value is String) return int.tryParse(value);
    return null;
  }

  Widget _infoSection(
    BuildContext ctx,
    String title,
    IconData icon,
    String content,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.secondaryGreen.withValues(alpha: 0.08)
            : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
        border: Border.all(
          color: isActive
              ? AppTheme.secondaryGreen.withValues(alpha: 0.2)
              : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isActive ? AppTheme.secondaryGreen : Colors.grey,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isActive ? AppTheme.secondaryGreen : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNearbyCarousel() {
    if (_loadingNearby) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppConstants.spaceM),
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
          ),
        ),
      );
    }

    if (_nearbyDestinations.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppConstants.spaceXXL),
        Text(
          'Other Places Nearby',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: AppConstants.spaceM),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _nearbyDestinations.length,
            itemBuilder: (context, index) {
              final nearby = _nearbyDestinations[index];
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DestinationDetailsScreen(destination: nearby),
                    ),
                  );
                },
                child: Container(
                  width: 170,
                  margin: const EdgeInsets.only(
                    right: AppConstants.spaceM,
                    bottom: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? Theme.of(context).cardColor : Colors.white,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(
                      color: isDark
                          ? Colors.white10
                          : Colors.grey.withValues(alpha: 0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Destination.loadImage(
                              nearby.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: AppTheme.primaryBlue.withValues(
                                  alpha: 0.1,
                                ),
                                child: const Icon(
                                  Icons.landscape_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 32,
                                ),
                              ),
                            ),
                            // Rating Badge
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.star,
                                      color: Color(0xFFFBBC04),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      '${nearby.rating}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
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
                      // Details
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nearby.name,
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isDark
                                    ? AppTheme.textPrimaryDark
                                    : AppTheme.textPrimaryLight,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 10,
                                  color: AppTheme.primaryBlue,
                                ),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    nearby.district,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isDark
                                          ? AppTheme.textSecondaryDark
                                          : AppTheme.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              nearby.estimatedCost == null
                                  ? 'Cost not listed'
                                  : '₱${nearby.estimatedCost!.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: AppTheme.secondaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class PulseHeartIcon extends StatefulWidget {
  final bool isSaved;

  const PulseHeartIcon({super.key, required this.isSaved});

  @override
  State<PulseHeartIcon> createState() => _PulseHeartIconState();
}

class _PulseHeartIconState extends State<PulseHeartIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.2), weight: 50),
      TweenSequenceItem(tween: Tween<double>(begin: 1.2, end: 1.0), weight: 50),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(covariant PulseHeartIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isSaved != oldWidget.isSaved) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.black26,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          widget.isSaved
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          color: widget.isSaved ? Colors.redAccent : Colors.white,
          size: 18,
        ),
      ),
    );
  }
}
