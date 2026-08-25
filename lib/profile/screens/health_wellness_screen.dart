import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../onboarding/models/onboarding_profile.dart';
import '../../onboarding/state/onboarding_controller.dart';
import '../models/profile_models.dart';
import '../state/profile_controller.dart';

/// Health & Wellness Profile — a read-only summary of real onboarding
/// (activity level, schedule) and Edit-Profile (gender/height/weight)
/// data, with a link to change the editable fields. Never fabricates a
/// value that hasn't actually been set.
class HealthWellnessScreen extends ConsumerWidget {
  const HealthWellnessScreen({super.key, this.onBack, this.onEditProfile});

  final VoidCallback? onBack;
  final VoidCallback? onEditProfile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboarding = ref.watch(onboardingControllerProvider);
    final profileAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Health & Wellness Profile',
              subtitle: 'Activity level, body and lifestyle',
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
                  final details = profileState.details;
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        GlowCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _InfoRow(
                                label: 'Activity level',
                                value: onboarding.fitnessLevel?.label,
                              ),
                              const _Sep(),
                              _InfoRow(
                                label: 'Typical schedule',
                                value: onboarding.scheduleWindow?.label,
                              ),
                              const _Sep(),
                              _InfoRow(
                                label: 'Gender',
                                value: details.gender?.label,
                              ),
                              const _Sep(),
                              _InfoRow(
                                label: 'Height',
                                value: details.heightCm == null
                                    ? null
                                    : '${details.heightCm!.toStringAsFixed(0)} cm',
                              ),
                              const _Sep(),
                              _InfoRow(
                                label: 'Weight',
                                value: details.weightKg == null
                                    ? null
                                    : '${details.weightKg!.toStringAsFixed(0)} kg',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: 'Edit Profile',
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: onEditProfile,
                              child: Container(
                                constraints: const BoxConstraints(
                                  minHeight: 44,
                                ),
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Edit in Profile →',
                                  style: AppTextStyles.captionBold.copyWith(
                                    fontSize: 14,
                                    color: AppColors.purple,
                                  ),
                                ),
                              ),
                            ),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
        ),
        Text(
          value ?? 'Not set',
          style: AppTextStyles.cardTitle.copyWith(
            fontSize: 14,
            color: value == null ? AppColors.textSecondary : Colors.white,
          ),
        ),
      ],
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Container(height: 1, color: AppColors.cardBorder),
  );
}
