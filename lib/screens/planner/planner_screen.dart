import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/routes/app_routes.dart';
import '../../providers/trip_provider.dart';
import '../../models/destination.dart';
import '../../models/trip.dart';
import '../../models/planner_draft.dart';

class PlannerScreen extends StatefulWidget {
  const PlannerScreen({super.key});

  @override
  State<PlannerScreen> createState() => _PlannerScreenState();
}

class _PlannerScreenState extends State<PlannerScreen> {
  final List<_ChatMessage> _messages = [];
  final TextEditingController _messageCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  bool _isTyping = false;

  // Standard flow state
  String _selectedDistrict = '';
  int _selectedDays = 3;
  String _selectedVibe = '';
  double _selectedBudget = 5000;

  // Destination-specific flow state
  Destination? _activeDest;
  String _selectedDate = '';
  String _selectedBudgetCategory = ''; // 'Low', 'Balanced', 'High'

  // Shared variables
  String _selectedTravelType = ''; // 'Solo' or 'Group'
  int _numTravelers = 1;

  // Conversational steps:
  // Standard flow: 0=District, 1=Days, 2=TravelType, 3=TravelersCount, 4=Vibe, 5=Budget, 6=Generating, 7=Done
  // Destination flow: 10=Date, 11=Duration, 12=TravelType, 125=TravelersCount, 13=Budget Category, 14=Generating, 15=Done
  int _currentStep = 0;

  final List<String> _districts = [
    'Davao City', 'Davao del Norte', 'Davao del Sur',
    'Davao Oriental', 'Davao de Oro', 'Davao Occidental',
  ];
  final List<String> _vibes = [
    'Nature', 'Beach', 'Mountain', 'Adventure', 'Culture', 'Food', 'Luxury', 'Family', 'Relaxation',
  ];
  final List<String> _durations = ['1 Day', '2 Days', '3 Days', '4 Days', '5 Days', '7 Days'];
  final List<String> _budgets = ['₱3,000', '₱5,000', '₱10,000', '₱15,000', '₱20,000', '₱30,000'];
  final List<String> _dateOptions = ['This Weekend', 'Next Weekend', 'Next Month', 'Flexible Dates'];
  final List<String> _budgetCategories = ['Low Budget', 'Balanced Budget', 'High Budget'];
  final List<String> _destDurations = ['1 Day', '2 Days', '3 Days', '4 Days', '5 Days'];
  
  final List<String> _travelTypes = ['Solo Travel', 'Group Travel'];
  final List<String> _travelerCounts = ['2', '3', '4', '5', '6+'];

  bool _isDestinationMode = false;

  @override
  void initState() {
    super.initState();
    // Check after first frame so the provider tree is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeChat();
    });
  }

  void _initializeChat() {
    final provider = context.read<TripProvider>();
    final dest = provider.activePlanDestination;

    _isDestinationMode = false;
    _currentStep = 7; // Configure to fully free-form conversation!

    if (dest != null) {
      _activeDest = dest;
      setState(() {
        _messages.add(_ChatMessage(
          text:
              "Hello! 👋 I'm your Lakbay AI Travel Assistant.\n\n"
              "I see you want to plan a trip to **${dest.name}** in ${dest.location}! ✨\n\n"
              "Tell me what you'd like to do, e.g.:\n"
              "💬 *\"Plan a 3-day weekend group trip for 4 on a balanced budget\"*\n"
              "💬 *\"What is a low-budget itinerary for a 2-day solo trip here?\"*\n\n"
              "How would you like to plan your visit?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } else {
      setState(() {
        _messages.add(_ChatMessage(
          text:
              "Hello! I am your Lakbay AI Travel Assistant 🤖.\n\n"
              "I can help you design the perfect custom travel itinerary anywhere in the Davao Region!\n\n"
              "Simply tell me what you want, e.g.:\n"
              "💬 *\"Plan a 3-day beach trip to Mati with a 10k budget next month for 4 people\"*\n"
              "💬 *\"Show me low-budget family adventures in Toril, Davao City\"*\n\n"
              "How can I help you explore today?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _resetChat() {
    final tripProv = context.read<TripProvider>();
    tripProv.setActivePlanDestination(null);
    tripProv.updateDraft(null); // Clear draft!
    setState(() {
      _messages.clear();
      _currentStep = 7; // Configure to fully free-form conversation!
      _isDestinationMode = false;
      _selectedDistrict = '';
      _selectedDays = 3;
      _selectedVibe = '';
      _selectedBudget = 5000;
      _activeDest = null;
      _selectedDate = '';
      _selectedBudgetCategory = '';
      _selectedTravelType = '';
      _numTravelers = 1;
      _isTyping = false;
      _messages.add(_ChatMessage(
        text:
            "Hello! I am your Lakbay AI Travel Assistant 🤖.\n\n"
            "I can help you design the perfect custom travel itinerary anywhere in the Davao Region!\n\n"
            "Simply tell me what you want, e.g.:\n"
            "💬 *\"Plan a 3-day beach trip to Mati with a 10k budget next month for 4 people\"*\n"
            "💬 *\"Show me low-budget family adventures in Toril, Davao City\"*\n\n"
            "How can I help you explore today?",
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;
    _messageCtrl.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true, timestamp: DateTime.now()));
      _isTyping = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;

      // ── DESTINATION MODE FLOW ──────────────────────────────────────────
      if (_isDestinationMode) {
        await _handleDestinationFlowStep(text);
        return;
      }

      // Check if this input should bypass structured steps and query the AI directly
      bool isFreeForm = false;
      if (_currentStep == 7) {
        isFreeForm = true;
      } else if (_currentStep == 0 && !_districts.contains(text)) {
        isFreeForm = true;
      } else if (_currentStep == 1 && !_durations.contains(text)) {
        isFreeForm = true;
      } else if (_currentStep == 2 && !_travelTypes.contains(text)) {
        isFreeForm = true;
      } else if (_currentStep == 3 && !_travelerCounts.contains(text)) {
        isFreeForm = true;
      } else if (_currentStep == 4 && !_vibes.contains(text)) {
        isFreeForm = true;
      } else if (_currentStep == 5 && !_budgets.contains(text)) {
        isFreeForm = true;
      }

      if (isFreeForm) {
        final provider = context.read<TripProvider>();
        final success = await provider.sendFreeFormChat(text);

        if (!mounted) return;
        setState(() {
          _isTyping = false;
        });

        if (success) {
          setState(() {
            _messages.add(_ChatMessage(
              text: provider.latestChatResponse ?? "Here are my thoughts on your request.",
              isUser: false,
              timestamp: DateTime.now(),
              recommendations: provider.latestRecommendations.isNotEmpty ? provider.latestRecommendations : null,
            ));
          });
        } else {
          setState(() {
            _messages.add(_ChatMessage(
              text: "I couldn't process that query. Please make sure you are logged in to use the AI Travel Assistant.",
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        }
        _scrollToBottom();
        return;
      }

      // ── STANDARD FLOW ─────────────────────────────────────────────────
      await _handleStandardFlowStep(text);
    });
  }

  // =========================================================================
  //  STANDARD FLOW
  // =========================================================================
  Future<void> _handleStandardFlowStep(String text) async {
    String aiResponse = '';

    switch (_currentStep) {
      case 0:
        _selectedDistrict = text;
        _currentStep = 1;
        aiResponse = "Great choice! $_selectedDistrict is beautiful. 🗺️\n\nHow many days are you planning to stay?";
        break;
      case 1:
        final parsed = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 3;
        _selectedDays = parsed;
        _currentStep = 2;
        aiResponse = "Got it! A $_selectedDays-day trip to $_selectedDistrict. 🌟\n\nWho will you be traveling with? Solo or with a Group?";
        break;
      case 2:
        _selectedTravelType = text;
        if (text.toLowerCase().contains('group')) {
          _currentStep = 3;
          aiResponse = "Awesome, a group trip! 👥 How many travelers will be joining?";
        } else {
          _selectedTravelType = 'Solo';
          _numTravelers = 1;
          _currentStep = 4;
          aiResponse = "A solo adventure! 🎒 What kind of travel vibe or theme do you prefer?";
        }
        break;
      case 3:
        final count = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
        _numTravelers = count;
        _currentStep = 4;
        aiResponse = "Got it, $_numTravelers travelers! 🌟 What kind of travel vibe or theme do you prefer?";
        break;
      case 4:
        _selectedVibe = text;
        _currentStep = 5;
        aiResponse = "Awesome! A $_selectedVibe trip sounds perfect. 🎒\n\nFinally, what is your estimated budget for this adventure?";
        break;
      case 5:
        final clean = double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
        _selectedBudget = clean;
        _currentStep = 6;
        aiResponse =
            "Wonderful! I am now generating your custom $_selectedVibe itinerary in $_selectedDistrict "
            "with a budget of ₱${_selectedBudget.toStringAsFixed(0)}... ⏳";

        _appendAIMessage(aiResponse);

        final provider = context.read<TripProvider>();
        final trip = await provider.generatePlan(
          district: _selectedDistrict,
          days: _selectedDays,
          vibe: _selectedVibe,
          budget: _selectedBudget,
          isGroup: _selectedTravelType.toLowerCase().contains('group'),
          numTravelers: _numTravelers,
        );

        if (!mounted) return;

        setState(() { _isTyping = false; });

        if (trip != null) {
          setState(() {
            _currentStep = 7;
            _messages.add(_ChatMessage(
              text: "Here is your custom travel itinerary! 🏝️\nI hope you enjoy exploring the beauty of the Davao Region.",
              isUser: false,
              timestamp: DateTime.now(),
              generatedTrip: trip,
            ));
          });
        } else {
          setState(() {
            _currentStep = 5;
            _messages.add(_ChatMessage(
              text: "Ah, I ran into an error generating your plan. Please check your options and try again!",
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        }
        _saveDraft();
        _scrollToBottom();
        return;
    }

    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()));
    });
    _saveDraft();
    _scrollToBottom();
  }

  void _saveDraft() {
    final tripProv = context.read<TripProvider>();
    if (_isDestinationMode || _currentStep == 0 || _currentStep >= 7) {
      tripProv.updateDraft(null);
      return;
    }

    final allDests = Destination.davaoDestinations;
    final match = allDests.firstWhere(
      (d) => d.district.toLowerCase() == _selectedDistrict.toLowerCase(),
      orElse: () => allDests.first,
    );

    // Save standard steps (convert dynamically)
    int draftStep = 1;
    if (_currentStep == 4) draftStep = 2;
    if (_currentStep == 5) draftStep = 3;

    tripProv.updateDraft(PlannerDraft(
      destinationName: _selectedDistrict,
      step: draftStep,
      days: _selectedDays,
      vibe: _selectedVibe,
      budget: _selectedBudget,
      imageUrl: match.imageUrl,
    ));
  }

  // =========================================================================
  //  DESTINATION-SPECIFIC FLOW
  // =========================================================================
  Future<void> _handleDestinationFlowStep(String text) async {
    String aiResponse = '';
    final dest = _activeDest!;

    switch (_currentStep) {
      // Step 10 — user picks a travel date
      case 10:
        _selectedDate = text;
        _currentStep = 11;
        aiResponse =
            "📅 Perfect! **$_selectedDate** it is.\n\n"
            "How many days would you like to spend at **${dest.name}**?";
        break;

      // Step 11 — user picks duration
      case 11:
        final parsed = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        _selectedDays = parsed;
        _currentStep = 12;
        aiResponse =
            "Great — a **$_selectedDays-day** adventure at ${dest.name}! 🌿\n\n"
            "Who will you be traveling with? Solo or with a Group?";
        break;

      // Step 12 — user picks travel type
      case 12:
        _selectedTravelType = text;
        if (text.toLowerCase().contains('group')) {
          _currentStep = 125;
          aiResponse = "Awesome, a group trip! 👥 How many travelers will be joining?";
        } else {
          _selectedTravelType = 'Solo';
          _numTravelers = 1;
          _currentStep = 13;
          aiResponse =
              "A solo adventure! 🎒 Last question: What is your budget style for this trip?\n\n"
              "🟢 **Low Budget** — bare essentials\n"
              "🟡 **Balanced Budget** — comfort + affordability\n"
              "🔴 **High Budget** — premium experience";
        }
        break;

      // Step 12.5 — user picks traveler count
      case 125:
        final count = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
        _numTravelers = count;
        _currentStep = 13;
        aiResponse =
            "Got it, $_numTravelers travelers! 👥 Last question: What is your budget style for this trip?\n\n"
            "🟢 **Low Budget** — bare essentials\n"
            "🟡 **Balanced Budget** — comfort + affordability\n"
            "🔴 **High Budget** — premium experience";
        break;

      // Step 13 — user picks budget category
      case 13:
        _selectedBudgetCategory = text;
        _currentStep = 14;
        aiResponse =
            "Excellent! Preparing your **$_selectedBudgetCategory** plan for "
            "${dest.name} ($_selectedDays day${_selectedDays > 1 ? 's' : ''}, $_selectedDate)... ⏳";

        _appendAIMessage(aiResponse);

        // Generate the trip with budget-aware logic
        final trip = await _generateDestinationPlan(dest);

        if (!mounted) return;
        setState(() { _isTyping = false; });

        // Build cost breakdown message
        final costBreakdown = _buildCostBreakdownText(dest);

        setState(() {
          _currentStep = 15;
          _messages.add(_ChatMessage(
            text: costBreakdown,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        _scrollToBottom();

        await Future.delayed(const Duration(milliseconds: 600));
        if (!mounted) return;

        setState(() {
          _messages.add(_ChatMessage(
            text:
                "Here is your personalised **$_selectedBudgetCategory** itinerary for ${dest.name}! 🎉\n"
                "Tap the bookmark icon to save it to My Trips.",
            isUser: false,
            timestamp: DateTime.now(),
            generatedTrip: trip,
          ));
        });
        _scrollToBottom();

        // Clear the active destination context
        context.read<TripProvider>().setActivePlanDestination(null);
        return;
    }

    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()));
    });
    _scrollToBottom();
  }

  // =========================================================================
  //  HELPERS
  // =========================================================================
  void _appendAIMessage(String text) {
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: false, timestamp: DateTime.now()));
    });
    _scrollToBottom();
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

  double _getAccommodationCost(Destination dest, String category) {
    final extra = dest.extra;
    if (extra.accommodationTypes.isNotEmpty) {
      final types = extra.accommodationTypes;
      if (category == 'Low Budget') {
        return _parsePrice(types.first['price'] ?? '0');
      } else if (category == 'High Budget') {
        return _parsePrice(types.last['price'] ?? '0');
      } else {
        final mid = types.length ~/ 2;
        return _parsePrice(types[mid]['price'] ?? '0');
      }
    }
    
    final feeStr = extra.overnightFee;
    if (feeStr.toLowerCase().contains('not applicable')) return 0.0;
    final numbers = RegExp(r'\d[\d,\.]*').allMatches(feeStr.replaceAll(',', '')).map((m) => double.tryParse(m.group(0) ?? '') ?? 0.0).toList();
    if (numbers.isEmpty) return 0.0;
    if (numbers.length == 1) return numbers[0];
    
    if (category == 'Low Budget') {
      return numbers[0];
    } else if (category == 'High Budget') {
      return numbers[1];
    } else {
      return (numbers[0] + numbers[1]) / 2;
    }
  }

  Map<String, String>? _getTransportOption(Destination dest, String category) {
    final options = dest.extra.transportOptions;
    if (options.isEmpty) return null;
    
    final sorted = List<Map<String, String>>.from(options)
      ..sort((a, b) => _parsePrice(a['price'] ?? '0').compareTo(_parsePrice(b['price'] ?? '0')));
    
    if (category == 'Low Budget') {
      return sorted.first;
    } else if (category == 'High Budget') {
      return sorted.last;
    } else {
      final mid = sorted.length ~/ 2;
      return sorted[mid];
    }
  }

  double _getTransportCost(Destination dest, String category) {
    final opt = _getTransportOption(dest, category);
    if (opt == null) return 0.0;
    final priceStr = opt['price'] ?? '0';
    
    final numbers = RegExp(r'\d[\d,\.]*').allMatches(priceStr.replaceAll(',', '')).map((m) => double.tryParse(m.group(0) ?? '') ?? 0.0).toList();
    if (numbers.isEmpty) return 0.0;
    if (numbers.length == 1) return numbers[0];
    
    if (category == 'Low Budget') {
      return numbers[0];
    } else if (category == 'High Budget') {
      return numbers[1];
    } else {
      return (numbers[0] + numbers[1]) / 2;
    }
  }

  double _getActivitiesCost(Destination dest, String category) {
    final prices = dest.extra.activityPrices;
    if (prices.isEmpty) return 0.0;
    
    final parsedPrices = prices.values.map((p) => _parsePrice(p)).toList();
    if (parsedPrices.isEmpty) return 0.0;
    
    if (category == 'Low Budget') {
      parsedPrices.sort();
      return parsedPrices.first;
    } else if (category == 'High Budget') {
      return parsedPrices.reduce((sum, p) => sum + p);
    } else {
      final avg = parsedPrices.reduce((sum, p) => sum + p) / parsedPrices.length;
      return avg * (parsedPrices.length > 1 ? 2 : 1);
    }
  }

  /// Builds a richly formatted cost breakdown string using actual destination financial data
  String _buildCostBreakdownText(Destination dest) {
    final extra = dest.extra;
    final isLow = _selectedBudgetCategory == 'Low Budget';
    final isHigh = _selectedBudgetCategory == 'High Budget';

    // 1. Transport
    final double totalTransport = _getTransportCost(dest, _selectedBudgetCategory);
    final transportOpt = _getTransportOption(dest, _selectedBudgetCategory);
    String transportInfo = '';
    if (transportOpt != null) {
      transportInfo = "${transportOpt['vehicle'] ?? ''} from ${transportOpt['from'] ?? ''} → ${transportOpt['to'] ?? ''}";
    }

    // 2. Meals
    final double mealsPerDay = isLow ? 150.0 * 3 : isHigh ? 600.0 * 3 : 300.0 * 3;
    final double totalMeals = mealsPerDay * _selectedDays;

    // 3. Activities
    final double totalActivities = _getActivitiesCost(dest, _selectedBudgetCategory);

    // 4. Accommodation
    final double accommodationPerNight = _getAccommodationCost(dest, _selectedBudgetCategory);
    final double totalAccomm = _selectedDays > 1 ? accommodationPerNight * (_selectedDays - 1) : 0.0;

    // 5. Environmental & Entrance Fees
    final double environmentalFee = _parsePrice(extra.environmentalFee);
    final double entranceFee = _parsePrice(dest.entranceFee);

    final double grandTotal = totalTransport + totalMeals + totalActivities + totalAccomm + environmentalFee + entranceFee;

    // Pick accommodation type based on category
    String accommType = '';
    if (extra.accommodationTypes.isNotEmpty) {
      if (isLow) {
        accommType = extra.accommodationTypes.first['type'] ?? '';
      } else if (isHigh) {
        accommType = extra.accommodationTypes.last['type'] ?? '';
      } else {
        final mid = extra.accommodationTypes.length ~/ 2;
        accommType = extra.accommodationTypes[mid]['type'] ?? '';
      }
    }

    final emoji = isLow ? '🟢' : isHigh ? '🔴' : '🟡';

    return "$emoji **$_selectedBudgetCategory Cost Breakdown**\n"
        "📍 ${dest.name} • $_selectedDays Day${_selectedDays > 1 ? 's' : ''} • $_selectedDate\n\n"
        "🚌 **Transport** — ₱${totalTransport.toStringAsFixed(0)}\n"
        "${transportInfo.isNotEmpty ? '   $transportInfo\n' : ''}"
        "🍽️ **Meals** (${_selectedDays}x) — ₱${totalMeals.toStringAsFixed(0)}\n"
        "   ${extra.mealInclusions.isNotEmpty ? extra.mealInclusions.first : 'Local food stalls available.'}\n"
        "🎯 **Activities** — ₱${totalActivities.toStringAsFixed(0)}\n"
        "   ${dest.activities.take(3).join(' • ')}\n"
        "${_selectedDays > 1 && totalAccomm > 0 ? '🏨 **Accommodation** (${_selectedDays - 1} night${_selectedDays > 2 ? 's' : ''}) — ₱${totalAccomm.toStringAsFixed(0)}\n'
            '   ${accommType.isNotEmpty ? accommType : 'Standard Room'}\n' : ''}"
        "🌿 **Environmental Fee** — ${extra.environmentalFee}\n"
        "🎟️ **Entrance Fee** — ${dest.entranceFee}\n\n"
        "━━━━━━━━━━━━━━━━━━\n"
        "💰 **Estimated Total: ₱${grandTotal.toStringAsFixed(0)}** per person\n"
        "${_selectedTravelType.toLowerCase().contains('group') ? '👥 **Group Total (for $_numTravelers travelers): ₱${(grandTotal * _numTravelers).toStringAsFixed(0)}**\n' : ''}"
        "(excluding personal expenses)";
  }

  /// Generates a Trip object tailored to the destination, date, days, and budget
  Future<Trip> _generateDestinationPlan(Destination dest) async {
    await Future.delayed(const Duration(milliseconds: 1800));

    final isLow = _selectedBudgetCategory == 'Low Budget';
    final isHigh = _selectedBudgetCategory == 'High Budget';

    // Compute a real start date
    DateTime startDate = DateTime.now();
    if (_selectedDate == 'This Weekend') {
      final daysUntilSat = (6 - startDate.weekday) % 7;
      startDate = startDate.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    } else if (_selectedDate == 'Next Weekend') {
      final daysUntilSat = (6 - startDate.weekday) % 7;
      startDate = startDate.add(Duration(days: daysUntilSat + 7));
    } else if (_selectedDate == 'Next Month') {
      startDate = DateTime(startDate.year, startDate.month + 1, 1);
    }

    final endDate = startDate.add(Duration(days: _selectedDays - 1));
    final dateRange = _selectedDays == 1
        ? _formatDate(startDate)
        : '${_formatDate(startDate)} – ${_formatDate(endDate)}';

    // Build day-by-day itinerary based on destination
    final Map<int, List<TripActivity>> agenda = {};
    final extra = dest.extra;

    final transportOpt = _getTransportOption(dest, _selectedBudgetCategory);

    for (int day = 1; day <= _selectedDays; day++) {
      final List<TripActivity> dayPlan = [];
      final String loc = dest.name;

      // Morning: transport + arrival or next-day activity
      dayPlan.add(TripActivity(
        time: '07:00 AM',
        title: day == 1 ? 'Depart & Travel to ${dest.name}' : 'Morning at ${dest.name}',
        description: day == 1
            ? (transportOpt != null
                ? '${transportOpt['vehicle']} from ${transportOpt['from']} → ${transportOpt['to']}.'
                : 'Head to ${dest.location} via your preferred transport.')
            : 'Start the day with breakfast and light exploration around the area.',
        cost: day == 1
            ? (transportOpt != null ? transportOpt['price']! : 'Free')
            : 'Free',
        location: day == 1 ? 'En Route' : loc,
      ));

      // Entrance / check-in
      dayPlan.add(TripActivity(
        time: '09:00 AM',
        title: day == 1 ? 'Arrival & Check-In at ${dest.name}' : 'Full Day Exploration',
        description: day == 1
            ? 'Pay entrance fee (${dest.entranceFee}) and environmental fee (${extra.environmentalFee}). Collect maps and orient with the surroundings.'
            : 'Enjoy a beautiful morning exploring the core sights of the destination.',
        cost: day == 1 ? dest.entranceFee : 'Free',
        location: loc,
      ));

      // Main activity
      if (dest.activities.isNotEmpty) {
        final actIdx = (day - 1) % dest.activities.length;
        final actName = dest.activities[actIdx];
        
        // Find price for this specific activity
        String actPrice = 'Free';
        final prices = extra.activityPrices;
        final matchingKey = prices.keys.firstWhere(
          (k) => k.toLowerCase().contains(actName.toLowerCase()) || actName.toLowerCase().contains(k.toLowerCase()),
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty) {
          actPrice = prices[matchingKey]!;
        } else if (isLow) {
          actPrice = 'Free';
        } else {
          actPrice = isHigh ? '₱400' : '₱200';
        }

        dayPlan.add(TripActivity(
          time: '10:30 AM',
          title: actName,
          description: isLow
              ? 'Budget-friendly option — enjoy $actName with value-conscious settings.'
              : isHigh
                  ? 'Premium private guided $actName with top-tier equipment and priority access.'
                  : 'Standard experience of $actName with standard equipment.',
          cost: actPrice,
          location: loc,
        ));
      }

      // Lunch
      dayPlan.add(TripActivity(
        time: '12:30 PM',
        title: 'Lunch Break',
        description: isLow
            ? 'Affordable local eateries or packed lunch. Karinderia-style meals available nearby.'
            : isHigh
                ? 'Premium in-resort dining or top-rated restaurant nearby.'
                : 'Mid-range restaurant or in-resort café.',
        cost: isLow ? '₱150' : isHigh ? '₱600' : '₱300',
        location: loc,
      ));

      // Afternoon activity
      dayPlan.add(TripActivity(
        time: '02:00 PM',
        title: 'Afternoon ${dest.category} Experience',
        description: 'Explore more of ${dest.name}. '
            '${extra.travelNotes.isNotEmpty ? extra.travelNotes.first : 'Enjoy the scenery and take photos.'}',
        cost: isLow ? '₱100' : isHigh ? '₱500' : '₱250',
        location: loc,
      ));

      // Evening / Overnight
      if (_selectedDays > 1 && day < _selectedDays) {
        final accommTypes = extra.accommodationTypes;
        String accommName = 'Standard Room';
        String accommPrice = '₱800–₱1,200 / night';
        if (accommTypes.isNotEmpty) {
          int accommIdx = isLow ? 0 : isHigh ? accommTypes.length - 1 : accommTypes.length ~/ 2;
          accommIdx = accommIdx.clamp(0, accommTypes.length - 1);
          accommName = accommTypes[accommIdx]['type'] ?? accommName;
          accommPrice = accommTypes[accommIdx]['price'] ?? accommPrice;
        }
        dayPlan.add(TripActivity(
          time: '06:00 PM',
          title: 'Dinner & Check-In: $accommName',
          description: '${extra.mealInclusions.isNotEmpty ? extra.mealInclusions.first : 'Dinner at nearby grill houses.'} Overnight at $accommName.',
          cost: accommPrice,
          location: loc,
        ));
      } else {
        dayPlan.add(TripActivity(
          time: '05:00 PM',
          title: 'Wrap Up & Return Trip',
          description: 'Pack up and head back via ${transportOpt != null ? transportOpt['vehicle'] ?? 'transport' : 'transport'}.',
          cost: transportOpt != null ? transportOpt['price']! : 'Free',
          location: 'En Route Home',
        ));
      }

      agenda[day] = dayPlan;
    }

    final double accommodationPerNight = _getAccommodationCost(dest, _selectedBudgetCategory);
    final double totalAccomm = _selectedDays > 1 ? accommodationPerNight * (_selectedDays - 1) : 0.0;
    final double totalTransport = _getTransportCost(dest, _selectedBudgetCategory);
    final double mealsPerDay = isLow ? 150.0 * 3 : isHigh ? 600.0 * 3 : 300.0 * 3;
    final double totalMeals = mealsPerDay * _selectedDays;
    final double totalActivities = _getActivitiesCost(dest, _selectedBudgetCategory);
    final double environmentalFee = _parsePrice(dest.extra.environmentalFee);
    final double entranceFee = _parsePrice(dest.entranceFee);
    final double budgetEst = totalTransport + totalMeals + totalActivities + totalAccomm + environmentalFee + entranceFee;

    return Trip(
      id: 'ai-dest-trip-${DateTime.now().millisecondsSinceEpoch}',
      title: '$_selectedBudgetCategory Trip to ${dest.name}',
      destinationName: '${dest.name}, ${dest.district}',
      dateRange: dateRange,
      budget: budgetEst,
      imageUrl: dest.imageUrl,
      itinerary: agenda,
      isGroup: _selectedTravelType.toLowerCase().contains('group'),
      numTravelers: _numTravelers,
    );
  }

  String _formatDate(DateTime d) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  // =========================================================================
  //  BUILD
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TripProvider>();

    // Check for prefilled mood prompt deep-link from home screen
    if (provider.activePlanningMoodPrompt != null) {
      final prompt = provider.activePlanningMoodPrompt!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setActivePlanningMoodPrompt(null);
        _handleSendMessage(prompt);
      });
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppTheme.primaryBlue,
        automaticallyImplyLeading: false,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
            ),
          ),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isDestinationMode && _activeDest != null
                      ? 'Planning: ${_activeDest!.name}'
                      : 'Lakbay AI Assistant',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isDestinationMode ? 'Destination Mode' : 'Online',
                      style: GoogleFonts.outfit(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            tooltip: 'Restart Planning',
            onPressed: _resetChat,
          ),
        ],
      ),
      body: Column(
        children: [
          // Destination context banner
          if (_isDestinationMode && _activeDest != null)
            _buildDestinationBanner(_activeDest!),

          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: AppConstants.spaceM),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildChatItem(_messages[index]);
              },
            ),
          ),
          _buildQuickReplies(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDestinationBanner(Destination dest) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.secondaryGreen.withValues(alpha: 0.15), AppTheme.primaryBlue.withValues(alpha: 0.08)],
        ),
        border: Border(bottom: BorderSide(color: AppTheme.secondaryGreen.withValues(alpha: 0.3))),
      ),
      child: Row(
        children: [
          const Icon(Icons.place_rounded, color: AppTheme.secondaryGreen, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dest.name,
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                ),
                Text(
                  dest.location,
                  style: GoogleFonts.outfit(fontSize: 11, color: AppTheme.textSecondaryLight),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppTheme.secondaryGreen,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              dest.category,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(_ChatMessage message) {
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryBlue,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
                child: Text(
                  message.text,
                  style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.12),
            child: const Icon(Icons.psychology_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.outfit(
                        color: AppTheme.textPrimaryLight, fontSize: 14, height: 1.5),
                  ),
                ),
                if (message.generatedTrip != null) ...[
                  const SizedBox(height: AppConstants.spaceM),
                  _buildTripCard(message.generatedTrip!),
                ],
                if (message.recommendations != null && message.recommendations!.isNotEmpty) ...[
                  _buildRecommendations(message.recommendations!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<Destination> recommendations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'Recommended Destinations:',
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlue,
            ),
          ),
        ),
        SizedBox(
          height: 190,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final dest = recommendations[index];
              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12, bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Destination Image
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              dest.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Container(
                                color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                                child: const Icon(Icons.place_rounded, color: AppTheme.primaryBlue),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.star_rounded, color: Colors.amber, size: 10),
                                    const SizedBox(width: 2),
                                    Text(
                                      dest.rating.toStringAsFixed(1),
                                      style: GoogleFonts.outfit(
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
                      // Destination Details
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dest.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, color: Colors.grey, size: 10),
                                const SizedBox(width: 2),
                                Expanded(
                                  child: Text(
                                    dest.district,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.outfit(
                                      fontSize: 9,
                                      color: AppTheme.textSecondaryLight,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              height: 24,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.zero,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed: () {
                                  // Switch to Destination flow
                                  setState(() {
                                    _activeDest = dest;
                                    _isDestinationMode = true;
                                    _currentStep = 10;
                                    
                                    _messages.add(_ChatMessage(
                                      text: "You selected **${dest.name}**! 🌴 Let's plan your customized visit here.\n\nFirst, when are you planning to travel?",
                                      isUser: false,
                                      timestamp: DateTime.now(),
                                    ));
                                  });
                                  _scrollToBottom();
                                },
                                child: Text(
                                  'Plan Trip',
                                  style: GoogleFonts.outfit(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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

  Widget _buildTripCard(Trip trip) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.premiumShadow,
        border: Border.all(color: AppTheme.secondaryGreen.withValues(alpha: 0.2)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero image
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    trip.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(color: AppTheme.primaryBlue),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12, left: 12, right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _chip('${trip.itinerary.length} Day${trip.itinerary.length > 1 ? 's' : ''}',
                                AppTheme.secondaryGreen),
                            const SizedBox(width: 6),
                            if (_selectedBudgetCategory.isNotEmpty)
                              _chip(_selectedBudgetCategory,
                                  _selectedBudgetCategory == 'Low Budget'
                                      ? Colors.green[700]!
                                      : _selectedBudgetCategory == 'High Budget'
                                          ? Colors.red[700]!
                                          : Colors.amber[700]!),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.title,
                          style: GoogleFonts.outfit(
                              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppConstants.spaceM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(Icons.location_on_rounded, trip.destinationName, AppTheme.textSecondaryLight),
                  const SizedBox(height: 6),
                  _infoRow(Icons.calendar_today_rounded, trip.dateRange, AppTheme.textSecondaryLight),
                  const SizedBox(height: 6),
                  _infoRow(Icons.payments_rounded,
                      'Est. Total: ₱${trip.budget.toStringAsFixed(0)}', AppTheme.secondaryGreen,
                      bold: true),
                  const SizedBox(height: AppConstants.spaceM),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.map_rounded, size: 16),
                          label: Text('View Details',
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold)),
                          onPressed: () {
                            Navigator.pushNamed(
                              context,
                              AppRoutes.plannerResults,
                              arguments: trip.itinerary.length,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.12),
                          foregroundColor: AppTheme.secondaryGreen,
                          padding: const EdgeInsets.all(10),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.bookmark_add_rounded, size: 20),
                        tooltip: 'Save to My Trips',
                        onPressed: () async {
                          final provider = context.read<TripProvider>();
                          provider.addNewTrip(trip);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Itinerary saved to My Trips! 🎉'),
                                backgroundColor: AppTheme.secondaryGreen,
                              ),
                            );
                          }
                        },
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

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(99)),
      child: Text(label,
          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _infoRow(IconData icon, String text, Color color, {bool bold = false}) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: bold ? FontWeight.bold : FontWeight.normal),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.12),
            child: const Icon(Icons.psychology_rounded, color: AppTheme.primaryBlue, size: 20),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(0),
                const SizedBox(width: 4),
                _buildDot(1),
                const SizedBox(width: 4),
                _buildDot(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDot(int index) => _TypingDot(delayMs: index * 150);

  Widget _buildQuickReplies() {
    if (_messages.length > 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 8),
        child: Row(
          children: [
            ActionChip(
              backgroundColor: AppTheme.secondaryGreen,
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text('Plan Another Trip',
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              onPressed: _resetChat,
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.black12.withValues(alpha: 0.08)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageCtrl,
                  onSubmitted: _handleSendMessage,
                  decoration: const InputDecoration(
                    hintText: 'Type your message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  style: GoogleFonts.outfit(fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _handleSendMessage(_messageCtrl.text),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
//  DATA CLASSES
// =============================================================================
class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final Trip? generatedTrip;
  final List<Destination>? recommendations;

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.generatedTrip,
    this.recommendations,
  });
}

class _TypingDot extends StatefulWidget {
  final int delayMs;
  const _TypingDot({required this.delayMs});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: widget.delayMs), () {
      if (mounted) {
        _animCtrl.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animCtrl,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -4 * _animCtrl.value),
        child: Opacity(
          opacity: 0.3 + 0.7 * _animCtrl.value,
          child: Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}
