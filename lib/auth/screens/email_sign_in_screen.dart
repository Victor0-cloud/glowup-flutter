import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../widgets/auth_widgets.dart';

/// Email sign-in — not one of the 6 approved AU0x references (the set has
/// no dedicated sign-in-form page), so this reuses AU03's exact visual
/// language (same field/button style) rather than inventing a new look,
/// per the written requirement for a real email/password sign-in flow.
class EmailSignInScreen extends StatefulWidget {
  const EmailSignInScreen({
    super.key,
    this.onBack,
    required this.onSignIn,
    this.onForgotPassword,
    this.onCreateAccount,
    this.loading = false,
    this.errorText,
  });

  final VoidCallback? onBack;
  final void Function(String email, String password) onSignIn;
  final VoidCallback? onForgotPassword;
  final VoidCallback? onCreateAccount;
  final bool loading;
  final String? errorText;

  @override
  State<EmailSignInScreen> createState() => _EmailSignInScreenState();
}

class _EmailSignInScreenState extends State<EmailSignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool get _isValidEmail => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(_emailController.text.trim());
  bool get _canSubmit => _isValidEmail && _passwordController.text.isNotEmpty;

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
                      'Sign in',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Welcome back to Glow Up.',
                      style: AppTextStyles.subtitleLg,
                    ),
                    const SizedBox(height: 28),
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
                      autofillHints: const [AutofillHints.password],
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
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerRight,
                      child: Semantics(
                        button: true,
                        label: 'Forgot password?',
                        child: InkWell(
                          onTap: widget.onForgotPassword,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Forgot password?',
                              style: AppTextStyles.captionBold.copyWith(
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (widget.errorText != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.errorText!,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ctaStart,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    GradientPillButton(
                      label: 'Sign In',
                      loading: widget.loading,
                      onPressed: _canSubmit && !widget.loading
                          ? () => widget.onSignIn(
                              _emailController.text.trim(),
                              _passwordController.text,
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Semantics(
                        button: true,
                        label: "Don't have an account? Sign Up",
                        child: InkWell(
                          onTap: widget.onCreateAccount,
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            alignment: Alignment.center,
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.subtitle,
                                children: [
                                  const TextSpan(
                                    text: "Don't have an account? ",
                                  ),
                                  TextSpan(
                                    text: 'Sign Up',
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
