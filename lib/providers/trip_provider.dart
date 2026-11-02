import 'package:flutter/material.dart';
import '../models/destination.dart';
import '../models/grouped_destinations.dart';
import '../models/trip.dart';
import '../models/app_notification.dart';
import '../models/planner_draft.dart';
import '../models/session_preferences.dart';
import '../models/chat_planning_session.dart';
import '../models/chat_destination_suggestion.dart';
import '../models/planning_feedback.dart';
import '../services/api_service.dart';
import '../services/bookmark_storage.dart';

class TripProvider extends ChangeNotifier {
  final ApiService _apiService;
  final BookmarkStore _bookmarkStore;

  TripProvider({BookmarkStore? bookmarkStore, ApiService? apiService})
    : _bookmarkStore = bookmarkStore ?? const SecureBookmarkStore(),
      _apiService = apiService ?? ApiService();

  List<Trip> _userTrips = [];
  List<Destination> _destinations = [];
  List<GroupedDestinations> _groupedDestinations = [];
  bool _catalogLoading = false;
  bool _catalogLoaded = false;
  String? _catalogError;
  bool _catalogOffline = false;
  Trip? _latestGeneratedTrip;
  bool _isLoading = false;
  String? _errorMessage;
  String? _tripsError;
  Destination? _activePlanDestination;
  final Set<int> _bookmarkedDestinationIds = {};
  bool _bookmarksLoaded = false;
  Future<void>? _bookmarkLoadFuture;

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

  int get unreadNotificationCount =>
      _notifications.where((n) => n.isNew).length;

  Future<bool> refreshNotifications() async {
    final data = await _apiService.fetchNotifications();
    if (data == null) {
      _errorMessage = 'Failed to load notifications.';
      notifyListeners();
      return false;
    }
    _notifications = data.map(AppNotification.fromJson).toList();
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> markNotificationAsRead(String id) async {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index == -1) return false;
    if (!await _apiService.markNotificationAsRead(id)) {
      _errorMessage = 'Failed to mark notification as read.';
      notifyListeners();
      return false;
    }
    final item = _notifications[index];
    _notifications[index] = AppNotification(
      id: item.id,
      title: item.title,
      body: item.body,
      time: item.time,
      icon: item.icon,
      isNew: false,
      type: item.type,
      tripId: item.tripId,
    );
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<bool> markAllNotificationsAsRead() async {
    if (!await _apiService.markAllNotificationsAsRead()) {
      _errorMessage = 'Failed to mark notifications as read.';
      notifyListeners();
      return false;
    }
    _notifications = _notifications
        .map(
          (n) => AppNotification(
            id: n.id,
            title: n.title,
            body: n.body,
            time: n.time,
            icon: n.icon,
            isNew: false,
            type: n.type,
            tripId: n.tripId,
          ),
        )
        .toList();
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  String? _latestChatResponse;
  List<Destination> _latestRecommendations = [];
  List<ChatDestinationSuggestion> _chatSuggestions = [];
  int _chatRecommendationTotalCandidates = 0;
  final ChatPlanningSession _chatPlanning = ChatPlanningSession();
  List<Map<String, dynamic>> _chatAIOptions = [];
  int? _chatGenerationRunId;
  int? _chatSelectedOptionNumber;

  List<Trip> get userTrips => _userTrips;
  List<Destination> get destinations => _destinations;
  List<GroupedDestinations> get groupedDestinations => _groupedDestinations;
  bool get catalogLoading => _catalogLoading;
  bool get catalogLoaded => _catalogLoaded;
  String? get catalogError => _catalogError;
  bool get catalogOffline => _catalogOffline;
  Trip? get latestGeneratedTrip => _latestGeneratedTrip;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String? get tripsError => _tripsError;

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
  List<ChatDestinationSuggestion> get chatSuggestions => _chatSuggestions;
  int get chatRecommendationTotalCandidates =>
      _chatRecommendationTotalCandidates;
  Map<String, dynamic> get chatPlanningState => _chatPlanning.state;
  Map<String, dynamic>? get chatPlanningPreview => _chatPlanning.preview;
  int get chatPlanningRevision => _chatPlanning.revision;
  bool get canGenerateChatPlan => _chatPlanning.canGenerate;
  List<Map<String, dynamic>> get chatAIOptions => _chatAIOptions;
  int? get chatSelectedOptionNumber => _chatSelectedOptionNumber;

  void setActivePlanDestination(Destination? dest) {
    _activePlanDestination = dest;
    notifyListeners();
  }

  List<int> get bookmarkedDestinationIds =>
      List.unmodifiable(_bookmarkedDestinationIds);

  bool isBookmarked(int id) {
    return _bookmarkedDestinationIds.contains(id);
  }

  Future<void> _loadBookmarks() async {
    if (_bookmarksLoaded) return;
    _bookmarkLoadFuture ??= () async {
      try {
        _bookmarkedDestinationIds.addAll(await _bookmarkStore.read());
      } catch (_) {
        // Keep the wishlist usable for this session if secure storage is unavailable.
      } finally {
        _bookmarksLoaded = true;
        notifyListeners();
      }
    }();
    await _bookmarkLoadFuture;
  }

  Future<void> loadBookmarks() => _loadBookmarks();

  Future<bool> toggleBookmark(int id) async {
    await _loadBookmarks();
    final wasBookmarked = _bookmarkedDestinationIds.remove(id);
    if (!wasBookmarked) _bookmarkedDestinationIds.add(id);
    notifyListeners();

    try {
      await _bookmarkStore.write(_bookmarkedDestinationIds);
      if (!wasBookmarked) {
        _apiService.recordInteraction(id, 'save');
      }
      return true;
    } catch (_) {
      if (wasBookmarked) {
        _bookmarkedDestinationIds.add(id);
      } else {
        _bookmarkedDestinationIds.remove(id);
      }
      _errorMessage = 'Could not save your wishlist. Please try again.';
      notifyListeners();
      return false;
    }
  }

  // Initialize data (mocked/API)
  Future<void> loadInitialData() async {
    await _loadBookmarks();
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await refreshDestinations();
      final trips = await _apiService.fetchUserTrips();
      _tripsError = _apiService.lastError;
      if (_tripsError == null) _userTrips = trips;

      if (_apiService.isAuthenticated) await refreshNotifications();
    } catch (e) {
      _errorMessage = 'Failed to load travel data.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshDestinations() async {
    _catalogLoading = true;
    _catalogError = null;
    _catalogOffline = false;
    notifyListeners();
    try {
      final destinations = await _apiService.fetchDestinations();
      final grouped = await _apiService.fetchGroupedDestinations(
        source: destinations,
      );
      _destinations = destinations;
      _groupedDestinations = grouped;
      _catalogLoaded = true;
    } on CatalogException catch (error) {
      _destinations = [];
      _groupedDestinations = [];
      _catalogLoaded = false;
      _catalogError = error.message;
      _catalogOffline = error.isOffline;
    } catch (_) {
      _destinations = [];
      _groupedDestinations = [];
      _catalogLoaded = false;
      _catalogError = 'The catalog could not be read. Please retry.';
    } finally {
      _catalogLoading = false;
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
    _chatSuggestions = [];
    _chatRecommendationTotalCandidates = 0;
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
        final String title =
            responseMap['title'] ?? '$vibe Adventure in $district';
        final String destinationName =
            responseMap['destination'] ?? '$district, Davao Region';

        // Find a matching image URL from local destinations list if possible
        String targetImageUrl =
            'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80';
        if (_destinations.isNotEmpty) {
          try {
            final match = _destinations.firstWhere(
              (d) =>
                  d.district.toLowerCase().contains(district.toLowerCase()) ||
                  d.name.toLowerCase().contains(district.toLowerCase()),
              orElse: () => _destinations.first,
            );
            targetImageUrl = match.imageUrl;
          } catch (_) {}
        }

        // Reconstruct itinerary map
        final Map<String, dynamic> itineraryJson =
            responseMap['itinerary'] ?? {};
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

  void startChatPlanning({Destination? destination}) {
    _chatPlanning.reset(
      destination: destination,
      preferences: _sessionPreferences,
    );
    _latestChatResponse = null;
    _latestRecommendations = [];
    _chatSuggestions = [];
    _chatRecommendationTotalCandidates = 0;
    _clearChatAIOptions();
    notifyListeners();
  }

  Future<bool> chooseChatDestination(Destination destination) async {
    _activePlanDestination = destination;
    return setChatDestinationIds(<int>[destination.id]);
  }

  Future<bool> setChatDestinationIds(List<int> ids) async {
    if (ids.length > 10 || ids.length != ids.toSet().length) {
      _errorMessage = 'Choose at most ten different destinations.';
      notifyListeners();
      return false;
    }
    _chatPlanning.edit({
      'destination_ids': ids,
      'selected_transport_option_ids': <String>[],
      'selected_activity_option_ids': <String>[],
      'selected_accommodation_ids': <int>[],
      'cost_allowances': <Map<String, dynamic>>[],
      'transport_pricing': <Map<String, dynamic>>[],
      'accommodation_pricing': <Map<String, dynamic>>[],
      'age_pricing_rules': <Map<String, dynamic>>[],
    });
    _chatSuggestions = [];
    _chatRecommendationTotalCandidates = 0;
    _clearChatAIOptions();
    notifyListeners();
    return refreshChatPlanningPreview();
  }

  Future<bool> updateChatPlanning(Map<String, dynamic> changes) async {
    _chatPlanning.edit(changes);
    _clearChatAIOptions();
    notifyListeners();
    return refreshChatPlanningPreview();
  }

  Future<bool> refreshChatPlanningPreview() async {
    final requestRevision = _chatPlanning.revision;
    final response = await _apiService.previewPlanningState(
      state: Map<String, dynamic>.from(_chatPlanning.state),
      inputRevision: requestRevision,
    );
    if (response == null) {
      if (requestRevision != _chatPlanning.revision) return false;
      _errorMessage = _apiService.lastError ?? 'Could not review this plan.';
      notifyListeners();
      return false;
    }
    if (!_chatPlanning.acceptPreview(response, requestRevision)) return false;
    _errorMessage = null;
    notifyListeners();
    return true;
  }

  Future<PlanningFeedback?> reviewChatPlanningFeedback({
    bool? travelingWithChildren,
  }) async {
    final revision = _chatPlanning.revision;
    final selectedOption = _chatSelectedOptionNumber;
    if (_latestGeneratedTrip == null || selectedOption == null) {
      _errorMessage = 'Select a current itinerary option first.';
      notifyListeners();
      return null;
    }
    final feedback = await _apiService.fetchPlanningFeedback(
      state: Map<String, dynamic>.from(_chatPlanning.state),
      inputRevision: revision,
      travelingWithChildren: travelingWithChildren,
    );
    if (revision != _chatPlanning.revision ||
        selectedOption != _chatSelectedOptionNumber ||
        _latestGeneratedTrip == null) {
      _errorMessage = 'The plan changed. Review its feedback again.';
      notifyListeners();
      return null;
    }
    if (feedback == null ||
        feedback.inputRevision != revision ||
        feedback.travelingWithChildren != travelingWithChildren) {
      _errorMessage = feedback == null
          ? _apiService.lastError ?? 'Could not check this plan.'
          : 'The plan changed. Review its feedback again.';
      notifyListeners();
      return null;
    }
    _errorMessage = null;
    notifyListeners();
    return feedback;
  }

  Future<bool> generateChatItinerary() async {
    if (!_chatPlanning.canGenerate) {
      _errorMessage = 'Review the destination, trip details, and costs first.';
      notifyListeners();
      return false;
    }
    final requestRevision = _chatPlanning.revision;
    _isLoading = true;
    _errorMessage = null;
    _clearChatAIOptions();
    notifyListeners();
    try {
      final response = await _apiService.generatePlanningItinerary(
        state: Map<String, dynamic>.from(_chatPlanning.state),
        inputRevision: requestRevision,
      );
      if (requestRevision != _chatPlanning.revision) {
        _errorMessage = 'The plan changed. Review it before generating again.';
        return false;
      }
      if (response == null) {
        _errorMessage =
            _apiService.lastError ?? 'AI itinerary generation failed.';
        return false;
      }
      final returnedPreview = response['planning_preview'];
      if (returnedPreview is! Map ||
          returnedPreview['input_revision'] != requestRevision) {
        _errorMessage = 'The AI response did not match the reviewed plan.';
        return false;
      }
      final runId = response['selected_generation_run_id'];
      final rawOptions = response['options'];
      if (runId is! int || rawOptions is! List || rawOptions.isEmpty) {
        _errorMessage =
            'The AI response did not include a validated itinerary.';
        return false;
      }
      _chatGenerationRunId = runId;
      _chatAIOptions = rawOptions
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
      if (_chatAIOptions.isEmpty) {
        _errorMessage =
            'The AI response did not include a validated itinerary.';
        return false;
      }
      return selectChatAIOption(_chatAIOptions.first['option_number'] as int);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool selectChatAIOption(int optionNumber) {
    if (_chatGenerationRunId == null) return false;
    final matches = _chatAIOptions.where(
      (option) => option['option_number'] == optionNumber,
    );
    if (matches.isEmpty) return false;
    _chatSelectedOptionNumber = optionNumber;
    _latestGeneratedTrip = _tripFromChatAIOption(matches.first);
    notifyListeners();
    return true;
  }

  Trip _tripFromChatAIOption(Map<String, dynamic> option) {
    final destinationIds = _chatPlanning.destinationIds;
    final selected = _destinations
        .where((destination) => destinationIds.contains(destination.id))
        .toList();
    final previewDestinations =
        (_chatPlanning.preview?['destinations'] as List? ?? const [])
            .whereType<Map>()
            .toList();
    final previewNames = previewDestinations
        .map((item) => item['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .join(', ');
    final byId = {
      for (final destination in selected) destination.id: destination,
    };
    final days = <int, List<TripActivity>>{};
    for (final rawDay
        in (option['days'] as List? ?? const []).whereType<Map>()) {
      final day = Map<String, dynamic>.from(rawDay);
      final dayNumber = day['day'];
      if (dayNumber is! int) continue;
      days[dayNumber] = [
        for (final rawActivity
            in (day['activities'] as List? ?? const []).whereType<Map>())
          TripActivity(
            time: rawActivity['time']?.toString() ?? '',
            title: rawActivity['title']?.toString() ?? '',
            description: rawActivity['description']?.toString() ?? '',
            cost: rawActivity['estimated_cost'] == null
                ? 'Cost not listed'
                : '₱${rawActivity['estimated_cost']}',
            location:
                byId[rawActivity['destination_id']]?.name ??
                selected.map((item) => item.name).join(', '),
          ),
      ];
    }
    final travelers = _chatPlanning.state['traveler_count'] as int? ?? 1;
    final total =
        double.tryParse(option['estimated_total_cost']?.toString() ?? '') ?? 0;
    return Trip(
      id: 'ai-chat-$_chatGenerationRunId-$_chatSelectedOptionNumber',
      title: option['title']?.toString() ?? 'AI itinerary',
      destinationName: selected.isEmpty
          ? previewNames
          : selected.map((item) => item.name).join(', '),
      destinationIds: destinationIds,
      dateRange: 'Flexible dates',
      budget: total,
      imageUrl: selected.isEmpty ? '' : selected.first.imageUrl,
      itinerary: days,
      isGroup: travelers > 1,
      numTravelers: travelers,
    );
  }

  void _clearChatAIOptions() {
    _chatAIOptions = [];
    _chatGenerationRunId = null;
    _chatSelectedOptionNumber = null;
    if (_latestGeneratedTrip?.id.startsWith('ai-chat-') == true) {
      _latestGeneratedTrip = null;
    }
  }

  // Free-form conversation with AI Chatbot
  Future<bool> sendFreeFormChat(
    String text, {
    List<Map<String, String>>? history,
  }) async {
    if (_isLoading) {
      _errorMessage = 'Please wait for the current request to finish.';
      notifyListeners();
      return false;
    }
    final requestRevision = _chatPlanning.revision;
    _isLoading = true;
    _errorMessage = null;
    _latestChatResponse = null;
    _latestRecommendations = [];
    notifyListeners();

    try {
      final response = await _apiService.chatWithAI(
        text,
        history: history,
        planningState: Map<String, dynamic>.from(_chatPlanning.state),
        inputRevision: requestRevision,
      );
      if (response == null) {
        _errorMessage =
            _apiService.lastError ?? 'Failed to chat with Lakbay AI.';
        return false;
      }
      if (!_chatPlanning.acceptChat(response, requestRevision)) {
        _errorMessage = requestRevision != _chatPlanning.revision
            ? 'The plan changed while I was replying. Please send that again.'
            : 'The assistant did not return a usable plan. Please try again.';
        return false;
      }
      final message = response['chat_response']?.toString().trim();
      if (message == null || message.isEmpty) {
        _errorMessage =
            'The assistant returned an empty reply. Please try again.';
        return false;
      }
      _latestChatResponse = message;
      final planning = response['planning'] as Map;
      final rawRecommendations = planning['recommendations'];
      _chatSuggestions = rawRecommendations is List
          ? rawRecommendations
                .whereType<Map>()
                .map(
                  (item) => ChatDestinationSuggestion.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : [];
      _chatRecommendationTotalCandidates =
          planning['recommendation_total_candidates'] as int? ?? 0;
      final stateUpdates = planning['state_updates'];
      if (planning['update_status'] == 'applied' ||
          (stateUpdates is Map && stateUpdates.isNotEmpty)) {
        _clearChatAIOptions();
      }
      _errorMessage = null;
      return true;
    } catch (_) {
      _errorMessage = _apiService.lastError ?? 'Failed to chat with Lakbay AI.';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Trip?> _persistTrip(Trip trip) {
    if (!trip.id.startsWith('ai-chat-')) return _apiService.createTrip(trip);
    if (_latestGeneratedTrip?.id != trip.id ||
        _chatGenerationRunId == null ||
        _chatSelectedOptionNumber == null) {
      _errorMessage =
          'This itinerary changed. Select the current option again.';
      return Future.value(null);
    }
    return _apiService.savePlanningAIOption(
      generationRunId: _chatGenerationRunId!,
      optionNumber: _chatSelectedOptionNumber!,
    );
  }

  // Save the AI generated itinerary into user's trip list
  Future<bool> saveGeneratedTrip() async {
    if (_latestGeneratedTrip == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final savedTrip = await _persistTrip(_latestGeneratedTrip!);
      if (savedTrip != null) {
        final localTrip = _latestGeneratedTrip!;
        _userTrips.insert(
          0,
          savedTrip.copyWith(
            imageUrl: savedTrip.imageUrl.isEmpty
                ? localTrip.imageUrl
                : savedTrip.imageUrl,
          ),
        );
        _latestGeneratedTrip = null;
        _clearChatAIOptions();
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
      final savedTrip = await _persistTrip(trip);
      if (savedTrip != null) {
        _userTrips.insert(
          0,
          savedTrip.copyWith(
            imageUrl: savedTrip.imageUrl.isEmpty
                ? trip.imageUrl
                : savedTrip.imageUrl,
          ),
        );
        if (trip.id.startsWith('ai-chat-')) {
          _latestGeneratedTrip = null;
          _clearChatAIOptions();
        }
        notifyListeners();
        return true;
      }
      _errorMessage =
          _apiService.lastError ?? 'Failed to save trip to database.';
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
    if (!isPersistedTrip(updatedTrip)) {
      _errorMessage = 'Save this trip before changing its details.';
      notifyListeners();
      return false;
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

  bool isPersistedTrip(Trip trip) {
    return _hasBackendTripId(trip) &&
        _userTrips.any((savedTrip) => savedTrip.id == trip.id);
  }

  Future<bool> refreshTripMemories(Trip trip) async {
    if (!isPersistedTrip(trip)) return false;
    final memories = await _apiService.fetchTripMemories(trip.id);
    if (_apiService.lastError != null) {
      _errorMessage = _apiService.lastError;
      notifyListeners();
      return false;
    }
    final index = _userTrips.indexWhere((savedTrip) => savedTrip.id == trip.id);
    if (index == -1) return false;
    _errorMessage = null;
    updateTrip(_userTrips[index].copyWith(memories: memories));
    return true;
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
      final effectiveMembers = membersError == null || members.isNotEmpty
          ? members
          : trip.members;
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

  Future<bool> addTaskToTrip(Trip trip, Map<String, dynamic> task) async {
    if (!isPersistedTrip(trip)) {
      _errorMessage = 'Save this trip before changing its tasks.';
      notifyListeners();
      return false;
    }

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

  Future<bool> setTaskCompletion(Trip trip, int index, bool isDone) async {
    if (!isPersistedTrip(trip)) {
      _errorMessage = 'Save this trip before changing its tasks.';
      notifyListeners();
      return false;
    }
    if (index < 0 || index >= trip.tasks.length) return false;

    final updatedTasks = List<Map<String, dynamic>>.from(
      trip.tasks.map((t) => Map<String, dynamic>.from(t)),
    );
    final currentTask = updatedTasks[index];

    if (_hasBackendTripId(trip)) {
      final taskId =
          currentTask['trip_task_id']?.toString() ??
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
        'category':
            currentTask['category'] ?? savedTask['category'] ?? 'General',
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
    if (!isPersistedTrip(trip)) {
      _errorMessage = 'Save this trip before adding memories.';
      notifyListeners();
      return false;
    }

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

    final currentTrip = _userTrips.firstWhere(
      (savedTrip) => savedTrip.id == trip.id,
    );
    final updatedMemories = List<Map<String, dynamic>>.from(
      currentTrip.memories,
    )..insert(0, created);
    _errorMessage = null;
    updateTrip(currentTrip.copyWith(memories: updatedMemories));
    return true;
  }

  Future<bool> deleteMemoryFromTrip(Trip trip, int index) async {
    if (!isPersistedTrip(trip)) {
      _errorMessage = 'Save this trip before changing its memories.';
      notifyListeners();
      return false;
    }
    if (index < 0 || index >= trip.memories.length) return false;

    final updatedMemories = List<Map<String, dynamic>>.from(trip.memories);
    final memory = updatedMemories[index];

    if (_hasBackendTripId(trip)) {
      final memoryId =
          memory['memory_id']?.toString() ?? memory['id']?.toString() ?? '';
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
      final currentItinerary = Map<int, List<TripActivity>>.from(
        trip.itinerary,
      );
      final dayActivities = List<TripActivity>.from(
        currentItinerary[day] ?? [],
      );
      dayActivities.add(activity);
      currentItinerary[day] = dayActivities;

      _userTrips[tripIndex] = trip.copyWith(itinerary: currentItinerary);
      notifyListeners();
    }
  }

  // Load any saved trip into active context to continue chatting with the AI Assistant
  void discussTripWithAI(Trip trip) {
    _latestGeneratedTrip = trip;
    _latestChatResponse =
        "Loaded '${trip.title}'! 🏝️\n\nHow can I help you modify this itinerary, plan budget changes, or suggest new activities?";
    notifyListeners();
  }
}
