import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/tod/tod_period.dart';
import '../../core/widgets/ambient_glow.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/dev_tod_picker.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../onboarding/models/onboarding_profile.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../../workout/state/workout_history_controller.dart';
import '../state/profile_controller.dart';
import '../theme/profile_variant_config.dart';

/// My Profile (approved design family "90 Profile"). One screen, driven
/// entirely by the shared [currentTodPeriodProvider] — never four
/// duplicated implementations. Every value shown (name, completion,
/// stats) comes from real stored data or an honest unavailable state;
/// this screen never calls an AI provider.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({
    super.key,
    this.onToday,
    this.onRoutines,
    this.onCoach,
    this.onSettings,
    this.onEditProfile,
    this.onGoals,
    this.onHealth,
    this.onAiPersonalization,
    this.onConnectedApps,
    this.onNotifications,
    this.onPrivacy,
    this.onSubscription,
    this.onManageData,
  });

  final VoidCallback? onToday;
  final VoidCallback? onRoutines;
  final VoidCallback? onCoach;
  final VoidCallback? onSettings;
  final VoidCallback? onEditProfile;
  final VoidCallback? onGoals;
  final VoidCallback? onHealth;
  final VoidCallback? onAiPersonalization;
  final VoidCallback? onConnectedApps;
  final VoidCallback? onNotifications;
  final VoidCallback? onPrivacy;
  final VoidCallback? onSubscription;
  final VoidCallback? onManageData;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final period = ref.watch(currentTodPeriodProvider);
    final variant = ProfileVariantConfig.byPeriod[period]!;
    final onboarding = ref.watch(onboardingControllerProvider);
    final profileAsync = ref.watch(profileControllerProvider);
    final workoutHistory =
        ref.watch(workoutHistoryControllerProvider).valueOrNull ?? const [];

    final realName = onboarding.firstName?.trim().isNotEmpty == true
        ? onboarding.firstName!.trim()
        : null;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned(
                    top: -60,
                    right: -40,
                    child: AmbientGlow(color: variant.glow, size: 260),
                  ),
                  SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (kDebugMode) ...[
                          const DevTodPicker(),
                          const SizedBox(height: 12),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      'My Profile',
                                      style: AppTextStyles.screenTitle.copyWith(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '✨',
                                    style: TextStyle(
                                      fontSize: 22,
                                      color: variant.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Semantics(
                              button: true,
                              label: 'Settings',
                              child: Material(
                                color: Colors.transparent,
                                shape: CircleBorder(
                                  side: BorderSide(
                                    color: variant.accent.withValues(
                                      alpha: 0.5,
                                    ),
                                  ),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: onSettings,
                                  child: SizedBox(
                                    width: 44,
                                    height: 44,
                                    child: Center(
                                      child: AppIcon(
                                        'settings-gear',
                                        size: 22,
                                        color: variant.accent,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        profileAsync.when(
                          loading: () => const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: AppColors.purple,
                              ),
                            ),
                          ),
                          error: (e, st) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text(
                              "Couldn't load your profile. Please restart the app.",
                              style: AppTextStyles.subtitle,
                            ),
                          ),
                          data: (profileState) => _IdentityCard(
                            accent: variant.accent,
                            name: realName ?? profileState.details.name,
                            tagline: onboarding.goals.isNotEmpty
                                ? 'Focused on ${onboarding.goals.first.label}'
                                : null,
                            completionPercent: profileState.completionPercent,
                            workoutsCount: workoutHistory.length,
                            onEditProfile: onEditProfile,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Your Glow Up',
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlowCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _ProfileRow(
                                icon: Icons.track_changes_outlined,
                                title: 'Goals & Preferences',
                                subtitle: 'Strength, sleep and stress goals',
                                accent: variant.accent,
                                onTap: onGoals,
                              ),
                              const _RowDivider(),
                              _ProfileRow(
                                icon: Icons.person_outline,
                                title: 'Health & Wellness Profile',
                                subtitle: 'Activity level, body and lifestyle',
                                accent: variant.accent,
                                onTap: onHealth,
                              ),
                              const _RowDivider(),
                              _ProfileRow(
                                icon: Icons.auto_awesome_outlined,
                                title: 'AI Personalization',
                                subtitle: 'Coach memory and adaptive settings',
                                accent: variant.accent,
                                onTap: onAiPersonalization,
                              ),
                              const _RowDivider(),
                              _ProfileRow(
                                icon: Icons.link,
                                title: 'Connected Apps',
                                subtitle: 'Health data and device connections',
                                accent: variant.accent,
                                onTap: onConnectedApps,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Account',
                          style: AppTextStyles.screenTitle.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GlowCard(
                          padding: EdgeInsets.zero,
                          child: Column(
                            children: [
                              _ProfileRow(
                                icon: Icons.notifications_outlined,
                                title: 'Notifications',
                                accent: variant.accent,
                                onTap: onNotifications,
                              ),
                              const _RowDivider(),
                              _ProfileRow(
                                icon: Icons.verified_user_outlined,
                                title: 'Privacy & Data',
                                accent: variant.accent,
                                onTap: onPrivacy,
                              ),
                              const _RowDivider(),
                              _ProfileRow(
                                icon: Icons.credit_card_outlined,
                                title: 'Subscription',
                                accent: variant.accent,
                                onTap: onSubscription,
                              ),
                              const _RowDivider(),
                              _ProfileRow(
                                icon: Icons.settings_outlined,
                                title: 'Settings',
                                accent: variant.accent,
                                onTap: onSettings,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _WellnessDataCard(
                          accent: variant.accent,
                          onManageData: onManageData,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            BottomNavBar(
              active: AppNavTab.profile,
              activeAccent: variant.accent,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    onToday?.call();
                  case AppNavTab.routines:
                    onRoutines?.call();
                  case AppNavTab.coach:
                    onCoach?.call();
                  case AppNavTab.profile:
                    break;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.accent,
    required this.name,
    required this.tagline,
    required this.completionPercent,
    required this.workoutsCount,
    required this.onEditProfile,
  });

  final Color accent;
  final String? name;
  final String? tagline;
  final int completionPercent;
  final int workoutsCount;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'Add your name';
    final initial = (name != null && name!.isNotEmpty)
        ? name![0].toUpperCase()
        : '?';

    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: Text(
                  initial,
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 22,
                    color: accent,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: AppTextStyles.cardTitleLg.copyWith(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (tagline != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        tagline!,
                        style: AppTextStyles.subtitle.copyWith(fontSize: 13),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Flexible(
                child: Semantics(
                  button: true,
                  label: 'Edit Profile',
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: onEditProfile,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: accent),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_outlined, size: 15, color: accent),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Edit Profile',
                                style: AppTextStyles.captionBold.copyWith(
                                  fontSize: 13,
                                  color: accent,
                                ),
                                overflow: TextOverflow.ellipsis,
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
          const SizedBox(height: 18),
          Row(
            children: [
              Text(
                'Profile ',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
              Flexible(
                child: Text(
                  '$completionPercent% complete',
                  style: AppTextStyles.captionBold.copyWith(
                    fontSize: 14,
                    color: accent,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Semantics(
            label: 'Profile completion',
            value: '$completionPercent percent',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: completionPercent / 100,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation(accent),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(height: 1, color: AppColors.cardBorder),
          const SizedBox(height: 16),
          Row(
            children: [
              _StatItem(
                icon: 'flame',
                value: '—',
                label: 'day streak',
                accent: accent,
                unavailable: true,
              ),
              _StatItem(
                icon: 'dumbbell',
                value: '$workoutsCount',
                label: 'workouts',
                accent: accent,
              ),
              _StatItem(
                icon: 'star',
                value: '—',
                label: 'Glow Score',
                accent: accent,
                unavailable: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.accent,
    this.unavailable = false,
  });

  final String icon;
  final String value;
  final String label;
  final Color accent;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        label: unavailable ? '$label not yet available' : '$value $label',
        child: Column(
          children: [
            AppIcon(
              icon,
              size: 20,
              color: unavailable ? AppColors.textSecondary : accent,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: unavailable ? AppColors.textSecondary : Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.accent,
    this.onTap,
    this.isLast = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color accent;
  final VoidCallback? onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: subtitle == null ? title : '$title, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: accent),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
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

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: AppColors.cardBorder),
  );
}

class _WellnessDataCard extends StatelessWidget {
  const _WellnessDataCard({required this.accent, required this.onManageData});

  final Color accent;
  final VoidCallback? onManageData;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      onTap: onManageData,
      child: Row(
        children: [
          Icon(Icons.shield_outlined, size: 26, color: accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your wellness data stays under your control.',
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Manage data',
                  style: AppTextStyles.captionBold.copyWith(
                    fontSize: 13,
                    color: accent,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, size: 20, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}
