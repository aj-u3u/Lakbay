import 'package:flutter/material.dart';
import '../models/destination.dart';
import '../models/grouped_destinations.dart';
import '../models/trip.dart';
import '../models/app_notification.dart';
import '../models/planner_draft.dart';
import '../models/session_preferences.dart';
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

  // Session Preferences for AI Conversation Context
  final SessionPreferences _sessionPreferences = SessionPreferences();
  SessionPreferences get sessionPreferences => _sessionPreferences;

  void resetSessionPreferences() {
    _sessionPreferences.reset();
    notifyListeners();
  }

  // Active planning draft state
  PlannerDraft? _activeDraft;

  PlannerDraft? get activeDraft => _activeDraft;

  void updateDraft(PlannerDraft? draft) {
    _activeDraft = draft;
    notifyListeners();
  }

  // In-app Notifications State
  List<AppNotification> _notifications = [];

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
      _apiService.markNotificationAsRead(id);
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
    _apiService.markAllNotificationsAsRead();
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

      final notifsData = await _apiService.fetchNotifications();
      if (notifsData != null) {
        _notifications = notifsData.map((data) => AppNotification.fromJson(data)).toList();
      }
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
  Future<bool> sendFreeFormChat(
    String text, {
    List<Map<String, String>>? history,
  }) async {
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

      final responseMap = await _apiService.chatWithAI(
        enrichedPrompt,
        history: history,
      );
      if (responseMap != null) {
        _latestChatResponse = responseMap['chat_response'];
        final List<dynamic> results = responseMap['results'] ?? [];
        _latestRecommendations = results.map((r) => Destination.fromJson(r)).toList();

        final prefs = responseMap['parsed_preferences'] ?? {};
        if (prefs is Map<String, dynamic> && prefs.isNotEmpty) {
          _sessionPreferences.updateFromMap(prefs);
        }

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
      _errorMessage = _apiService.lastError ?? 'Failed to chat with AI.';
    } catch (e) {
      _errorMessage = _apiService.lastError ?? 'Failed to chat with AI.';
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
      final savedTrip = await _apiService.createTrip(_latestGeneratedTrip!);
      if (savedTrip != null) {
        final localTrip = _latestGeneratedTrip!;
        _userTrips.insert(
          0,
          savedTrip.copyWith(
            imageUrl:
                savedTrip.imageUrl.isEmpty ? localTrip.imageUrl : savedTrip.imageUrl,
          ),
        );
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
      final savedTrip = await _apiService.createTrip(trip);
      if (savedTrip != null) {
        _userTrips.insert(
          0,
          savedTrip.copyWith(
            imageUrl: savedTrip.imageUrl.isEmpty ? trip.imageUrl : savedTrip.imageUrl,
          ),
        );
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

  Future<bool> saveTripMetadata(Trip updatedTrip) async {
    if (!_hasBackendTripId(updatedTrip)) {
      updateTrip(updatedTrip);
      return true;
    }

    final savedTrip = await _apiService.updateTripMetadata(updatedTrip);
    if (savedTrip == null) {
      _errorMessage = _apiService.lastError ?? 'Failed to update trip.';
      notifyListeners();
      return false;
    }

    updateTrip(
      savedTrip.copyWith(
        imageUrl: savedTrip.imageUrl.isEmpty
            ? updatedTrip.imageUrl
            : savedTrip.imageUrl,
        tasks: updatedTrip.tasks,
        memories: updatedTrip.memories,
        members: updatedTrip.members,
      ),
    );
    return true;
  }

  bool _hasBackendTripId(Trip trip) {
    final id = int.tryParse(trip.id);
    return id != null && id > 0;
  }

  String? _memberIdForAssignee(Trip trip, String? assigneeName) {
    if (assigneeName == null || assigneeName.isEmpty) return null;
    for (final member in trip.members) {
      final memberId = member['trip_member_id'] ?? member['id'];
      if (memberId == null || int.tryParse(memberId) == null) continue;
      if ((member['name'] ?? '').toLowerCase() == assigneeName.toLowerCase()) {
        return memberId;
      }
    }
    return null;
  }

  Future<void> refreshTripCollaboration(Trip trip) async {
    if (!_hasBackendTripId(trip)) return;

    try {
      var updatedTrip = trip;
      final members = await _apiService.fetchTripMembers(trip.id);
      final membersError = _apiService.lastError;
      final effectiveMembers =
          membersError == null || members.isNotEmpty ? members : trip.members;
      updatedTrip = updatedTrip.copyWith(members: effectiveMembers);

      final tasks = await _apiService.fetchTripTasks(
        trip.id,
        members: effectiveMembers,
      );
      final tasksError = _apiService.lastError;
      if (tasksError == null || tasks.isNotEmpty) {
        updatedTrip = updatedTrip.copyWith(tasks: tasks);
      }

      final memories = await _apiService.fetchTripMemories(trip.id);
      final memoriesError = _apiService.lastError;
      if (memoriesError == null || memories.isNotEmpty) {
        updatedTrip = updatedTrip.copyWith(memories: memories);
      }

      updateTrip(updatedTrip);
    } catch (e) {
      _errorMessage = 'Failed to refresh trip collaboration data.';
    }
  }

  Future<bool> addTaskToTrip(
    Trip trip,
    Map<String, dynamic> task,
  ) async {
    final updatedTasks = List<Map<String, dynamic>>.from(trip.tasks);

    if (_hasBackendTripId(trip)) {
      final assignedMemberId = task['assigned_trip_member_id']?.toString();
      final created = await _apiService.createTripTask(
        trip.id,
        title: task['task']?.toString() ?? '',
        assignedTripMemberId: assignedMemberId?.isNotEmpty == true
            ? assignedMemberId
            : _memberIdForAssignee(trip, task['assignee']?.toString()),
        members: trip.members,
      );
      if (created == null) {
        _errorMessage = _apiService.lastError ?? 'Failed to create task.';
        notifyListeners();
        return false;
      }
      updatedTasks.add({
        ...created,
        'category': task['category'] ?? created['category'] ?? 'General',
      });
    } else {
      updatedTasks.add(task);
    }

    updateTrip(trip.copyWith(tasks: updatedTasks));
    return true;
  }

  Future<bool> setTaskCompletion(
    Trip trip,
    int index,
    bool isDone,
  ) async {
    if (index < 0 || index >= trip.tasks.length) return false;

    final updatedTasks = List<Map<String, dynamic>>.from(
      trip.tasks.map((t) => Map<String, dynamic>.from(t)),
    );
    final currentTask = updatedTasks[index];

    if (_hasBackendTripId(trip)) {
      final taskId = currentTask['trip_task_id']?.toString() ??
          currentTask['id']?.toString() ??
          '';
      final savedTask = await _apiService.updateTripTask(
        trip.id,
        taskId,
        status: isDone ? 'completed' : 'pending',
        members: trip.members,
      );
      if (savedTask == null) {
        _errorMessage = _apiService.lastError ?? 'Failed to update task.';
        notifyListeners();
        return false;
      }
      updatedTasks[index] = {
        ...currentTask,
        ...savedTask,
        'category': currentTask['category'] ?? savedTask['category'] ?? 'General',
      };
    } else {
      updatedTasks[index]['done'] = isDone;
      updatedTasks[index]['status'] = isDone ? 'completed' : 'pending';
    }

    updateTrip(trip.copyWith(tasks: updatedTasks));
    return true;
  }

  Future<bool> addMemoryToTrip(
    Trip trip, {
    required String filePath,
    required String caption,
    required String location,
  }) async {
    final updatedMemories = List<Map<String, dynamic>>.from(trip.memories);

    if (_hasBackendTripId(trip)) {
      final upload = await _apiService.uploadTripMemoryImage(trip.id, filePath);
      final imageUrl = upload?['image_url']?.toString();
      if (imageUrl == null || imageUrl.isEmpty) {
        _errorMessage = _apiService.lastError ?? 'Failed to upload memory.';
        notifyListeners();
        return false;
      }

      final created = await _apiService.createTripMemory(
        trip.id,
        imageUrl: imageUrl,
        cloudinaryPublicId: upload?['cloudinary_public_id']?.toString(),
        caption: caption,
        locationTag: location,
      );
      if (created == null) {
        _errorMessage = _apiService.lastError ?? 'Failed to save memory.';
        notifyListeners();
        return false;
      }
      updatedMemories.insert(0, created);
    } else {
      updatedMemories.insert(0, {
        'id': 'mem-${DateTime.now().millisecondsSinceEpoch}',
        'user': 'Arjane',
        'avatar':
            'https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=100&q=80',
        'time': 'Just now',
        'caption': caption,
        'image': filePath,
        'likes': '0',
        'comments': '0',
        'location': location.isNotEmpty
            ? location
            : trip.destinationName.split(',').first,
      });
    }

    updateTrip(trip.copyWith(memories: updatedMemories));
    return true;
  }

  Future<bool> deleteMemoryFromTrip(Trip trip, int index) async {
    if (index < 0 || index >= trip.memories.length) return false;

    final updatedMemories = List<Map<String, dynamic>>.from(trip.memories);
    final memory = updatedMemories[index];

    if (_hasBackendTripId(trip)) {
      final memoryId = memory['memory_id']?.toString() ??
          memory['id']?.toString() ??
          '';
      final hasBackendMemoryId = int.tryParse(memoryId) != null;
      if (hasBackendMemoryId) {
        final deleted = await _apiService.deleteTripMemory(trip.id, memoryId);
        if (!deleted) {
          _errorMessage = _apiService.lastError ?? 'Failed to delete memory.';
          notifyListeners();
          return false;
        }
      }
    }

    updatedMemories.removeAt(index);
    updateTrip(trip.copyWith(memories: updatedMemories));
    return true;
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
