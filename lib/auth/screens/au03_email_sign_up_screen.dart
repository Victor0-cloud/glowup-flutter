import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../widgets/auth_widgets.dart';

/// AU03 Create Your Account — real Supabase `signUp`. Validates locally
/// (matches AU03's 3-rule checklist + a real confirm-password check, which
/// the task explicitly requires even though the reference doesn't show a
/// second field) before ever calling Supabase.
class EmailSignUpScreen extends StatefulWidget {
  const EmailSignUpScreen({
    super.key,
    this.onBack,
    required this.onSignUp,
    this.onSignIn,
    this.loading = false,
    this.errorText,
  });

  final VoidCallback? onBack;
  final void Function(String name, String email, String password) onSignUp;
  final VoidCallback? onSignIn;
  final bool loading;
  final String? errorText;

  @override
  State<EmailSignUpScreen> createState() => _EmailSignUpScreenState();
}

class _EmailSignUpScreenState extends State<EmailSignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  bool _obscureConfirm = true;
  String? _confirmError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isValidEmail => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(_emailController.text.trim());
  bool get _isStrongPassword {
    final p = _passwordController.text;
    return p.length >= 8 &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\]').hasMatch(p);
  }

  /// Confirm-password match is deliberately NOT part of this gate — the
  /// button must stay tappable so `_submit` can run and show a real
  /// "Passwords do not match" error; gating on match here would make that
  /// error unreachable (a mismatched confirm field would just disable the
  /// button with no explanation).
  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty &&
      _isValidEmail &&
      _isStrongPassword;

  void _submit() {
    final mismatch = _confirmController.text != _passwordController.text;
    setState(() => _confirmError = mismatch ? 'Passwords do not match' : null);
    if (!_canSubmit || mismatch) return;
    widget.onSignUp(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: '',
              onBack: widget.onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Create your account',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "Let's get you glowing ✨",
                      style: AppTextStyles.subtitleLg,
                    ),
                    const SizedBox(height: 28),
                    AuthTextField(
                      label: 'Full Name',
                      controller: _nameController,
                      hintText: 'e.g., Angel Otite',
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      label: 'Email',
                      controller: _emailController,
                      hintText: 'you@example.com',
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      label: 'Password',
                      controller: _passwordController,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    PasswordStrengthChecklist(
                      password: _passwordController.text,
                    ),
                    const SizedBox(height: 18),
                    AuthTextField(
                      label: 'Confirm Password',
                      controller: _confirmController,
                      obscureText: _obscureConfirm,
                      errorText: _confirmError,
                      suffix: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: AppColors.textSecondary,
                          size: 20,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
                      onChanged: (_) => setState(() => _confirmError = null),
                    ),
                    if (widget.errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        widget.errorText!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ctaStart,
                        ),
                      ),
                    ],
                    const SizedBox(height: 28),
                    GradientPillButton(
                      label: 'Sign Up',
                      loading: widget.loading,
                      onPressed: _canSubmit && !widget.loading ? _submit : null,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Semantics(
                        button: true,
                        label: 'Already have an account? Sign In',
                        child: InkWell(
                          onTap: widget.onSignIn,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.subtitle,
                                children: [
                                  const TextSpan(
                                    text: 'Already have an account? ',
                                  ),
                                  TextSpan(
                                    text: 'Sign In',
                                    style: AppTextStyles.captionBold.copyWith(
                                      color: AppColors.gold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
