import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../../core/widgets/sub_screen_header.dart';

/// AU04 Check Your Email — real Supabase resend + a truthful
/// "I've verified my email" recheck (never marks verified locally).
/// "Open Gmail" only appears/launches where a mail app is actually
/// reachable; otherwise a generic "Open email app" fallback is shown.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({
    super.key,
    this.onBack,
    required this.email,
    required this.onResend,
    required this.onIveVerified,
    this.resending = false,
    this.checking = false,
    this.notYetVerified = false,
  });

  final VoidCallback? onBack;
  final String email;
  final VoidCallback onResend;
  final VoidCallback onIveVerified;
  final bool resending;
  final bool checking;

  /// Set true after a real recheck against Supabase came back still
  /// unverified — an honest "not yet" message, never silently ignored.
  final bool notYetVerified;

  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  static const _cooldown = Duration(seconds: 45);
  int _secondsLeft = _cooldown.inSeconds;
  Timer? _timer;

  /// mm:ss, matching AU04's approved "(00:45)" countdown display exactly.
  static String _formatCooldown(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  void _startCooldown() {
    _timer?.cancel();
    setState(() => _secondsLeft = _cooldown.inSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openMailApp() async {
    final gmail = Uri.parse('googlegmail://');
    if (await canLaunchUrl(gmail)) {
      await launchUrl(gmail);
      return;
    }
    final mailto = Uri.parse('mailto:');
    if (await canLaunchUrl(mailto)) {
      await launchUrl(mailto);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canResend = _secondsLeft == 0 && !widget.resending;
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
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: AppColors.purple.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.mail_outline,
                        size: 48,
                        color: AppColors.purple,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Check your email',
                      style: AppTextStyles.screenTitle.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitleLg,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.email,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.cardTitleLg.copyWith(fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tap the link in the email to verify your account.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.subtitle,
                    ),
                    if (widget.notYetVerified) ...[
                      const SizedBox(height: 16),
                      Text(
                        "Not verified yet — check your inbox and tap the link, then try again.",
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.ctaStart,
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _openMailApp,
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.cardBorder),
                          shape: const StadiumBorder(),
                        ),
                        icon: const Icon(
                          Icons.email_outlined,
                          color: Colors.white,
                          size: 20,
                        ),
                        label: Text(
                          'Open email app',
                          style: AppTextStyles.buttonLabel.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    GradientPillButton(
                      label: "I've verified my email",
                      loading: widget.checking,
                      onPressed: widget.checking ? null : widget.onIveVerified,
                    ),
                    const SizedBox(height: 20),
                    Semantics(
                      button: true,
                      label: 'Resend email',
                      child: InkWell(
                        onTap: canResend
                            ? () {
                                widget.onResend();
                                _startCooldown();
                              }
                            : null,
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 44),
                          alignment: Alignment.center,
                          child: Text(
                            canResend
                                ? 'Resend email'
                                : 'Resend email (${_formatCooldown(_secondsLeft)})',
                            style: AppTextStyles.captionBold.copyWith(
                              color: canResend
                                  ? AppColors.gold
                                  : AppColors.textSecondary,
                              fontSize: 14,
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
