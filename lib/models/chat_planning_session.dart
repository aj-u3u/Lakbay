import 'destination.dart';
import 'session_preferences.dart';

/// The backend preview is the source of truth for one conversational plan.
class ChatPlanningSession {
  Map<String, dynamic> state = {
    'destination_ids': <int>[],
    'interests': <String>[],
  };
  Map<String, dynamic>? preview;
  int revision = 0;

  void reset({Destination? destination, SessionPreferences? preferences}) {
    state = {
      'destination_ids': destination == null ? <int>[] : <int>[destination.id],
      'interests': preferences?.vibe == null || preferences!.vibe!.isEmpty
          ? <String>[]
          : <String>[preferences.vibe!],
      if (preferences?.budget != null)
        'total_budget': preferences!.budget!.toStringAsFixed(2),
      if (preferences?.numTravelers != null)
        'traveler_count': preferences!.numTravelers,
      if (preferences?.numDays != null) 'day_count': preferences!.numDays,
    };
    preview = null;
    revision++;
  }

  void edit(Map<String, dynamic> changes) {
    state = {...state, ...changes};
    preview = null;
    revision++;
  }

  bool acceptPreview(Map<String, dynamic> result, int requestRevision) {
    if (revision != requestRevision ||
        result['input_revision'] != requestRevision ||
        result['state'] is! Map) {
      return false;
    }
    preview = result;
    state = Map<String, dynamic>.from(result['state'] as Map);
    return true;
  }

  bool acceptChat(Map<String, dynamic> result, int requestRevision) {
    final planning = result['planning'];
    if (planning is! Map ||
        planning['input_revision'] != requestRevision ||
        planning['preview'] is! Map) {
      return false;
    }
    return acceptPreview(
      Map<String, dynamic>.from(planning['preview'] as Map),
      requestRevision,
    );
  }

  List<int> get destinationIds =>
      (state['destination_ids'] as List? ?? const []).whereType<int>().toList();

  bool get canGenerate {
    final currentPreview = preview;
    if (currentPreview == null || destinationIds.isEmpty) return false;
    if (state['total_budget'] == null ||
        state['traveler_count'] == null ||
        state['day_count'] == null ||
        state['night_count'] == null ||
        state['return_to_origin'] == null) {
      return false;
    }
    final budget = currentPreview['budget'];
    if (budget is! Map ||
        budget['completeness'] != 'complete' ||
        budget['total_estimate'] == null ||
        budget['fit'] == 'over_budget') {
      return false;
    }
    final missing = (currentPreview['missing_inputs'] as List? ?? const [])
        .where((item) => item != 'origin.coordinates');
    final route = currentPreview['route'];
    final routeRequested = state['route_preferences'] != null;
    if (routeRequested && (route is! Map || route['status'] != 'calculated')) {
      return false;
    }
    return missing.isEmpty &&
        (currentPreview['selection_problems'] as List? ?? const []).isEmpty &&
        (budget['missing_costs'] as List? ?? const []).isEmpty;
  }
}
