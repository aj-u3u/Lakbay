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

  // Conversational steps:
  // Standard flow: 0=District 1=Days 2=Vibe 3=Budget 4=Generating 5=Done
  // Destination flow: 10=Date 11=Duration 12=Budget Category 13=Generating 14=Done
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

    if (dest != null) {
      _activeDest = dest;
      _isDestinationMode = true;
      _currentStep = 10;

      setState(() {
        _messages.add(_ChatMessage(
          text:
              "Hello! 👋 I'm your Lakbay AI Travel Assistant.\n\n"
              "I see you're interested in visiting **${dest.name}** in ${dest.location}! ✨\n\n"
              "Let me help you plan the perfect trip there. First — when are you planning to go?",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } else {
      _isDestinationMode = false;
      _currentStep = 0;

      setState(() {
        _messages.add(_ChatMessage(
          text:
              "Hello! I am your Lakbay AI Travel Assistant 🤖.\n\n"
              "Let's design your perfect itinerary in the Davao Region! Where would you like to travel?",
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
    // Clear active destination from provider
    context.read<TripProvider>().setActivePlanDestination(null);
    setState(() {
      _messages.clear();
      _currentStep = 0;
      _isDestinationMode = false;
      _selectedDistrict = '';
      _selectedDays = 3;
      _selectedVibe = '';
      _selectedBudget = 5000;
      _activeDest = null;
      _selectedDate = '';
      _selectedBudgetCategory = '';
      _isTyping = false;
      _messages.add(_ChatMessage(
        text:
            "Hello! I am your Lakbay AI Travel Assistant 🤖.\n\n"
            "Let's design your perfect itinerary in the Davao Region! Where would you like to travel?",
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
        aiResponse = "Got it! A $_selectedDays-day trip to $_selectedDistrict.🌟\n\nWhat kind of travel vibe or theme do you prefer?";
        break;
      case 2:
        _selectedVibe = text;
        _currentStep = 3;
        aiResponse = "Awesome! A $_selectedVibe trip sounds perfect. 🎒\n\nFinally, what is your estimated budget for this adventure?";
        break;
      case 3:
        final clean = double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
        _selectedBudget = clean;
        _currentStep = 4;
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
        );

        if (!mounted) return;

        setState(() { _isTyping = false; });

        if (trip != null) {
          setState(() {
            _currentStep = 5;
            _messages.add(_ChatMessage(
              text: "Here is your custom travel itinerary! 🏝️\nI hope you enjoy exploring the beauty of the Davao Region.",
              isUser: false,
              timestamp: DateTime.now(),
              generatedTrip: trip,
            ));
          });
        } else {
          setState(() {
            _currentStep = 3;
            _messages.add(_ChatMessage(
              text: "Ah, I ran into an error generating your plan. Please check your options and try again!",
              isUser: false,
              timestamp: DateTime.now(),
            ));
          });
        }
        _scrollToBottom();
        return;
    }

    setState(() {
      _isTyping = false;
      _messages.add(_ChatMessage(text: aiResponse, isUser: false, timestamp: DateTime.now()));
    });
    _scrollToBottom();
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
            "Last question: What is your budget style for this trip?\n\n"
            "🟢 **Low Budget** — bare essentials, value-for-money\n"
            "🟡 **Balanced Budget** — comfort + affordability\n"
            "🔴 **High Budget** — premium experience, no compromises";
        break;

      // Step 12 — user picks budget category
      case 12:
        _selectedBudgetCategory = text;
        _currentStep = 13;
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
          _currentStep = 14;
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

  /// Returns budget multipliers for each category
  Map<String, double> _budgetMultipliers() {
    switch (_selectedBudgetCategory) {
      case 'Low Budget':
        return {'transport': 0.6, 'meals': 0.5, 'activity': 0.4, 'accommodation': 0.4};
      case 'High Budget':
        return {'transport': 1.6, 'meals': 1.8, 'activity': 1.5, 'accommodation': 2.0};
      default: // Balanced
        return {'transport': 1.0, 'meals': 1.0, 'activity': 1.0, 'accommodation': 1.0};
    }
  }

  /// Builds a richly formatted cost breakdown string
  String _buildCostBreakdownText(Destination dest) {
    final extra = dest.extra;
    final m = _budgetMultipliers();
    final isLow = _selectedBudgetCategory == 'Low Budget';
    final isHigh = _selectedBudgetCategory == 'High Budget';

    final double transportBase = isLow ? 150 : isHigh ? 1400 : 350;
    final double mealsPerDay = isLow ? 200 : isHigh ? 900 : 450;
    final double activityBase = isLow ? 100 : isHigh ? 800 : 350;
    final double accommodationPerNight = _selectedDays > 1
        ? (isLow ? 300 : isHigh ? 12000 : 2500)
        : 0.0;

    final double totalTransport = transportBase * (m['transport'] ?? 1.0);
    final double totalMeals = mealsPerDay * _selectedDays * (m['meals'] ?? 1.0);
    final double totalActivities = activityBase * _selectedDays * (m['activity'] ?? 1.0);
    final double totalAccomm = _selectedDays > 1 ? accommodationPerNight * (_selectedDays - 1) : 0.0;
    final double grandTotal = totalTransport + totalMeals + totalActivities + totalAccomm;

    // Pick accommodation type based on category
    String accommType = '';
    if (extra.accommodationTypes.isNotEmpty) {
      if (isLow) {
        accommType = extra.accommodationTypes.first['type'] ?? '';
      } else if (isHigh) {
        accommType = extra.accommodationTypes.last['type'] ?? '';
      } else {
        accommType = extra.accommodationTypes.length > 1
            ? extra.accommodationTypes[1]['type'] ?? ''
            : extra.accommodationTypes.first['type'] ?? '';
      }
    }

    // Pick transport option
    String transportInfo = '';
    if (extra.transportOptions.isNotEmpty) {
      final t = extra.transportOptions.first;
      transportInfo = "${t['vehicle'] ?? ''} from ${t['from'] ?? ''} → ${t['to'] ?? ''}";
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
        "${_selectedDays > 1 ? '🏨 **Accommodation** (${_selectedDays - 1} night${_selectedDays > 2 ? 's' : ''}) — ₱${totalAccomm.toStringAsFixed(0)}\n'
            '   ${accommType.isNotEmpty ? accommType : 'Standard Room'}\n' : ''}"
        "🌿 **Environmental Fee** — ${extra.environmentalFee}\n"
        "🎟️ **Entrance Fee** — ${dest.entranceFee}\n\n"
        "━━━━━━━━━━━━━━━━━━\n"
        "💰 **Estimated Total: ₱${grandTotal.toStringAsFixed(0)}**\n"
        "(per person, excluding personal expenses)";
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

    for (int day = 1; day <= _selectedDays; day++) {
      final List<TripActivity> dayPlan = [];
      final String loc = dest.name;

      // Morning: transport + arrival or next-day activity
      dayPlan.add(TripActivity(
        time: '07:00 AM',
        title: day == 1 ? 'Depart & Travel to ${dest.name}' : 'Morning at ${dest.name}',
        description: day == 1
            ? (extra.transportOptions.isNotEmpty
                ? '${extra.transportOptions.first['vehicle']} from ${extra.transportOptions.first['from']} → ${extra.transportOptions.first['to']}.'
                : 'Head to ${dest.location} via your preferred transport.')
            : 'Start the day with breakfast and light exploration around the area.',
        cost: day == 1
            ? (isLow ? '₱100–₱250' : isHigh ? '₱1,200–₱1,500' : '₱300–₱500')
            : '₱150–₱300',
        location: day == 1 ? 'En Route' : loc,
      ));

      // Entrance / check-in
      dayPlan.add(TripActivity(
        time: '09:00 AM',
        title: day == 1 ? 'Arrival & Check-In at ${dest.name}' : 'Full Day Exploration',
        description: 'Pay entrance fee (${dest.entranceFee}) and ${extra.environmentalFee}. '
            'Collect maps and orient with the surroundings.',
        cost: dest.entranceFee,
        location: loc,
      ));

      // Main activity
      if (dest.activities.isNotEmpty) {
        final actIdx = (day - 1) % dest.activities.length;
        final actPrices = extra.activityPrices;
        final actKey = actPrices.keys.isNotEmpty
            ? actPrices.keys.elementAt((day - 1) % actPrices.keys.length)
            : null;
        dayPlan.add(TripActivity(
          time: '10:30 AM',
          title: dest.activities[actIdx],
          description: isLow
              ? 'Budget-friendly version — join group activities and shared tours.'
              : isHigh
                  ? 'Premium private guided experience with all equipment included.'
                  : 'Standard experience with optional guided tour available on-site.',
          cost: actKey != null ? actPrices[actKey]! : '₱150–₱500',
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
        cost: isLow ? '₱80–₱150' : isHigh ? '₱600–₱900' : '₱250–₱450',
        location: loc,
      ));

      // Afternoon activity
      dayPlan.add(TripActivity(
        time: '02:00 PM',
        title: 'Afternoon ${dest.category} Experience',
        description: 'Explore more of ${dest.name}. '
            '${extra.travelNotes.isNotEmpty ? extra.travelNotes.first : 'Enjoy the scenery and take photos.'}',
        cost: isLow ? '₱50–₱100' : isHigh ? '₱500–₱800' : '₱200–₱350',
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
          description: '${extra.mealInclusions.length > 1 ? extra.mealInclusions[1] : 'Dinner on own.'} '
              'Overnight at $accommName ($accommPrice).',
          cost: accommPrice,
          location: loc,
        ));
      } else {
        dayPlan.add(TripActivity(
          time: '05:00 PM',
          title: 'Wrap Up & Return Trip',
          description: 'Pack up and head back via ${extra.transportOptions.isNotEmpty ? extra.transportOptions.first['vehicle'] ?? 'transport' : 'transport'}.',
          cost: isLow ? '₱80–₱150' : isHigh ? '₱800–₱1,200' : '₱250–₱400',
          location: 'En Route Home',
        ));
      }

      agenda[day] = dayPlan;
    }

    final budgetEst = _selectedDays *
        (isLow ? dest.estimatedCost * 0.6 : isHigh ? dest.estimatedCost * 1.8 : dest.estimatedCost);

    return Trip(
      id: 'ai-dest-trip-${DateTime.now().millisecondsSinceEpoch}',
      title: '$_selectedBudgetCategory Trip to ${dest.name}',
      destinationName: '${dest.name}, ${dest.district}',
      dateRange: dateRange,
      budget: budgetEst,
      imageUrl: dest.imageUrl,
      itinerary: agenda,
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
              ],
            ),
          ),
        ],
      ),
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
    List<String> options = [];

    // Destination-specific flow
    if (_isDestinationMode) {
      if (_currentStep == 10) {
        options = _dateOptions;
      } else if (_currentStep == 11) {
        options = _destDurations;
      } else if (_currentStep == 12) {
        options = _budgetCategories;
      } else if (_currentStep == 14) {
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
    } else {
      // Standard flow
      if (_currentStep == 0) {
        options = _districts;
      } else if (_currentStep == 1) {
        options = _durations;
      } else if (_currentStep == 2) {
        options = _vibes;
      } else if (_currentStep == 3) {
        options = _budgets;
      } else if (_currentStep == 5) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM, vertical: 8),
          child: ActionChip(
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
        );
      }
    }

    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppConstants.spaceM),
        itemCount: options.length,
        itemBuilder: (context, index) {
          final opt = options[index];
          // Budget category chips get colored
          Color? chipColor;
          if (_isDestinationMode && _currentStep == 12) {
            chipColor = opt.contains('Low')
                ? Colors.green[50]
                : opt.contains('High')
                    ? Colors.red[50]
                    : Colors.amber[50];
          }
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ActionChip(
              backgroundColor: chipColor ?? Colors.white,
              elevation: 1,
              shadowColor: Colors.black.withValues(alpha: 0.05),
              side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(99)),
              label: Text(opt,
                  style: GoogleFonts.outfit(
                      color: AppTheme.primaryBlue, fontSize: 13, fontWeight: FontWeight.w600)),
              onPressed: () => _handleSendMessage(opt),
            ),
          );
        },
      ),
    );
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

  _ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.generatedTrip,
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
