import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../widgets/auth_widgets.dart';

/// Forgot Password — not in the approved reference set; reuses AU03's
/// visual language. Sends a real Supabase reset email; never invents a
/// local password change.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    this.onBack,
    required this.onSend,
    this.loading = false,
    this.errorText,
    this.sent = false,
  });

  final VoidCallback? onBack;
  final ValueChanged<String> onSend;
  final bool loading;
  final String? errorText;
  final bool sent;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool get _isValidEmail => RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  ).hasMatch(_emailController.text.trim());

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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Reset your password',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      "We'll email you a real link to reset it.",
                      style: AppTextStyles.subtitleLg,
                    ),
                    const SizedBox(height: 28),
                    if (widget.sent)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: AppColors.success.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          "If an account exists for ${_emailController.text.trim()}, we've sent a reset link.",
                          style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                        ),
                      )
                    else ...[
                      AuthTextField(
                        label: 'Email',
                        controller: _emailController,
                        hintText: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => setState(() {}),
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
                      const SizedBox(height: 24),
                      GradientPillButton(
                        label: 'Send Reset Link',
                        loading: widget.loading,
                        onPressed: _isValidEmail && !widget.loading
                            ? () => widget.onSend(_emailController.text.trim())
                            : null,
                      ),
                    ],
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
