import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/app_routes.dart';
import '../../core/constants/app_constants.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../widgets/inputs/custom_input_field.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final success = await auth.login(_emailCtrl.text.trim(), _passCtrl.text);
    if (success && mounted) {
      Navigator.pushReplacementNamed(context, AppRoutes.navShell);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top decorative header
          Container(
            height: 280,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.primaryBlue, Color(0xFF104B50)],
              ),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -40,
                  top: -40,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.secondaryGreen.withOpacity(0.12),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
              ],
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button & logo
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
                    padding: const EdgeInsets.fromLTRB(
                      AppConstants.spaceL, AppConstants.spaceS, AppConstants.spaceL, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome\nBack 👋', style: GoogleFonts.outfit(
                          fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white, height: 1.2)),
                        const SizedBox(height: AppConstants.spaceS),
                        Text('Sign in to continue your Davao adventure',
                          style: GoogleFonts.outfit(fontSize: 14, color: Colors.white60)),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),

                  // White card form
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
                          Text('Sign In', style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          )),
                          const SizedBox(height: AppConstants.spaceXL),

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
                          const SizedBox(height: AppConstants.spaceS),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: () => Navigator.pushNamed(context, AppRoutes.forgotPassword),
                              child: const Text('Forgot Password?',
                                style: TextStyle(color: AppTheme.secondaryGreen, fontWeight: FontWeight.w600)),
                            ),
                          ),

                          Consumer<AuthProvider>(
                            builder: (_, auth, __) {
                              if (auth.errorMessage != null) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: AppConstants.spaceM),
                                  child: Container(
                                    padding: const EdgeInsets.all(AppConstants.spaceM),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withOpacity(0.08),
                                      borderRadius: BorderRadius.circular(AppConstants.radiusM),
                                      border: Border.all(color: Colors.red.withOpacity(0.3)),
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
                            builder: (_, auth, __) => CustomButton(
                              label: 'Sign In',
                              onPressed: _handleLogin,
                              isLoading: auth.isLoading,
                              variant: ButtonVariant.primary,
                              width: double.infinity,
                            ),
                          ),
                          const SizedBox(height: AppConstants.spaceL),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text("Don't have an account?  ",
                                style: TextStyle(color: AppTheme.textSecondaryLight)),
                              GestureDetector(
                                onTap: () => Navigator.pushReplacementNamed(context, AppRoutes.signup),
                                child: const Text('Sign Up',
                                  style: TextStyle(
                                    color: AppTheme.secondaryGreen,
                                    fontWeight: FontWeight.bold,
                                  )),
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
