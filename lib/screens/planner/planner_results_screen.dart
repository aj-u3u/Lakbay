import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/trip_provider.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../models/trip.dart';
import '../../models/destination.dart';
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

class PlannerResultsScreen extends StatefulWidget {
  final int durationDays;
  final Trip? trip;
  const PlannerResultsScreen({super.key, required this.durationDays, this.trip});

  @override
  State<PlannerResultsScreen> createState() => _PlannerResultsScreenState();
}

class _PlannerResultsScreenState extends State<PlannerResultsScreen> {
  Position? _userPosition;
  StreamSubscription<Position>? _positionStreamSubscription;
  final MapController _mapController = MapController();
  String _commuterStartPoint = 'Current Location';
  List<LatLng> _roadGeometryPoints = [];
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
      final isSamal = dest.name.toLowerCase().contains('samal') || 
                      dest.location.toLowerCase().contains('samal') || 
                      widget.trip?.destinationName.toLowerCase().contains('samal') == true;

      List<Map<String, dynamic>> destinationsList = [];
      if (isSamal) {
        destinationsList.add({
          "destination_id": -1,
          "name": "Sasa Wharf",
          "lat": 7.1017,
          "lng": 125.6601
        });
        destinationsList.add({
          "destination_id": -2,
          "name": "Babak Port",
          "lat": 7.1189,
          "lng": 125.6822
        });
      }
      destinationsList.add({
        "destination_id": dest.id,
        "name": dest.name,
        "lat": dest.latitude,
        "lng": dest.longitude
      });

      final response = await ApiService().optimizeRoute(
        destinations: destinationsList,
        startLat: startLocation.latitude,
        startLng: startLocation.longitude,
        startName: 'Start Point',
        returnToStart: false,
      );

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
        _isLoadingRoute = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _requestLocation();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
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
      _positionStreamSubscription = Geolocator.getPositionStream(
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
    if (titleLower.contains('low budget') || titleLower.contains('low-budget') || titleLower.contains('cheap')) {
      return 'Low Budget';
    } else if (titleLower.contains('balanced budget') || titleLower.contains('balanced-budget') || titleLower.contains('balanced')) {
      return 'Balanced Budget';
    } else if (titleLower.contains('high budget') || titleLower.contains('high-budget') || titleLower.contains('premium') || titleLower.contains('luxury')) {
      return 'High Budget';
    } else {
      final perPerson = trip.budget / (trip.numTravelers > 0 ? trip.numTravelers : 1);
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

  String _formatCurrency(double amount) {
    final str = amount.toStringAsFixed(0);
    final reg = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
    return str.replaceAllMapped(reg, (Match m) => '${m[1]},');
  }

  double _calculateOptionCost(Destination dest, String category) {
    final extra = dest.extra;
    final isLow = category == 'Low Budget';
    final isHigh = category == 'High Budget';

    // 1. Transport
    double totalTransport = 0.0;
    final transOpt = _getBudgetTransport(dest, category);
    if (transOpt != null) {
      totalTransport = _parsePrice(transOpt['price'] ?? '0');
    }

    // 2. Meals
    final double mealsPerDay = isLow ? 150.0 * 3 : isHigh ? 600.0 * 3 : 300.0 * 3;
    final double totalMeals = mealsPerDay * widget.durationDays;

    // 3. Activities
    double totalActivities = 0.0;
    final prices = extra.activityPrices;
    if (prices.isNotEmpty) {
      final parsedPrices = prices.values.map((p) => _parsePrice(p)).toList();
      if (isLow) {
        parsedPrices.sort();
        totalActivities = parsedPrices.first;
      } else if (isHigh) {
        totalActivities = parsedPrices.reduce((sum, p) => sum + p);
      } else {
        final avg = parsedPrices.reduce((sum, p) => sum + p) / parsedPrices.length;
        totalActivities = avg * (parsedPrices.length > 1 ? 2 : 1);
      }
    }

    // 4. Accommodation
    double totalAccomm = 0.0;
    final accommOpt = _getBudgetAccommodation(dest, category);
    if (accommOpt != null && widget.durationDays > 1) {
      final pricePerNight = _parsePrice(accommOpt['price'] ?? '0');
      totalAccomm = pricePerNight * (widget.durationDays - 1);
    }

    // 5. Environmental & Entrance Fees
    final double environmentalFee = _parsePrice(extra.environmentalFee);
    final double entranceFee = _parsePrice(dest.entranceFee);

    return totalTransport + totalMeals + totalActivities + totalAccomm + environmentalFee + entranceFee;
  }

  Map<String, String>? _getBudgetAccommodation(Destination dest, String budgetStyle) {
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

  Map<String, String>? _getBudgetTransport(Destination dest, String budgetStyle) {
    final transOptions = dest.extra.transportOptions;
    if (transOptions.isEmpty) return null;

    final sortedTrans = List<Map<String, String>>.from(transOptions)
      ..sort((a, b) {
        return _parsePrice(a['price'] ?? '0').compareTo(_parsePrice(b['price'] ?? '0'));
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

  List<Map<String, String>> _getCommuterSteps(Destination dest, String startPoint, String budgetStyle, Position? userPos) {
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
          'type': '${firstMile['vehicle']} (${firstMile['distance'].toStringAsFixed(1)} km)',
          'cost': '₱${firstMile['cost'].toStringAsFixed(0)}',
          'duration': firstMile['duration'],
        }
      ];

      for (int i = 0; i < baseSteps.length; i++) {
        final originalStep = baseSteps[i];
        final cleanStepName = originalStep['step']!.replaceFirst(RegExp(r'^\d+\.\s*'), '');
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
    final isSamal = lowerName.contains('samal') || lowerLoc.contains('samal') || lowerName.contains('pearl farm') || lowerName.contains('hagimit');
    final isEden = lowerName.contains('eden');
    final isMati = lowerName.contains('dahican') || lowerLoc.contains('mati');
    final isMalagos = lowerName.contains('malagos') || lowerName.contains('eagle') || lowerLoc.contains('calinan');

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
            'cost': dest.extra.environmentalFee.isNotEmpty ? dest.extra.environmentalFee : '₱30',
            'duration': 'Instant',
          }
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
            'cost': dest.extra.environmentalFee.isNotEmpty ? dest.extra.environmentalFee : '₱30',
            'duration': 'Instant',
          }
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
          }
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
          }
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
          }
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
          }
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
          }
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
          }
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
          }
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
          }
        ];
      }
    }
  }

  Widget _buildCommuterRouteCard(Destination dest, String budgetStyle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final steps = _getCommuterSteps(dest, _commuterStartPoint, budgetStyle, _userPosition);
    double totalCost = 0.0;
    for (final step in steps) {
      final priceText = step['cost'] ?? '0';
      if (priceText.toLowerCase().contains('included') || priceText.toLowerCase().contains('free')) {
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
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.primaryBlue.withValues(alpha: 0.15)),
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
                    Icon(Icons.commute_rounded, color: isDark ? Colors.white : AppTheme.primaryBlue, size: 20),
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
                // Commuter Start Point Dropdown selection
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.1) : AppTheme.primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _commuterStartPoint,
                      dropdownColor: Theme.of(context).cardColor,
                      icon: Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: isDark ? Colors.white : AppTheme.primaryBlue),
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : AppTheme.primaryBlue,
                      ),
                      items: ['Current Location', 'Panabo', 'Davao City'].map((String val) {
                        return DropdownMenuItem<String>(
                          value: val,
                          child: Text(
                            val == 'Current Location' ? '📍 Current Location' : val,
                            style: GoogleFonts.outfit(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppTheme.textPrimaryDark : AppTheme.primaryBlue,
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (newVal) {
                        if (newVal != null) {
                          setState(() {
                            _commuterStartPoint = newVal;
                          });
                          if (newVal == 'Current Location' && _userPosition == null) {
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
            style: GoogleFonts.outfit(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
          ),
          const SizedBox(height: AppConstants.spaceL),
          // Commuter steps vertical timeline list
          ...List.generate(steps.length, (index) {
            final step = steps[index];
            final isLast = index == steps.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline left dot & connector line
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
                // Step Content details
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
                                '${step['type']} • ${step['duration']}',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: GoogleFonts.outfit(
                                  fontSize: 11,
                                  color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              step['cost'] ?? '',
                              style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryGreen),
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
              color: isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.secondaryGreen.withValues(alpha: 0.06),
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

  @override
  Widget build(BuildContext context) {
    return Consumer<TripProvider>(
      builder: (context, provider, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final trip = widget.trip ?? provider.latestGeneratedTrip ?? Trip.mockTrips.first;
        final bool isTripSaved = provider.userTrips.any((t) => t.id == trip.id);

        // Resolve matching Destination model
        final lowerSearch = trip.destinationName.toLowerCase();
        final List<Destination> allDests = [
          ...provider.destinations,
          ...Destination.davaoDestinations,
        ];
        final Destination dest = allDests.firstWhere(
          (d) => lowerSearch.contains(d.name.toLowerCase()) ||
                 d.name.toLowerCase().contains(lowerSearch) ||
                 trip.title.toLowerCase().contains(d.name.toLowerCase()),
          orElse: () => provider.activePlanDestination ?? allDests.firstWhere((d) => d.id == 1, orElse: () => Destination.davaoDestinations.first),
        );

        final budgetStyle = _deriveBudgetStyle(trip);
        final accommOpt = _getBudgetAccommodation(dest, budgetStyle);
        final transOpt = _getBudgetTransport(dest, budgetStyle);

        // Define starting coordinates based on commuter starting point
        LatLng startLocation;
        String startName;
        if (_commuterStartPoint == 'Panabo') {
          startLocation = const LatLng(7.3079, 125.6811); // Panabo Terminal
          startName = 'Panabo Terminal';
        } else if (_commuterStartPoint == 'Current Location' && _userPosition != null) {
          startLocation = LatLng(_userPosition!.latitude, _userPosition!.longitude);
          startName = 'Your Location';
        } else {
          startLocation = const LatLng(7.0706, 125.6092); // Davao City Center
          startName = _commuterStartPoint == 'Current Location' ? 'Davao City Center (GPS Loading...)' : 'Davao City Center';
        }

        // Trigger road route fetching from OSRM
        _fetchRoadRoute(startLocation, dest);

        // Generate optimized route coordinates with barge crossing if destination is in Samal Island
        final isSamal = lowerSearch.contains('samal') || dest.location.toLowerCase().contains('samal') || dest.name.toLowerCase().contains('pearl farm') || dest.name.toLowerCase().contains('hagimit');

        final List<LatLng> routePoints = [startLocation];
        if (isSamal) {
          // Commuter Barge Crossing points: start -> Sasa Wharf -> Babak Port -> Samal Destination
          routePoints.add(const LatLng(7.1017, 125.6601)); // Sasa Wharf
          routePoints.add(const LatLng(7.1189, 125.6822)); // Babak Port
        }
        routePoints.add(LatLng(dest.latitude, dest.longitude));

        final double minLowCostPerPerson = _calculateOptionCost(dest, 'Low Budget');
        final double minLowCost = trip.isGroup ? minLowCostPerPerson * trip.numTravelers * 0.8 : minLowCostPerPerson;
        final double perPersonBudget = trip.budget / (trip.numTravelers > 0 ? trip.numTravelers : 1);
        final double requiredMinCostPerPerson = trip.isGroup ? minLowCostPerPerson * 0.8 : minLowCostPerPerson;
        final bool isBudgetTooLow = perPersonBudget < requiredMinCostPerPerson;

        final Color budgetBadgeColor = budgetStyle == 'Low Budget'
            ? Colors.green[700]!
            : budgetStyle == 'High Budget'
                ? Colors.red[700]!
                : Colors.amber[700]!;

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
                  title: Text(
                    dest.name,
                    style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      Destination.loadImage(
                        dest.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (ctx, err, stack) => Container(color: AppTheme.primaryBlue),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, AppTheme.primaryBlue.withValues(alpha: 0.9)],
                          ),
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
                      // Budget Too Low Warning Alert
                      if (isBudgetTooLow) ...[
                        Container(
                          margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
                          padding: const EdgeInsets.all(AppConstants.spaceM),
                          decoration: BoxDecoration(
                            color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C1414) : Colors.red[50]!,
                            borderRadius: BorderRadius.circular(AppConstants.radiusL),
                            border: Border.all(color: Theme.of(context).brightness == Brightness.dark ? Colors.red[900]! : Colors.red[300]!),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              )
                            ],
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.warning_amber_rounded, color: Colors.red[700]!, size: 22),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Budget Warning',
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.red[200]! : Colors.red[900]!,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Your set budget of ₱${_formatCurrency(trip.budget)} is lower than the minimum estimated expense of ₱${_formatCurrency(minLowCost)} for this trip. We highly recommend saving more money before traveling, to ensure a safe, comfortable, and stress-free journey!',
                                      style: GoogleFonts.outfit(
                                        fontSize: 11,
                                        color: Theme.of(context).brightness == Brightness.dark ? Colors.red[100]! : Colors.red[800]!,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // 1. Details Block: Cover & Info Card
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spaceL),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.secondaryGreen.withValues(alpha: 0.12),
                              AppTheme.accentTeal.withValues(alpha: 0.06)
                            ],
                          ),
                          borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                          border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.25)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: budgetBadgeColor,
                                    borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                                  ),
                                  child: Text(
                                    budgetStyle,
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
                            Text(
                              trip.title,
                              style: GoogleFonts.outfit(
                                  fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryBlue),
                            ),
                            const SizedBox(height: 8),
                            _infoFactRow(Icons.place_rounded, dest.name, isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                            const SizedBox(height: 6),
                            _infoFactRow(Icons.location_on_rounded, dest.location, isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                            const SizedBox(height: 6),
                            _infoFactRow(
                                Icons.access_time_filled_rounded, dest.operatingHours, isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                            const SizedBox(height: 6),
                            _infoFactRow(Icons.payments_rounded, 'Entrance: ${dest.entranceFee}', AppTheme.secondaryGreen,
                                bold: true),
                            const SizedBox(height: AppConstants.spaceM),
                            Divider(color: Theme.of(context).dividerColor, height: 1),
                            const SizedBox(height: AppConstants.spaceM),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                _infoDetailChip(Icons.calendar_month_rounded, '${widget.durationDays} Days'),
                                _infoDetailChip(Icons.calendar_today_rounded, trip.dateRange),
                                _infoDetailChip(Icons.people_alt_rounded,
                                    trip.isGroup ? '${trip.numTravelers} Guests' : 'Solo Travel'),
                                _infoDetailChip(Icons.wb_sunny_rounded, dest.category),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Text(
                                  'Estimated Budget: ₱${_formatCurrency(trip.budget)}',
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.secondaryGreen,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 2. Interactive Route Optimization Map
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Route Optimization',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI optimized paths calculated for your journey.',
                        style: GoogleFonts.outfit(fontSize: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                      ),
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
                                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName: 'com.lakbay.plus',
                                ),
                                PolylineLayer(
                                  polylines: [
                                    Polyline(
                                      points: _roadGeometryPoints.isNotEmpty ? _roadGeometryPoints : routePoints,
                                      color: AppTheme.primaryBlue,
                                      strokeWidth: 4,
                                    ),
                                  ],
                                ),
                                MarkerLayer(
                                  markers: [
                                    // Start marker
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
                                      // Sasa Wharf Barge Crossing Marker
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
                                              )
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
                                    // Destination Marker
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
                            // Map Banner overlay
                            Positioned(
                              top: 10,
                              left: 10,
                              right: 10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    )
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.navigation_rounded, color: isDark ? Colors.white : AppTheme.primaryBlue, size: 16),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Optimized Route: $startName ➔ ${dest.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.outfit(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : AppTheme.primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Recenter map button
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: FloatingActionButton.small(
                                heroTag: 'recenter_planner_map',
                                backgroundColor: Theme.of(context).cardColor,
                                foregroundColor: Theme.of(context).colorScheme.primary,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                onPressed: () {
                                  _mapController.move(LatLng(dest.latitude, dest.longitude), 11.5);
                                },
                                child: const Icon(Icons.center_focus_strong_rounded, size: 18),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // 3. Accommodation & Transportation details
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Budget-Matched Bookings',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                      Row(
                        children: [
                          // Accommodation Option Card
                          Expanded(
                            child: Container(
                              height: 140,
                              padding: const EdgeInsets.all(AppConstants.spaceM),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                                boxShadow: AppConstants.premiumShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.hotel_rounded, color: budgetBadgeColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Lodging',
                                        style: GoogleFonts.outfit(
                                            fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryBlue),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    accommOpt != null ? accommOpt['type'] ?? 'Standard Room' : 'Standard Lodging',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                  ),
                                  const Spacer(),
                                  Text(
                                    accommOpt != null ? accommOpt['price'] ?? 'Free' : 'Included in trip',
                                    style: GoogleFonts.outfit(
                                        fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: AppConstants.spaceM),
                          // Transportation Option Card
                          Expanded(
                            child: Container(
                              height: 140,
                              padding: const EdgeInsets.all(AppConstants.spaceM),
                              decoration: BoxDecoration(
                                color: Theme.of(context).cardColor,
                                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
                                boxShadow: AppConstants.premiumShadow,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.directions_bus_rounded, color: budgetBadgeColor, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Transport',
                                        style: GoogleFonts.outfit(
                                            fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryBlue),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    transOpt != null ? transOpt['vehicle'] ?? 'Public Transit' : 'Local Commute',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                        fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    transOpt != null
                                        ? 'Route: ${transOpt['from'] ?? ''} ➔ ${transOpt['to'] ?? ''}'
                                        : 'City Center ➔ Destination',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(fontSize: 10, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                  ),
                                  const Spacer(),
                                  if (trip.isGroup && trip.numTravelers > 1) ...[
                                    // Group: show per pax + total
                                    Text(
                                      transOpt != null ? '${transOpt['price'] ?? 'Free'}/pax' : 'Free/pax',
                                      style: GoogleFonts.outfit(
                                          fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen),
                                    ),
                                    Builder(builder: (ctx) {
                                      final perPax = _parsePrice(transOpt?['price'] ?? '0');
                                      final total = perPax * trip.numTravelers;
                                      return Text(
                                        'Total: ₱${total.toStringAsFixed(0)} for ${trip.numTravelers} pax',
                                        style: GoogleFonts.outfit(
                                            fontSize: 9, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                                      );
                                    }),
                                  ] else
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            transOpt != null ? transOpt['price'] ?? 'Free' : 'Free',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: GoogleFonts.outfit(
                                                fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.secondaryGreen),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Flexible(
                                          child: Text(
                                            transOpt != null ? transOpt['duration'] ?? '1 hr' : '1 hr',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                            style: GoogleFonts.outfit(fontSize: 10, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
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

                      // 4. Day-by-Day Itinerary Header
                      const SizedBox(height: AppConstants.spaceXL),
                      Text(
                        'Day-by-Day Itinerary',
                        style: GoogleFonts.outfit(
                            fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : AppTheme.primaryBlue),
                      ),
                      const SizedBox(height: AppConstants.spaceM),
                    ],
                  ),
                ),
              ),

              // Day-by-day Itinerary List (Dynamic Duration length)
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, dayIndex) {
                    final dayNum = dayIndex + 1;
                    final activities = trip.itinerary[dayNum] ?? [];
                    return Padding(
                      padding:
                          const EdgeInsets.fromLTRB(AppConstants.spaceL, 0, AppConstants.spaceL, AppConstants.spaceL),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                            ),
                            child: Text(
                              'Day $dayNum',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceM),
                          if (activities.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(AppConstants.spaceL),
                              child: Center(
                                child: Text(
                                  'Relax and explore at your own pace today!',
                                  style: GoogleFonts.outfit(color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight, fontSize: 13),
                                ),
                              ),
                            )
                          else
                            ...activities.map((activity) => _buildItineraryTile(activity)),
                        ],
                      ),
                    );
                  },
                  childCount: widget.durationDays,
                ),
              ),

              // 5. Travel tips panel
              if (dest.extra.travelNotes.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceL, vertical: AppConstants.spaceM),
                    child: Container(
                      padding: const EdgeInsets.all(AppConstants.spaceL),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white.withValues(alpha: 0.03) : AppTheme.primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
                        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.primaryBlue.withValues(alpha: 0.15)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_rounded, color: isDark ? Colors.white : AppTheme.primaryBlue, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Important Travel Tips & Notes',
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.primaryBlue,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppConstants.spaceM),
                          ...dest.extra.travelNotes.map((note) => Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(Icons.check_circle_outline_rounded,
                                        color: AppTheme.secondaryGreen, size: 14),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        note,
                                        style: GoogleFonts.outfit(
                                          fontSize: 12,
                                          height: 1.4,
                                          color: isDark ? AppTheme.textPrimaryDark : AppTheme.textPrimaryLight,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              )),
                        ],
                      ),
                    ),
                  ),
                ),

              // Save to My Trips & Regenerate Actions
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(AppConstants.spaceXL),
                  child: Column(
                    children: [
                      if (isTripSaved) ...[
                        // Itinerary Saved ✓ Banner
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          margin: const EdgeInsets.only(bottom: AppConstants.spaceM),
                          decoration: BoxDecoration(
                            color: AppTheme.secondaryGreen.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: AppTheme.secondaryGreen, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Itinerary Saved ✓',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.secondaryGreen,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Manage Trip button
                        CustomButton(
                          label: 'Manage Trip',
                          onPressed: () {
                            Navigator.pushReplacementNamed(
                              context,
                              AppRoutes.groupDashboard,
                              arguments: trip,
                            );
                          },
                          variant: ButtonVariant.primary,
                          width: double.infinity,
                          leadingIcon: Icons.dashboard_customize_rounded,
                        ),
                      ] else ...[
                        // Save Itinerary to My Trips button
                        CustomButton(
                          label: 'Save Itinerary to My Trips',
                          onPressed: () async {
                            final provider = context.read<TripProvider>();
                            
                            // Show a persistent loading indicator dialog
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const Center(
                                child: CircularProgressIndicator(color: AppTheme.primaryBlue),
                              ),
                            );

                            final success = await provider.addNewTrip(trip);
                            
                            if (context.mounted) {
                              Navigator.pop(context); // Dismiss loading dialog
                              
                              if (success) {
                                Navigator.pop(context); // Close results screen
                                
                                // Auto-route to GroupDashboardScreen
                                Navigator.pushNamed(
                                  context,
                                  AppRoutes.groupDashboard,
                                  arguments: trip,
                                );

                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Trip saved successfully! 🎉'),
                                    backgroundColor: AppTheme.secondaryGreen,
                                  ),
                                );
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(provider.errorMessage ?? 'Failed to save itinerary. Please try again.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          variant: ButtonVariant.primary,
                          width: double.infinity,
                          leadingIcon: Icons.bookmark_add_rounded,
                        ),
                      ],
                      const SizedBox(height: AppConstants.spaceM),
                      CustomButton(
                        label: 'Go Back & Regenerate',
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

  Widget _buildItineraryTile(TripActivity activity) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Elegant Icons for Meal times & Activities
    IconData tileIcon = Icons.explore_rounded;
    Color iconBg = AppTheme.secondaryGreen.withValues(alpha: 0.12);
    Color iconColor = AppTheme.secondaryGreen;

    final titleLower = activity.title.toLowerCase();
    final descLower = activity.description.toLowerCase();

    if (titleLower.contains('breakfast') || descLower.contains('breakfast')) {
      tileIcon = Icons.breakfast_dining_rounded;
      iconBg = Colors.amber.withValues(alpha: 0.12);
      iconColor = Colors.amber[800]!;
    } else if (titleLower.contains('lunch') || descLower.contains('lunch')) {
      tileIcon = Icons.restaurant_rounded;
      iconBg = Colors.orange.withValues(alpha: 0.12);
      iconColor = Colors.orange[800]!;
    } else if (titleLower.contains('dinner') || descLower.contains('dinner')) {
      tileIcon = Icons.dinner_dining_rounded;
      iconBg = Colors.purple.withValues(alpha: 0.12);
      iconColor = Colors.purple[800]!;
    } else if (titleLower.contains('depart') || titleLower.contains('transit') || titleLower.contains('travel to')) {
      tileIcon = Icons.directions_car_rounded;
      iconBg = AppTheme.primaryBlue.withValues(alpha: 0.12);
      iconColor = AppTheme.primaryBlue;
    } else if (titleLower.contains('hotel') || titleLower.contains('check-in') || titleLower.contains('resort')) {
      tileIcon = Icons.home_work_rounded;
      iconBg = AppTheme.accentTeal.withValues(alpha: 0.12);
      iconColor = AppTheme.accentTeal;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time badge
          Column(
            children: [
              Container(
                width: 54,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                decoration: BoxDecoration(
                  color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  activity.time,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryGreen,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppConstants.spaceM),
          // Activity Detail card
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusL),
                border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.15)),
                boxShadow: AppConstants.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: iconBg,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(tileIcon, size: 14, color: iconColor),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activity.title,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : AppTheme.primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    activity.description,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Divider(color: Theme.of(context).dividerColor, height: 1),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.location_on_rounded, size: 12, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          activity.location,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.outfit(fontSize: 11, color: isDark ? AppTheme.textSecondaryDark : AppTheme.textSecondaryLight),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        activity.cost,
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          color: AppTheme.secondaryGreen,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _infoFactRow(IconData icon, String text, Color color, {bool bold = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
              fontSize: 12,
              color: color,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoDetailChip(IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: isDark ? Colors.white : AppTheme.primaryBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.outfit(fontSize: 11, color: isDark ? Colors.white : AppTheme.primaryBlue, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
