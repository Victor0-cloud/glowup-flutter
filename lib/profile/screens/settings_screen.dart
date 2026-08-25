import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../coach/widgets/settings_widgets.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/profile_models.dart';
import '../state/profile_controller.dart';

/// Settings. Preferences/Notifications toggles read and write the exact
/// same [AppSettings] the Notifications screen and Privacy & Data use —
/// one shared store, never a duplicated one. Theme and Language are
/// stored real preferences, but this app only actually has one theme
/// (dark) and one language (English) implemented today, so both are
/// disclosed as such rather than offering options with no real effect.
class ProfileSettingsScreen extends ConsumerWidget {
  const ProfileSettingsScreen({super.key, this.onBack, this.onHelp});

  final VoidCallback? onBack;
  final VoidCallback? onHelp;

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
              title: 'Settings',
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
                data: (profileState) {
                  final settings = profileState.settings;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PREFERENCES',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlowCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _SelectorRow(
                                label: 'Units',
                                value: settings.units.label,
                                onTap: () => controller.updateSettings(
                                  settings.copyWith(
                                    units: settings.units == AppUnits.imperial
                                        ? AppUnits.metric
                                        : AppUnits.imperial,
                                  ),
                                ),
                              ),
                              const _Sep(),
                              const _StaticRow(label: 'Theme', value: 'Dark'),
                              const _Sep(),
                              const _StaticRow(
                                label: 'Language',
                                value: 'English',
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'NOTIFICATIONS',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ToggleRow(
                          label: 'Push Notifications',
                          value: settings.pushNotificationsEnabled,
                          onChanged: (v) => controller.updateSettings(
                            settings.copyWith(pushNotificationsEnabled: v),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'MORE',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GlowCard(
                          padding: EdgeInsets.zero,
                          child: _LinkRow(
                            label: 'Help Center',
                            onTap: onHelp,
                            isLast: true,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      value: value,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  value,
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StaticRow extends StatelessWidget {
  const _StaticRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });
  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(value, style: AppTextStyles.caption.copyWith(fontSize: 13)),
        ],
      ),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.label,
    required this.onTap,
    this.isLast = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
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
