import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _api = ApiService();
  bool _busy = false;
  bool _obscure = true;
  String? _error;
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _api.close();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await _api.login(_email.text.trim(), _password.text);
      if (result['role'] != 'admin') {
        throw const ApiException(
          'Use an administrator account to access this workspace.',
        );
      }
      await SessionManager.instance.saveSession(
        token: result['access_token'].toString(),
        refreshToken: result['refresh_token']?.toString(),
        name: (result['full_name'] ?? '').toString(),
        email: result['email'].toString(),
        role: result['role'].toString(),
        userId: result['user_id'].toString(),
      );
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (_) => false);
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          final form = ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Form(
              key: _form,
              child: AutofillGroup(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!wide) ...[_brand(theme), const SizedBox(height: 40)],
                    Text('Welcome back', style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 8),
                    const Text('Sign in to your Lakbay admin workspace.'),
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _email,
                      enabled: !_busy,
                      autofillHints: const [
                        AutofillHints.username,
                        AutofillHints.email,
                      ],
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                        prefixIcon: Icon(Icons.mail_outline),
                      ),
                      validator: (value) =>
                          value == null ||
                              !RegExp(
                                r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                              ).hasMatch(value.trim())
                          ? 'Enter a valid email address.'
                          : null,
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _password,
                      enabled: !_busy,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _signIn(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Enter your password.'
                          : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 20),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _busy ? null : _signIn,
                        child: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Administrator access only',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          );
          return Row(
            children: [
              if (wide)
                Expanded(
                  child: Container(
                    height: constraints.maxHeight,
                    color: theme.cardColor,
                    padding: const EdgeInsets.all(64),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _brand(theme),
                        const SizedBox(height: 56),
                        Text(
                          'One workspace.\nBetter travel information.',
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Maintain destinations and market rates. Understand the people and trips behind every journey.',
                        ),
                        const SizedBox(height: 36),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: const [
                            Chip(label: Text('Destinations')),
                            Chip(label: Text('Market rates')),
                            Chip(label: Text('Travel insights')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(wide ? 48 : 24),
                    child: form,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _brand(ThemeData theme) => Row(
    children: [
      Container(
        width: 48,
        height: 48,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Image.asset(
          'assets/images/lakbay_logo.png',
          fit: BoxFit.contain,
        ),
      ),
      const SizedBox(width: 14),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Lakbay+', style: theme.textTheme.titleLarge),
          Text('Admin workspace', style: theme.textTheme.bodySmall),
        ],
      ),
    ],
  );
}
