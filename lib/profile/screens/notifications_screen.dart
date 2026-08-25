import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../state/profile_controller.dart';

/// Notifications. No push/email delivery infrastructure exists in this
/// app — these are real, stored local preferences (same honesty standard
/// as onboarding's own `NotificationPrefs`), not a claim that
/// notifications are actively being sent. Email Notifications is omitted:
/// there is no verified email or sending capability anywhere in the app
/// to back it.
class ProfileNotificationsScreen extends ConsumerWidget {
  const ProfileNotificationsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileControllerProvider);
    final controller = ref.read(profileControllerProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Notifications',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: profileAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
                error: (e, st) => Center(
                  child: Text(
                    "Couldn't load this page.",
                    style: AppTextStyles.subtitle,
                  ),
                ),
                data: (profileState) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: Column(
                    children: [
                      ToggleRow(
                        label: 'Push Notifications',
                        value: profileState.settings.pushNotificationsEnabled,
                        onChanged: (v) => controller.updateSettings(
                          profileState.settings.copyWith(
                            pushNotificationsEnabled: v,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ToggleRow(
                        label: 'Reminders',
                        value: profileState.settings.remindersEnabled,
                        onChanged: (v) => controller.updateSettings(
                          profileState.settings.copyWith(remindersEnabled: v),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
