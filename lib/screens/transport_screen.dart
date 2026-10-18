import 'package:flutter/material.dart';
import 'market_rates_screen.dart';

/// Keeps existing transport links open in the shared rates workspace.
class TransportScreen extends StatelessWidget {
  const TransportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const MarketRatesScreen(initialTab: 1);
  }
}
