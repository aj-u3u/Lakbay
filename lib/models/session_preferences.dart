class SessionPreferences {
  double? budget;
  int? numTravelers;
  int? numDays;
  String? travelType;
  String? vibe;
  String? selectedDate;
  String? district;
  String? budgetCategory;

  SessionPreferences({
    this.budget,
    this.numTravelers,
    this.numDays,
    this.travelType,
    this.vibe,
    this.selectedDate,
    this.district,
    this.budgetCategory,
  });

  void updateFromMap(Map<String, dynamic> prefs) {
    if (prefs['total_budget'] != null) {
      budget = (prefs['total_budget'] as num).toDouble();
    } else if (prefs['budget'] != null) {
      budget = (prefs['budget'] as num).toDouble();
    }

    if (prefs['group_size'] != null) {
      numTravelers = (prefs['group_size'] as num).toInt();
      travelType = numTravelers! > 1 ? 'Group' : 'Solo';
    }

    if (prefs['duration_days'] != null) {
      numDays = (prefs['duration_days'] as num).toInt();
    }

    if (prefs['vibe'] != null && (prefs['vibe'] as String).isNotEmpty) {
      vibe = prefs['vibe'];
    }

    if (prefs['location'] != null && (prefs['location'] as String).isNotEmpty) {
      district = prefs['location'];
    }
  }

  void reset() {
    budget = null;
    numTravelers = null;
    numDays = null;
    travelType = null;
    vibe = null;
    selectedDate = null;
    district = null;
    budgetCategory = null;
  }
}
