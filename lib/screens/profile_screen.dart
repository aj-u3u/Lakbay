import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';
import '../widgets/admin_widgets.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _api = ApiService();
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _avatar = TextEditingController();
  Map<String, dynamic>? _profile;
  String? _error;
  bool _loading = true;
  bool _saving = false;
  bool get _dirty =>
      _profile != null &&
      (_name.text != (_profile!['full_name'] ?? '').toString() ||
          _avatar.text != (_profile!['avatar_url'] ?? '').toString());

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    adminHasUnsavedChanges.value = false;
    adminIsSaving.value = false;
    _api.close();
    _name.dispose();
    _avatar.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = await _api.getCurrentUser();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _name.text = profile['full_name'].toString();
        _avatar.text = (profile['avatar_url'] ?? '').toString();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changed(String _) =>
      setState(() => adminHasUnsavedChanges.value = _dirty);
  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
      adminIsSaving.value = true;
    });
    try {
      final saved = await _api.updateOwnProfile({
        'full_name': _name.text.trim(),
        'avatar_url': _avatar.text.trim(),
      });
      if (!mounted) return;
      await SessionManager.instance.updateProfile(
        name: saved['full_name'].toString(),
        email: saved['email'].toString(),
      );
      if (!mounted) return;
      setState(() {
        _profile = saved;
        _name.text = saved['full_name'].toString();
        _avatar.text = (saved['avatar_url'] ?? '').toString();
        adminHasUnsavedChanges.value = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Your profile has been saved.')),
      );
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      adminIsSaving.value = false;
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _reset() async {
    if (!await confirmAdminNavigation(context) || !mounted) return;
    setState(() {
      _name.text = (_profile!['full_name'] ?? '').toString();
      _avatar.text = (_profile!['avatar_url'] ?? '').toString();
      _error = null;
      adminHasUnsavedChanges.value = false;
    });
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_dirty && !_saving,
    onPopInvokedWithResult: (didPop, result) async {
      if (didPop || _saving) return;
      if (await confirmAdminNavigation(context) && context.mounted) {
        setState(() {
          _name.text = (_profile?['full_name'] ?? '').toString();
          _avatar.text = (_profile?['avatar_url'] ?? '').toString();
        });
        if (context.mounted) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            Navigator.pushReplacementNamed(context, '/dashboard');
          }
        }
      }
    },
    child: AdminPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AdminPageHeader(
            title: 'Your Profile',
            description: 'Keep your administrator identity up to date.',
          ),
          const SizedBox(height: 24),
          if (_loading)
            const AdminPanel(child: Center(child: CircularProgressIndicator()))
          else if (_profile == null)
            AdminMessage(
              icon: Icons.error_outline,
              title: 'Could not load your profile',
              message: _error ?? 'Please try again.',
              isError: true,
              action: OutlinedButton(
                onPressed: _load,
                child: const Text('Retry'),
              ),
            )
          else
            Align(
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: AdminPanel(
                  child: Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account details',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            AdminBadge(
                              label: (_profile!['role'] ?? '').toString(),
                            ),
                            AdminBadge(
                              label: _profile!['is_active'] == true
                                  ? 'Active'
                                  : 'Inactive',
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _name,
                          enabled: !_saving,
                          onChanged: _changed,
                          maxLength: 255,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            counterText: '',
                          ),
                          validator: (value) => (value ?? '').trim().length < 2
                              ? 'Enter at least two characters.'
                              : null,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Email address',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        const SizedBox(height: 6),
                        SelectableText(_profile!['email'].toString()),
                        const SizedBox(height: 6),
                        Text(
                          'Email and role changes are not available from your profile.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _avatar,
                          enabled: !_saving,
                          onChanged: _changed,
                          maxLength: 2048,
                          decoration: const InputDecoration(
                            labelText: 'Avatar image URL (optional)',
                            counterText: '',
                            hintText: 'https://...',
                          ),
                          validator: (value) {
                            if ((value ?? '').trim().isEmpty) return null;
                            final uri = Uri.tryParse(value!.trim());
                            return uri != null &&
                                    ['https', 'http'].contains(uri.scheme) &&
                                    uri.host.isNotEmpty
                                ? null
                                : 'Enter a valid http or https image URL.';
                          },
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Semantics(
                            liveRegion: true,
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            FilledButton(
                              onPressed: _saving || !_dirty ? null : _save,
                              child: Text(
                                _saving ? 'Saving...' : 'Save profile',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: _saving || !_dirty ? null : _reset,
                              child: const Text('Discard changes'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}
