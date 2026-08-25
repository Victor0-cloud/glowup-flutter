import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../auth/state/auth_controller.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../state/profile_controller.dart';

/// Help & Support. No external support URL/email/ticketing system exists
/// anywhere in this app — every informational row here is honestly
/// disabled/"coming soon" rather than linking to a fabricated endpoint.
/// Log Out signs out of the real Supabase session (when configured) and
/// clears local onboarding progress; it never touches Cycle/Water/Food/
/// Workout history, per the "never delete wellness history on logout"
/// rule. Delete Account additionally wipes all local data, since this app
/// still has no server-side account deletion of its own.
class HelpSupportScreen extends ConsumerWidget {
  const HelpSupportScreen({super.key, this.onBack, this.onLoggedOut});

  final VoidCallback? onBack;
  final VoidCallback? onLoggedOut;

  static const _comingSoon = [
    ('Help Center', Icons.help_outline),
    ('Contact Support', Icons.mail_outline),
    ('Report a Problem', Icons.flag_outlined),
    ('Suggest a Feature', Icons.lightbulb_outline),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Help & Support',
              subtitle: 'We\'re here to help',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GlowCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (var i = 0; i < _comingSoon.length; i++) ...[
                            if (i > 0) const _Sep(),
                            _InfoRow(
                              icon: _comingSoon[i].$2,
                              label: _comingSoon[i].$1,
                            ),
                          ],
                          const _Sep(),
                          const _AboutRow(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Semantics(
                      button: true,
                      label: 'Log Out',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmLogOut(context, ref),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              'Log Out',
                              style: AppTextStyles.captionBold.copyWith(
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Semantics(
                      button: true,
                      label: 'Delete Account',
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _confirmDeleteAccount(context, ref),
                          child: Container(
                            width: double.infinity,
                            constraints: const BoxConstraints(minHeight: 48),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0x33FF5E97),
                              ),
                            ),
                            child: Text(
                              'Delete Account',
                              style: AppTextStyles.captionBold.copyWith(
                                fontSize: 15,
                                color: AppColors.ctaStart,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (kDebugMode) ...[
                      const SizedBox(height: 24),
                      Semantics(
                        button: true,
                        label: 'Reset Test State (Dev Only)',
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _confirmDevReset(context, ref),
                            child: Container(
                              width: double.infinity,
                              constraints: const BoxConstraints(minHeight: 48),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.5),
                                ),
                              ),
                              child: Text(
                                'Reset Test State (Dev Only)',
                                style: AppTextStyles.captionBold.copyWith(
                                  fontSize: 15,
                                  color: AppColors.gold,
                                ),
                              ),
                            ),
                          ),
                        ),
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

  /// Debug-only (see [kDebugMode] guard above it is built behind): signs
  /// out and clears just the local onboarding/profile-setup state needed
  /// to re-run the fresh-signup flow from AU01. Never available in a
  /// release build, never deletes the account, never touches wellness
  /// history (cycle/water/food/workout) or any other module's local data.
  Future<void> _confirmDevReset(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text(
          'Reset test state?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Dev only — signs out and clears local onboarding/profile-setup '
          'progress so you can re-test the fresh sign-up flow from the '
          'Welcome screen. Your account and any saved wellness history stay '
          'intact.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      await ref
          .read(profileControllerProvider.notifier)
          .resetOnboardingTestState();
      ref.read(onboardingControllerProvider.notifier).reset();
      onLoggedOut?.call();
    }
  }

  Future<void> _confirmLogOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text('Log out?', style: TextStyle(color: Colors.white)),
        content: Text(
          "You'll be signed out and returned to the Glow Up welcome screen. Your workout, cycle, water and food history stay on this device.",
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
      ref.read(onboardingControllerProvider.notifier).reset();
      onLoggedOut?.call();
    }
  }

  Future<void> _confirmDeleteAccount(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text(
          'Delete account?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This app has no server-side account — this permanently deletes everything stored on this device. This cannot be undone.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(profileControllerProvider.notifier).clearAllLocalData();
      await ref.read(authControllerProvider.notifier).signOut();
      ref.read(onboardingControllerProvider.notifier).reset();
      onLoggedOut?.call();
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, not available yet',
      child: Opacity(
        opacity: 0.5,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(icon, size: 20, color: AppColors.textSecondary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                'Coming soon',
                style: AppTextStyles.caption.copyWith(fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 20, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'About Glow Up',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: AppColors.cardBorder),
  );
}
