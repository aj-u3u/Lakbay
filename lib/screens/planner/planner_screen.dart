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
import 'chat_plan_review_sheet.dart';
import 'chat_ai_options_sheet.dart';

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
    final session = provider.sessionPreferences;
    provider.startChatPlanning(destination: dest);
    provider.refreshChatPlanningPreview();

    // Pre-populate shared preferences from session context
    if (session.budget != null) {
      _selectedBudget = session.budget!;
      _extractedBudget = true;
    }
    if (session.numTravelers != null) {
      _numTravelers = session.numTravelers!;
      _selectedTravelType = _numTravelers > 1 ? 'Group' : 'Solo';
      _extractedTravelType = true;
    }
    if (session.numDays != null) {
      _selectedDays = session.numDays!;
      _extractedDays = true;
    }
    if (session.vibe != null && session.vibe!.isNotEmpty) {
      _selectedVibe = session.vibe!;
    }
    if (session.selectedDate != null && session.selectedDate!.isNotEmpty) {
      _selectedDate = session.selectedDate!;
    }

    if (dest != null) {
      _activeDest = dest;
      _isDestinationMode = true;
      _currentStep = 10;

      final List<String> remembered = [];
      if (_extractedDays) {
        remembered.add(
          "Duration: $_selectedDays day${_selectedDays > 1 ? 's' : ''}",
        );
      }
      if (_extractedTravelType) {
        remembered.add(
          "Travelers: $_numTravelers (${_numTravelers > 1 ? 'Group' : 'Solo'})",
        );
      }
      if (_extractedBudget) {
        remembered.add("Budget: ₱${_selectedBudget.toStringAsFixed(0)}");
      }

      String welcomeText =
          "You selected **${dest.name}**! 🌴 Let's plan your customized visit here.";
      if (remembered.isNotEmpty) {
        welcomeText +=
            "\n\nI remembered your preferences from our conversation:\n• ${remembered.join('\n• ')}";
      }
      welcomeText += "\n\nFirst, when do you plan to travel?";

      setState(() {
        _messages.clear();
        _messages.add(
          _ChatMessage(
            text: welcomeText,
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
    tripProv.startChatPlanning();
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
    tripProv.startChatPlanning();
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
              "Your trip has been saved! Ready to plan another adventure? 🗺️",
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

        final historyPayload = _messages
            .where((m) => m.text.isNotEmpty)
            .map(
              (m) => {
                'role': m.isUser ? 'user' : 'assistant',
                'content': m.text,
              },
            )
            .toList();

        final success = await provider.sendFreeFormChat(
          text,
          history: historyPayload,
        );

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
                    provider.errorMessage ??
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
        final matchedDistrict = _tryParseDistrict(text);
        if (matchedDistrict == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't recognize a destination. Please choose a location in the Davao Region, such as 'Davao City', 'Samal Island', or 'Mati'.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _selectedDistrict = matchedDistrict;
        _currentStep = 1;
        aiResponse =
            "Great choice! $_selectedDistrict is beautiful. 🗺️\n\nHow many days are you planning to stay?";
        break;
      case 1:
        final parsed = _tryParseDuration(text);
        if (parsed == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine the duration of your stay. Please specify the number of days (e.g., 2, 3, or 5 days).",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _selectedDays = parsed;
        _extractedDays = true;
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
        } else if (text.toLowerCase().contains('solo') ||
            text.toLowerCase().contains('myself') ||
            text.toLowerCase().contains('alone')) {
          _selectedTravelType = 'Solo';
          _numTravelers = 1;
          _extractedTravelType = true;
          _currentStep = 5;
          aiResponse =
              "A solo adventure! 🎒 What is your estimated budget for this adventure?";
        } else {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine your travel type. Please specify whether you are traveling Solo or with a Group.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        break;
      case 3:
        final count = _tryParseTravelerCount(text);
        if (count == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine the number of travelers. Please enter a number, such as 2, 4, or 6.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _numTravelers = count;
        _extractedTravelType = true;
        _currentStep = 5;
        aiResponse =
            "Got it, $_numTravelers travelers! 👥 What is your estimated budget for this adventure?";
        break;
      case 5:
        final clean = _tryParseBudget(text);
        if (clean == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "Please enter a whole-trip budget amount (e.g., 5000 or 10000). You can choose a travel style next.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _selectedBudget = clean;
        _extractedBudget = true;
        _currentStep = 4;
        aiResponse =
            "Got it! A budget of ₱${_selectedBudget.toStringAsFixed(0)} is set. 💰\n\nWhat kind of travel vibe or theme do you prefer?";
        break;
      case 4:
        final matchedVibe = _tryParseVibe(text);
        if (matchedVibe == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't recognize a travel vibe. Please choose a theme such as 'Beach', 'Nature', 'Adventure', or 'Relaxing'.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _selectedVibe = matchedVibe;
        final provider = context.read<TripProvider>();
        if (provider.destinations.isEmpty) await provider.refreshDestinations();
        if (!mounted) return;
        final matching = provider.destinations
            .where(
              (destination) =>
                  destination.district.toLowerCase() ==
                  _selectedDistrict.toLowerCase(),
            )
            .take(5)
            .toList();
        final choices = matching.isEmpty
            ? provider.destinations.take(5).toList()
            : matching;
        setState(() {
          _isTyping = false;
          _currentStep = 7;
          _messages.add(
            _ChatMessage(
              text: choices.isEmpty
                  ? 'The destination catalog is unavailable. Retry from Review plan.'
                  : 'Choose a catalog destination, then review your trip details and cost estimates.',
              isUser: false,
              timestamp: DateTime.now(),
              recommendations: choices.isEmpty ? null : choices,
            ),
          );
        });
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

  DateTime _parseSmartDate(String input) =>
      _tryParseSmartDate(input) ?? DateTime.now();

  bool _isPastDate(String input) {
    final text = input.toLowerCase().trim();
    if (text.contains('yesterday') ||
        text.contains('last week') ||
        text.contains('last month') ||
        text.contains('ago') ||
        text.contains('previous')) {
      return true;
    }

    final parsed = _tryParseSmartDate(input);
    if (parsed == null) return false;
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    if (parsed.isBefore(todayMidnight)) {
      return true;
    }

    return false;
  }

  DateTime? _tryParseSmartDate(String input) {
    final text = input.trim();
    final textLower = text.toLowerCase();
    final today = DateTime.now();

    if (textLower == 'today') {
      return today;
    } else if (textLower == 'tomorrow') {
      return today.add(const Duration(days: 1));
    } else if (textLower == 'this weekend') {
      final daysUntilSat = (6 - today.weekday) % 7;
      return today.add(Duration(days: daysUntilSat == 0 ? 7 : daysUntilSat));
    } else if (textLower == 'next weekend') {
      final daysUntilSat = (6 - today.weekday) % 7;
      return today.add(Duration(days: daysUntilSat + 7));
    } else if (textLower == 'next month') {
      return DateTime(today.year, today.month + 1, 1);
    }

    // Relative "in X days" pattern
    final inDaysMatch = RegExp(
      r'\bin\s+(\d+)\s*days?\b',
      caseSensitive: false,
    ).firstMatch(textLower);
    if (inDaysMatch != null) {
      final days = int.tryParse(inDaysMatch.group(1) ?? '');
      if (days != null && days > 0) {
        return today.add(Duration(days: days));
      }
    }

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

    return null; // Return null if no valid date pattern matched!
  }

  int? _tryParseDuration(String input) {
    final textLower = input.toLowerCase().trim();
    if (textLower == 'weekend' ||
        textLower == 'a weekend' ||
        textLower == 'this weekend') {
      return 2;
    }
    if (textLower == 'a week' ||
        textLower == '1 week' ||
        textLower == 'one week') {
      return 7;
    }
    final daysMatch = RegExp(r'\b(\d+)\s*(?:day|days)\b').firstMatch(textLower);
    if (daysMatch != null) {
      final d = int.tryParse(daysMatch.group(1) ?? '');
      if (d != null && d > 0 && d <= 30) return d;
    }
    final pureNumMatch = RegExp(r'^\s*(\d{1,2})\s*$').firstMatch(textLower);
    if (pureNumMatch != null) {
      final d = int.tryParse(pureNumMatch.group(1) ?? '');
      if (d != null && d > 0 && d <= 30) return d;
    }
    return null;
  }

  int? _tryParseTravelerCount(String input) {
    final textLower = input.toLowerCase().trim();
    if (textLower.contains('solo') ||
        textLower.contains('myself') ||
        textLower.contains('alone') ||
        textLower == '1') {
      return 1;
    }
    if (textLower.contains('couple') ||
        textLower.contains('two of us') ||
        textLower.contains('both of us')) {
      return 2;
    }
    final groupMatch = RegExp(
      r'\b(?:group of|we are|family of|splitting with|split between)\s*(\d+)\b|\b(\d+)\s*(?:pax|people|persons|members|friends|head|guests|travelers|of us)\b',
    ).firstMatch(textLower);
    if (groupMatch != null) {
      final countStr = groupMatch.group(1) ?? groupMatch.group(2);
      final count = int.tryParse(countStr ?? '');
      if (count != null && count > 0 && count <= 100) return count;
    }
    final pureNumMatch = RegExp(r'^\s*(\d{1,2})\s*$').firstMatch(textLower);
    if (pureNumMatch != null) {
      final count = int.tryParse(pureNumMatch.group(1) ?? '');
      if (count != null && count > 0 && count <= 100) return count;
    }
    return null;
  }

  double? _tryParseBudget(String input) {
    final textLower = input.toLowerCase().trim();
    final budgetMatch = RegExp(r'\b(\d+[\d,]*)\s*(k)?\b').firstMatch(textLower);
    if (budgetMatch != null) {
      var valStr = budgetMatch.group(1)!.replaceAll(',', '');
      var val = double.tryParse(valStr);
      if (val != null) {
        if (budgetMatch.group(2) == 'k') {
          val *= 1000;
        }
        if (val >= 100 && val <= 1000000) return val;
      }
    }
    return null;
  }

  String? _tryParseDistrict(String input) {
    final textLower = input.toLowerCase().trim();
    const knownDistricts = [
      'davao city',
      'davao',
      'samal',
      'samal island',
      'mati',
      'toril',
      'panabo',
      'digos',
      'kopiat',
      'malagos',
      'roxas',
      'lake leonard',
      'aliwagwag',
      'hamiguitan',
      'tagbibinta',
      'davao del norte',
      'davao del sur',
      'davao oriental',
      'davao de oro',
    ];
    for (final dist in knownDistricts) {
      if (textLower.contains(dist)) {
        if (dist.contains('samal')) return 'Samal Island';
        if (dist.contains('mati')) return 'Mati';
        if (dist.contains('toril')) return 'Toril';
        if (dist.contains('panabo')) return 'Panabo';
        if (dist.contains('digos')) return 'Digos';
        return 'Davao City';
      }
    }
    for (final d in _districts) {
      if (textLower.contains(d.toLowerCase())) return d;
    }
    return null;
  }

  String? _tryParseVibe(String input) {
    final textLower = input.toLowerCase().trim();
    const vibesMap = {
      'Beach': ['beach', 'beaches', 'island', 'resort', 'coastal', 'sea'],
      'Nature': [
        'nature',
        'mountain',
        'hiking',
        'park',
        'falls',
        'waterfall',
        'green',
        'forest',
      ],
      'Adventure': [
        'adventure',
        'adventurous',
        'trekking',
        'climb',
        'surfing',
        'action',
      ],
      'Relaxing': [
        'relaxing',
        'relax',
        'quiet',
        'peaceful',
        'spa',
        'chill',
        'serene',
      ],
      'Culture': [
        'culture',
        'cultural',
        'heritage',
        'museum',
        'historical',
        'history',
      ],
      'Food Trip': [
        'food',
        'dining',
        'culinary',
        'restaurant',
        'street food',
        'eat',
        'market',
      ],
      'Nightlife': ['nightlife', 'night', 'bar', 'party', 'evening'],
    };
    for (final entry in vibesMap.entries) {
      if (textLower.contains(entry.key.toLowerCase())) return entry.key;
      for (final alias in entry.value) {
        if (textLower.contains(alias)) return entry.key;
      }
    }
    for (final v in _vibes) {
      if (textLower.contains(v.toLowerCase())) return v;
    }
    return null;
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
        } else if (text.contains('affordable') ||
            text.contains('moderate') ||
            text.contains('comfort')) {
          _selectedBudgetCategory = 'Balanced Budget';
        }
      }
    } else if (text.contains('luxury') ||
        text.contains('premium') ||
        text.contains('high') ||
        text.contains('expensive')) {
      _selectedBudgetCategory = 'High Budget';
    }

    try {
      final provider = context.read<TripProvider>();
      final session = provider.sessionPreferences;
      if (_extractedDays) session.numDays = _selectedDays;
      if (_extractedTravelType) {
        session.numTravelers = _numTravelers;
        session.travelType = _selectedTravelType;
      }
      if (_extractedBudget) session.budget = _selectedBudget;
      if (_selectedVibe.isNotEmpty) session.vibe = _selectedVibe;
      if (_selectedDate.isNotEmpty) session.selectedDate = _selectedDate;
    } catch (_) {}
  }

  // =========================================================================
  //  DESTINATION-SPECIFIC FLOW
  // =========================================================================
  Future<void> _generateAndShowDestinationPlan(Destination dest) async {
    setState(() {
      _isTyping = true;
    });
    final provider = context.read<TripProvider>();
    await provider.chooseChatDestination(dest);
    await provider.updateChatPlanning({
      'day_count': _selectedDays,
      'traveler_count': _numTravelers,
      if (_extractedBudget) 'total_budget': _selectedBudget.toStringAsFixed(2),
      if (_selectedVibe.isNotEmpty) 'interests': <String>[_selectedVibe],
    });
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _currentStep = 15;
      _messages.add(
        _ChatMessage(
          text:
              'Review ${dest.name}, your travel details, and whole-trip cost estimates. The itinerary will be generated after the estimate is complete.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
    });
    _scrollToBottom();
    _openChatPlanReview();
  }

  void _openChatPlanReview() {
    final provider = context.read<TripProvider>();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChatPlanReviewSheet(provider: provider),
    );
  }

  void _openChatAIOptions() {
    final provider = context.read<TripProvider>();
    if (provider.chatAIOptions.isEmpty) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChatAIOptionsSheet(
        provider: provider,
        onSaved: _resetChatWithSuccessMessage,
      ),
    );
  }

  Future<void> _generateReviewedChatPlan() async {
    final provider = context.read<TripProvider>();
    setState(() => _isTyping = true);
    final success = await provider.generateChatItinerary();
    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add(
        _ChatMessage(
          text: success
              ? 'Validated AI itineraries are ready. Review the options and save the one you prefer.'
              : provider.errorMessage ??
                    'Could not generate an itinerary. Review the plan and retry.',
          isUser: false,
          timestamp: DateTime.now(),
          generatedTrip: success ? provider.latestGeneratedTrip : null,
        ),
      );
    });
    _scrollToBottom();
    if (success) _openChatAIOptions();
  }

  Widget _buildChatPlanningBar() {
    return Consumer<TripProvider>(
      builder: (context, provider, _) {
        final preview = provider.chatPlanningPreview;
        final state = provider.chatPlanningState;
        final budget = preview?['budget'];
        final budgetMap = budget is Map ? budget : const <String, dynamic>{};
        final names = (preview?['destinations'] as List? ?? const [])
            .whereType<Map>()
            .map((destination) => destination['name']?.toString() ?? '')
            .where((name) => name.isNotEmpty)
            .join(', ');
        final missing = (preview?['missing_inputs'] as List? ?? const [])
            .map((item) => item.toString().replaceAll('_', ' '))
            .toList();
        final missingCosts = (budgetMap['missing_costs'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => item['message']?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
        final problems = (preview?['selection_problems'] as List? ?? const [])
            .whereType<Map>()
            .map((item) => item['message']?.toString() ?? '')
            .where((item) => item.isNotEmpty)
            .toList();
        final summary = names.isEmpty ? 'No destination selected' : names;
        final cost = budgetMap['total_estimate'];
        final fit = budgetMap['fit']?.toString();
        final detail = cost == null
            ? (missing.isNotEmpty
                  ? 'Needs ${missing.take(2).join(', ')}'
                  : missingCosts.isNotEmpty
                  ? missingCosts.first
                  : problems.isNotEmpty
                  ? problems.first
                  : 'Review the trip details and costs')
            : 'Whole-trip estimate ₱$cost • ${fit == 'fits_estimate'
                  ? 'fits budget'
                  : fit == 'over_budget'
                  ? 'over budget'
                  : 'needs review'}';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                detail,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _openChatPlanReview,
                    child: const Text('Review plan'),
                  ),
                  if (provider.chatAIOptions.isNotEmpty)
                    TextButton(
                      onPressed: _openChatAIOptions,
                      child: const Text('View AI options'),
                    ),
                  FilledButton(
                    onPressed:
                        provider.canGenerateChatPlan && !provider.isLoading
                        ? _generateReviewedChatPlan
                        : null,
                    child: const Text('Generate'),
                  ),
                ],
              ),
              if (state['destination_ids'] is List &&
                  (state['destination_ids'] as List).length > 1)
                Text(
                  'Review all selected stops before generating.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        );
      },
    );
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

        final parsedDate = _tryParseSmartDate(text);
        if (parsedDate == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't recognize a travel date. Please provide a valid date, such as \"August 15, 2026\", \"next weekend\", or \"tomorrow\".",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }

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
        final parsed = _tryParseDuration(text);
        if (parsed == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine the duration of your stay. Please specify the number of days (e.g., 2, 3, or 5 days).",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
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
        _extractPrefsFromPrompt(text);

        if (text.toLowerCase().contains('group')) {
          _selectedTravelType = 'Group';
          _extractedTravelType = true;
          _currentStep = 125;
          aiResponse =
              "Awesome, a group trip! 👥 How many travelers will be joining?";
        } else if (text.toLowerCase().contains('solo') ||
            text.toLowerCase().contains('myself') ||
            text.toLowerCase().contains('alone')) {
          _selectedTravelType = 'Solo';
          _numTravelers = 1;
          _extractedTravelType = true;

          _currentStep = 128;
          aiResponse =
              "A solo adventure! 🎒 What is your estimated budget for this trip?";
        } else {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine your travel type. Please specify whether you are traveling Solo or with a Group.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        break;

      // Step 12.5 — user picks traveler count
      case 125:
        final count = _tryParseTravelerCount(text);
        if (count == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine the number of travelers. Please enter a number, such as 2, 4, or 6.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _numTravelers = count;
        _extractedTravelType = true;
        _extractPrefsFromPrompt(text);

        _currentStep = 128;
        aiResponse =
            "Got it, $_numTravelers travelers! 👥 What is your estimated budget for this group trip?";
        break;

      // Step 128 — user sets their estimated budget
      case 128:
        final clean = _tryParseBudget(text);
        if (clean == null) {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "Please enter a whole-trip budget amount (e.g., 5000 or 10000). You can choose a budget style next.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
        _selectedBudget = clean;
        _extractedBudget = true;
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
        if (cleanInput.contains('low') || cleanInput.contains('cheap')) {
          _selectedBudgetCategory = 'Low Budget';
        } else if (cleanInput.contains('high') ||
            cleanInput.contains('premium') ||
            cleanInput.contains('luxury')) {
          _selectedBudgetCategory = 'High Budget';
        } else if (cleanInput.contains('balanced') ||
            cleanInput.contains('moderate') ||
            cleanInput.contains('comfort') ||
            cleanInput.contains('medium')) {
          _selectedBudgetCategory = 'Balanced Budget';
        } else {
          setState(() {
            _isTyping = false;
            _messages.add(
              _ChatMessage(
                text:
                    "I couldn't determine your budget category preference. Please specify Low Budget, Balanced Budget, or High Budget.",
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          _scrollToBottom();
          return;
        }
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

          _buildChatPlanningBar(),
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
            'Choose a destination:',
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
                onTap: () async {
                  final provider = context.read<TripProvider>();
                  await provider.chooseChatDestination(dest);
                  await provider.updateChatPlanning({
                    'day_count': _selectedDays,
                    'traveler_count': _numTravelers,
                    if (_extractedBudget)
                      'total_budget': _selectedBudget.toStringAsFixed(2),
                    if (_selectedVibe.isNotEmpty)
                      'interests': <String>[_selectedVibe],
                  });
                  if (!mounted) return;
                  setState(() {
                    _activeDest = dest;
                    _currentStep = 7;
                    _messages.add(
                      _ChatMessage(
                        text:
                            '${dest.name} selected. Review the trip details and costs before generating.',
                        isUser: false,
                        timestamp: DateTime.now(),
                      ),
                    );
                  });
                  _openChatPlanReview();
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

                                if (mounted) {
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
