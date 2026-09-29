import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../models/trip.dart';
import '../../models/destination.dart';
import '../../services/api_service.dart';
import '../../providers/trip_provider.dart';

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

class GroupDashboardScreen extends StatefulWidget {
  final Trip? trip;
  const GroupDashboardScreen({super.key, this.trip});

  @override
  State<GroupDashboardScreen> createState() => _GroupDashboardScreenState();
}

class _GroupDashboardScreenState extends State<GroupDashboardScreen> {
  // Named constants for budget thresholds (PHP)
  static const double kLowBudgetMax = 5000.0;
  static const double kBalancedBudgetMax = 15000.0;
  final ApiService _apiService = ApiService();

  // Members List State
  late List<Map<String, String>> _members;

  // Contributions Tracker State — seeded from members in initState
  late List<Map<String, dynamic>> _contributions;

  // Notes Editing State
  bool _isEditingNotes = false;
  late TextEditingController _notesController;

  // Real logged expenses state
  late List<Map<String, dynamic>> _loggedExpenses;
  bool _isLoadingBackendCollaboration = false;
  final Map<int, Future<Map<String, dynamic>?>> _weatherFutures = {};

  // Route & Location State
  Position? _userPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController _mapController = MapController();
  String _commuterStartPoint = 'Current Location';
  List<LatLng> _roadGeometryPoints = [];
  Map<String, dynamic>? _trafficSummary;
  bool _isLoadingRoute = false;
  LatLng? _lastStartLoc;
  int? _lastDestId;

  Future<void> _fetchRoadRoute(LatLng startLocation, Destination dest) async {
    if (_lastStartLoc == startLocation && _lastDestId == dest.id) {
      return;
    }
    _lastStartLoc = startLocation;
    _lastDestId = dest.id;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isLoadingRoute = true;
        });
      }
    });

    try {
      final isSamal =
          dest.name.toLowerCase().contains('samal') ||
          dest.location.toLowerCase().contains('samal') ||
          widget.trip?.destinationName.toLowerCase().contains('samal') == true;

      List<Map<String, dynamic>> destinationsList = [];
      if (isSamal) {
        destinationsList.add({
          "destination_id": -1,
          "name": "Sasa Wharf",
          "lat": 7.1017,
          "lng": 125.6601,
        });
        destinationsList.add({
          "destination_id": -2,
          "name": "Babak Port",
          "lat": 7.1189,
          "lng": 125.6822,
        });
      }
      destinationsList.add({
        "destination_id": dest.id,
        "name": dest.name,
        "lat": dest.latitude,
        "lng": dest.longitude,
      });

      final response = await ApiService().optimizeRoute(
        destinations: destinationsList,
        startLat: startLocation.latitude,
        startLng: startLocation.longitude,
        startName: 'Start Point',
        returnToStart: false,
      );
      final trafficRaw = response?['traffic'];
      final trafficSummary = trafficRaw is Map
          ? trafficRaw.cast<String, dynamic>()
          : null;

      if (response != null && response['geometry'] != null) {
        final geometry = response['geometry'];
        if (geometry['coordinates'] != null) {
          final List<dynamic> coords = geometry['coordinates'];
          final List<LatLng> points = coords.map((c) {
            final double lng = (c[0] as num).toDouble();
            final double lat = (c[1] as num).toDouble();
            return LatLng(lat, lng);
          }).toList();

          if (mounted) {
            setState(() {
              _roadGeometryPoints = points;
              _trafficSummary = trafficSummary;
              _isLoadingRoute = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Error fetching road route: $e');
    }

    if (mounted) {
      setState(() {
        _roadGeometryPoints = [];
        _trafficSummary = null;
        _isLoadingRoute = false;
      });
    }
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

  @override
  void initState() {
    super.initState();
    _requestLocation();
    final trip = widget.trip;
    if (trip != null && trip.members.isNotEmpty) {
      // Real members from saved trip data
      _members = List<Map<String, String>>.from(
        trip.members.map((m) => Map<String, String>.from(m)),
      );
    } else if (trip != null && trip.isGroup) {
      // Seed placeholder slots from numTravelers
      _members = List.generate(
        trip.numTravelers,
        (i) => {
          'name': i == 0 ? 'You (Organizer)' : 'Traveler ${i + 1}',
          'role': i == 0 ? 'Organizer' : 'Member',
          'avatar': '',
        },
      );
    } else {
      _members = [];
    }

    _syncContributionsFromMembers();

    _notesController = TextEditingController();

    _loggedExpenses = _hasBackendTripId(trip)
        ? []
        : [
            {
              'id': 'exp-1',
              'amount': 1200.0,
              'category': 'Food',
              'note': 'Group dinner at Jack\'s Ridge',
            },
            {
              'id': 'exp-2',
              'amount': 850.0,
              'category': 'Transport',
              'note': 'Ferry transfer to Samal',
            },
          ];

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadBackendCollaborationData();
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  bool _hasBackendTripId(Trip? trip) {
    final id = int.tryParse(trip?.id ?? '');
    return id != null && id > 0;
  }

  Trip? _currentTripSnapshot() {
    if (widget.trip != null) {
      final trips = context.read<TripProvider>().userTrips;
      return trips.firstWhere(
        (t) => t.id == widget.trip!.id,
        orElse: () => widget.trip!,
      );
    }
    final trips = context.read<TripProvider>().userTrips;
    return trips.isNotEmpty ? trips.first : null;
  }

  void _syncContributionsFromMembers() {
    _contributions = _members
        .map<Map<String, dynamic>>(
          (m) => {
            'name': m['name'] ?? 'Traveler',
            'amount': 0.0,
            'status': 'Unpaid',
          },
        )
        .toList();
  }

  void _syncProviderMembers(Trip activeTrip) {
    context.read<TripProvider>().updateTrip(
      activeTrip.copyWith(members: List<Map<String, String>>.from(_members)),
    );
  }

  String? _firstBackendMemberId() {
    for (final member in _members) {
      final id = member['trip_member_id'] ?? member['id'];
      if (id != null && int.tryParse(id) != null) return id;
    }
    return null;
  }

  Future<void> _loadBackendCollaborationData() async {
    final trip = _currentTripSnapshot();
    if (!_hasBackendTripId(trip)) return;

    setState(() => _isLoadingBackendCollaboration = true);
    final members = await _apiService.fetchTripMembers(trip!.id);
    final membersError = _apiService.lastError;
    final expenses = await _apiService.fetchTripExpenses(trip.id);
    final expensesError = _apiService.lastError;
    if (!mounted) return;

    setState(() {
      if (membersError == null || members.isNotEmpty) {
        _members = members;
        _syncContributionsFromMembers();
      }
      if (expensesError == null || expenses.isNotEmpty) {
        _loggedExpenses = expenses;
      }
      _isLoadingBackendCollaboration = false;
    });
    _syncProviderMembers(trip);
  }

  Future<void> _requestLocation() async {
    if (!mounted) return;

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permission was denied.';
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw 'Location permission is permanently denied.';
      }

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 4),
        ),
      );

      if (mounted) {
        setState(() {
          _userPosition = pos;
        });
      }

      _positionStreamSubscription?.cancel();
      _positionStreamSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 10,
            ),
          ).listen(
            (Position position) {
              if (mounted) {
                setState(() {
                  _userPosition = position;
                });
              }
            },
            onError: (error) {
              debugPrint("Real-time location stream error: $error");
            },
          );
    } catch (e) {
      debugPrint('GPS query error: $e');
    }
  }

  String _deriveBudgetStyle(Trip trip) {
    final titleLower = trip.title.toLowerCase();
    if (titleLower.contains('low budget') ||
        titleLower.contains('low-budget') ||
        titleLower.contains('cheap')) {
      return 'Low Budget';
    } else if (titleLower.contains('balanced budget') ||
        titleLower.contains('balanced-budget') ||
        titleLower.contains('balanced')) {
      return 'Balanced Budget';
    } else if (titleLower.contains('high budget') ||
        titleLower.contains('high-budget') ||
        titleLower.contains('premium') ||
        titleLower.contains('luxury')) {
      return 'High Budget';
    } else {
      final perPerson =
          trip.budget / (trip.numTravelers > 0 ? trip.numTravelers : 1);
      if (perPerson <= 1500.0) {
        return 'Low Budget';
      } else if (perPerson <= 5000.0) {
        return 'Balanced Budget';
      } else {
        return 'High Budget';
      }
    }
  }

  double _parsePrice(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^\d\.-]'), '');
    if (cleanText.isEmpty) return 0.0;
    if (cleanText.contains('-')) {
      final parts = cleanText.split('-');
      final p1 = double.tryParse(parts[0]) ?? 0.0;
      final p2 = double.tryParse(parts[1]) ?? 0.0;
      return (p1 + p2) / 2;
    }
    return double.tryParse(cleanText) ?? 0.0;
  }

  Map<String, String>? _getBudgetAccommodation(
    Destination dest,
    String budgetStyle,
  ) {
    final accommTypes = dest.extra.accommodationTypes;
    if (accommTypes.isEmpty) return null;
    if (budgetStyle == 'Low Budget') {
      return accommTypes.first;
    } else if (budgetStyle == 'High Budget') {
      return accommTypes.last;
    } else {
      return accommTypes[accommTypes.length ~/ 2];
    }
  }

  Map<String, String>? _getBudgetTransport(
    Destination dest,
    String budgetStyle,
  ) {
    final transOptions = dest.extra.transportOptions;
    if (transOptions.isEmpty) return null;

    final sortedTrans = List<Map<String, String>>.from(transOptions)
      ..sort((a, b) {
        return _parsePrice(
          a['price'] ?? '0',
        ).compareTo(_parsePrice(b['price'] ?? '0'));
      });

    if (budgetStyle == 'Low Budget') {
      return sortedTrans.first;
    } else if (budgetStyle == 'High Budget') {
      return sortedTrans.last;
    } else {
      return sortedTrans[sortedTrans.length ~/ 2];
    }
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

  List<Map<String, String>> _getCommuterSteps(
    Destination dest,
    String startPoint,
    String budgetStyle,
    Position? userPos,
  ) {
    if (startPoint == 'Current Location') {
      if (userPos == null) {
        return _getCommuterSteps(dest, 'Davao City', budgetStyle, null);
      }
      final firstMile = _calculateFirstMile(userPos);
      final hub = firstMile['nearestHub'] as TransitHub;
      final baseSteps = _getCommuterSteps(dest, hub.city, budgetStyle, null);

      final List<Map<String, String>> customSteps = [
        {
          'step': '1. Your Location to ${hub.name}',
          'type':
              firstMile['vehicle'] +
              " (" +
              firstMile['distance'].toStringAsFixed(1) +
              " km)",
          'cost': '₱' + firstMile['cost'].toStringAsFixed(0),
          'duration': firstMile['duration'],
        },
      ];

      for (int i = 0; i < baseSteps.length; i++) {
        final originalStep = baseSteps[i];
        final cleanStepName = originalStep['step']!.replaceFirst(
          RegExp(r'^\d+\.\s*'),
          '',
        );
        customSteps.add({
          'step': '${i + 2}. $cleanStepName',
          'type': originalStep['type'] ?? '',
          'cost': originalStep['cost'] ?? '',
          'duration': originalStep['duration'] ?? '',
        });
      }
      return customSteps;
    }

    final lowerName = dest.name.toLowerCase();
    final lowerLoc = dest.location.toLowerCase();
    final isSamal =
        lowerName.contains('samal') ||
        lowerLoc.contains('samal') ||
        lowerName.contains('pearl farm') ||
        lowerName.contains('hagimit');
    final isEden = lowerName.contains('eden');
    final isMati = lowerName.contains('dahican') || lowerLoc.contains('mati');
    final isMalagos =
        lowerName.contains('malagos') ||
        lowerName.contains('eagle') ||
        lowerLoc.contains('calinan');

    if (isSamal) {
      if (startPoint == 'Panabo') {
        return [
          {
            'step': '1. Panabo Terminal to Sasa Wharf',
            'type': 'Public Bus (commuter)',
            'cost': '₱90',
            'duration': '45 mins',
          },
          {
            'step': '2. Sasa Wharf to Samal (Babak Port)',
            'type': 'Barge / Ferry',
            'cost': '₱20',
            'duration': '15 mins',
          },
          {
            'step': '3. Babak Port to ${dest.name}',
            'type': 'Tricycle / Habal-Habal',
            'cost': '₱80',
            'duration': '15 mins',
          },
          {
            'step': '4. Environmental Fee',
            'type': 'Environmental Fee (Included)',
            'cost': dest.extra.environmentalFee.isNotEmpty
                ? dest.extra.environmentalFee
                : '₱30',
            'duration': 'Instant',
          },
        ];
      } else {
        return [
          {
            'step': '1. Davao City Center to Sasa Wharf',
            'type': 'Jeepney / Cab',
            'cost': '₱30',
            'duration': '25 mins',
          },
          {
            'step': '2. Sasa Wharf to Samal (Babak Port)',
            'type': 'Barge / Ferry',
            'cost': '₱20',
            'duration': '15 mins',
          },
          {
            'step': '3. Babak Port to ${dest.name}',
            'type': 'Tricycle / Habal-Habal',
            'cost': '₱80',
            'duration': '15 mins',
          },
          {
            'step': '4. Environmental Fee',
            'type': 'Environmental Fee (Included)',
            'cost': dest.extra.environmentalFee.isNotEmpty
                ? dest.extra.environmentalFee
                : '₱30',
            'duration': 'Instant',
          },
        ];
      }
    } else if (isEden) {
      if (startPoint == 'Panabo') {
        return [
          {
            'step': '1. Panabo to Davao City proper',
            'type': 'Bus / Jeepney',
            'cost': '₱70',
            'duration': '50 mins',
          },
          {
            'step': '2. Davao Proper to Toril Mercury Drug',
            'type': 'Jeepney',
            'cost': '₱40',
            'duration': '35 mins',
          },
          {
            'step': '3. Toril to ${dest.name}',
            'type': 'Habal-Habal (Motorcycle)',
            'cost': '₱120',
            'duration': '20 mins',
          },
          {
            'step': '4. Environmental Fee',
            'type': 'Resort Entry Fee',
            'cost': '₱50',
            'duration': 'Instant',
          },
        ];
      } else {
        return [
          {
            'step': '1. Davao Center to Toril Mercury Drug',
            'type': 'Jeepney / Commuter',
            'cost': '₱40',
            'duration': '30 mins',
          },
          {
            'step': '2. Toril to ${dest.name}',
            'type': 'Habal-Habal (Motorcycle)',
            'cost': '₱120',
            'duration': '20 mins',
          },
          {
            'step': '3. Environmental Fee',
            'type': 'Resort Entry Fee',
            'cost': '₱50',
            'duration': 'Instant',
          },
        ];
      }
    } else if (isMati) {
      if (startPoint == 'Panabo') {
        return [
          {
            'step': '1. Panabo to Mati Town Proper',
            'type': 'Shared Passenger Van',
            'cost': '₱400',
            'duration': '4.5 hours',
          },
          {
            'step': '2. Mati Terminal to ${dest.name}',
            'type': 'Local Commuter Tricycle',
            'cost': '₱75',
            'duration': '15 mins',
          },
          {
            'step': '3. Environmental Entry Fee',
            'type': 'Dahican local tourist fee',
            'cost': '₱50',
            'duration': 'Instant',
          },
        ];
      } else {
        return [
          {
            'step': '1. Davao City Center to Mati Terminal',
            'type': 'Public Bus (Non-Stop)',
            'cost': '₱400',
            'duration': '4 - 5 hours',
          },
          {
            'step': '2. Mati Terminal to ${dest.name}',
            'type': 'Local Tricycle',
            'cost': '₱75',
            'duration': '15 mins',
          },
          {
            'step': '3. Environmental Fee',
            'type': 'Tourist environmental entry fee',
            'cost': '₱50',
            'duration': 'Instant',
          },
        ];
      }
    } else if (isMalagos) {
      if (startPoint == 'Panabo') {
        return [
          {
            'step': '1. Panabo to Calinan Terminal',
            'type': 'Public Van / Jeepney',
            'cost': '₱150',
            'duration': '1.5 hours',
          },
          {
            'step': '2. Calinan to ${dest.name}',
            'type': 'Habal-Habal / Tricycle',
            'cost': '₱40',
            'duration': '10 mins',
          },
          {
            'step': '3. Local Environmental Fee',
            'type': 'Calinan community fee',
            'cost': '₱30',
            'duration': 'Instant',
          },
        ];
      } else {
        return [
          {
            'step': '1. Davao proper to Calinan Terminal',
            'type': 'Public Jeepney',
            'cost': '₱60',
            'duration': '1 hour',
          },
          {
            'step': '2. Calinan to ${dest.name}',
            'type': 'Habal-Habal / Tricycle',
            'cost': '₱40',
            'duration': '10 mins',
          },
          {
            'step': '3. Local Environmental Fee',
            'type': 'Calinan community fee',
            'cost': '₱30',
            'duration': 'Instant',
          },
        ];
      }
    } else {
      if (startPoint == 'Panabo') {
        return [
          {
            'step': '1. Panabo to City Terminal',
            'type': 'Public Bus',
            'cost': '₱80',
            'duration': '1 hour',
          },
          {
            'step': '2. Terminal to ${dest.name}',
            'type': 'Jeepney / Habal-Habal',
            'cost': '₱50',
            'duration': '20 mins',
          },
          {
            'step': '3. Environmental Fee',
            'type': 'Local community fee',
            'cost': '₱30',
            'duration': 'Instant',
          },
        ];
      } else {
        return [
          {
            'step': '1. Davao City Center to ${dest.name}',
            'type': 'Public Jeepney',
            'cost': '₱40',
            'duration': '35 mins',
          },
          {
            'step': '2. Local Hub to Entry Gate',
            'type': 'Tricycle',
            'cost': '₱30',
            'duration': '10 mins',
          },
          {
            'step': '3. Environmental Fee',
            'type': 'Local community fee',
            'cost': '₱30',
            'duration': 'Instant',
          },
        ];
      }
    }
  }

  Widget _buildCommuterRouteCard(Destination dest, String budgetStyle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = _getCommuterSteps(
      dest,
      _commuterStartPoint,
      budgetStyle,
      _userPosition,
    );
    double totalCost = 0.0;
    for (final step in steps) {
      final priceText = step['cost'] ?? '0';
      if (priceText.toLowerCase().contains('included') ||
          priceText.toLowerCase().contains('free')) {
        continue;
      }
      totalCost += _parsePrice(priceText);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : AppTheme.primaryBlue.withValues(alpha: 0.15),
        ),
        boxShadow: AppConstants.premiumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.commute_rounded,
                      color: isDark ? Colors.white : AppTheme.primaryBlue,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Commuter Route Guide',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryBlue,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _commuterStartPoint,
                      dropdownColor: Theme.of(context).cardColor,
                      icon: Icon(
                        Icons.keyboard_arrow_down_rounded,
                        size: 16,
                        color: isDark ? Colors.white : AppTheme.primaryBlue,
                      ),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryBlue,
                      ),
                      items: ['Current Location', 'Panabo', 'Davao City'].map((
                        String val,
                      ) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(
                            val == 'Current Location'
                                ? '📍 Current Location'
                                : val,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.textPrimaryDark
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newVal) {
                        if (newVal != null) {
                          setState(() {
                            _commuterStartPoint = newVal;
                          });
                          if (newVal == 'Current Location' &&
                              _userPosition == null) {
                            _requestLocation();
                          }
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Text(
            'Dynamic step-by-step commuter routing, including barge connections and fees.',
            style: GoogleFonts.outfit(
              fontSize: 11,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppConstants.spaceL),
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AppTheme.secondaryGreen.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.secondaryGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 36,
                        color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                      ),
                  ],
                ),
                const SizedBox(width: AppConstants.spaceM),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          step['step'] ?? '',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${step["type"] ?? ""} • ${step["duration"] ?? ""}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              step['cost'] ?? '',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.secondaryGreen,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
          Divider(color: Theme.of(context).dividerColor, height: 1),
          const SizedBox(height: AppConstants.spaceM),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppTheme.secondaryGreen.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Estimated Commuter Cost:',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '₱${totalCost.toStringAsFixed(0)} / pax',
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryGreen,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteAndTransportationSection(
    Trip activeTrip,
    Destination dest,
  ) {
    final budgetStyle = _deriveBudgetStyle(activeTrip);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final accommOpt = _getBudgetAccommodation(dest, budgetStyle);
    final transOpt = _getBudgetTransport(dest, budgetStyle);

    LatLng startLocation;
    String startName;
    if (_commuterStartPoint == 'Panabo') {
      startLocation = const LatLng(7.3079, 125.6811);
      startName = 'Panabo Terminal';
    } else if (_commuterStartPoint == 'Current Location' &&
        _userPosition != null) {
      startLocation = LatLng(_userPosition!.latitude, _userPosition!.longitude);
      startName = 'Your Location';
    } else {
      startLocation = const LatLng(7.0706, 125.6092);
      startName = _commuterStartPoint == 'Current Location'
          ? 'Davao City Center (GPS Loading...)'
          : 'Davao City Center';
    }

    // Trigger OSRM road geometry fetching
    _fetchRoadRoute(startLocation, dest);

    final lowerSearch = activeTrip.destinationName.toLowerCase();
    final isSamal =
        lowerSearch.contains('samal') ||
        dest.location.toLowerCase().contains('samal') ||
        dest.name.toLowerCase().contains('pearl farm') ||
        dest.name.toLowerCase().contains('hagimit');

    final List<LatLng> routePoints = [startLocation];
    if (isSamal) {
      routePoints.add(const LatLng(7.1017, 125.6601));
      routePoints.add(const LatLng(7.1189, 125.6822));
    }
    routePoints.add(LatLng(dest.latitude, dest.longitude));

    final Color budgetBadgeColor = budgetStyle == 'Low Budget'
        ? Colors.green[700]!
        : budgetStyle == 'High Budget'
        ? Colors.red[700]!
        : Colors.amber[700]!;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spaceXL),
          Text(
            'Route Optimization',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'AI optimized paths calculated for your journey.',
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: isDark
                  ? AppTheme.textSecondaryDark
                  : AppTheme.textSecondaryLight,
            ),
          ),
          if (_trafficSummary != null) ...[
            const SizedBox(height: AppConstants.spaceS),
            _buildTrafficSummaryBanner(isDark),
          ],
          const SizedBox(height: AppConstants.spaceM),
          Container(
            height: 280,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
              boxShadow: AppConstants.premiumShadow,
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(dest.latitude, dest.longitude),
                    initialZoom: 11.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          AppConstants.mapboxAccessToken.isEmpty ||
                              AppConstants.mapboxAccessToken ==
                                  'YOUR_MAPBOX_ACCESS_TOKEN'
                          ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
                          : 'https://api.mapbox.com/styles/v1/mapbox/streets-v11/tiles/{z}/{x}/{y}?access_token=${AppConstants.mapboxAccessToken}',
                      userAgentPackageName: 'com.lakbay.plus',
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: _roadGeometryPoints.isNotEmpty
                              ? _roadGeometryPoints
                              : routePoints,
                          color: AppTheme.primaryBlue,
                          strokeWidth: 4,
                        ),
                      ],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: startLocation,
                          width: 40,
                          height: 40,
                          child: const Icon(
                            Icons.my_location_rounded,
                            color: AppTheme.secondaryGreen,
                            size: 28,
                          ),
                        ),
                        if (isSamal) ...[
                          Marker(
                            point: const LatLng(7.1017, 125.6601),
                            width: 32,
                            height: 32,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 3,
                                    offset: Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.directions_boat_rounded,
                                  color: AppTheme.primaryBlue,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                        Marker(
                          point: LatLng(dest.latitude, dest.longitude),
                          width: 45,
                          height: 45,
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.redAccent,
                            size: 38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 10,
                  left: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).cardColor.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(8),
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
                        Icon(
                          Icons.navigation_rounded,
                          color: isDark ? Colors.white : AppTheme.primaryBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Optimized Route: $startName ➔ ${dest.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  right: 10,
                  bottom: 10,
                  child: FloatingActionButton.small(
                    heroTag: 'recenter_dashboard_map',
                    backgroundColor: Theme.of(context).cardColor,
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    onPressed: () {
                      _mapController.move(
                        LatLng(dest.latitude, dest.longitude),
                        11.5,
                      );
                    },
                    child: const Icon(
                      Icons.center_focus_strong_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppConstants.spaceXL),
          Text(
            'Budget-Matched Bookings',
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppTheme.primaryBlue,
            ),
          ),
          const SizedBox(height: AppConstants.spaceM),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: AppConstants.premiumShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.hotel_rounded,
                            color: budgetBadgeColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Lodging',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        accommOpt != null
                            ? accommOpt['type'] ?? 'Standard Room'
                            : 'Standard Lodging',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        accommOpt != null
                            ? accommOpt['price'] ?? 'Free'
                            : 'Included in trip',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: Container(
                  height: 140,
                  padding: const EdgeInsets.all(AppConstants.spaceM),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(AppConstants.radiusL),
                    border: Border.all(
                      color: Colors.grey.withValues(alpha: 0.15),
                    ),
                    boxShadow: AppConstants.premiumShadow,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.directions_bus_rounded,
                            color: budgetBadgeColor,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Transport',
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        transOpt != null
                            ? transOpt['vehicle'] ?? 'Public Transit'
                            : 'Local Commute',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        transOpt != null
                            ? 'Route: ${transOpt['from'] ?? ''} ➔ ${transOpt['to'] ?? ''}'
                            : 'City Center ➔ Destination',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 10,
                          color: isDark
                              ? AppTheme.textSecondaryDark
                              : AppTheme.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      if (activeTrip.isGroup &&
                          activeTrip.numTravelers > 1) ...[
                        Text(
                          transOpt != null
                              ? '${transOpt['price'] ?? 'Free'}/pax'
                              : 'Free/pax',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.secondaryGreen,
                          ),
                        ),
                        Builder(
                          builder: (ctx) {
                            final perPax = _parsePrice(
                              transOpt?['price'] ?? '0',
                            );
                            final total = perPax * activeTrip.numTravelers;
                            return Text(
                              'Total: ₱${total.toStringAsFixed(0)} for ${activeTrip.numTravelers} pax',
                              style: GoogleFonts.outfit(
                                fontSize: 9,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            );
                          },
                        ),
                      ] else
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                transOpt != null
                                    ? transOpt['price'] ?? 'Free'
                                    : 'Free',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryGreen,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                transOpt != null
                                    ? transOpt['duration'] ?? '1 hr'
                                    : '1 hr',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppTheme.textSecondaryDark
                                      : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spaceM),
          _buildCommuterRouteCard(dest, budgetStyle),
        ],
      ),
    );
  }

  Trip _getTrip(BuildContext context) {
    if (widget.trip != null) {
      // Find updated version in provider if exists to maintain sync
      final trips = context.watch<TripProvider>().userTrips;
      final found = trips.firstWhere(
        (t) => t.id == widget.trip!.id,
        orElse: () => widget.trip!,
      );
      return found;
    }
    final trips = context.watch<TripProvider>().userTrips;
    return trips.isNotEmpty ? trips.first : Trip.mockTrips[0];
  }

  Widget _summaryDivider() {
    return Container(width: 1, height: 20, color: Colors.white24);
  }

  Widget _summaryCol(String val, String label) {
    return Column(
      children: [
        Text(
          val,
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 9)),
      ],
    );
  }

  Future<Map<String, dynamic>?> _weatherFutureFor(Destination destination) {
    return _weatherFutures.putIfAbsent(
      destination.id,
      () => _apiService.fetchDestinationWeather(destination.id),
    );
  }

  Widget _buildWeatherCard(Destination destination) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<Map<String, dynamic>?>(
      future: _weatherFutureFor(destination),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
            padding: const EdgeInsets.all(AppConstants.spaceM),
            decoration: BoxDecoration(
              color: AppTheme.accentTeal.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppConstants.radiusXL),
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
        final firstDay = days.isNotEmpty && days.first is Map
            ? (days.first as Map).cast<String, dynamic>()
            : <String, dynamic>{};
        final temp = _weatherNumber(current['temp_c']);
        final rain = _weatherInt(firstDay['rain_chance_percent']);
        final main = condition['main']?.toString() ?? 'Weather';
        final description = condition['description']?.toString() ?? main;
        final advisory =
            current['advisory']?.toString() ??
            firstDay['advisory']?.toString() ??
            '';

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: BoxDecoration(
            color: AppTheme.accentTeal.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppConstants.radiusXL),
            border: Border.all(
              color: AppTheme.accentTeal.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.accentTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(_weatherIcon(main), color: AppTheme.accentTeal),
              ),
              const SizedBox(width: AppConstants.spaceM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weather for ${destination.name}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppTheme.textPrimaryDark
                            : AppTheme.primaryBlue,
                      ),
                    ),
                    Text(
                      advisory.isEmpty ? description : advisory,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: AppConstants.spaceM),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    temp == null ? '--' : '${temp.toStringAsFixed(0)} C',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.accentTeal,
                    ),
                  ),
                  Text(
                    rain == null ? 'Rain --' : 'Rain $rain%',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
        );
      },
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

  Widget _buildHeroBanner(Trip activeTrip, int totalStops, bool isGroup) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: const Color(
          0xFF104B50,
        ), // Premium deep dark teal fallback background color
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
          Text(
            activeTrip.destinationName,
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            activeTrip.title,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              // Solo/Group Pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isGroup ? Icons.people_alt_rounded : Icons.person_rounded,
                      size: 11,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isGroup ? 'Group' : 'Solo',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Budget Level Chip
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  activeTrip.budget <= kLowBudgetMax
                      ? '⬇ Low Budget'
                      : activeTrip.budget <= kBalancedBudgetMax
                      ? '= Balanced'
                      : '⬆ High Budget',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Duration pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '📅 ${activeTrip.itinerary.length} Days',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _summaryCol('${activeTrip.itinerary.length}', 'Days'),
                _summaryDivider(),
                _summaryCol('$totalStops', 'Stops'),
                _summaryDivider(),
                _summaryCol(
                  '₱${activeTrip.budget.toStringAsFixed(0)}',
                  'Est. Budget',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItinerarySection(Trip activeTrip) {
    // Note: The itinerary data source is retrieved from activeTrip.itinerary, which is passed down
    // from the saved planner output in TripProvider.
    // TODO: Sync / fetch itinerary from Neon DB (itineraries table)
    if (activeTrip.itinerary.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(
          vertical: 16.0,
          horizontal: AppConstants.spaceM,
        ),
        child: Text(
          'No activities scheduled yet.',
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
        ),
      );
    }

    // Sort days in ascending order
    final sortedDays = activeTrip.itinerary.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedDays.map((dayNum) {
        final activities = activeTrip.itinerary[dayNum] ?? [];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: AppConstants.spaceL,
              ),
              child: Text(
                'Day $dayNum',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            ...activities.map((act) => ActivityTile(activity: act)),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildExpenseTracker(
    Trip activeTrip,
    Destination matchedDest,
    dynamic destExtra,
  ) {
    final totalSpent = _loggedExpenses.fold<double>(
      0,
      (sum, item) => sum + item['amount'],
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = activeTrip.budget > 0
        ? (totalSpent / activeTrip.budget).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.account_balance_wallet_rounded,
                    color: AppTheme.secondaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Expense Tracker',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _showAddExpenseDialog(activeTrip),
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(
                  'Add Expense',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.secondaryGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: AppTheme.secondaryGreen.withValues(
                    alpha: 0.1,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (_isLoadingBackendCollaboration) ...[
            const LinearProgressIndicator(minHeight: 2),
            const SizedBox(height: 12),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _financeMetric(
                'Spent',
                '₱${totalSpent.toStringAsFixed(0)}',
                AppTheme.secondaryGreen,
              ),
              _financeMetric(
                'Remaining',
                '₱${(activeTrip.budget - totalSpent).toStringAsFixed(0)}',
                AppTheme.primaryBlue,
              ),
              _financeMetric(
                'Budget',
                '₱${activeTrip.budget.toStringAsFixed(0)}',
                Colors.grey,
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: percent,
              minHeight: 8,
              backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                percent > 0.9 ? Colors.redAccent : AppTheme.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${(percent * 100).toStringAsFixed(0)}% of budget used',
              style: const TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          if (_loggedExpenses.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No expenses logged yet. Tap Add Expense to start tracking!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _loggedExpenses.length,
              itemBuilder: (context, index) {
                final exp = _loggedExpenses[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          _getExpenseCategoryIcon(exp['category']),
                          size: 16,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              exp['note'],
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              exp['category'],
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '₱${exp['amount'].toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryGreen,
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_rounded,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onPressed: () =>
                            _showEditExpenseDialog(activeTrip, index),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          size: 16,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _deleteExpense(activeTrip, index),
                      ),
                    ],
                  ),
                );
              },
            ),
          const Divider(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showDigitalReceiptModal(
                context,
                activeTrip,
                matchedDest,
                destExtra,
              ),
              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
              label: Text(
                'Export PDF Travel Receipt',
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryBlue,
                side: const BorderSide(color: AppTheme.primaryBlue),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _financeMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: color,
          ),
        ),
      ],
    );
  }

  IconData _getExpenseCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'transport':
        return Icons.directions_car_rounded;
      case 'accommodation':
        return Icons.hotel_rounded;
      case 'activities':
        return Icons.local_activity_rounded;
      default:
        return Icons.payments_rounded;
    }
  }

  Future<void> _deleteExpense(Trip activeTrip, int index) async {
    final expense = _loggedExpenses[index];
    final expenseId =
        expense['trip_expense_id']?.toString() ??
        expense['id']?.toString() ??
        '';
    if (_hasBackendTripId(activeTrip) && int.tryParse(expenseId) != null) {
      final deleted = await _apiService.deleteTripExpense(
        activeTrip.id,
        expenseId,
      );
      if (!mounted) return;
      if (!deleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_apiService.lastError ?? 'Failed to delete expense.'),
            backgroundColor: Colors.redAccent,
          ),
        );
        return;
      }
    }

    setState(() {
      _loggedExpenses.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Expense deleted successfully'),
        backgroundColor: Colors.redAccent,
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _showAddExpenseDialog(Trip activeTrip) {
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    String category = 'Food';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Add Expense',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (PHP)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: category,
                items:
                    const [
                          'Food',
                          'Transport',
                          'Accommodation',
                          'Activities',
                          'Others',
                        ]
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                onChanged: (val) {
                  if (val != null) category = val;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text);
                final note = noteCtrl.text.trim();
                if (amt == null || amt <= 0 || note.isEmpty) return;

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(this.context);
                Map<String, dynamic>? savedExpense;
                if (_hasBackendTripId(activeTrip)) {
                  final payerId = _firstBackendMemberId();
                  if (payerId == null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Add or load trip members before logging expenses.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                  savedExpense = await _apiService.createTripExpense(
                    activeTrip.id,
                    amount: amt,
                    category: category,
                    note: note,
                    paidByTripMemberId: payerId,
                  );
                  if (!mounted) return;
                  if (savedExpense == null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _apiService.lastError ?? 'Failed to add expense.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                }

                setState(() {
                  _loggedExpenses.add(
                    savedExpense ??
                        {
                          'id': 'exp-${DateTime.now().millisecondsSinceEpoch}',
                          'amount': amt,
                          'category': category,
                          'note': note,
                        },
                  );
                });
                navigator.pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showEditExpenseDialog(Trip activeTrip, int index) {
    final exp = _loggedExpenses[index];
    final amountCtrl = TextEditingController(
      text: exp['amount'].toStringAsFixed(0),
    );
    final noteCtrl = TextEditingController(text: exp['note']);
    String category = exp['category'];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Edit Expense',
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount (PHP)'),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: category,
                items:
                    const [
                          'Food',
                          'Transport',
                          'Accommodation',
                          'Activities',
                          'Others',
                        ]
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                onChanged: (val) {
                  if (val != null) category = val;
                },
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteCtrl,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final amt = double.tryParse(amountCtrl.text);
                final note = noteCtrl.text.trim();
                if (amt == null || amt <= 0 || note.isEmpty) return;

                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(this.context);
                Map<String, dynamic>? savedExpense;
                final expenseId =
                    exp['trip_expense_id']?.toString() ??
                    exp['id']?.toString() ??
                    '';
                if (_hasBackendTripId(activeTrip) &&
                    int.tryParse(expenseId) != null) {
                  savedExpense = await _apiService.updateTripExpense(
                    activeTrip.id,
                    expenseId,
                    amount: amt,
                    category: category,
                    note: note,
                    paidByTripMemberId:
                        exp['paid_by_trip_member_id']?.toString() ??
                        _firstBackendMemberId(),
                  );
                  if (!mounted) return;
                  if (savedExpense == null) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(
                          _apiService.lastError ?? 'Failed to update expense.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    return;
                  }
                }

                setState(() {
                  _loggedExpenses[index] =
                      savedExpense ??
                      {
                        ...exp,
                        'amount': amt,
                        'category': category,
                        'note': note,
                      };
                });
                navigator.pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPhotoMemories(Trip activeTrip) {
    // Extract photo URLs from trip memories (for clean DB wiring in Step 10)
    final List<String> photoUrls = activeTrip.memories
        .map<String>((m) => m['image'] as String? ?? '')
        .where((url) => url.isNotEmpty)
        .toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
      padding: const EdgeInsets.all(AppConstants.spaceL),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.cardShadow,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_library_rounded,
                    color: AppTheme.accentTeal,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Photo Memories',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () => _addPhotoFromGallery(activeTrip),
                icon: const Icon(Icons.add_a_photo_rounded, size: 16),
                label: Text(
                  'Add Photo',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accentTeal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  backgroundColor: AppTheme.accentTeal.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (photoUrls.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: Text(
                  'No photo memories uploaded yet. Tap Add Photo to share a memory!',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1.0,
              ),
              itemCount: photoUrls.length,
              itemBuilder: (context, index) {
                final url = photoUrls[index];
                final mem = activeTrip.memories.firstWhere(
                  (m) => m['image'] == url,
                  orElse: () => <String, dynamic>{},
                );
                final caption = mem['caption'] as String? ?? '';
                final isLocal = !url.startsWith('http');

                return ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      isLocal
                          ? Image.file(
                              File(url),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[900],
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.white38,
                                    ),
                                  ),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: Colors.grey[900],
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.white38,
                                    ),
                                  ),
                            ),
                      if (caption.isNotEmpty)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            color: Colors.black45,
                            child: Text(
                              caption,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _addPhotoFromGallery(Trip trip) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (pickedFile == null) return;

    final file = File(pickedFile.path);
    final result = await _showAddPhotoDialog(file, trip.destinationName);
    if (result == null) return;

    final caption = result['caption'] ?? '';
    final location = result['location'] ?? '';

    final provider = context.read<TripProvider>();
    final success = await provider.addMemoryToTrip(
      trip,
      filePath: file.path,
      caption: caption,
      location: location.isNotEmpty ? location : trip.destinationName,
    );
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Memory photo uploaded and synced!'
              : (provider.errorMessage ?? 'Failed to upload memory photo.'),
        ),
        backgroundColor: success ? AppTheme.secondaryGreen : Colors.redAccent,
      ),
    );
  }

  Future<Map<String, String>?> _showAddPhotoDialog(
    File imageFile,
    String defaultLocation,
  ) async {
    final captionCtrl = TextEditingController();
    final locationCtrl = TextEditingController(
      text: defaultLocation.split(',').first,
    );

    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.cardColorDark : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.all(AppConstants.spaceL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppConstants.spaceL),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Add Photo Memory',
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                  child: Image.file(
                    imageFile,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(height: AppConstants.spaceM),
                TextField(
                  controller: captionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Caption (optional)',
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: AppConstants.spaceS),
                TextField(
                  controller: locationCtrl,
                  decoration: InputDecoration(
                    labelText: 'Location Tag (optional)',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                    ),
                  ),
                ),
                const SizedBox(height: AppConstants.spaceL),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                          ),
                        ),
                        child: Text('Cancel', style: GoogleFonts.outfit()),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceM),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, {
                          'caption': captionCtrl.text.trim(),
                          'location': locationCtrl.text.trim(),
                        }),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusM,
                            ),
                          ),
                        ),
                        child: Text(
                          'Upload',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTravelNotesWidget(Trip activeTrip, Destination dest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Dynamic AI Suggestions based on destination
    final List<String> aiSuggestions = [
      '🎒 Pack light: Bring breathable clothes, a dry bag for wet items, and sun protection.',
      '🚗 Transit advice: Hiring a local tricycle or habal-habal is the easiest way to travel between attractions.',
      '⏰ Early start: Reach local spots by 8:00 AM to beat the mid-day heat and large crowds.',
      '💳 Cash is King: Bring local currency (PHP cash) as small vendors and entrance gates do not accept cards.',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // AI Suggestions Card
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppConstants.radiusXL),
            border: Border.all(
              color: AppTheme.primaryBlue.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.psychology_alt_rounded,
                    color: AppTheme.primaryBlue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Recommendations',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spaceM),
              ...aiSuggestions.map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Text(
                    tip,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppConstants.spaceM),

        // Personal Notes Card (re-using the existing amber notes design)
        Container(
          margin: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
          padding: const EdgeInsets.all(AppConstants.spaceL),
          decoration: BoxDecoration(
            color: Colors.amber.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(AppConstants.radiusXL),
            border: Border.all(color: Colors.amber.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.note_alt_rounded,
                    color: Colors.amber,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Personal Notes & Reminders',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.amber[850],
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: Icon(
                      _isEditingNotes
                          ? Icons.check_circle_rounded
                          : Icons.edit_rounded,
                      size: 20,
                      color: _isEditingNotes
                          ? AppTheme.secondaryGreen
                          : Colors.grey,
                    ),
                    onPressed: () async {
                      if (_isEditingNotes) {
                        final updated = activeTrip.copyWith(
                          notes: _notesController.text,
                        );
                        final provider = context.read<TripProvider>();
                        final success = await provider.saveTripMetadata(
                          updated,
                        );
                        if (!mounted) return;
                        if (success) {
                          setState(() => _isEditingNotes = false);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              success
                                  ? 'Notes saved persistently!'
                                  : (provider.errorMessage ??
                                        'Failed to save notes.'),
                            ),
                            backgroundColor: success
                                ? AppTheme.secondaryGreen
                                : Colors.redAccent,
                          ),
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
                      style: const TextStyle(fontSize: 12, height: 1.4),
                    ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeTrip = _getTrip(context);
    final totalStops = activeTrip.itinerary.values.fold<int>(
      0,
      (sum, list) => sum + list.length,
    );
    final isGroup = activeTrip.isGroup;

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
      (d) =>
          activeTrip.destinationName.toLowerCase().contains(
            d.name.toLowerCase(),
          ) ||
          d.name.toLowerCase().contains(
            activeTrip.destinationName.toLowerCase(),
          ) ||
          activeTrip.title.toLowerCase().contains(d.name.toLowerCase()),
      orElse: () {
        if (activeTrip.destinationName.toLowerCase().contains('samal') ||
            activeTrip.title.toLowerCase().contains('samal')) {
          return destinations.firstWhere(
            (d) => d.id == 8,
            orElse: () => destinations.first,
          );
        } else if (activeTrip.destinationName.toLowerCase().contains('eden') ||
            activeTrip.title.toLowerCase().contains('eden')) {
          return destinations.firstWhere(
            (d) => d.id == 1,
            orElse: () => destinations.first,
          );
        }
        return destinations.isNotEmpty
            ? destinations.first
            : Destination.davaoDestinations.first;
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
            icon: const Icon(
              Icons.delete_outline_rounded,
              size: 26,
              color: Colors.redAccent,
            ),
            onPressed: () => _confirmDeleteTrip(context, activeTrip),
            tooltip: 'Delete Trip',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero banner redesign
            _buildHeroBanner(activeTrip, totalStops, isGroup),
            const SizedBox(height: AppConstants.spaceM),
            _buildWeatherCard(matchedDest),

            // Embedded Day-by-Day Itinerary Section
            const SizedBox(height: AppConstants.spaceM),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceL,
              ),
              child: Text(
                'Day-by-Day Itinerary',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceS),
            _buildItinerarySection(activeTrip),

            _buildRouteAndTransportationSection(activeTrip, matchedDest),

            // Active Expense Tracker & Logger
            const SizedBox(height: AppConstants.spaceL),
            _buildExpenseTracker(activeTrip, matchedDest, destExtra),

            // Travel Notes Section Overhaul
            const SizedBox(height: AppConstants.spaceL),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.spaceL,
              ),
              child: Text(
                'Travel Notes & Tips',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ),
            const SizedBox(height: AppConstants.spaceS),
            _buildTravelNotesWidget(activeTrip, matchedDest),

            // Photo Memories scrapbook
            const SizedBox(height: AppConstants.spaceL),
            _buildPhotoMemories(activeTrip),

            // Collaborative widgets appended for groups only
            if (isGroup) ...[
              const SizedBox(height: AppConstants.spaceXL),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceL,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Members',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    Text(
                      _members.any((m) => m['avatar']!.isEmpty)
                          ? 'Tap a slot to name them ✏️'
                          : 'Tap to remove',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: isDark
                            ? AppTheme.textSecondaryDark
                            : AppTheme.textSecondaryLight,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceM),
              SizedBox(
                height: 90,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spaceM,
                  ),
                  itemCount: _members.length + 1,
                  itemBuilder: (_, i) {
                    if (i == _members.length) {
                      return Padding(
                        padding: const EdgeInsets.only(
                          right: AppConstants.spaceM,
                        ),
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: () => _showInviteMemberDialog(activeTrip),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppTheme.primaryBlue.withValues(
                                      alpha: 0.3,
                                    ),
                                    width: 2,
                                  ),
                                  color: AppTheme.primaryBlue.withValues(
                                    alpha: 0.07,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.person_add_rounded,
                                  color: AppTheme.primaryBlue,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Invite',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    final m = _members[i];
                    final isPlaceholder = m['avatar']!.isEmpty;
                    final initials = (m['name'] ?? '?').trim().isNotEmpty
                        ? (m['name']!
                                  .trim()
                                  .split(' ')
                                  .map((w) => w.isNotEmpty ? w[0] : '')
                                  .take(2)
                                  .join())
                              .toUpperCase()
                        : '?';
                    final avatarColors = [
                      AppTheme.primaryBlue,
                      AppTheme.secondaryGreen,
                      AppTheme.accentTeal,
                      Colors.orange,
                      Colors.purple,
                      Colors.redAccent,
                    ];
                    final memberColor = avatarColors[i % avatarColors.length];
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: AppConstants.spaceM,
                      ),
                      child: GestureDetector(
                        onTap: () => isPlaceholder
                            ? _renameMember(i)
                            : _confirmRemoveMember(activeTrip, i),
                        child: Column(
                          children: [
                            Stack(
                              children: [
                                isPlaceholder
                                    ? Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: memberColor.withValues(
                                            alpha: 0.15,
                                          ),
                                          border: Border.all(
                                            color: memberColor.withValues(
                                              alpha: 0.4,
                                            ),
                                            width: 2,
                                          ),
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
                                        child: Image.network(
                                          m['avatar']!,
                                          width: 56,
                                          height: 56,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) =>
                                                  Container(
                                                    width: 56,
                                                    height: 56,
                                                    color: AppTheme
                                                        .secondaryGreen
                                                        .withValues(alpha: 0.2),
                                                    child: Center(
                                                      child: Text(
                                                        initials,
                                                        style: const TextStyle(
                                                          fontSize: 16,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: AppTheme
                                                              .primaryBlue,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                        ),
                                      ),
                                if (m['role'] == 'Organizer')
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: const BoxDecoration(
                                        color: AppTheme.secondaryGreen,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.star_rounded,
                                        size: 11,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                if (isPlaceholder)
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Container(
                                      width: 18,
                                      height: 18,
                                      decoration: BoxDecoration(
                                        color: memberColor,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.edit_rounded,
                                        size: 10,
                                        color: Colors.white,
                                      ),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceL,
                ),
                child: Text(
                  'Budget Split & Expenses',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                ),
                padding: const EdgeInsets.all(AppConstants.spaceL),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                  border: Border.all(
                    color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.pie_chart_outline_rounded,
                          color: AppTheme.secondaryGreen,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Group split summary',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _splitMetric(
                          'Total Budget',
                          '₱${activeTrip.budget.toStringAsFixed(0)}',
                        ),
                        _splitMetric(
                          'Travelers',
                          '${activeTrip.numTravelers} people',
                        ),
                        _splitMetric(
                          'Per-Person Share',
                          '₱${(activeTrip.budget / activeTrip.numTravelers).toStringAsFixed(0)}',
                          isPrimary: true,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppConstants.spaceL),

              // Group Contribution Tracker
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceL,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Contribution Tracker',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showAddContributionDialog(context),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Payment'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.secondaryGreen,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppConstants.spaceS),
              Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                ),
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
                    final personalTargetShare =
                        activeTrip.budget / activeTrip.numTravelers;
                    final diff = c['amount'] - personalTargetShare;
                    final isSettled = diff >= 0;

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSettled
                            ? AppTheme.secondaryGreen.withValues(alpha: 0.1)
                            : Colors.orange.withValues(alpha: 0.1),
                        child: Text(
                          c['name']![0],
                          style: TextStyle(
                            color: isSettled
                                ? AppTheme.secondaryGreen
                                : Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        c['name']!,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        isSettled
                            ? 'Fully Contributed (Excess: ₱${diff.toStringAsFixed(0)})'
                            : 'Owes: ₱${(-diff).toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isSettled
                              ? AppTheme.secondaryGreen
                              : Colors.orange,
                        ),
                      ),
                      trailing: Text(
                        '₱${c['amount'].toStringAsFixed(0)}',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: AppConstants.spaceXL),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceL,
                ),
                child: Text(
                  'Collaboration & Tasks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(height: AppConstants.spaceM),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spaceM,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _accessCard(
                        context,
                        'Tasks',
                        Icons.checklist_rounded,
                        AppTheme.secondaryGreen,
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.groupTasks,
                          arguments: activeTrip,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppConstants.spaceM),
                    Expanded(
                      child: _accessCard(
                        context,
                        'Shared Memories',
                        Icons.photo_album_rounded,
                        AppTheme.accentTeal,
                        () => Navigator.pushNamed(
                          context,
                          AppRoutes.groupMemories,
                          arguments: activeTrip,
                        ),
                      ),
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

  Widget _splitMetric(String label, String value, {bool isPrimary = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppTheme.textSecondaryDark
                : AppTheme.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: isPrimary ? 16 : 14,
            color: isPrimary ? AppTheme.secondaryGreen : AppTheme.primaryBlue,
          ),
        ),
      ],
    );
  }

  Widget _accessCard(
    BuildContext ctx,
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
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
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteMemberDialog(Trip activeTrip) {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Invite Member',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        content: TextField(
          controller: emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Registered email',
            border: OutlineInputBorder(),
            hintText: 'friend@example.com',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            onPressed: () async {
              final email = emailController.text.trim();
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              if (!email.contains('@')) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Enter a valid registered email.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }
              if (!_hasBackendTripId(activeTrip)) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Save this trip before inviting members.'),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              final member = await _apiService.addTripMember(
                activeTrip.id,
                email: email,
              );
              if (!mounted) return;
              if (member == null) {
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      _apiService.lastError ?? 'Failed to invite member.',
                    ),
                    backgroundColor: Colors.redAccent,
                  ),
                );
                return;
              }

              setState(() {
                _members.add(member);
                _syncContributionsFromMembers();
              });
              _syncProviderMembers(activeTrip);
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('${member['name']} added to the trip.'),
                  backgroundColor: AppTheme.secondaryGreen,
                ),
              );
            },
            child: const Text('Invite', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Confirmation dialog organizer role for removing members
  void _confirmRemoveMember(Trip activeTrip, int index) {
    final memberName = _members[index]['name'];
    if (_members[index]['role'] == 'Organizer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot remove the trip Organizer!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Remove Member?',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Colors.red,
          ),
        ),
        content: Text(
          'Are you sure you want to remove $memberName from this group trip? They will lose access.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final memberId =
                  _members[index]['trip_member_id'] ??
                  _members[index]['id'] ??
                  '';
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              if (_hasBackendTripId(activeTrip) &&
                  int.tryParse(memberId) != null) {
                final removed = await _apiService.removeTripMember(
                  activeTrip.id,
                  memberId,
                );
                if (!mounted) return;
                if (!removed) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        _apiService.lastError ?? 'Failed to remove member.',
                      ),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                  return;
                }
              }
              setState(() {
                _members.removeAt(index);
                if (index < _contributions.length) {
                  _contributions.removeAt(index);
                }
              });
              _syncProviderMembers(activeTrip);
              navigator.pop();
              messenger.showSnackBar(
                SnackBar(
                  content: Text('$memberName removed successfully.'),
                  backgroundColor: AppTheme.secondaryGreen,
                ),
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
    final nameController = TextEditingController(text: _members[index]['name']);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Name this Traveler',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
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
        title: Text(
          'Add Contribution Payment',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Traveler Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount Contributed (₱)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
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
                  const SnackBar(
                    content: Text('Payment registered successfully.'),
                    backgroundColor: AppTheme.secondaryGreen,
                  ),
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
    final budgetCtrl = TextEditingController(
      text: activeTrip.budget.toStringAsFixed(0),
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Edit Trip Details',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Trip Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: datesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Date Range',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: budgetCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Budget (₱)',
                  border: OutlineInputBorder(),
                ),
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
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
            ),
            onPressed: () async {
              final newBudget =
                  double.tryParse(budgetCtrl.text) ?? activeTrip.budget;
              final updated = activeTrip.copyWith(
                title: titleCtrl.text,
                dateRange: datesCtrl.text,
                budget: newBudget,
              );
              final provider = context.read<TripProvider>();
              final navigator = Navigator.of(ctx);
              final messenger = ScaffoldMessenger.of(context);
              final success = await provider.saveTripMetadata(updated);
              if (!mounted) return;
              if (success) {
                navigator.pop();
              }
              messenger.showSnackBar(
                SnackBar(
                  content: Text(
                    success
                        ? 'Trip details saved successfully.'
                        : (provider.errorMessage ??
                              'Failed to save trip details.'),
                  ),
                  backgroundColor: success
                      ? AppTheme.secondaryGreen
                      : Colors.redAccent,
                ),
              );
            },
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteTrip(BuildContext context, Trip trip) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'Delete Trip',
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.redAccent,
            ),
          ),
          content: Text(
            'Are you sure you want to delete "${trip.title}"? This will permanently erase the itinerary, tasks, and memories associated with it.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                final provider = Provider.of<TripProvider>(
                  context,
                  listen: false,
                );
                final success = await provider.deleteTrip(trip.id);
                if (success) {
                  if (context.mounted) {
                    Navigator.pop(context); // Pop back to trips screen
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Trip deleted successfully.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          provider.errorMessage ?? 'Failed to delete trip.',
                        ),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  // Interactive Digital PDF Receipt Modal Simulation
  void _showDigitalReceiptModal(
    BuildContext context,
    Trip activeTrip,
    Destination dest,
    DestinationExtra extra,
  ) {
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

              Navigator.pop(ctx); // Close receipt sheet
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'PDF Receipt exported successfully to Downloads! 📄✅',
                  ),
                  backgroundColor: AppTheme.secondaryGreen,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
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
                      width: 50,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Itemized Travel Receipt',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Transaction ID: LKB-${activeTrip.id.toUpperCase()}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppTheme.textSecondaryDark
                          : AppTheme.textSecondaryLight,
                      fontStyle: FontStyle.italic,
                    ),
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
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w900,
                                fontSize: 14,
                                letterSpacing: 1.5,
                                color: Colors.grey[700],
                              ),
                            ),
                            const Divider(thickness: 1.5, height: 24),
                            _receiptLine(
                              'Destination',
                              activeTrip.destinationName,
                            ),
                            _receiptLine('Travel Dates', activeTrip.dateRange),
                            _receiptLine(
                              'Travel Type',
                              activeTrip.isGroup
                                  ? 'Group Trip (${activeTrip.numTravelers} Pax)'
                                  : 'Solo Trip',
                            ),
                            const Divider(thickness: 1, height: 24),

                            // Itemized costs
                            _receiptLine(
                              '1. Base Entrance Fee',
                              dest.entranceFee,
                            ),
                            if (extra.activityPrices.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(
                                '2. Activity Fees:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                              ...extra.activityPrices.entries.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.only(
                                    left: 12.0,
                                    top: 2,
                                  ),
                                  child: _receiptLine('• ${e.key}', e.value),
                                ),
                              ),
                            ],
                            const SizedBox(height: 6),
                            _receiptLine(
                              '3. Accommodation',
                              extra.overnightFee,
                            ),
                            const SizedBox(height: 6),
                            _receiptLine(
                              '4. Transport Estimate',
                              extra.transportOptions.isNotEmpty
                                  ? extra.transportOptions.first['price']!
                                  : 'Varies',
                            ),

                            const Divider(thickness: 2, height: 32),
                            _receiptLine(
                              'Estimated Trip Base Cost',
                              '₱${totalEst.toStringAsFixed(0)}',
                              isBold: true,
                            ),
                            _receiptLine(
                              'Your Custom Saved Budget',
                              '₱${activeTrip.budget.toStringAsFixed(0)}',
                              isBold: true,
                            ),

                            if (activeTrip.isGroup) ...[
                              const SizedBox(height: 6),
                              _receiptLine(
                                'Cost Share Per Traveler',
                                '₱${(activeTrip.budget / activeTrip.numTravelers).toStringAsFixed(0)}',
                                isBold: true,
                              ),
                            ],

                            const SizedBox(height: 30),
                            // Simulated Stamp
                            Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.green,
                                    width: 3,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'LAKBAY+ APPROVED',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                    letterSpacing: 1.2,
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
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                AppTheme.secondaryGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Generating PDF Receipt... ${(progress * 100).toStringAsFixed(0)}%',
                              style: GoogleFonts.outfit(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        )
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: runDownloadProgress,
                          icon: const Icon(Icons.download_rounded),
                          label: Text(
                            'Download PDF Receipt',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
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

class PulsingDot extends StatefulWidget {
  const PulsingDot({super.key});

  @override
  State<PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<PulsingDot>
    with SingleTickerProviderStateMixin {
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

class ActivityTile extends StatefulWidget {
  final TripActivity activity;

  const ActivityTile({super.key, required this.activity});

  @override
  State<ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends State<ActivityTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(
        vertical: 6,
        horizontal: AppConstants.spaceM,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          onExpansionChanged: (val) => setState(() => _isExpanded = val),
          trailing: Icon(
            _isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
            color: AppTheme.primaryBlue,
          ),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              widget.activity.time,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlue,
              ),
            ),
          ),
          title: Text(
            widget.activity.title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          subtitle: Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 12,
                color: Colors.grey,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.activity.location,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: 12,
                top: 4,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 12),
                  const SizedBox(height: 4),
                  Text(
                    widget.activity.description,
                    style: const TextStyle(fontSize: 12, height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.payments_rounded,
                        size: 14,
                        color: AppTheme.secondaryGreen,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Est. Cost: ${widget.activity.cost}',
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.secondaryGreen,
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
    );
  }
}
