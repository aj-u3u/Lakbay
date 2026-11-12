import 'package:flutter/material.dart';
import 'capability_screen.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});
  @override
  Widget build(BuildContext context) => const CapabilityScreen(
    title: 'Reviews & Feedback',
    description:
        'Understand traveler experiences and find opportunities to improve destination information.',
    availability:
        'Traveler feedback is currently accessible within each traveler’s trip. A shared admin feedback directory is needed before reviews can be shown here.',
    icon: Icons.rate_review_outlined,
    details: [
      'Read original comments with their trip and destination context.',
      'Inspect post-trip rating, accuracy, route efficiency, budget adherence, and overall experience.',
      'Use feedback to guide destination and rate corrections. Moderation and replies require a separate review workflow.',
    ],
  );
}
