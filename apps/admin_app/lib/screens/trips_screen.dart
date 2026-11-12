import 'package:flutter/material.dart';
import 'capability_screen.dart';

class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});
  @override
  Widget build(BuildContext context) => const CapabilityScreen(
    title: 'Trip Information',
    description:
        'Inspect travel plans, itinerary destinations, budgets, and related feedback.',
    availability:
        'Trip information is currently restricted to trip owners and members. Admin-wide read access is needed before the trip directory can be shown here.',
    icon: Icons.route_outlined,
    details: [
      'View trip dates, participants, and planned, ongoing, completed, or archived status.',
      'Read the itinerary and open its related destination records.',
      'Distinguish planned budgets from recorded expenses. This workspace is intended for viewing trip information.',
    ],
  );
}
