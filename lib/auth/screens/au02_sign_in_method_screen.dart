import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../widgets/auth_widgets.dart';

/// AU02 Sign In Method — real Google OAuth, real email sign-in, and a real
/// "Create an account" path to AU03. No fake/decorative buttons.
class AuthMethodScreen extends StatelessWidget {
  const AuthMethodScreen({
    super.key,
    this.onBack,
    required this.onGoogle,
    required this.onEmailSignIn,
    required this.onCreateAccount,
    this.googleLoading = false,
    this.errorText,
  });

  final VoidCallback? onBack;
  final VoidCallback onGoogle;
  final VoidCallback onEmailSignIn;
  final VoidCallback onCreateAccount;
  final bool googleLoading;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: '',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Welcome back!',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue your\nGlow Up journey.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitleLg,
                    ),
                    const SizedBox(height: 32),
                    GoogleSignInButton(
                      onPressed: onGoogle,
                      loading: googleLoading,
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: onEmailSignIn,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(
                          Icons.mail_outline,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'Continue with Email',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    if (errorText != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        errorText!,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ctaStart,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text('or', style: AppTextStyles.caption),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton(
                        onPressed: onCreateAccount,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: const StadiumBorder(),
                        ),
                        child: Text(
                          'Create an account',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'By continuing, you agree to our\nTerms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption,
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
