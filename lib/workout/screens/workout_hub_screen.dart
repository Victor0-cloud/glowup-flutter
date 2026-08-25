import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../routines/theme/routines_variant_config.dart';
import '../data/exercise_catalog.dart';
import '../data/workout_catalog.dart';
import '../models/exercise_models.dart';
import '../widgets/workout_widgets.dart';

/// 31_workout_categories (368:2980). Browsing now uses the real 7-category
/// Exercise Library taxonomy (Core/Strength/Flexibility/Bedtime/Mobility/
/// Cardio/Recovery) instead of the original 6 discipline cards, so every
/// category opens routines built from real EX001-EX052 content — see
/// `workout_models.dart`'s doc comment for why.
class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({
    super.key,
    required this.onOpenCategory,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onCoach,
    required this.onProfile,
  });

  final ValueChanged<ExerciseCategory> onOpenCategory;
  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = ExerciseCategory.values
        .where((c) => c.label.toLowerCase().contains(_query.toLowerCase()))
        .toList();

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
                      title: 'Workouts',
                      subtitle: 'Choose your discipline',
                      onBack: widget.onBack,
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF181436),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: Row(
                          children: [
                            const AppIcon('search', size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _searchController,
                                onChanged: (v) => setState(() => _query = v),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search workouts, trainers...',
                                  hintStyle: AppTextStyles.subtitle.copyWith(
                                    fontSize: 14,
                                  ),
                                  border: InputBorder.none,
                                  isCollapsed: true,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          for (var i = 0; i < categories.length; i++) ...[
                            CategoryCardTile(
                              category: categories[i],
                              workoutCount: workoutsForCategory(
                                categories[i],
                              ).length,
                              exerciseCount: exercisesByPrimaryCategory(
                                categories[i],
                              ).length,
                              onTap: () => widget.onOpenCategory(categories[i]),
                            ),
                            if (i != categories.length - 1)
                              const SizedBox(height: 12),
                          ],
                          if (categories.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No workouts match "$_query".',
                                style: AppTextStyles.subtitle,
                                textAlign: TextAlign.center,
                              ),
                            ),
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
                    widget.onToday();
                  case AppNavTab.routines:
                    widget.onRoutines();
                  case AppNavTab.coach:
                    widget.onCoach();
                  case AppNavTab.profile:
                    widget.onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
