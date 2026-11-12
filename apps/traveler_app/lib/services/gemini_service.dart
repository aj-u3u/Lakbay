import '../models/trip.dart';
import 'api_service.dart';

class GeminiService {
  // Generates a customized travel itinerary by calling the FastAPI backend (RAG/LLM/Groq)
  Future<Trip?> generateItinerary({
    required String destinationDistrict, // e.g. 'Davao City', 'Davao Oriental', 'Davao del Norte'
    required int durationDays,
    required String travelVibe, // e.g. 'nature', 'beach', 'urban', 'adventure'
    required double budgetLimit,
  }) async {
    final apiService = ApiService();
    final responseMap = await apiService.generateAIItinerary(
      destinationName: destinationDistrict,
      numDays: durationDays,
      budget: budgetLimit,
      numAdults: 1,
      numChildren: 0,
      childAges: '',
      interests: [travelVibe],
    );

    if (responseMap != null) {
      final String title = responseMap['title'] ?? '$travelVibe Adventure in $destinationDistrict';
      final String destinationName = responseMap['destination'] ?? '$destinationDistrict, Davao Region';
      final String image = 'https://images.unsplash.com/photo-1470071459604-3b5ec3a7fe05?w=800&q=80';

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

      return Trip(
        id: 'ai-trip-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        destinationName: destinationName,
        dateRange: 'Flexible Dates (AI Generated)',
        budget: budgetLimit,
        imageUrl: image,
        itinerary: agenda,
      );
    }
    return null;
  }
}
