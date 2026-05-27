import 'package:flutter/material.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../services/api_service.dart';
import '../services/gemini_service.dart';

class TripProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final GeminiService _geminiService = GeminiService();

  List<Trip> _userTrips = [];
  List<Destination> _destinations = [];
  Trip? _latestGeneratedTrip;
  bool _isLoading = false;
  String? _errorMessage;
  Destination? _activePlanDestination;

  List<Trip> get userTrips => _userTrips;
  List<Destination> get destinations => _destinations;
  Trip? get latestGeneratedTrip => _latestGeneratedTrip;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  Destination? get activePlanDestination => _activePlanDestination;

  void setActivePlanDestination(Destination? dest) {
    _activePlanDestination = dest;
    notifyListeners();
  }

  // Initialize data (mocked)
  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _destinations = await _apiService.fetchDestinations();
      _userTrips = await _apiService.fetchUserTrips();
    } catch (e) {
      _errorMessage = 'Failed to load travel data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Generate an itinerary with Gemini AI (UI Mocked)
  Future<Trip?> generatePlan({
    required String district,
    required int days,
    required String vibe,
    required double budget,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _latestGeneratedTrip = null;
    notifyListeners();

    try {
      final trip = await _geminiService.generateItinerary(
        destinationDistrict: district,
        durationDays: days,
        travelVibe: vibe,
        budgetLimit: budget,
      );
      _latestGeneratedTrip = trip;
      return trip;
    } catch (e) {
      _errorMessage = 'AI planning failed. Please try again.';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Save the AI generated itinerary into user's trip list
  Future<bool> saveGeneratedTrip() async {
    if (_latestGeneratedTrip == null) return false;

    _isLoading = true;
    notifyListeners();

    try {
      final success = await _apiService.createTrip(_latestGeneratedTrip!);
      if (success) {
        _userTrips.insert(0, _latestGeneratedTrip!);
        _latestGeneratedTrip = null;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      _errorMessage = 'Failed to save itinerary.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a direct manual trip
  void addNewTrip(Trip trip) {
    _userTrips.insert(0, trip);
    notifyListeners();
  }

  // Add an activity dynamically to an existing trip
  void addActivityToTrip(String tripId, TripActivity activity, {int day = 1}) {
    final tripIndex = _userTrips.indexWhere((t) => t.id == tripId);
    if (tripIndex != -1) {
      final trip = _userTrips[tripIndex];
      final currentItinerary = Map<int, List<TripActivity>>.from(trip.itinerary);
      final dayActivities = List<TripActivity>.from(currentItinerary[day] ?? []);
      dayActivities.add(activity);
      currentItinerary[day] = dayActivities;
      
      _userTrips[tripIndex] = Trip(
        id: trip.id,
        title: trip.title,
        destinationName: trip.destinationName,
        dateRange: trip.dateRange,
        budget: trip.budget, // Keep current budget
        imageUrl: trip.imageUrl,
        itinerary: currentItinerary,
      );
      notifyListeners();
    }
  }
}
