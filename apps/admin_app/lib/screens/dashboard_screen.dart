import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/admin_widgets.dart';

class DashboardScreen extends StatefulWidget {
  final ApiService? api;
  const DashboardScreen({super.key, this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final ApiService _api = widget.api ?? ApiService();
  late Future<List<dynamic>> _destinations;

  @override
  void initState() {
    super.initState();
    _destinations = _api.getDestinations();
  }

  void _refresh() => setState(() {
    _destinations = _api.getDestinations();
  });

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  Future<void> _open(String route) async {
    if (!await confirmAdminNavigation(context) || !mounted) return;
    if (!context.mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminPageHeader(
            title: 'Overview',
            description:
                'Maintain destination information and travel costs from one workspace.',
            action: OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Refresh catalog'),
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
            future: _destinations,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AdminPanel(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 16),
                      Expanded(child: Text('Loading the destination catalog…')),
                    ],
                  ),
                );
              }
              if (snapshot.hasError) {
                final error = snapshot.error;
                return AdminMessage(
                  icon: Icons.cloud_off_outlined,
                  title: 'Destination catalog unavailable',
                  message: error is ApiException
                      ? error.message
                      : 'The destination catalog could not be loaded. Try again.',
                  isError: true,
                  action: OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Try again'),
                  ),
                );
              }
              final destinations = snapshot.data ?? [];
              final activeCount = destinations
                  .where((item) => item is Map && item['is_active'] != false)
                  .length;
              return AdminPanel(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final summary = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withValues(
                              alpha: 0.09,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.travel_explore,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Active destinations',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '$activeCount',
                                style: theme.textTheme.headlineLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activeCount == 0
                                    ? 'No active destinations were returned by the public catalog.'
                                    : 'Active records loaded from the public catalog. Inactive inventory is not included.',
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                    final action = OutlinedButton.icon(
                      onPressed: () => _open('/destinations'),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Manage destinations'),
                    );
                    if (constraints.maxWidth < 680) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [summary, const SizedBox(height: 20), action],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: summary),
                        const SizedBox(width: 24),
                        action,
                      ],
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 32),
          Semantics(
            header: true,
            child: Text('Manage Lakbay', style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose the information you want to maintain or inspect.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 960
                  ? 3
                  : constraints.maxWidth >= 620
                  ? 2
                  : 1;
              final cardWidth =
                  (constraints.maxWidth - (columns - 1) * 16) / columns;
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (final area in _workAreas)
                    SizedBox(
                      width: cardWidth,
                      child: _WorkspaceCard(
                        area: area,
                        onOpen: () => _open(area.route),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _WorkArea {
  final String title;
  final String description;
  final String route;
  final IconData icon;
  final bool accessPending;

  const _WorkArea(
    this.title,
    this.description,
    this.route,
    this.icon, {
    this.accessPending = false,
  });
}

const _workAreas = [
  _WorkArea(
    'Destinations',
    'Maintain places, descriptions, location details, images, and traveler information.',
    '/destinations',
    Icons.place_outlined,
  ),
  _WorkArea(
    'Market Rates',
    'View and maintain accommodation and transportation costs for a selected destination.',
    '/market-rates',
    Icons.payments_outlined,
  ),
  _WorkArea(
    'User Accounts',
    'Inspect account information when administrator access is available.',
    '/users',
    Icons.people_outline,
    accessPending: true,
  ),
  _WorkArea(
    'Reviews & Feedback',
    'Read traveler comments and ratings with their original trip context.',
    '/reviews',
    Icons.rate_review_outlined,
    accessPending: true,
  ),
  _WorkArea(
    'Trip Information',
    'Inspect itineraries and related destinations through read-only trip access.',
    '/trips',
    Icons.route_outlined,
    accessPending: true,
  ),
];

class _WorkspaceCard extends StatelessWidget {
  final _WorkArea area;
  final VoidCallback onOpen;

  const _WorkspaceCard({required this.area, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AdminPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  area.icon,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
              ),
              if (area.accessPending) const AdminBadge(label: 'Access pending'),
            ],
          ),
          const SizedBox(height: 16),
          Text(area.title, style: theme.textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            area.description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.arrow_forward, size: 18),
            label: Text(
              area.accessPending ? 'View access details' : 'Open workspace',
            ),
          ),
        ],
      ),
    );
  }
}
