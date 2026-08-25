import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../widgets/onboarding_scaffold.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';

/// 05_create_account (node 368:238). Figma shows three method buttons plus
/// a generic bottom "Continue" pill — there's no dedicated email/password
/// entry frame in the approved file, so picking "Continue with Email"
/// reveals two inline fields styled like 06_personal_info's inputs rather
/// than inventing a new screen. The "Google" button uses the exact
/// `circle-x` glyph the approved frame itself uses there — Figma's own
/// source doesn't have real Google branding on this button, and per the
/// build brief the approved screen wins over inventing something "more
/// correct" looking.
class CreateAccountScreen extends ConsumerStatefulWidget {
  const CreateAccountScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<CreateAccountScreen> createState() =>
      _CreateAccountScreenState();
}

class _CreateAccountScreenState extends ConsumerState<CreateAccountScreen> {
  AuthProvider? _selected;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  late final TapGestureRecognizer _signInRecognizer;

  @override
  void initState() {
    super.initState();
    _signInRecognizer = TapGestureRecognizer()..onTap = _handleSignInTap;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _signInRecognizer.dispose();
    super.dispose();
  }

  void _handleSignInTap() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Sign in isn't part of this build yet — continue with a new account for now.",
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  bool get _canContinue {
    if (_selected == null) return false;
    if (_selected == AuthProvider.email) {
      return _emailController.text.trim().contains('@') &&
          _passwordController.text.trim().length >= 6;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingScaffold(
      title: 'Create your Glow Up account',
      subtitle: 'Start saving your customized wellness tracking',
      primaryLabel: 'Continue',
      primaryEnabled: _canContinue,
      onPrimaryPressed: _canContinue
          ? () {
              ref
                  .read(onboardingControllerProvider.notifier)
                  .setAuthProvider(_selected!);
              widget.onNext();
            }
          : null,
      belowButton: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          link: true,
          label: 'Sign in to an existing account',
          child: Text.rich(
            TextSpan(
              style: AppTextStyles.caption,
              children: [
                const TextSpan(text: 'Already have an account? '),
                TextSpan(
                  text: 'Sign in',
                  style: AppTextStyles.captionBold.copyWith(
                    color: AppColors.gold,
                  ),
                  recognizer: _signInRecognizer,
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 8),
            const Center(child: AppMascot(size: 80)),
            const SizedBox(height: 24),
            _MethodButton(
              icon: 'circle-x',
              label: 'Continue with Google',
              selected: _selected == AuthProvider.google,
              onTap: () => setState(() => _selected = AuthProvider.google),
            ),
            const SizedBox(height: 12),
            _MethodButton(
              icon: 'apple-brand',
              label: 'Continue with Apple',
              selected: _selected == AuthProvider.apple,
              onTap: () => setState(() => _selected = AuthProvider.apple),
            ),
            const SizedBox(height: 12),
            _MethodButton(
              icon: 'mail',
              label: 'Continue with Email',
              selected: _selected == AuthProvider.email,
              onTap: () => setState(() => _selected = AuthProvider.email),
            ),
            if (_selected == AuthProvider.email) ...[
              const SizedBox(height: 16),
              _InlineField(
                label: 'Email',
                controller: _emailController,
                hint: 'you@example.com',
              ),
              const SizedBox(height: 12),
              _InlineField(
                label: 'Password',
                controller: _passwordController,
                hint: 'At least 6 characters',
                obscure: true,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MethodButton extends StatelessWidget {
  const _MethodButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        onTap: onTap,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.gold : Colors.white24,
              width: selected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(AppRadii.pill),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppIcon(icon, size: 18),
              const SizedBox(width: 12),
              Text(
                label,
                style: AppTextStyles.fieldLabel.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineField extends StatelessWidget {
  const _InlineField({
    required this.label,
    required this.controller,
    required this.hint,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final bool obscure;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.fieldLabel),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(AppRadii.sm),
            border: Border.all(color: AppColors.cardBorder),
          ),
          alignment: Alignment.centerLeft,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: AppTextStyles.fieldValue,
            decoration: InputDecoration(
              border: InputBorder.none,
              isDense: true,
              hintText: hint,
              hintStyle: AppTextStyles.fieldPlaceholder,
            ),
          ),
        ),
      ],
    );
  }
}
