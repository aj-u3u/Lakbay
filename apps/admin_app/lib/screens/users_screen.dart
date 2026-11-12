import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/admin_widgets.dart';

class UsersScreen extends StatefulWidget {
  final ApiService? api;
  const UsersScreen({super.key, this.api});
  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  late final _api = widget.api ?? ApiService();
  late Future<Map<String, dynamic>> _profile;
  @override
  void initState() {
    super.initState();
    _profile = _api.getCurrentUser();
  }

  @override
  void dispose() {
    _api.close();
    super.dispose();
  }

  void _reload() => setState(() {
    _profile = _api.getCurrentUser();
  });

  @override
  Widget build(BuildContext context) => AdminPage(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AdminPageHeader(
          title: 'User Accounts',
          description:
              'Inspect account information and manage supported account details.',
        ),
        const SizedBox(height: 24),
        const AdminMessage(
          icon: Icons.people_outline_rounded,
          title: 'Traveler account directory is not available yet',
          message:
              'The shared account directory needs admin access before travelers can be listed or their account roles changed. Your own administrator profile is available below.',
        ),
        const SizedBox(height: 24),
        Text(
          'Your administrator account',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _profile,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const AdminPanel(
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError) {
              return AdminMessage(
                icon: Icons.error_outline,
                title: 'Could not load your account',
                message: snapshot.error.toString(),
                isError: true,
                action: OutlinedButton(
                  onPressed: _reload,
                  child: const Text('Retry'),
                ),
              );
            }
            final user = snapshot.data!;
            return AdminPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        (user['full_name'] ?? '').toString(),
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      AdminBadge(label: (user['role'] ?? '').toString()),
                      AdminBadge(
                        label: user['is_active'] == true
                            ? 'Active'
                            : 'Inactive',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text((user['email'] ?? '').toString()),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.pushReplacementNamed(context, '/profile'),
                    icon: const Icon(Icons.manage_accounts_outlined),
                    label: const Text('Manage your profile'),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    ),
  );
}
