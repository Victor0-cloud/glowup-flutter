import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 06_personal_info (node 368:267). Collects First Name / Date of Birth —
/// its own Figma annotation also mentions height, weight & gender, but
/// Glow Up is a women-only app, so no gender/model selector is collected
/// or offered anywhere in onboarding.
class PersonalInfoScreen extends ConsumerStatefulWidget {
  const PersonalInfoScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  ConsumerState<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends ConsumerState<PersonalInfoScreen> {
  late final TextEditingController _nameController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: ref.read(onboardingControllerProvider).firstName ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(onboardingControllerProvider);
    final controller = ref.read(onboardingControllerProvider.notifier);
    final canContinue =
        _nameController.text.trim().isNotEmpty && profile.dateOfBirth != null;

    // Never fabricates a birth date: typing a name alone only ever updates
    // the name (setFirstName), and dateOfBirth is only ever set from a real
    // date the user actually picked.
    void commitName() {
      controller.setFirstName(_nameController.text.trim());
    }

    void commitDob(DateTime picked) {
      controller.setPersonalInfo(
        firstName: _nameController.text.trim(),
        dateOfBirth: picked,
      );
    }

    return OnboardingScaffold(
      title: 'Personal Info',
      subtitle: "Let's personalize your experience",
      progressIndex: 4,
      primaryLabel: 'Next',
      primaryEnabled: canContinue,
      onPrimaryPressed: canContinue ? widget.onNext : null,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('First Name', style: AppTextStyles.fieldLabel),
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
                controller: _nameController,
                style: AppTextStyles.fieldValue,
                onChanged: (_) => setState(commitName),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  hintText: 'e.g., Alex',
                  hintStyle: AppTextStyles.fieldPlaceholder,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Date of Birth', style: AppTextStyles.fieldLabel),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(AppRadii.sm),
              onTap: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: profile.dateOfBirth ?? DateTime(now.year - 20),
                  firstDate: DateTime(1930),
                  lastDate: now,
                );
                if (picked != null) commitDob(picked);
              },
              child: Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.cardStart, AppColors.cardEnd],
                  ),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      profile.dateOfBirth == null
                          ? 'Select your birth date'
                          : _formatDate(profile.dateOfBirth!),
                      style: profile.dateOfBirth == null
                          ? AppTextStyles.fieldPlaceholder
                          : AppTextStyles.fieldValue,
                    ),
                    const AppIcon(
                      'calendar',
                      size: 18,
                      color: AppColors.textSecondary,
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

  String _formatDate(DateTime d) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
