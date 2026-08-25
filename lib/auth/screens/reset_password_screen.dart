import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../widgets/auth_widgets.dart';

/// Reset Password — reached only via the real Supabase recovery-link
/// callback (`AuthChangeEvent.passwordRecovery`), never reachable any
/// other way. Calls `auth.updateUser` for the real password change; never
/// sets a password locally.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({
    super.key,
    this.onBack,
    required this.onReset,
    this.loading = false,
    this.errorText,
  });

  final VoidCallback? onBack;
  final ValueChanged<String> onReset;
  final bool loading;
  final String? errorText;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscure = true;
  String? _confirmError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _isStrong {
    final p = _passwordController.text;
    return p.length >= 8 &&
        RegExp(r'[0-9]').hasMatch(p) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>_\-\[\]/\\]').hasMatch(p);
  }

  bool get _canSubmit =>
      _isStrong && _confirmController.text == _passwordController.text;

  void _submit() {
    setState(
      () => _confirmError = _confirmController.text != _passwordController.text
          ? 'Passwords do not match'
          : null,
    );
    if (!_canSubmit) return;
    widget.onReset(_passwordController.text);
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
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 8, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Set a new password',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 24),
                    AuthTextField(
                      label: 'New Password',
                      controller: _passwordController,
                      obscureText: _obscure,
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
                      label: 'Confirm New Password',
                      controller: _confirmController,
                      obscureText: true,
                      errorText: _confirmError,
                      onChanged: (_) => setState(() => _confirmError = null),
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
                      label: 'Reset Password',
                      loading: widget.loading,
                      onPressed: _canSubmit && !widget.loading ? _submit : null,
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
