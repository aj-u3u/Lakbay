import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../widgets/inputs/custom_input_field.dart';
import '../../widgets/inputs/preference_selector.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;
  List<String> _selectedPrefs = [];

  final List<String> _allPrefs = [
    'Nature', 'Beach', 'Mountain', 'Food & Culture',
    'Adventure', 'Family', 'Luxury', 'Eco-Tourism',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.register(
      _nameCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.navShell);
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
                      color: Theme.of(context).colorScheme.background,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    padding: const EdgeInsets.all(AppConstants.spaceXL),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Join Lakbay+', style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                          const SizedBox(height: 4),
                          Text('Start exploring Davao Region today',
                            style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppConstants.spaceXL),

                          CustomInputField(
                            label: 'Full Name',
                            hint: 'Juan dela Cruz',
                            controller: _nameCtrl,
                            prefixIcon: Icons.person_outline_rounded,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                          ),
                          const SizedBox(height: AppConstants.spaceL),
                          CustomInputField(
                            label: 'Email Address',
                            hint: 'you@example.com',
                            controller: _emailCtrl,
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
                          ),
                          const SizedBox(height: AppConstants.spaceL),
                          CustomInputField(
                            label: 'Password',
                            hint: '••••••••',
                            controller: _passCtrl,
                            prefixIcon: Icons.lock_outline_rounded,
                            obscureText: _obscurePass,
                            suffixIcon: _obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            onSuffixTap: () => setState(() => _obscurePass = !_obscurePass),
                            validator: (v) => (v == null || v.length < 6) ? 'Minimum 6 characters' : null,
                          ),
                          const SizedBox(height: AppConstants.spaceXL),

                          Text('Travel Preferences', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text('Select all that apply to personalize your experience',
                            style: Theme.of(context).textTheme.bodyMedium),
                          const SizedBox(height: AppConstants.spaceM),
                          PreferenceSelector(
                            options: _allPrefs,
                            selected: _selectedPrefs,
                            onToggle: (p) => setState(() {
                              _selectedPrefs.contains(p)
                                  ? _selectedPrefs.remove(p)
                                  : _selectedPrefs.add(p);
                            }),
                          ),
                          const SizedBox(height: AppConstants.spaceXL),

                          Consumer<AuthProvider>(
                            builder: (_, auth, __) => CustomButton(
                              label: 'Create Account',
                              onPressed: _handleRegister,
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
