import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../widgets/inputs/custom_input_field.dart';
import '../../widgets/shared/error_state.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _obscureConfirmPass = true;

  bool _nameTouched = false;
  bool _emailTouched = false;
  bool _passTouched = false;
  bool _confirmPassTouched = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_onFieldChanged);
    _emailCtrl.addListener(_onFieldChanged);
    _passCtrl.addListener(_onFieldChanged);
    _confirmPassCtrl.addListener(_onFieldChanged);
  }

  void _onFieldChanged() {
    setState(() {
      if (_nameCtrl.text.isNotEmpty) _nameTouched = true;
      if (_emailCtrl.text.isNotEmpty) _emailTouched = true;
      if (_passCtrl.text.isNotEmpty) _passTouched = true;
      if (_confirmPassCtrl.text.isNotEmpty) _confirmPassTouched = true;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your name';
    if (value.trim().length < 2) return 'Name must be at least 2 characters';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Enter your email address';
    final emailVal = value.trim().toLowerCase();
    if (!emailVal.endsWith('@gmail.com')) {
      return 'Only Gmail addresses are allowed';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@gmail\.com$');
    if (!emailRegex.hasMatch(emailVal)) return 'Enter a valid Gmail address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Minimum 8 characters';
    if (!RegExp(r'[A-Z]').hasMatch(value)) return 'At least 1 uppercase letter';
    if (!RegExp(r'[0-9]').hasMatch(value)) return 'At least 1 number';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Confirm your password';
    if (value != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  bool get _isFormValid {
    return _validateName(_nameCtrl.text) == null &&
        _validateEmail(_emailCtrl.text) == null &&
        _validatePassword(_passCtrl.text) == null &&
        _validateConfirmPassword(_confirmPassCtrl.text) == null;
  }

  Future<void> _handleRegister() async {
    if (!_isFormValid) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully! Please sign in to access your account.'),
          backgroundColor: AppTheme.secondaryGreen,
          duration: Duration(seconds: 4),
        ),
      );
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 240,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF104B50), AppTheme.primaryBlue],
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppConstants.spaceM),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                          ),
                          child: Row(
                            children: [
                              Image.asset('assets/images/lakbay_logo.png', width: 22, height: 22),
                              const SizedBox(width: 8),
                              const Text('Lakbay+', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(AppConstants.spaceL, 0, AppConstants.spaceL, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create\nAccount ✈️', style: GoogleFonts.outfit(
                          fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                        const SizedBox(height: 60),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.all(AppConstants.spaceXL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Join Lakbay+', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                        const SizedBox(height: 4),
                        Text('Start exploring Davao Region today',
                          style: Theme.of(context).textTheme.bodyMedium),
                        const SizedBox(height: AppConstants.spaceXL),

                        // ── NAME ─────────────────────────────────────────────
                        CustomInputField(
                          label: 'Full Name',
                          hint: 'Juan dela Cruz',
                          controller: _nameCtrl,
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        if (_nameTouched && _validateName(_nameCtrl.text) != null) ...[
                          const SizedBox(height: 4),
                          InlineFieldError(_validateName(_nameCtrl.text)!),
                        ],
                        const SizedBox(height: AppConstants.spaceL),

                        // ── EMAIL ────────────────────────────────────────────
                        CustomInputField(
                          label: 'Email Address',
                          hint: 'you@example.com',
                          controller: _emailCtrl,
                          prefixIcon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                        ),
                        if (_emailTouched && _validateEmail(_emailCtrl.text) != null) ...[
                          const SizedBox(height: 4),
                          InlineFieldError(_validateEmail(_emailCtrl.text)!),
                        ],
                        const SizedBox(height: AppConstants.spaceL),

                        // ── PASSWORD ─────────────────────────────────────────
                        CustomInputField(
                          label: 'Password',
                          hint: '••••••••',
                          controller: _passCtrl,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscurePass,
                          suffixIcon: _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscurePass = !_obscurePass),
                        ),
                        if (_passTouched && _validatePassword(_passCtrl.text) != null) ...[
                          const SizedBox(height: 4),
                          InlineFieldError(_validatePassword(_passCtrl.text)!),
                        ],
                        const SizedBox(height: AppConstants.spaceL),

                        // ── CONFIRM PASSWORD ─────────────────────────────────
                        CustomInputField(
                          label: 'Confirm Password',
                          hint: '••••••••',
                          controller: _confirmPassCtrl,
                          prefixIcon: Icons.lock_outline_rounded,
                          obscureText: _obscureConfirmPass,
                          suffixIcon: _obscureConfirmPass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          onSuffixTap: () => setState(() => _obscureConfirmPass = !_obscureConfirmPass),
                        ),
                        if (_confirmPassTouched && _validateConfirmPassword(_confirmPassCtrl.text) != null) ...[
                          const SizedBox(height: 4),
                          InlineFieldError(_validateConfirmPassword(_confirmPassCtrl.text)!),
                        ],
                        const SizedBox(height: AppConstants.spaceXL),

                        Consumer<AuthProvider>(
                          builder: (_, auth, _) {
                            if (auth.errorMessage != null) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
                                child: Container(
                                  padding: const EdgeInsets.all(AppConstants.spaceM),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(children: [
                                    const Icon(Icons.error_outline, color: Colors.red, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(child: Text(auth.errorMessage!,
                                      style: const TextStyle(color: Colors.red, fontSize: 13))),
                                  ]),
                                ),
                              );
                            }
                            return const SizedBox.shrink();
                          },
                        ),

                        const SizedBox(height: AppConstants.spaceM),
                        Consumer<AuthProvider>(
                          builder: (_, auth, _) => CustomButton(
                            label: 'Create Account',
                            onPressed: _isFormValid ? _handleRegister : null,
                            isLoading: auth.isLoading,
                            variant: ButtonVariant.primary,
                            width: double.infinity,
                            leadingIcon: Icons.check_circle_outline_rounded,
                          ),
                        ),
                        const SizedBox(height: AppConstants.spaceL),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Already have an account?  ",
                              style: TextStyle(color: AppTheme.textSecondaryLight)),
                            GestureDetector(
                              onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.login),
                              child: const Text('Sign In',
                                style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppConstants.spaceL),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
