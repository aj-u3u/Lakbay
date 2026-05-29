import 'package:flutter/material.dart';
import '../models/destination.dart';
import '../models/trip.dart';
import '../models/app_notification.dart';
import '../models/planner_draft.dart';
import '../services/api_service.dart';

class TripProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Trip> _userTrips = [];
  List<Destination> _destinations = [];
  Trip? _latestGeneratedTrip;
  bool _isLoading = false;
  String? _errorMessage;
  Destination? _activePlanDestination;

  // Active planning draft state
  PlannerDraft? _activeDraft;

  PlannerDraft? get activeDraft => _activeDraft;

  void updateDraft(PlannerDraft? draft) {
    _activeDraft = draft;
    notifyListeners();
  }

  // In-app Notifications State
  List<AppNotification> _notifications = AppNotification.mockNotifications;

  List<AppNotification> get notifications => _notifications;

  int get unreadNotificationCount => _notifications.where((n) => n.isNew).length;

  void markNotificationAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      final item = _notifications[index];
      _notifications[index] = AppNotification(
        id: item.id,
        title: item.title,
        body: item.body,
        time: item.time,
        icon: item.icon,
        isNew: false,
        type: item.type,
      );
      notifyListeners();
    }
  }

  void markAllNotificationsAsRead() {
    _notifications = _notifications.map((n) => AppNotification(
      id: n.id,
      title: n.title,
      body: n.body,
      time: n.time,
      icon: n.icon,
      isNew: false,
      type: n.type,
    )).toList();
    notifyListeners();
  }

  String? _latestChatResponse;
  List<Destination> _latestRecommendations = [];

  List<Trip> get userTrips => _userTrips;
  List<Destination> get destinations => _destinations;
  Trip? get latestGeneratedTrip => _latestGeneratedTrip;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Prefilled prompt for deep-linking mood planning
  String? _activePlanningMoodPrompt;

  String? get activePlanningMoodPrompt => _activePlanningMoodPrompt;

  void setActivePlanningMoodPrompt(String? prompt) {
    _activePlanningMoodPrompt = prompt;
    notifyListeners();
  }

  Destination? get activePlanDestination => _activePlanDestination;

  String? get latestChatResponse => _latestChatResponse;
  List<Destination> get latestRecommendations => _latestRecommendations;

  void setActivePlanDestination(Destination? dest) {
    _activePlanDestination = dest;
    notifyListeners();
  }

  // Initialize data (mocked/API)
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

  // Generate an itinerary with Gemini AI (FastAPI Integration)
  Future<Trip?> generatePlan({
    required String district,
    required int days,
    required String vibe,
    required double budget,
    bool isGroup = false,
    int numTravelers = 1,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _latestGeneratedTrip = null;
    _latestChatResponse = null;
    _latestRecommendations = [];
    notifyListeners();

    try {
      // Construct prompt matching backend travel search intent
      final prompt = 'I want to travel to $district for $days days. My vibe is $vibe and my budget is ₱${budget.toStringAsFixed(0)}. Please plan this trip for me.';
      
      final responseMap = await _apiService.chatWithAI(prompt);
      
      if (responseMap != null) {
        _latestChatResponse = responseMap['chat_response'];
        final List<dynamic> results = responseMap['results'] ?? [];
        _latestRecommendations = results.map((r) => Destination.fromJson(r)).toList();
        
        final targetDestName = _latestRecommendations.isNotEmpty ? _latestRecommendations.first.name : district;
        final targetImageUrl = _latestRecommendations.isNotEmpty ? _latestRecommendations.first.imageUrl : 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80';
        
        // Build day-to-day agenda in Dart dynamically
        final Map<int, List<TripActivity>> agenda = {};
        for (int day = 1; day <= days; day++) {
          agenda[day] = [
            TripActivity(
              time: '08:30 AM',
              title: 'Explore $targetDestName',
              description: 'Start with scenic morning trails and cultural guidance.',
              cost: '₱150 - ₱300',
              location: targetDestName,
            ),
            TripActivity(
              time: '12:30 PM',
              title: 'Local Lunch Feast',
              description: 'Try the fresh seafood grills and fruit varieties.',
              cost: '₱200 - ₱400',
              location: 'Nearby Diner',
            ),
            TripActivity(
              time: '03:00 PM',
              title: 'Afternoon $vibe Spot',
              description: 'Custom sightseeing matching your requested $vibe preference.',
              cost: '₱250',
              location: targetDestName,
            ),
            TripActivity(
              time: '07:00 PM',
              title: 'Dinner & Relaxation',
              description: 'Relax and unwind at local food districts and night spots.',
              cost: '₱400',
              location: 'Food Street',
            ),
          ];
        }

        _latestGeneratedTrip = Trip(
          id: 'ai-trip-${DateTime.now().millisecondsSinceEpoch}',
          title: 'Custom $vibe Adventure in $district',
          destinationName: '$district, Davao Region',
          dateRange: 'Flexible Dates (AI Generated)',
          budget: budget,
          imageUrl: targetImageUrl,
          itinerary: agenda,
          isGroup: isGroup,
          numTravelers: numTravelers,
        );

        notifyListeners();
        return _latestGeneratedTrip;
      }
    } catch (e) {
      _errorMessage = 'AI planning failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }

  // Free-form conversation with AI Chatbot
  Future<bool> sendFreeFormChat(String text) async {
    _isLoading = true;
    _errorMessage = null;
    _latestChatResponse = null;
    _latestRecommendations = [];
    notifyListeners();

    try {
      final responseMap = await _apiService.chatWithAI(text);
      if (responseMap != null) {
        _latestChatResponse = responseMap['chat_response'];
        final List<dynamic> results = responseMap['results'] ?? [];
        _latestRecommendations = results.map((r) => Destination.fromJson(r)).toList();
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = 'Failed to chat with AI.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return false;
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

  // Update an existing trip in the provider
  void updateTrip(Trip updatedTrip) {
    final index = _userTrips.indexWhere((t) => t.id == updatedTrip.id);
    if (index != -1) {
      _userTrips[index] = updatedTrip;
      notifyListeners();
    }
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
      
      _userTrips[tripIndex] = trip.copyWith(itinerary: currentItinerary);
      notifyListeners();
    }
  }
}
