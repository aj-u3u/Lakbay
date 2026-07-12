import 'package:flutter/material.dart';
import '../models/destination.dart';
import '../models/grouped_destinations.dart';
import '../models/trip.dart';
import '../models/app_notification.dart';
import '../models/planner_draft.dart';
import '../services/api_service.dart';

class TripProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Trip> _userTrips = [];
  List<Destination> _destinations = [];
  List<GroupedDestinations> _groupedDestinations = [];
  Trip? _latestGeneratedTrip;
  bool _isLoading = false;
  String? _errorMessage;
  Destination? _activePlanDestination;
  // TODO: persist bookmarks to Neon DB (bookmarks table)
  final List<int> _bookmarkedDestinationIds = [];


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
  List<GroupedDestinations> get groupedDestinations => _groupedDestinations;
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

  List<int> get bookmarkedDestinationIds => _bookmarkedDestinationIds;

  bool isBookmarked(int id) {
    return _bookmarkedDestinationIds.contains(id);
  }

  void toggleBookmark(int id) {
    if (_bookmarkedDestinationIds.contains(id)) {
      _bookmarkedDestinationIds.remove(id);
    } else {
      _bookmarkedDestinationIds.add(id);
      _apiService.recordInteraction(id, 'save');
    }
    notifyListeners();
  }

  // Initialize data (mocked/API)
  Future<void> loadInitialData() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _destinations = await _apiService.fetchDestinations();
      _groupedDestinations = await _apiService.fetchGroupedDestinations();
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
      final responseMap = await _apiService.generateAIItinerary(
        destinationName: district,
        numDays: days,
        budget: budget,
        numAdults: isGroup ? numTravelers : 1,
        numChildren: 0,
        childAges: '',
        interests: [vibe],
      );

      if (responseMap != null) {
        final String title = responseMap['title'] ?? '$vibe Adventure in $district';
        final String destinationName = responseMap['destination'] ?? '$district, Davao Region';
        
        // Find a matching image URL from local destinations list if possible
        String targetImageUrl = 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80';
        if (_destinations.isNotEmpty) {
          try {
            final match = _destinations.firstWhere(
              (d) => d.district.toLowerCase().contains(district.toLowerCase()) || 
                     d.name.toLowerCase().contains(district.toLowerCase()),
              orElse: () => _destinations.first,
            );
            targetImageUrl = match.imageUrl;
          } catch (_) {}
        }

        // Reconstruct itinerary map
        final Map<String, dynamic> itineraryJson = responseMap['itinerary'] ?? {};
        final Map<int, List<TripActivity>> agenda = {};
        
        itineraryJson.forEach((dayStr, list) {
          final day = int.tryParse(dayStr) ?? 1;
          final List<dynamic> actList = list;
          agenda[day] = actList
              .map(
                (act) => TripActivity(
                  time: act['time'] ?? '',
                  title: act['title'] ?? '',
                  description: act['description'] ?? '',
                  cost: act['cost'] ?? 'Free',
                  location: act['location'] ?? '',
                ),
              )
              .toList();
        });

        _latestGeneratedTrip = Trip(
          id: 'ai-trip-${DateTime.now().millisecondsSinceEpoch}',
          title: title,
          destinationName: destinationName,
          dateRange: 'Flexible Dates (AI Generated)',
          budget: budget,
          imageUrl: targetImageUrl,
          itinerary: agenda,
          isGroup: isGroup,
          numTravelers: numTravelers,
          members: isGroup ? Trip.seedMembers(numTravelers) : const [],
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
      String enrichedPrompt = text;
      if (_latestGeneratedTrip != null) {
        final trip = _latestGeneratedTrip!;
        final itinerarySummary = StringBuffer();
        trip.itinerary.forEach((day, activities) {
          itinerarySummary.write('\nDay $day:');
          for (var act in activities) {
            itinerarySummary.write('\n - ${act.time}: ${act.title} at ${act.location} (${act.cost}) - ${act.description}');
          }
        });

        enrichedPrompt = '[Current Active Trip Context:\n'
            'Destination: ${trip.destinationName}\n'
            'Budget: ₱${trip.budget.toStringAsFixed(0)}\n'
            'Days: ${trip.itinerary.length}\n'
            'Group Trip: ${trip.isGroup} (Travelers: ${trip.numTravelers})\n'
            'Itinerary:$itinerarySummary]\n\n'
            'User follow-up message / request: $text';
      }

      final responseMap = await _apiService.chatWithAI(enrichedPrompt);
      if (responseMap != null) {
        _latestChatResponse = responseMap['chat_response'];
        final List<dynamic> results = responseMap['results'] ?? [];
        _latestRecommendations = results.map((r) => Destination.fromJson(r)).toList();

        final mode = responseMap['mode'] as String?;
        if (mode == 'travel' && _latestRecommendations.isNotEmpty) {
          final prefs = responseMap['parsed_preferences'] ?? {};
          final int days = prefs['duration_days'] ?? 3;
          final double budget = (prefs['total_budget'] as num?)?.toDouble() ?? (prefs['budget'] as num?)?.toDouble() ?? 5000.0;
          final String district = prefs['location'] ?? _latestRecommendations.first.district;
          final String vibe = prefs['vibe'] ?? 'Nature';
          final bool isGroup = prefs['group_size'] != null && (prefs['group_size'] as num) > 1;
          final int numTravelers = (prefs['group_size'] as num?)?.toInt() ?? 1;

          final itineraryMap = await _apiService.generateAIItinerary(
            destinationName: district,
            numDays: days,
            budget: budget,
            numAdults: isGroup ? numTravelers : 1,
            numChildren: 0,
            childAges: '',
            interests: [vibe],
          );

          if (itineraryMap != null) {
            final String title = itineraryMap['title'] ?? '$vibe Adventure in $district';
            final String destinationName = itineraryMap['destination'] ?? '$district, Davao Region';
            
            // Reconstruct itinerary map
            final Map<String, dynamic> itineraryJson = itineraryMap['itinerary'] ?? {};
            final Map<int, List<TripActivity>> agenda = {};
            
            itineraryJson.forEach((dayStr, list) {
              final day = int.tryParse(dayStr) ?? 1;
              final List<dynamic> actList = list;
              agenda[day] = actList
                  .map(
                    (act) => TripActivity(
                      time: act['time'] ?? '',
                      title: act['title'] ?? '',
                      description: act['description'] ?? '',
                      cost: act['cost'] ?? 'Free',
                      location: act['location'] ?? '',
                    ),
                  )
                  .toList();
            });

            String targetImageUrl = 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80';
            if (_destinations.isNotEmpty) {
              try {
                final match = _destinations.firstWhere(
                  (d) => d.district.toLowerCase().contains(district.toLowerCase()) || 
                         d.name.toLowerCase().contains(district.toLowerCase()),
                  orElse: () => _destinations.first,
                );
                targetImageUrl = match.imageUrl;
              } catch (_) {}
            }

            _latestGeneratedTrip = Trip(
              id: 'ai-trip-${DateTime.now().millisecondsSinceEpoch}',
              title: title,
              destinationName: destinationName,
              dateRange: 'Flexible Dates (AI Generated)',
              budget: budget,
              imageUrl: targetImageUrl,
              itinerary: agenda,
              isGroup: isGroup,
              numTravelers: numTravelers,
              members: isGroup ? Trip.seedMembers(numTravelers) : const [],
            );
          } else {
            _latestGeneratedTrip = null;
          }
        } else {
          _latestGeneratedTrip = null;
        }

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
    _errorMessage = null;
    notifyListeners();

    try {
      final success = await _apiService.createTrip(_latestGeneratedTrip!);
      if (success) {
        _userTrips.insert(0, _latestGeneratedTrip!);
        _latestGeneratedTrip = null;
        notifyListeners();
        return true;
      }
      _errorMessage = _apiService.lastError ?? 'Failed to save itinerary.';
      return false;
    } catch (e) {
      _errorMessage = 'Failed to save itinerary.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Add a direct manual trip and save to PostgreSQL database
  Future<bool> addNewTrip(Trip trip) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _apiService.createTrip(trip);
      if (success) {
        _userTrips.insert(0, trip);
        notifyListeners();
        return true;
      }
      _errorMessage = _apiService.lastError ?? 'Failed to save trip to database.';
      return false;
    } catch (e) {
      _errorMessage = 'Failed to save trip.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Delete a trip from database and update local state
  Future<bool> deleteTrip(String tripId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final success = await _apiService.deleteTrip(tripId);
      if (success) {
        _userTrips.removeWhere((t) => t.id == tripId);
        notifyListeners();
        return true;
      }
      _errorMessage = _apiService.lastError ?? 'Failed to delete trip.';
      return false;
    } catch (e) {
      _errorMessage = 'Failed to delete trip.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
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

  // Load any saved trip into active context to continue chatting with the AI Assistant
  void discussTripWithAI(Trip trip) {
    _latestGeneratedTrip = trip;
    _latestChatResponse = "Loaded '${trip.title}'! 🏝️\n\nHow can I help you modify this itinerary, plan budget changes, or suggest new activities?";
    notifyListeners();
  }
}
