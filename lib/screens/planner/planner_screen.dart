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
import '../destinations/destination_details_screen.dart';

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
    'Davao City',
    'Davao del Norte',
    'Davao del Sur',
    'Davao Oriental',
    'Davao de Oro',
    'Davao Occidental',
  ];
  final List<String> _vibes = [
    'Nature',
    'Beach',
    'Mountain',
    'Adventure',
    'Culture',
    'Food',
    'Luxury',
    'Family',
    'Relaxation',
  ];
  final List<String> _durations = [
    '1 Day',
    '2 Days',
    '3 Days',
    '4 Days',
    '5 Days',
    '7 Days',
  ];
  final List<String> _budgets = [
    '₱3,000',
    '₱5,000',
    '₱10,000',
    '₱15,000',
    '₱20,000',
    '₱30,000',
  ];
  final List<String> _dateOptions = [
    'This Weekend',
    'Next Weekend',
    'Next Month',
    'Flexible Dates',
  ];
  final List<String> _budgetCategories = [
    'Low Budget',
    'Balanced Budget',
    'High Budget',
  ];
  final List<String> _destDurations = [
    '1 Day',
    '2 Days',
    '3 Days',
    '4 Days',
    '5 Days',
  ];

  final List<String> _travelTypes = ['Solo Travel', 'Group Travel'];
  final List<String> _travelerCounts = ['2', '3', '4', '5', '6+'];

  bool _isDestinationMode = false;
  bool _extractedDays = false;
  bool _extractedTravelType = false;
  bool _extractedBudget = false;

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
        _messages.clear();
        _messages.add(
          _ChatMessage(
            text:
                "You selected **${dest.name}**! 🌴 Let's plan your customized visit here.\n\nFirst, when are you planning to travel?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
    } else {
      _isDestinationMode = false;
      _currentStep = 7; // Configure to fully free-form conversation!
      setState(() {
        _messages.add(
          _ChatMessage(
            text:
                "Hello! I am your Lakbay AI travel assistant. I can help you design the perfect custom travel itinerary anywhere in the Davao Region. How can I help you explore today?",
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
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
      _extractedDays = false;
      _extractedTravelType = false;
      _extractedBudget = false;
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
      _messages.add(
        _ChatMessage(
          text:
              "Hello! I am your Lakbay AI travel assistant. I can help you design the perfect custom travel itinerary anywhere in the Davao Region. How can I help you explore today?",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _resetChatWithSuccessMessage() {
    final tripProv = context.read<TripProvider>();
    tripProv.setActivePlanDestination(null);
    tripProv.updateDraft(null); // Clear draft!
    setState(() {
      _messages.clear();
      _currentStep = 7; // Configure to fully free-form conversation!
      _isDestinationMode = false;
      _extractedDays = false;
      _extractedTravelType = false;
      _extractedBudget = false;
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
      _messages.add(
        _ChatMessage(
          text: "Your trip has been saved! Ready to plan another adventure? 🗺️",
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;
    _messageCtrl.clear();

    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isTyping = true;
    });
    _scrollToBottom();

    Future.delayed(const Duration(milliseconds: 900), () async {
      if (!mounted) return;

      // ── DESTINATION MODE FLOW ──────────────────────────────────────────
      if (_isDestinationMode) {
        // Intercept correction attempts during active planning steps
        const correctableSteps = [10, 11, 12, 115, 116, 125, 128, 13];
        if (correctableSteps.contains(_currentStep) &&
            _detectCorrectionIntent(text)) {
          await _handleCorrectionIntent(text);
          return;
        }
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
        _extractPrefsFromPrompt(text);
        final provider = context.read<TripProvider>();
        final success = await provider.sendFreeFormChat(text);

        if (!mounted) return;
        setState(() {
          _isTyping = false;
        });

        if (success) {
          setState(() {
            _messages.add(
              _ChatMessage(
                text:
                    provider.latestChatResponse ??
                    "Here are my thoughts on your request.",
                isUser: false,
                timestamp: DateTime.now(),
                recommendations: provider.latestRecommendations.isNotEmpty
                    ? provider.latestRecommendations
                    : null,
              ),
            );
          });
        } else {
          setState(() {
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't process that query. Please make sure you are logged in to use the AI Travel Assistant.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
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
        aiResponse =
            "Great choice! $_selectedDistrict is beautiful. 🗺️\n\nHow many days are you planning to stay?";
        break;
      case 1:
        final parsed =
            int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 3;
        _selectedDays = parsed;
        _currentStep = 2;
        aiResponse =
            "Got it! A $_selectedDays-day trip to $_selectedDistrict. 🌟\n\nWho will you be traveling with? Solo or with a Group?";
        break;
      case 2:
        _selectedTravelType = text;
        if (text.toLowerCase().contains('group')) {
          _currentStep = 3;
          aiResponse =
              "Awesome, a group trip! 👥 How many travelers will be joining?";
        } else {
          _selectedTravelType = 'Solo';
          _numTravelers = 1;
          _currentStep = 5;
          aiResponse =
              "A solo adventure! 🎒 What is your estimated budget for this adventure?";
        }
        break;
      case 3:
        final count = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
        _numTravelers = count;
        _currentStep = 5;
        aiResponse =
            "Got it, $_numTravelers travelers! 👥 What is your estimated budget for this adventure?";
        break;
      case 5:
        final clean =
            double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
        _selectedBudget = clean;
        _currentStep = 4;
        aiResponse =
            "Got it! A budget of ₱${_selectedBudget.toStringAsFixed(0)} is set. 💰\n\nWhat kind of travel vibe or theme do you prefer?";
        break;
      case 4:
        _selectedVibe = text;
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

        setState(() {
          _isTyping = false;
        });

        if (trip != null) {
          setState(() {
            _currentStep = 7;
            _messages.add(
              _ChatMessage(
                text:
                    "Here is your custom travel itinerary! 🏝️\nI hope you enjoy exploring the beauty of the Davao Region.",
                isUser: false,
                timestamp: DateTime.now(),
                generatedTrip: trip,
              ),
            );
          });
        } else {
          setState(() {
            _currentStep = 4;
            _messages.add(
              _ChatMessage(
                text:
                    "Ah, I ran into an error generating your plan. Please check your options and try again!",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
        }
        _saveDraft();
        _scrollToBottom();
        return;
    }

    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          text: aiResponse,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
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
    if (_currentStep == 4) draftStep = 3;
    if (_currentStep == 5) draftStep = 2;

    tripProv.updateDraft(
      PlannerDraft(
        destinationName: _selectedDistrict,
        step: draftStep,
        days: _selectedDays,
        vibe: _selectedVibe,
        budget: _selectedBudget,
        imageUrl: match.imageUrl,
      ),
    );
  }

  bool _isPastDate(String input) {
    final text = input.toLowerCase().trim();
    if (text.contains('yesterday') ||
        text.contains('last week') ||
        text.contains('last month') ||
        text.contains('ago') ||
        text.contains('previous')) {
      return true;
    }

    final parsed = _parseSmartDate(input);
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    if (parsed.isBefore(todayMidnight)) {
      return true;
    }

    return false;
  }

  DateTime _parseSmartDate(String input) {
    final text = input.trim();
    final today = DateTime.now();

    // Check if input is a pure number (e.g. "2" or "15" or "31")
    final pureDayReg = RegExp(r'^(\d{1,2})$');
    final match = pureDayReg.firstMatch(text);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '');
      if (day != null && day >= 1 && day <= 31) {
        try {
          DateTime candidate = DateTime(today.year, today.month, day);
          final todayMidnight = DateTime(today.year, today.month, today.day);
          if (candidate.isBefore(todayMidnight)) {
            int nextMonth = today.month + 1;
            int year = today.year;
            if (nextMonth > 12) {
              nextMonth = 1;
              year += 1;
            }
            candidate = _safeDateTime(year, nextMonth, day);
          }
          return candidate;
        } catch (_) {}
      }
    }

    final textLower = text.toLowerCase();
    if (textLower == 'this weekend') {
      final daysUntilSat = (6 - today.weekday) % 7;
      return today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    } else if (textLower == 'next weekend') {
      final daysUntilSat = (6 - today.weekday) % 7;
      return today.add(Duration(days: daysUntilSat + 7));
    } else if (textLower == 'next month') {
      return DateTime(today.year, today.month + 1, 1);
    }

    final parsed = DateTime.tryParse(text);
    if (parsed != null) {
      return parsed;
    }

    final monthDayReg1 = RegExp(
      r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\s+(\d{1,2})\b',
      caseSensitive: false,
    );
    final m1 = monthDayReg1.firstMatch(textLower);
    if (m1 != null) {
      final monthStr = m1.group(1)!;
      final day = int.tryParse(m1.group(2) ?? '') ?? today.day;
      final month = _monthNumber(monthStr);
      DateTime candidate = _safeDateTime(today.year, month, day);
      final todayMidnight = DateTime(today.year, today.month, today.day);
      if (candidate.isBefore(todayMidnight)) {
        candidate = _safeDateTime(today.year + 1, month, day);
      }
      return candidate;
    }

    final monthDayReg2 = RegExp(
      r'\b(\d{1,2})\s+(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z]*\b',
      caseSensitive: false,
    );
    final m2 = monthDayReg2.firstMatch(textLower);
    if (m2 != null) {
      final day = int.tryParse(m2.group(1) ?? '') ?? today.day;
      final monthStr = m2.group(2)!;
      final month = _monthNumber(monthStr);
      DateTime candidate = _safeDateTime(today.year, month, day);
      final todayMidnight = DateTime(today.year, today.month, today.day);
      if (candidate.isBefore(todayMidnight)) {
        candidate = _safeDateTime(today.year + 1, month, day);
      }
      return candidate;
    }

    return today;
  }

  int _monthNumber(String shortMonth) {
    const list = [
      'jan',
      'feb',
      'mar',
      'apr',
      'may',
      'jun',
      'jul',
      'aug',
      'sep',
      'oct',
      'nov',
      'dec',
    ];
    final idx = list.indexOf(shortMonth.toLowerCase());
    return idx != -1 ? idx + 1 : DateTime.now().month;
  }

  DateTime _safeDateTime(int year, int month, int day) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final clampedDay = day.clamp(1, lastDay);
    return DateTime(year, month, clampedDay);
  }

  void _extractPrefsFromPrompt(String prompt) {
    final text = prompt.toLowerCase();

    // 1. Extract days
    final daysMatch = RegExp(r'\b(\d+)\s*(?:day|days)\b').firstMatch(text);
    if (daysMatch != null) {
      final val = int.tryParse(daysMatch.group(1) ?? '');
      if (val != null && val > 0) {
        _selectedDays = val;
        _extractedDays = true;
      }
    }

    // 2. Extract travel type & traveler count
    if (text.contains('solo') ||
        text.contains('myself') ||
        text.contains('alone') ||
        text.contains('single traveler')) {
      _selectedTravelType = 'Solo';
      _numTravelers = 1;
      _extractedTravelType = true;
    } else {
      final groupMatch = RegExp(
        r'\b(?:group of|we are|splitting with|split between)\s*(\d+)\b|\b(\d+)\s*(?:pax|people|persons|members|friends|head|guests|of us)\b',
      ).firstMatch(text);
      if (groupMatch != null) {
        final countStr = groupMatch.group(1) ?? groupMatch.group(2);
        final count = int.tryParse(countStr ?? '');
        if (count != null && count > 1) {
          _selectedTravelType = 'Group';
          _numTravelers = count;
          _extractedTravelType = true;
        }
      } else if (text.contains('group') ||
          text.contains('family') ||
          text.contains('friends') ||
          text.contains('couple') ||
          text.contains('we ')) {
        _selectedTravelType = 'Group';
        _extractedTravelType = true;
      }
    }

    // 3. Extract budget style
    if (text.contains('low') ||
        text.contains('cheap') ||
        text.contains('budget') ||
        text.contains('essential') ||
        text.contains('affordable')) {
      final budgetMatch = RegExp(r'\b(\d+[\d,]*)\s*(k)?\b').firstMatch(text);
      if (budgetMatch != null) {
        var valStr = budgetMatch.group(1)!.replaceAll(',', '');
        var val = double.tryParse(valStr) ?? 0.0;
        if (budgetMatch.group(2) == 'k') {
          val *= 1000;
        }
        if (val > 0) {
          _selectedBudget = val;
          if (val <= 3000) {
            _selectedBudgetCategory = 'Low Budget';
          } else if (val <= 10000) {
            _selectedBudgetCategory = 'Balanced Budget';
          } else {
            _selectedBudgetCategory = 'High Budget';
          }
          _extractedBudget = true;
        }
      } else {
        if (text.contains('low') || text.contains('cheap')) {
          _selectedBudgetCategory = 'Low Budget';
          _extractedBudget = true;
        } else if (text.contains('affordable') ||
            text.contains('moderate') ||
            text.contains('comfort')) {
          _selectedBudgetCategory = 'Balanced Budget';
          _extractedBudget = true;
        }
      }
    } else if (text.contains('luxury') ||
        text.contains('premium') ||
        text.contains('high') ||
        text.contains('expensive')) {
      _selectedBudgetCategory = 'High Budget';
      _extractedBudget = true;
    }
  }

  // =========================================================================
  //  DESTINATION-SPECIFIC FLOW
  // =========================================================================
  Future<void> _generateAndShowDestinationPlan(Destination dest) async {
    setState(() {
      _isTyping = true;
    });

    final aiResponse =
        "Excellent! Preparing your **$_selectedBudgetCategory** plan for "
        "${dest.name} ($_selectedDays day${_selectedDays > 1 ? 's' : ''}, $_selectedDate)... ⏳";

    _appendAIMessage(aiResponse);

    // Generate the trip with budget-aware logic
    final trip = await _generateDestinationPlan(dest);

    if (!mounted) return;
    setState(() {
      _isTyping = false;
    });

    // Build cost breakdown message
    final costBreakdown = _buildCostBreakdownText(dest);

    setState(() {
      _currentStep = 15;
      _messages.add(
        _ChatMessage(
          text: costBreakdown,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();

    await Future.delayed(const Duration(milliseconds: 600));
    setState(() {
      _messages.add(
        _ChatMessage(
          text:
              "Here is your personalised **$_selectedBudgetCategory** itinerary for ${dest.name}! 🎉\n"
              "Tap the bookmark icon to save it to My Trips.",
          isUser: false,
          timestamp: DateTime.now(),
          generatedTrip: trip,
        ),
      );
    });
    _scrollToBottom();
  }

  // =========================================================================
  //  SMART CORRECTION HELPERS
  // =========================================================================

  /// Returns true if the user message contains intent to correct a previous input.
  bool _detectCorrectionIntent(String text) {
    final lower = text.toLowerCase().trim();
    const triggers = [
      'no,',
      'nope',
      'wait,',
      'wait ',
      'actually',
      'i meant',
      'i mean',
      'not right',
      'wrong',
      'incorrect',
      'change it',
      'fix it',
      'change the',
      'fix the',
      'correction',
      're-do',
      'redo',
      "that's not",
      "that is not",
      'should be',
      'supposed to be',
      'not june',
      'not may',
      'not 1',
      'not 2',
      'not 3',
    ];
    return triggers.any((t) => lower.contains(t));
  }

  /// Re-parses a correction message and updates only the fields that were found.
  void _parseCorrection(String correctionText) {
    final lower = correctionText.toLowerCase();

    // Re-extract duration — "X day(s)" pattern
    final daysMatch = RegExp(r'\b(\d+)\s*(?:day|days)\b').firstMatch(lower);
    if (daysMatch != null) {
      final d = int.tryParse(daysMatch.group(1) ?? '');
      if (d != null && d > 0 && d <= 30) {
        _selectedDays = d;
        _extractedDays = true;
      }
    }

    // Re-extract date via the existing smart parser
    // Only update the date if the correction text contains explicit date language
    final hasDateHint = RegExp(
      r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|'
      r'monday|tuesday|wednesday|thursday|friday|saturday|sunday|'
      r'today|tomorrow|next|this weekend|next weekend|next month|'
      r'\d+\s*days?\s*from|june|july|august|january|february|march|april)',
      caseSensitive: false,
    ).hasMatch(correctionText);

    if (hasDateHint) {
      final newDate = _parseSmartDate(correctionText);
      final today = DateTime.now();
      final todayMidnight = DateTime(today.year, today.month, today.day);
      if (!newDate.isBefore(todayMidnight)) {
        _selectedDate = _formatDate(newDate);
      }
    }
  }

  /// Shows a confirmation card asking the user to verify their date + duration.
  void _showPlanConfirmationCard(Destination dest) {
    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          text:
              'Here\'s what I understood from your input — please confirm before we continue:',
          isUser: false,
          timestamp: DateTime.now(),
          isConfirmationPrompt: true,
        ),
      );
    });
    _scrollToBottom();
  }

  /// Intercepts a correction intent at any step in the destination flow.
  Future<void> _handleCorrectionIntent(String text) async {
    _parseCorrection(text);
    final dest = _activeDest!;
    setState(() {
      _isTyping = false;
    });
    _showPlanConfirmationCard(dest);
    _currentStep = 115;
  }

  // =========================================================================
  //  DESTINATION-SPECIFIC FLOW
  // =========================================================================
  Future<void> _handleDestinationFlowStep(String text) async {
    String aiResponse = '';
    if (_activeDest == null) {
      setState(() {
        _isDestinationMode = false;
        _currentStep = 7;
      });
      return;
    }
    final dest = _activeDest!;

    switch (_currentStep) {
      // Step 10 — user picks a travel date
      case 10:
        if (_isPastDate(text)) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "⚠️ Please choose an upcoming travel date. Yesterday and past dates cannot be selected!",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }

        final parsedDate = _parseSmartDate(text);
        _selectedDate = _formatDate(parsedDate);
        _extractPrefsFromPrompt(text);

        // Determine where to go next based on extracted preferences
        if (!_extractedDays) {
          _currentStep = 11;
          aiResponse =
              "📅 Perfect! **$_selectedDate** it is.\n\n"
              "How many days would you like to spend at **${dest.name}**?";
        } else {
          // Both date and duration are known — show confirmation card
          _currentStep = 115;
          setState(() {
            _isTyping = false;
          });
          _showPlanConfirmationCard(dest);
          return;
        }
        break;

      // Step 11 — user picks duration
      case 11:
        final parsed =
            int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 1;
        _selectedDays = parsed;
        _extractedDays = true;
        _extractPrefsFromPrompt(text);

        // Both date and duration are now known — always confirm before advancing
        _currentStep = 115;
        setState(() {
          _isTyping = false;
        });
        _showPlanConfirmationCard(dest);
        return;

      // Step 115 — waiting for user to confirm date + duration
      case 115:
        final lower = text.toLowerCase();
        if (lower.contains('confirm') ||
            lower.contains('correct') ||
            lower.contains('yes') ||
            lower.contains('right') ||
            lower.contains('looks good') ||
            lower.contains('ok') ||
            lower.contains('sure') ||
            lower.contains('proceed') ||
            lower.contains('continue') ||
            lower == '✅') {
          // User confirmed — advance to travel type
          if (!_extractedTravelType) {
            _currentStep = 12;
            aiResponse =
                "Great! $_selectedDate for $_selectedDays day${_selectedDays > 1 ? 's' : ''} at ${dest.name}. 🌿\n\n"
                "Who will you be traveling with? Solo or with a Group?";
          } else if (!_extractedBudget) {
            _currentStep = 128;
            aiResponse =
                "Confirmed! $_selectedDate for $_selectedDays day${_selectedDays > 1 ? 's' : ''} at ${dest.name}. 🎒\n\n"
                "What is your estimated budget for this trip?";
          } else {
            await _generateAndShowDestinationPlan(dest);
            return;
          }
        } else {
          // User typed something else — treat as an inline correction
          _parseCorrection(text);
          setState(() {
            _isTyping = false;
          });
          _showPlanConfirmationCard(dest);
          return;
        }
        break;

      // Step 116 — user clicked "Let me fix this" and typed a correction
      case 116:
        _parseCorrection(text);
        _currentStep = 115;
        setState(() {
          _isTyping = false;
        });
        _showPlanConfirmationCard(dest);
        return;

      // Step 12 — user picks travel type
      case 12:
        _selectedTravelType = text;
        _extractedTravelType = true;
        _extractPrefsFromPrompt(text);

        if (text.toLowerCase().contains('group')) {
          _currentStep = 125;
          aiResponse =
              "Awesome, a group trip! 👥 How many travelers will be joining?";
        } else {
          _selectedTravelType = 'Solo';
          _numTravelers = 1;

          _currentStep = 128;
          aiResponse =
              "A solo adventure! 🎒 What is your estimated budget for this trip?";
        }
        break;

      // Step 12.5 — user picks traveler count
      case 125:
        final count = int.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 2;
        _numTravelers = count;
        _extractPrefsFromPrompt(text);

        _currentStep = 128;
        aiResponse =
            "Got it, $_numTravelers travelers! 👥 What is your estimated budget for this group trip?";
        break;

      // Step 128 — user sets their estimated budget
      case 128:
        final clean =
            double.tryParse(text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 5000;
        _selectedBudget = clean;
        _currentStep = 13;
        final prompt = _buildSuggestedBudgetPrompt(dest);
        setState(() {
          _isTyping = false;
          _messages.add(
            _ChatMessage(
              text: prompt,
              isUser: false,
              timestamp: DateTime.now(),
              isBudgetPrompt: true,
            ),
          );
        });
        _scrollToBottom();
        return;

      // Step 13 — user picks budget category
      case 13:
        final cleanInput = text.toLowerCase();
        if (cleanInput.contains('low')) {
          _selectedBudgetCategory = 'Low Budget';
        } else if (cleanInput.contains('high') ||
            cleanInput.contains('premium')) {
          _selectedBudgetCategory = 'High Budget';
        } else {
          _selectedBudgetCategory = 'Balanced Budget';
        }
        _extractedBudget = true;
        await _generateAndShowDestinationPlan(dest);
        return;
    }

    setState(() {
      _isTyping = false;
      if (aiResponse.isNotEmpty) {
        _messages.add(
          _ChatMessage(
            text: aiResponse,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      }
    });
    _scrollToBottom();
  }

  // =========================================================================
  //  HELPERS
  // =========================================================================
  void _appendAIMessage(String text) {
    setState(() {
      _messages.add(
        _ChatMessage(text: text, isUser: false, timestamp: DateTime.now()),
      );
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
    final numbers = RegExp(r'\d[\d,\.]*')
        .allMatches(feeStr.replaceAll(',', ''))
        .map((m) => double.tryParse(m.group(0) ?? '') ?? 0.0)
        .toList();
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
      ..sort(
        (a, b) => _parsePrice(
          a['price'] ?? '0',
        ).compareTo(_parsePrice(b['price'] ?? '0')),
      );

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

    final numbers = RegExp(r'\d[\d,\.]*')
        .allMatches(priceStr.replaceAll(',', ''))
        .map((m) => double.tryParse(m.group(0) ?? '') ?? 0.0)
        .toList();
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
      final avg =
          parsedPrices.reduce((sum, p) => sum + p) / parsedPrices.length;
      return avg * (parsedPrices.length > 1 ? 2 : 1);
    }
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
    final double totalTransport = _getTransportCost(dest, category);

    // 2. Meals
    final double mealsPerDay = isLow
        ? 150.0 * 3
        : isHigh
        ? 600.0 * 3
        : 300.0 * 3;
    final double totalMeals = mealsPerDay * _selectedDays;

    // 3. Activities
    final double totalActivities = _getActivitiesCost(dest, category);

    // 4. Accommodation
    final double accommodationPerNight = _getAccommodationCost(dest, category);
    final double totalAccomm = _selectedDays > 1
        ? accommodationPerNight * (_selectedDays - 1)
        : 0.0;

    // 5. Environmental & Entrance Fees
    final double environmentalFee = _parsePrice(extra.environmentalFee);
    final double entranceFee = _parsePrice(dest.entranceFee);

    return totalTransport +
        totalMeals +
        totalActivities +
        totalAccomm +
        environmentalFee +
        entranceFee;
  }

  double _calculateOptimizedCost(
    Destination dest,
    String transCat,
    String accommCat,
    String mealCat,
    String actCat,
  ) {
    final extra = dest.extra;
    final isLowMeal = mealCat == 'Low Budget';
    final isHighMeal = mealCat == 'High Budget';

    // 1. Transport
    final double totalTransport = _getTransportCost(dest, transCat);

    // 2. Meals
    final double mealsPerDay = isLowMeal
        ? 150.0 * 3
        : isHighMeal
        ? 600.0 * 3
        : 300.0 * 3;
    final double totalMeals = mealsPerDay * _selectedDays;

    // 3. Activities
    final double totalActivities = _getActivitiesCost(dest, actCat);

    // 4. Accommodation
    final double accommodationPerNight = _getAccommodationCost(dest, accommCat);
    final double totalAccomm = _selectedDays > 1
        ? accommodationPerNight * (_selectedDays - 1)
        : 0.0;

    // 5. Environmental & Entrance Fees
    final double environmentalFee = _parsePrice(extra.environmentalFee);
    final double entranceFee = _parsePrice(dest.entranceFee);

    return totalTransport +
        totalMeals +
        totalActivities +
        totalAccomm +
        environmentalFee +
        entranceFee;
  }

  String _buildSuggestedBudgetPrompt(Destination dest) {
    final lowCost = _calculateOptionCost(dest, 'Low Budget');
    final balancedCost = _calculateOptionCost(dest, 'Balanced Budget');
    final highCost = _calculateOptionCost(dest, 'High Budget');

    final isGroup = _selectedTravelType.toLowerCase().contains('group');
    final numTravelers = isGroup ? _numTravelers : 1;

    // Suggest based on per-person cost
    double userPerPersonBudget = _selectedBudget;
    if (isGroup && _selectedBudget > 5000) {
      userPerPersonBudget = _selectedBudget / numTravelers;
    }

    final minRequired = lowCost * numTravelers;
    String warningText = '';
    if (_selectedBudget < minRequired) {
      warningText =
          "⚠️ **WARNING**: Your estimated budget of **₱${_formatCurrency(_selectedBudget)}** is lower than the minimum required expense of **₱${_formatCurrency(minRequired)}** for this trip. We highly recommend saving more money before traveling, to ensure a safe, comfortable, and stress-free journey! 🎒💰\n\n";
    }

    String suggestion = '';
    if (userPerPersonBudget >= highCost) {
      suggestion =
          "Your estimated budget of **₱${_formatCurrency(_selectedBudget)}** fits perfectly with our premium **High Budget** style! This includes all activities and premium lodging.";
    } else if (userPerPersonBudget >= balancedCost) {
      suggestion =
          "Your estimated budget of **₱${_formatCurrency(_selectedBudget)}** fits perfectly with our **Balanced Budget** style (₱${_formatCurrency(balancedCost)} per person) for a comfortable and complete experience!";
    } else {
      suggestion =
          "To fit your estimated budget of **₱${_formatCurrency(_selectedBudget)}**, we suggest our value-conscious **Low Budget** style (₱${_formatCurrency(lowCost)} per person) covering essential transit and entrance fees.";
    }

    String lowText =
        "🟢 **Low Budget** — ₱${_formatCurrency(lowCost)} per person";
    String balancedText =
        "🟡 **Balanced Budget** — ₱${_formatCurrency(balancedCost)} per person";
    String highText =
        "🔴 **High Budget** — ₱${_formatCurrency(highCost)} per person";

    if (isGroup) {
      lowText += " (Group Total: ₱${_formatCurrency(lowCost * numTravelers)})";
      balancedText +=
          " (Group Total: ₱${_formatCurrency(balancedCost * numTravelers)})";
      highText +=
          " (Group Total: ₱${_formatCurrency(highCost * numTravelers)})";
    }

    return "${warningText}Thank you! Based on your estimated budget of **₱${_formatCurrency(_selectedBudget)}**:\n\n"
        "💡 **AI Recommendation**: $suggestion\n\n"
        "Here are the available budget styles for **${dest.name}**:\n\n"
        "$lowText\n"
        "$balancedText\n"
        "$highText\n\n"
        "Which budget style would you like to select for your customized trip? (Low, Balanced, or High)";
  }

  /// Builds a richly formatted cost breakdown string using actual destination financial data
  String _buildCostBreakdownText(Destination dest) {
    final extra = dest.extra;
    final isLow = _selectedBudgetCategory == 'Low Budget';
    final isHigh = _selectedBudgetCategory == 'High Budget';

    // 1. Transport
    final double totalTransport = _getTransportCost(
      dest,
      _selectedBudgetCategory,
    );
    final transportOpt = _getTransportOption(dest, _selectedBudgetCategory);
    String transportInfo = '';
    if (transportOpt != null) {
      transportInfo =
          "${transportOpt['vehicle'] ?? ''} from ${transportOpt['from'] ?? ''} → ${transportOpt['to'] ?? ''}";
    }

    // 2. Meals
    final double mealsPerDay = isLow
        ? 150.0 * 3
        : isHigh
        ? 600.0 * 3
        : 300.0 * 3;
    final double totalMeals = mealsPerDay * _selectedDays;

    // 3. Activities
    final double totalActivities = _getActivitiesCost(
      dest,
      _selectedBudgetCategory,
    );

    // 4. Accommodation
    final double accommodationPerNight = _getAccommodationCost(
      dest,
      _selectedBudgetCategory,
    );
    final double totalAccomm = _selectedDays > 1
        ? accommodationPerNight * (_selectedDays - 1)
        : 0.0;

    // 5. Environmental & Entrance Fees
    final double environmentalFee = _parsePrice(extra.environmentalFee);
    final double entranceFee = _parsePrice(dest.entranceFee);

    final double grandTotal =
        totalTransport +
        totalMeals +
        totalActivities +
        totalAccomm +
        environmentalFee +
        entranceFee;

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

    final emoji = isLow
        ? '🟢'
        : isHigh
        ? '🔴'
        : '🟡';

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

    // Compute a real start date
    final startDate = _parseSmartDate(_selectedDate);

    final endDate = startDate.add(Duration(days: _selectedDays - 1));
    final dateRange = _selectedDays == 1
        ? _formatDate(startDate)
        : '${_formatDate(startDate)} – ${_formatDate(endDate)}';

    // User's per-person budget limit
    final double perPersonLimit =
        _selectedBudget / (_numTravelers > 0 ? _numTravelers : 1);

    // Intelligently select category if not explicitly chosen
    String activeCategory = _selectedBudgetCategory;
    if (activeCategory.isEmpty) {
      final double balancedCost = _calculateOptionCost(dest, 'Balanced Budget');
      if (perPersonLimit >= _calculateOptionCost(dest, 'High Budget')) {
        activeCategory = 'High Budget';
      } else if (perPersonLimit >= balancedCost) {
        activeCategory = 'Balanced Budget';
      } else {
        activeCategory = 'Low Budget';
      }
      _selectedBudgetCategory = activeCategory;
    }

    // Check if the chosen category cost exceeds the user's financial limit
    bool needsCostOptimization =
        _calculateOptionCost(dest, activeCategory) > perPersonLimit;

    // Optimization modifiers per category
    String transportCategory = activeCategory;
    String accommCategory = activeCategory;
    String mealCategory = activeCategory;
    String activityCategory = activeCategory;

    if (needsCostOptimization) {
      // Intelligently minimize costs step-by-step to fit within the limit
      // 1. First downgrade transport to Low Budget (commuter transit)
      transportCategory = 'Low Budget';
      double optimizedCost = _calculateOptimizedCost(
        dest,
        transportCategory,
        accommCategory,
        mealCategory,
        activityCategory,
      );

      // 2. If still exceeding, downgrade accommodation to Low Budget (camp space/hostel)
      if (optimizedCost > perPersonLimit) {
        accommCategory = 'Low Budget';
        optimizedCost = _calculateOptimizedCost(
          dest,
          transportCategory,
          accommCategory,
          mealCategory,
          activityCategory,
        );
      }

      // 3. If still exceeding, downgrade meals to Low Budget
      if (optimizedCost > perPersonLimit) {
        mealCategory = 'Low Budget';
        optimizedCost = _calculateOptimizedCost(
          dest,
          transportCategory,
          accommCategory,
          mealCategory,
          activityCategory,
        );
      }

      // 4. If still exceeding, downgrade activities to Low Budget (focus on free activities)
      if (optimizedCost > perPersonLimit) {
        activityCategory = 'Low Budget';
      }
    }

    final isLowMeal = mealCategory == 'Low Budget';
    final isHighMeal = mealCategory == 'High Budget';

    final isLowAct = activityCategory == 'Low Budget';
    final isHighAct = activityCategory == 'High Budget';

    final isLowAcc = accommCategory == 'Low Budget';
    final isHighAcc = accommCategory == 'High Budget';

    // Build day-by-day itinerary based on destination
    final Map<int, List<TripActivity>> agenda = {};
    final extra = dest.extra;

    final transportOpt = _getTransportOption(dest, transportCategory);

    for (int day = 1; day <= _selectedDays; day++) {
      final List<TripActivity> dayPlan = [];
      final String loc = dest.name;

      // Morning: transport + arrival or next-day activity
      dayPlan.add(
        TripActivity(
          time: '07:00 AM',
          title: day == 1
              ? 'Depart & Travel to ${dest.name}'
              : 'Morning at ${dest.name}',
          description: day == 1
              ? (transportOpt != null
                    ? '${transportOpt['vehicle']} from ${transportOpt['from']} → ${transportOpt['to']}.'
                    : 'Head to ${dest.location} via your preferred transport.')
              : 'Start the day with breakfast and light exploration around the area.',
          cost: day == 1
              ? (transportOpt != null ? transportOpt['price']! : 'Free')
              : 'Free',
          location: day == 1 ? 'En Route' : loc,
        ),
      );

      // Entrance / check-in
      dayPlan.add(
        TripActivity(
          time: '09:00 AM',
          title: day == 1
              ? 'Arrival & Check-In at ${dest.name}'
              : 'Full Day Exploration',
          description: day == 1
              ? 'Pay entrance fee (${dest.entranceFee}) and environmental fee (${extra.environmentalFee}). Collect maps and orient with the surroundings.'
              : 'Enjoy a beautiful morning exploring the core sights of the destination.',
          cost: day == 1 ? dest.entranceFee : 'Free',
          location: loc,
        ),
      );

      // Main activity
      if (dest.activities.isNotEmpty) {
        final actIdx = (day - 1) % dest.activities.length;
        final actName = dest.activities[actIdx];

        // Find price for this specific activity
        String actPrice = 'Free';
        final prices = extra.activityPrices;
        final matchingKey = prices.keys.firstWhere(
          (k) =>
              k.toLowerCase().contains(actName.toLowerCase()) ||
              actName.toLowerCase().contains(k.toLowerCase()),
          orElse: () => '',
        );
        if (matchingKey.isNotEmpty) {
          actPrice = prices[matchingKey]!;
        } else if (isLowAct) {
          actPrice = 'Free';
        } else {
          actPrice = isHighAct ? '₱400' : '₱200';
        }

        dayPlan.add(
          TripActivity(
            time: '10:30 AM',
            title: actName,
            description: isLowAct
                ? 'Budget-friendly option — enjoy $actName with value-conscious settings.'
                : isHighAct
                ? 'Premium private guided $actName with top-tier equipment and priority access.'
                : 'Standard experience of $actName with standard equipment.',
            cost: actPrice,
            location: loc,
          ),
        );
      }

      // Lunch
      dayPlan.add(
        TripActivity(
          time: '12:30 PM',
          title: 'Lunch Break',
          description: isLowMeal
              ? 'Affordable local eateries or packed lunch. Karinderia-style meals available nearby.'
              : isHighMeal
              ? 'Premium in-resort dining or top-rated restaurant nearby.'
              : 'Mid-range restaurant or in-resort café.',
          cost: isLowMeal
              ? '₱150'
              : isHighMeal
              ? '₱600'
              : '₱300',
          location: loc,
        ),
      );

      // Afternoon activity
      dayPlan.add(
        TripActivity(
          time: '02:00 PM',
          title: 'Afternoon ${dest.category} Experience',
          description:
              'Explore more of ${dest.name}. '
              '${extra.travelNotes.isNotEmpty ? extra.travelNotes.first : 'Enjoy the scenery and take photos.'}',
          cost: isLowAct
              ? '₱100'
              : isHighAct
              ? '₱500'
              : '₱250',
          location: loc,
        ),
      );

      // Evening / Overnight
      if (_selectedDays > 1 && day < _selectedDays) {
        final accommTypes = extra.accommodationTypes;
        String accommName = 'Standard Room';
        String accommPrice = '₱800–₱1,200 / night';
        if (accommTypes.isNotEmpty) {
          int accommIdx = isLowAcc
              ? 0
              : isHighAcc
              ? accommTypes.length - 1
              : accommTypes.length ~/ 2;
          accommIdx = accommIdx.clamp(0, accommTypes.length - 1);
          accommName = accommTypes[accommIdx]['type'] ?? accommName;
          accommPrice = accommTypes[accommIdx]['price'] ?? accommPrice;
        }
        dayPlan.add(
          TripActivity(
            time: '06:00 PM',
            title: 'Dinner & Check-In: $accommName',
            description:
                '${extra.mealInclusions.isNotEmpty ? extra.mealInclusions.first : 'Dinner at nearby grill houses.'} Overnight at $accommName.',
            cost: accommPrice,
            location: loc,
          ),
        );
      } else {
        dayPlan.add(
          TripActivity(
            time: '05:00 PM',
            title: 'Wrap Up & Return Trip',
            description:
                'Pack up and head back via ${transportOpt != null ? transportOpt['vehicle'] ?? 'transport' : 'transport'}.',
            cost: transportOpt != null ? transportOpt['price']! : 'Free',
            location: 'En Route Home',
          ),
        );
      }

      agenda[day] = dayPlan;
    }

    final double budgetEst = _calculateOptimizedCost(
      dest,
      transportCategory,
      accommCategory,
      mealCategory,
      activityCategory,
    );

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
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
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

    // Check for prefilled destination deep-link from home screen
    if (provider.activePlanDestination != null) {
      final dest = provider.activePlanDestination!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        provider.setActivePlanDestination(null);
        setState(() {
          _activeDest = dest;
          _isDestinationMode = true;
          _currentStep = 10;
          _messages.clear();
          _messages.add(
            _ChatMessage(
              text:
                  "You selected **${dest.name}**! 🌴 Let's plan your customized visit here.\n\nFirst, when are you planning to travel?",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
        });
        _scrollToBottom();
      });
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
              child: const ImageIcon(
                AssetImage('assets/icons/ai_planner.png'),
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDestinationMode && _activeDest != null
                        ? 'Planning: ${_activeDest!.name}'
                        : 'Lakbay AI Assistant',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _isDestinationMode ? 'Destination Mode' : 'Online',
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
              padding: const EdgeInsets.symmetric(
                vertical: AppConstants.spaceM,
              ),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isTyping) {
                  return _buildTypingIndicator();
                }
                return _buildChatItem(_messages[index]);
              },
            ),
          ),

          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildDestinationBanner(Destination dest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [
                  AppTheme.secondaryGreen.withValues(alpha: 0.08),
                  AppTheme.primaryBlue.withValues(alpha: 0.04),
                ]
              : [
                  AppTheme.secondaryGreen.withValues(alpha: 0.15),
                  AppTheme.primaryBlue.withValues(alpha: 0.08),
                ],
        ),
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? AppTheme.secondaryGreen.withValues(alpha: 0.15)
                : AppTheme.secondaryGreen.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.place_rounded,
            color: AppTheme.secondaryGreen,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dest.name,
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: isDark ? Colors.white : AppTheme.primaryBlue,
                  ),
                ),
                Text(
                  dest.location,
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
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
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatItem(_ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (message.isUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.spaceM,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceM,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: isDark
                ? AppTheme.secondaryGreen.withValues(alpha: 0.2)
                : AppTheme.secondaryGreen.withValues(alpha: 0.12),
            child: const ImageIcon(
              AssetImage('assets/icons/ai_planner.png'),
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    message.text,
                    style: GoogleFonts.outfit(
                      color: isDark
                          ? AppTheme.textPrimaryDark
                          : AppTheme.textPrimaryLight,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
                if (message.generatedTrip != null) ...[
                  const SizedBox(height: AppConstants.spaceM),
                  _buildTripCard(message.generatedTrip!),
                ],
                if (message.isBudgetPrompt && _activeDest != null) ...[
                  const SizedBox(height: AppConstants.spaceM),
                  _buildBudgetSelectorWidget(_activeDest!),
                ],
                if (message.isConfirmationPrompt && _activeDest != null) ...[
                  const SizedBox(height: AppConstants.spaceM),
                  _buildConfirmationCard(_activeDest!),
                ],
                if (message.recommendations != null &&
                    message.recommendations!.isNotEmpty) ...[
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
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
              color: isDark ? Colors.white : AppTheme.primaryBlue,
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
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DestinationDetailsScreen(
                        destination: dest,
                        isFromRecommendation: true,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.only(right: 12, bottom: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withValues(alpha: 0.1)
                            : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.05),
                    ),
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
                              Destination.loadImage(
                                dest.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                      color: AppTheme.primaryBlue.withValues(
                                        alpha: 0.1,
                                      ),
                                      child: const Icon(
                                        Icons.place_rounded,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                              ),
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        color: Colors.amber,
                                        size: 10,
                                      ),
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
                                  color: isDark
                                      ? AppTheme.textPrimaryDark
                                      : AppTheme.textPrimaryLight,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.grey,
                                    size: 10,
                                  ),
                                  const SizedBox(width: 2),
                                  Expanded(
                                    child: Text(
                                      dest.district,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.outfit(
                                        fontSize: 9,
                                        color: isDark
                                            ? AppTheme.textSecondaryDark
                                            : AppTheme.textSecondaryLight,
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

                                      _messages.add(
                                        _ChatMessage(
                                          text:
                                              "You selected **${dest.name}**! 🌴 Let's plan your customized visit here.\n\nFirst, when are you planning to travel?",
                                          isUser: false,
                                          timestamp: DateTime.now(),
                                        ),
                                      );
                                    });
                                    _scrollToBottom();
                                  },
                                  child: Text(
                                    'Plan Trip',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
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
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTripCard(Trip trip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final provider = context.watch<TripProvider>();
    final bool isTripSaved = provider.userTrips.any((t) => t.id == trip.id);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXL),
        boxShadow: AppConstants.premiumShadow,
        border: Border.all(
          color: AppTheme.secondaryGreen.withValues(alpha: 0.2),
        ),
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
                  Destination.loadImage(
                    trip.imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        Container(color: AppTheme.primaryBlue),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            _chip(
                              '${trip.itinerary.length} Day${trip.itinerary.length > 1 ? "s" : ""}',
                              AppTheme.secondaryGreen,
                            ),
                            const SizedBox(width: 6),
                            if (_selectedBudgetCategory.isNotEmpty)
                              _chip(
                                _selectedBudgetCategory,
                                _selectedBudgetCategory == 'Low Budget'
                                    ? Colors.green[700]!
                                    : _selectedBudgetCategory == 'High Budget'
                                    ? Colors.red[700]!
                                    : Colors.amber[700]!,
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trip.title,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
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
                  _infoRow(
                    Icons.location_on_rounded,
                    trip.destinationName,
                    isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                  const SizedBox(height: 6),
                  _infoRow(
                    Icons.calendar_today_rounded,
                    trip.dateRange,
                    isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                  const SizedBox(height: 6),
                  _infoRow(
                    Icons.payments_rounded,
                    'Est. Total: ₱${trip.budget.toStringAsFixed(0)}',
                    AppTheme.secondaryGreen,
                    bold: true,
                  ),
                  const SizedBox(height: AppConstants.spaceM),
                  Row(
                    children: [
                      Expanded(
                        child: isTripSaved
                            ? ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.secondaryGreen,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.dashboard_customize_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'Manage Trip',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.groupDashboard,
                                    arguments: trip,
                                  );
                                },
                              )
                            : ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                icon: const Icon(
                                  Icons.visibility_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  'View Details',
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppRoutes.plannerResults,
                                    arguments: trip,
                                  );
                                },
                              ),
                      ),
                      const SizedBox(width: 8),
                      isTripSaved
                          ? Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.secondaryGreen.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(
                                Icons.bookmark_added_rounded,
                                color: AppTheme.secondaryGreen,
                                size: 20,
                              ),
                            )
                          : IconButton(
                              style: IconButton.styleFrom(
                                backgroundColor: AppTheme.secondaryGreen
                                    .withValues(alpha: 0.12),
                                foregroundColor: AppTheme.secondaryGreen,
                                padding: const EdgeInsets.all(10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              icon: const Icon(
                                Icons.bookmark_add_rounded,
                                size: 20,
                              ),
                              tooltip: 'Save to My Trips',
                              onPressed: () async {
                                final provider = context.read<TripProvider>();

                                // Show a persistent loading indicator dialog
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (_) => const Center(
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                );

                                final success = await provider.addNewTrip(trip);

                                if (context.mounted) {
                                  Navigator.pop(
                                    context,
                                  ); // Dismiss loading dialog

                                  if (success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Trip saved successfully! 🎉',
                                        ),
                                        backgroundColor:
                                            AppTheme.secondaryGreen,
                                      ),
                                    );
                                    _resetChatWithSuccessMessage();
                                  } else {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          provider.errorMessage ??
                                              'Failed to save itinerary. Please try again.',
                                        ),
                                        backgroundColor: Colors.redAccent,
                                      ),
                                    );
                                  }
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
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _infoRow(
    IconData icon,
    String text,
    Color color, {
    bool bold = false,
  }) {
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
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.spaceM,
        vertical: 8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.secondaryGreen.withValues(alpha: 0.12),
            child: const ImageIcon(
              AssetImage('assets/icons/ai_planner.png'),
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: AppConstants.spaceM),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.black.withValues(alpha: 0.06),
              ),
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


  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.1)
                : Colors.black.withValues(alpha: 0.04),
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
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black12.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _messageCtrl,
                  onSubmitted: _handleSendMessage,
                  decoration: InputDecoration(
                    hintText: 'Type your message...',
                    border: InputBorder.none,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white60 : Colors.grey,
                      fontSize: 14,
                    ),
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
                decoration: const BoxDecoration(
                  color: AppTheme.primaryBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getIncludedActivitiesForCategory(
    Destination dest,
    String category,
  ) {
    final prices = dest.extra.activityPrices;
    if (prices.isEmpty) return ['Self-guided sightseeing'];

    final sortedKeys = prices.keys.toList()
      ..sort(
        (a, b) => _parsePrice(prices[a]!).compareTo(_parsePrice(prices[b]!)),
      );

    if (category == 'Low Budget') {
      return [sortedKeys.first];
    } else if (category == 'High Budget') {
      return prices.keys.toList();
    } else {
      final count = sortedKeys.length > 2 ? 2 : sortedKeys.length;
      return sortedKeys.sublist(0, count);
    }
  }

  String _getAccommodationDetails(Destination dest, String category) {
    final types = dest.extra.accommodationTypes;
    if (types.isEmpty) {
      final overnight = dest.extra.overnightFee;
      return overnight.toLowerCase().contains('not applicable')
          ? 'No overnight stay planned'
          : 'Standard Lodging ($overnight)';
    }
    if (category == 'Low Budget') {
      final first = types.first;
      return "${first['type'] ?? 'Standard Room'} (${first['price'] ?? 'Free'})";
    } else if (category == 'High Budget') {
      final last = types.last;
      return "${last['type'] ?? 'Deluxe Resort/Villa'} (${last['price'] ?? 'Premium Price'})";
    } else {
      final mid = types.length ~/ 2;
      final middle = types[mid];
      return "${middle['type'] ?? 'Comfortable Inn/Hotel'} (${middle['price'] ?? 'Standard Price'})";
    }
  }

  String _getTransportDetails(Destination dest, String category) {
    final opt = _getTransportOption(dest, category);
    if (opt == null) return 'Local commuting';
    final vehicle = opt['vehicle'] ?? 'Public Transit';
    final price = opt['price'] ?? 'Free';
    final route = (opt['from'] != null && opt['to'] != null)
        ? "${opt['from']} ➔ ${opt['to']}"
        : "";
    return "$vehicle${route.isNotEmpty ? ' ($route)' : ''} — $price";
  }

  String _getMealDetails(Destination dest, String category) {
    if (category == 'Low Budget') {
      return "Local street food & budget eateries (₱150/meal)";
    } else if (category == 'High Budget') {
      return "Fine dining & premium resort restaurants (₱600/meal)";
    } else {
      return "Mid-range casual dining & tourist cafes (₱300/meal)";
    }
  }

  Widget _buildConfirmationCard(Destination dest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = Theme.of(context).cardColor;
    final borderColor = isDark
        ? AppTheme.primaryBlue.withValues(alpha: 0.35)
        : AppTheme.primaryBlue.withValues(alpha: 0.25);

    Widget summaryRow(
      IconData icon,
      String label,
      String value,
      Color iconColor,
    ) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: iconColor),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                  ),
                ),
                Text(
                  value,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.primaryBlue,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final durationLabel = _selectedDays == 1
        ? '1 Day (Day trip)'
        : '$_selectedDays Days';

    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.checklist_rounded,
                size: 16,
                color: AppTheme.primaryBlue,
              ),
              const SizedBox(width: 6),
              Text(
                'Confirm your plan details',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Divider(color: borderColor, height: 1),
          const SizedBox(height: 10),
          summaryRow(
            Icons.calendar_today_rounded,
            'Travel Date',
            _selectedDate.isNotEmpty ? _selectedDate : 'Not set',
            Colors.blue,
          ),
          summaryRow(
            Icons.schedule_rounded,
            'Duration',
            durationLabel,
            Colors.teal,
          ),
          summaryRow(
            Icons.place_rounded,
            'Destination',
            dest.name,
            AppTheme.secondaryGreen,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.secondaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: Text(
                    'Looks right!',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () => _handleSendMessage('confirm'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? Colors.white
                        : AppTheme.primaryBlue,
                    side: BorderSide(color: borderColor, width: 1.5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: Text(
                    'Fix this',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentStep = 116;
                    });
                    // Prompt user to type correction
                    setState(() {
                      _isTyping = false;
                      _messages.add(
                        _ChatMessage(
                          text:
                              "Sure! What would you like to change — the travel date, the duration, or both? Just type your correction. 📝",
                          isUser: false,
                          timestamp: DateTime.now(),
                        ),
                      );
                    });
                    _scrollToBottom();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetSelectorWidget(Destination dest) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final categories = ['Low Budget', 'Balanced Budget', 'High Budget'];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      child: Column(
        children: categories.map((cat) {
          final lowCost = _calculateOptionCost(dest, cat);
          final isGroup = _selectedTravelType.toLowerCase().contains('group');
          final numTravelers = isGroup ? _numTravelers : 1;
          final totalCost = lowCost * numTravelers;

          Color badgeColor = Colors.green[700]!;
          if (cat == 'Balanced Budget') badgeColor = Colors.amber[700]!;
          if (cat == 'High Budget') badgeColor = Colors.red[700]!;

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: badgeColor.withValues(alpha: 0.3),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: badgeColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          cat,
                          style: GoogleFonts.outfit(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: badgeColor,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₱${_formatCurrency(lowCost)} / pax',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                          if (isGroup)
                            Text(
                              'Total: ₱${_formatCurrency(totalCost)}',
                              style: GoogleFonts.outfit(
                                fontSize: 10,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                Divider(
                  color: Theme.of(context).dividerColor.withValues(alpha: 0.15),
                  height: 1,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          icon: Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: isDark ? Colors.white : AppTheme.primaryBlue,
                          ),
                          label: Text(
                            'View Details',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : AppTheme.primaryBlue,
                            ),
                          ),
                          onPressed: () => _showBudgetDetailsSheet(dest, cat),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: badgeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            _handleSendMessage(cat);
                          },
                          child: Text(
                            'Select Style',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
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
          );
        }).toList(),
      ),
    );
  }

  void _showBudgetDetailsSheet(Destination dest, String category) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double accommCost = _getAccommodationCost(dest, category);
    final String accommDetail = _getAccommodationDetails(dest, category);

    final double transCost = _getTransportCost(dest, category);
    final String transDetail = _getTransportDetails(dest, category);

    final double mealsCost =
        (category == 'Low Budget'
            ? 150.0
            : category == 'High Budget'
            ? 600.0
            : 300.0) *
        3 *
        _selectedDays;
    final String mealsDetail = _getMealDetails(dest, category);

    final double actCost = _getActivitiesCost(dest, category);
    final List<String> actDetails = _getIncludedActivitiesForCategory(
      dest,
      category,
    );

    final double envFee = _parsePrice(dest.extra.environmentalFee);
    final double entFee = _parsePrice(dest.entranceFee);

    Color themeColor = Colors.green[700]!;
    if (category == 'Balanced Budget') themeColor = Colors.amber[700]!;
    if (category == 'High Budget') themeColor = Colors.red[700]!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.8,
              padding: const EdgeInsets.all(AppConstants.spaceL),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              category,
                              style: GoogleFonts.outfit(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: themeColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Complete breakdown of budget & inclusions',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppTheme.textSecondaryDark
                                    : AppTheme.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(sheetCtx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildDetailRow(
                            Icons.hotel_rounded,
                            '🏨 Accommodation Inclusions',
                            accommDetail,
                            'Est. Cost: ₱${_formatCurrency(accommCost * (_selectedDays > 1 ? _selectedDays - 1 : 1))} total',
                            themeColor,
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.directions_bus_rounded,
                            '🚌 Transportation Inclusions',
                            transDetail,
                            'Est. Cost: ₱${_formatCurrency(transCost)} / person',
                            themeColor,
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.restaurant_rounded,
                            '🍽️ Food & Meals Plan',
                            mealsDetail,
                            'Est. Cost: ₱${_formatCurrency(mealsCost)} for $_selectedDays Days',
                            themeColor,
                          ),
                          const SizedBox(height: 16),
                          _buildDetailRow(
                            Icons.explore_rounded,
                            '🎯 Covered Activities & Entry',
                            actDetails.map((act) => '• $act').join('\n'),
                            'Est. Cost: ₱${_formatCurrency(actCost)} / person',
                            themeColor,
                          ),
                          if (envFee > 0 || entFee > 0) ...[
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              Icons.payments_rounded,
                              '💵 Mandated Local Fees',
                              "Environmental Fee: ₱${_formatCurrency(envFee)}\nEntrance Fee: ₱${_formatCurrency(entFee)}",
                              'Local Government requirements',
                              themeColor,
                            ),
                          ],
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetCtx);
                        _handleSendMessage(category);
                      },
                      child: Text(
                        'Select $category',
                        style: GoogleFonts.outfit(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
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

  Widget _buildDetailRow(
    IconData icon,
    String title,
    String details,
    String costText,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.02)
            : color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : color.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppTheme.textSecondaryDark
                        : AppTheme.textSecondaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  costText,
                  style: GoogleFonts.outfit(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
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
  final bool isBudgetPrompt;
  final bool isConfirmationPrompt;

  _ChatMessage({
    required String text,
    required this.isUser,
    required this.timestamp,
    this.generatedTrip,
    this.recommendations,
    this.isBudgetPrompt = false,
    this.isConfirmationPrompt = false,
  }) : text = isUser ? text : _cleanMarkdown(text);

  static String _cleanMarkdown(String rawText) {
    String cleaned = rawText;

    // 1. Replace headers: lines starting with one or more '#' followed by spaces
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^#+\s*(.*)$', multiLine: true),
      (match) {
        return match.group(1) ?? '';
      },
    );

    // 2. Convert list item asterisks or hyphens to a nice bullet point
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'^\s*[\*\-]\s+', multiLine: true),
      (match) {
        return '• ';
      },
    );

    // 3. Remove bold / italic symbols: '**', '*', '__', '_'
    cleaned = cleaned.replaceAll('**', '');
    cleaned = cleaned.replaceAll('___', '');
    cleaned = cleaned.replaceAll('__', '');
    cleaned = cleaned.replaceAll('*', '');
    cleaned = cleaned.replaceAll('_', '');

    // 4. Normalize consecutive newlines
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');

    return cleaned.trim();
  }
}

class _TypingDot extends StatefulWidget {
  final int delayMs;
  const _TypingDot({required this.delayMs});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
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
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}
