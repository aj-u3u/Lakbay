import 'package:flutter/material.dart';
import 'market_rates_screen.dart';

/// Keeps existing accommodation links open in the shared rates workspace.
class AccommodationScreen extends StatelessWidget {
  const AccommodationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MarketRatesScreen(initialTab: 0);
  }
}
