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
        
        // Build day-to-day agenda dynamically using actual database recommendations!
        final Map<int, List<TripActivity>> agenda = {};
        
        double helperParsePrice(String text) {
          final cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
          return double.tryParse(cleanText) ?? 0.0;
        }

        String formatCost(String baseCost, {bool isPerPerson = true}) {
          if (baseCost.toLowerCase().contains('free') || baseCost.toLowerCase().contains('included') || baseCost == '0') {
            return 'Free';
          }
          if (!isGroup) return baseCost;
          
          final val = helperParsePrice(baseCost);
          if (val == 0.0) return baseCost;

          if (isPerPerson) {
            final total = val * numTravelers;
            return '₱${val.toStringAsFixed(0)} / pax (Total ₱${total.toStringAsFixed(0)})';
          } else {
            // Collective cost (e.g. cottage, taxi, double room split)
            final split = val / numTravelers;
            return '₱${split.toStringAsFixed(0)} / pax (Total ₱${val.toStringAsFixed(0)})';
          }
        }

        if (_latestRecommendations.isNotEmpty) {
          for (int day = 1; day <= days; day++) {
            // Spread the days across recommendations
            final dest = _latestRecommendations[(day - 1) % _latestRecommendations.length];
            final extra = dest.extra;
            final String loc = dest.name;
            final List<TripActivity> dayPlan = [];

            // Determine calculated budget style based on per-person budget
            final perPerson = budget / (numTravelers > 0 ? numTravelers : 1);
            String calculatedStyle = 'Balanced Budget';
            if (perPerson <= 1500.0) {
              calculatedStyle = 'Low Budget';
            } else if (perPerson <= 5000.0) {
              calculatedStyle = 'Balanced Budget';
            } else {
              calculatedStyle = 'High Budget';
            }

            // 1. Morning Transport (07:00 AM) matched to budget
            Map<String, String>? transportOpt;
            if (extra.transportOptions.isNotEmpty) {
              final transOptions = extra.transportOptions;
              final sortedTrans = List<Map<String, String>>.from(transOptions)
                ..sort((a, b) => helperParsePrice(a['price'] ?? '0').compareTo(helperParsePrice(b['price'] ?? '0')));
              if (calculatedStyle == 'Low Budget') {
                transportOpt = sortedTrans.first;
              } else if (calculatedStyle == 'High Budget') {
                transportOpt = sortedTrans.last;
              } else {
                transportOpt = sortedTrans[sortedTrans.length ~/ 2];
              }
            }
            final transPrice = transportOpt != null ? transportOpt['price'] ?? '₱150' : '₱150';

            dayPlan.add(TripActivity(
              time: '07:00 AM',
              title: day == 1 ? 'Departure to ${dest.name}' : 'Morning Transit',
              description: transportOpt != null
                  ? 'Board ${transportOpt['vehicle']} from ${transportOpt['from']} → ${transportOpt['to']}. Est. Duration: ${transportOpt['duration'] ?? '1 hour'}.'
                  : 'Travel to $loc via local transport.',
              cost: formatCost(transPrice, isPerPerson: false),
              location: 'En Route',
            ));

            // 2. Arrival & Registration (09:00 AM)
            final envFeeStr = extra.environmentalFee.isNotEmpty ? extra.environmentalFee : '₱30';
            dayPlan.add(TripActivity(
              time: '09:00 AM',
              title: 'Arrival & Registration at $loc',
              description: '${dest.description} Environmental Fee: $envFeeStr.',
              cost: formatCost(dest.entranceFee, isPerPerson: true),
              location: loc,
            ));

            // 3. Lunch Break (12:30 PM) matched to budget
            final mealNotes = extra.mealInclusions.isNotEmpty 
                ? extra.mealInclusions.first 
                : 'Local food stalls and restaurants available.';
            final mealPrice = calculatedStyle == 'Low Budget' ? '₱150' : calculatedStyle == 'High Budget' ? '₱600' : '₱300';
            dayPlan.add(TripActivity(
              time: '12:30 PM',
              title: 'Lunch Break',
              description: mealNotes,
              cost: formatCost(mealPrice, isPerPerson: true),
              location: loc,
            ));

            // 4. Afternoon Activity (02:30 PM) matched to budget
            final actName = dest.activities.isNotEmpty 
                ? dest.activities[(day - 1) % dest.activities.length] 
                : 'Sightseeing';
            
            String actPrice = 'Free';
            if (extra.activityPrices.isNotEmpty) {
              final prices = extra.activityPrices;
              final matchingKey = prices.keys.firstWhere(
                (k) => k.toLowerCase().contains(actName.toLowerCase()) || actName.toLowerCase().contains(k.toLowerCase()),
                orElse: () => '',
              );
              if (matchingKey.isNotEmpty) {
                actPrice = prices[matchingKey]!;
              } else {
                actPrice = calculatedStyle == 'Low Budget' ? 'Free' : calculatedStyle == 'High Budget' ? '₱400' : '₱200';
              }
            } else {
              actPrice = calculatedStyle == 'Low Budget' ? 'Free' : calculatedStyle == 'High Budget' ? '₱400' : '₱200';
            }

            final noteStr = extra.travelNotes.isNotEmpty 
                ? extra.travelNotes.first 
                : 'Enjoy the majestic sights and take photos.';
            dayPlan.add(TripActivity(
              time: '02:30 PM',
              title: actName,
              description: 'Vibe: $vibe. $noteStr',
              cost: formatCost(actPrice, isPerPerson: true),
              location: loc,
            ));

            // 5. Evening dinner / stay (06:00 PM) matched to budget
            if (days > 1 && day < days) {
              Map<String, String>? accomm;
              if (extra.accommodationTypes.isNotEmpty) {
                final accommTypes = extra.accommodationTypes;
                if (calculatedStyle == 'Low Budget') {
                  accomm = accommTypes.first;
                } else if (calculatedStyle == 'High Budget') {
                  accomm = accommTypes.last;
                } else {
                  accomm = accommTypes[accommTypes.length ~/ 2];
                }
              }
              final accommName = accomm != null ? accomm['type'] ?? 'Standard Room' : 'Standard Room';
              final accommPrice = accomm != null ? accomm['price'] ?? '₱1,200' : '₱1,200';
              dayPlan.add(TripActivity(
                time: '06:00 PM',
                title: 'Check-in at $accommName',
                description: 'Stay overnight near $loc. Get dinner and relax.',
                cost: formatCost(accommPrice, isPerPerson: false),
                location: loc,
              ));
            } else {
              dayPlan.add(TripActivity(
                time: '06:00 PM',
                title: 'Evening Return',
                description: 'Wrap up the journey. Travel back to city center.',
                cost: 'Free',
                location: 'Davao City',
              ));
            }

            agenda[day] = dayPlan;
          }
        } else {
          // Fallback if no database matches (e.g. for general areas)
          for (int day = 1; day <= days; day++) {
            agenda[day] = [
              TripActivity(
                time: '08:30 AM',
                title: 'Explore $targetDestName',
                description: 'Start with scenic morning trails and cultural guidance.',
                cost: formatCost('₱150', isPerPerson: true),
                location: targetDestName,
              ),
              TripActivity(
                time: '12:30 PM',
                title: 'Local Lunch Feast',
                description: 'Try the fresh seafood grills and fruit varieties.',
                cost: formatCost('₱250', isPerPerson: true),
                location: 'Nearby Diner',
              ),
              TripActivity(
                time: '03:00 PM',
                title: 'Afternoon $vibe Spot',
                description: 'Custom sightseeing matching your requested $vibe preference.',
                cost: formatCost('₱150', isPerPerson: true),
                location: targetDestName,
              ),
              TripActivity(
                time: '07:00 PM',
                title: 'Dinner & Relaxation',
                description: 'Relax and unwind at local food districts and night spots.',
                cost: formatCost('₱350', isPerPerson: true),
                location: 'Food Street',
              ),
            ];
          }
        }


        // Derive calculatedStyle again for the title
        final perPerson = budget / (numTravelers > 0 ? numTravelers : 1);
        String calculatedStyle = 'Balanced Budget';
        if (perPerson <= 1500.0) {
          calculatedStyle = 'Low Budget';
        } else if (perPerson <= 5000.0) {
          calculatedStyle = 'Balanced Budget';
        } else {
          calculatedStyle = 'High Budget';
        }

        _latestGeneratedTrip = Trip(
          id: 'ai-trip-${DateTime.now().millisecondsSinceEpoch}',
          title: '$calculatedStyle $vibe Adventure in $district',
          destinationName: '$district, Davao Region',
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

          final targetDestName = _latestRecommendations.first.name;
          final targetImageUrl = _latestRecommendations.first.imageUrl;
          
          final Map<int, List<TripActivity>> agenda = {};
          
          double helperParsePrice(String text) {
            final cleanText = text.replaceAll(RegExp(r'[^\d]'), '');
            return double.tryParse(cleanText) ?? 0.0;
          }

          String formatCost(String baseCost, {bool isPerPerson = true}) {
            if (baseCost.toLowerCase().contains('free') || baseCost.toLowerCase().contains('included') || baseCost == '0') {
              return 'Free';
            }
            if (!isGroup) return baseCost;
            
            final val = helperParsePrice(baseCost);
            if (val == 0.0) return baseCost;

            if (isPerPerson) {
              final total = val * numTravelers;
              return '₱${val.toStringAsFixed(0)} / pax (Total ₱${total.toStringAsFixed(0)})';
            } else {
              final split = val / numTravelers;
              return '₱${split.toStringAsFixed(0)} / pax (Total ₱${val.toStringAsFixed(0)})';
            }
          }

          // Determine calculated budget style based on per-person budget
          final perPerson = budget / (numTravelers > 0 ? numTravelers : 1);
          String calculatedStyle = 'Balanced Budget';
          if (perPerson <= 1500.0) {
            calculatedStyle = 'Low Budget';
          } else if (perPerson <= 5000.0) {
            calculatedStyle = 'Balanced Budget';
          } else {
            calculatedStyle = 'High Budget';
          }

          for (int day = 1; day <= days; day++) {
            final dest = _latestRecommendations[(day - 1) % _latestRecommendations.length];
            final extra = dest.extra;
            final String loc = dest.name;
            final List<TripActivity> dayPlan = [];

            // 1. Morning Transport matched to budget
            Map<String, String>? transportOpt;
            if (extra.transportOptions.isNotEmpty) {
              final transOptions = extra.transportOptions;
              final sortedTrans = List<Map<String, String>>.from(transOptions)
                ..sort((a, b) => helperParsePrice(a['price'] ?? '0').compareTo(helperParsePrice(b['price'] ?? '0')));
              if (calculatedStyle == 'Low Budget') {
                transportOpt = sortedTrans.first;
              } else if (calculatedStyle == 'High Budget') {
                transportOpt = sortedTrans.last;
              } else {
                transportOpt = sortedTrans[sortedTrans.length ~/ 2];
              }
            }
            final transPrice = transportOpt != null ? transportOpt['price'] ?? '₱150' : '₱150';

            dayPlan.add(TripActivity(
              time: '07:00 AM',
              title: day == 1 ? 'Departure to ${dest.name}' : 'Morning Transit',
              description: transportOpt != null
                  ? 'Board ${transportOpt['vehicle']} from ${transportOpt['from']} → ${transportOpt['to']}. Est. Duration: ${transportOpt['duration'] ?? '1 hour'}.'
                  : 'Travel to $loc via local transport.',
              cost: formatCost(transPrice, isPerPerson: false),
              location: 'En Route',
            ));

            // 2. Arrival & Registration
            final envFeeStr = extra.environmentalFee.isNotEmpty ? extra.environmentalFee : '₱30';
            dayPlan.add(TripActivity(
              time: '09:00 AM',
              title: 'Arrival & Registration at $loc',
              description: '${dest.description} Environmental Fee: $envFeeStr.',
              cost: formatCost(dest.entranceFee, isPerPerson: true),
              location: loc,
            ));

            // 3. Lunch Break matched to budget
            final mealNotes = extra.mealInclusions.isNotEmpty 
                ? extra.mealInclusions.first 
                : 'Local food stalls and restaurants available.';
            final mealPrice = calculatedStyle == 'Low Budget' ? '₱150' : calculatedStyle == 'High Budget' ? '₱600' : '₱300';
            dayPlan.add(TripActivity(
              time: '12:30 PM',
              title: 'Lunch Break',
              description: mealNotes,
              cost: formatCost(mealPrice, isPerPerson: true),
              location: loc,
            ));

            // 4. Afternoon Activity matched to budget
            final actName = dest.activities.isNotEmpty 
                ? dest.activities[(day - 1) % dest.activities.length] 
                : 'Sightseeing';
            
            String actPrice = 'Free';
            if (extra.activityPrices.isNotEmpty) {
              final prices = extra.activityPrices;
              final matchingKey = prices.keys.firstWhere(
                (k) => k.toLowerCase().contains(actName.toLowerCase()) || actName.toLowerCase().contains(k.toLowerCase()),
                orElse: () => '',
              );
              if (matchingKey.isNotEmpty) {
                actPrice = prices[matchingKey]!;
              } else {
                actPrice = calculatedStyle == 'Low Budget' ? 'Free' : calculatedStyle == 'High Budget' ? '₱400' : '₱200';
              }
            } else {
              actPrice = calculatedStyle == 'Low Budget' ? 'Free' : calculatedStyle == 'High Budget' ? '₱400' : '₱200';
            }

            final noteStr = extra.travelNotes.isNotEmpty 
                ? extra.travelNotes.first 
                : 'Enjoy the majestic sights and take photos.';
            dayPlan.add(TripActivity(
              time: '02:30 PM',
              title: actName,
              description: 'Vibe: $vibe. $noteStr',
              cost: formatCost(actPrice, isPerPerson: true),
              location: loc,
            ));

            // 5. Evening stay matched to budget
            if (days > 1 && day < days) {
              Map<String, String>? accomm;
              if (extra.accommodationTypes.isNotEmpty) {
                final accommTypes = extra.accommodationTypes;
                if (calculatedStyle == 'Low Budget') {
                  accomm = accommTypes.first;
                } else if (calculatedStyle == 'High Budget') {
                  accomm = accommTypes.last;
                } else {
                  accomm = accommTypes[accommTypes.length ~/ 2];
                }
              }
              final accommName = accomm != null ? accomm['type'] ?? 'Standard Room' : 'Standard Room';
              final accommPrice = accomm != null ? accomm['price'] ?? '₱1,200' : '₱1,200';
              dayPlan.add(TripActivity(
                time: '06:00 PM',
                title: 'Check-in at $accommName',
                description: 'Stay overnight near $loc. Get dinner and relax.',
                cost: formatCost(accommPrice, isPerPerson: false),
                location: loc,
              ));
            } else {
              dayPlan.add(TripActivity(
                time: '06:00 PM',
                title: 'Evening Return',
                description: 'Wrap up the journey. Travel back.',
                cost: 'Free',
                location: 'Davao Region',
              ));
            }

            agenda[day] = dayPlan;
          }

          _latestGeneratedTrip = Trip(
            id: 'ai-trip-${DateTime.now().millisecondsSinceEpoch}',
            title: '$calculatedStyle $vibe Adventure in $district',
            destinationName: '$district, Davao Region',
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
