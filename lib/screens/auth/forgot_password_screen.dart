import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../widgets/buttons/custom_button.dart';
import '../../widgets/inputs/custom_input_field.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _emailSent = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 1500));
    setState(() { _isLoading = false; _emailSent = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Reset Password'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.spaceXL),
        child: _emailSent ? _buildSuccessState() : _buildFormState(),
      ),
    );
  }

  Widget _buildFormState() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppConstants.spaceL),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.lock_reset_rounded, size: 36, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: AppConstants.spaceXL),
          Text('Forgot Password?', style: GoogleFonts.outfit(
            fontSize: 28, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          const SizedBox(height: AppConstants.spaceS),
          Text(
            'Enter your registered email address and we\'ll send you a reset link.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
          const SizedBox(height: AppConstants.spaceXXL),
          CustomInputField(
            label: 'Email Address',
            hint: 'you@example.com',
            controller: _emailCtrl,
            prefixIcon: Icons.email_outlined,
            keyboardType: TextInputType.emailAddress,
            validator: (v) => (v == null || !v.contains('@')) ? 'Enter a valid email' : null,
          ),
          const SizedBox(height: AppConstants.spaceXL),
          CustomButton(
            label: 'Send Reset Link',
            onPressed: _handleReset,
            isLoading: _isLoading,
            variant: ButtonVariant.primary,
            width: double.infinity,
            leadingIcon: Icons.send_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 60),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: AppTheme.secondaryGreen.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_rounded, size: 50, color: AppTheme.secondaryGreen),
        ),
        const SizedBox(height: AppConstants.spaceXL),
        Text('Check Your Email', style: GoogleFonts.outfit(
          fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
        const SizedBox(height: AppConstants.spaceM),
        Text(
          'We\'ve sent a password reset link to\n${_emailCtrl.text}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.6),
        ),
        const SizedBox(height: AppConstants.spaceXXL),
        CustomButton(
          label: 'Back to Login',
          onPressed: () => Navigator.pop(context),
          variant: ButtonVariant.outlined,
          width: double.infinity,
        ),
      ],
    );
  }
}

