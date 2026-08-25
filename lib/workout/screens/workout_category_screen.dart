import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../routines/theme/routines_variant_config.dart';
import '../data/exercise_catalog.dart';
import '../data/workout_catalog.dart';
import '../models/exercise_models.dart';
import '../models/workout_models.dart';

/// Lists the real routines within one Exercise Library category — the
/// screen a category card on 31_workout_categories opens into, since each
/// of the 7 categories now has one or more real routines built from
/// EX001-EX052 (`workout_catalog.dart`), not a single fixed workout.
class WorkoutCategoryScreen extends StatelessWidget {
  const WorkoutCategoryScreen({
    super.key,
    required this.category,
    required this.onOpenWorkout,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onCoach,
    required this.onProfile,
  });

  final ExerciseCategory category;
  final ValueChanged<String> onOpenWorkout;
  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    final routines = workoutsForCategory(category);
    final exerciseCount = exercisesByPrimaryCategory(category).length;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubScreenHeader(
                      title: '${category.emoji} ${category.label}',
                      subtitle:
                          '$exerciseCount exercises · ${routines.length} routine${routines.length == 1 ? '' : 's'}',
                      onBack: onBack,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          for (var i = 0; i < routines.length; i++) ...[
                            _RoutineCard(
                              workout: routines[i],
                              onTap: () => onOpenWorkout(routines[i].id),
                            ),
                            if (i != routines.length - 1)
                              const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            BottomNavBar(
              active: AppNavTab.today,
              activeAccent: RoutinesVariantConfig.navActiveColor,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    onToday();
                  case AppNavTab.routines:
                    onRoutines();
                  case AppNavTab.coach:
                    onCoach();
                  case AppNavTab.profile:
                    onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _RoutineCard extends StatelessWidget {
  const _RoutineCard({required this.workout, required this.onTap});

  final Workout workout;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.cardStart, AppColors.cardEnd],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                workout.title,
                style: AppTextStyles.cardTitle.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                workout.subtitle,
                style: AppTextStyles.subtitle.copyWith(fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill(text: '${workout.totalMinutes} min'),
                  _Pill(text: workout.difficulty.label),
                  _Pill(text: '${workout.exercises.length} exercises'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF181436),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Text(text, style: AppTextStyles.caption.copyWith(fontSize: 11)),
    );
  }
}
