import 'package:flutter/material.dart';
import '../widgets/admin_widgets.dart';

/// An honest availability state for admin-wide resources not yet exposed.
class CapabilityScreen extends StatelessWidget {
  final String title;
  final String description;
  final String availability;
  final IconData icon;
  final List<String> details;

  const CapabilityScreen({
    super.key,
    required this.title,
    required this.description,
    required this.availability,
    required this.icon,
    required this.details,
  });

  @override
  Widget build(BuildContext context) => AdminPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AdminPageHeader(title: title, description: description),
        const SizedBox(height: 24),
        AdminMessage(
          icon: icon,
          title: 'Admin access is not available yet',
          message: availability,
          action: OutlinedButton.icon(
            onPressed: () =>
                Navigator.pushReplacementNamed(context, '/dashboard'),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to overview'),
          ),
        ),
        const SizedBox(height: 24),
        AdminPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace scope',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              for (final detail in details)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(detail)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
