import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/tod/tod_period.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../../routing/app_router.dart';
import '../../workout/data/exercise_catalog.dart';
import '../../workout/data/workout_catalog.dart';
import '../../workout/models/exercise_models.dart';
import '../../workout/widgets/workout_widgets.dart';
import '../state/routines_controller.dart';
import '../theme/routines_variant_config.dart';
import '../widgets/routine_card.dart';

/// Covers 22a-22d (368:1618/1697/1776/1855) as one reusable screen, same
/// pattern as Today — which variant renders is resolved from
/// [currentTodPeriodProvider], not four separate implementations.
class RoutinesHubScreen extends ConsumerStatefulWidget {
  const RoutinesHubScreen({
    super.key,
    required this.onOpenRoutine,
    required this.onCreateRoutine,
    required this.onOpenCalendar,
    required this.onToday,
    required this.onCoach,
    required this.onProfile,
  });

  final void Function(String routineId) onOpenRoutine;
  final VoidCallback onCreateRoutine;
  final VoidCallback onOpenCalendar;
  final VoidCallback onToday;
  final VoidCallback onCoach;
  final VoidCallback onProfile;

  @override
  ConsumerState<RoutinesHubScreen> createState() => _RoutinesHubScreenState();
}

class _RoutinesHubScreenState extends ConsumerState<RoutinesHubScreen> {
  bool _showDiscover = false;
  final _discoverSearchController = TextEditingController();
  String _discoverQuery = '';

  @override
  void dispose() {
    _discoverSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final period = ref.watch(currentTodPeriodProvider);
    final variant = RoutinesVariantConfig.byPeriod[period]!;
    final routines = ref.watch(
      routinesControllerProvider.select(
        (all) => all.where((r) => r.period == period).toList(),
      ),
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Stack(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Routines ${variant.emoji}',
                        style: AppTextStyles.screenTitle.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Semantics(
                        button: true,
                        label: 'Routine calendar',
                        child: Material(
                          color: Colors.transparent,
                          shape: const CircleBorder(),
                          clipBehavior: Clip.antiAlias,
                          child: InkWell(
                            onTap: widget.onOpenCalendar,
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.07),
                                shape: BoxShape.circle,
                              ),
                              child: const Center(
                                child: AppIcon(
                                  'calendar',
                                  size: 18,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      _RoutinesTab(
                        label: 'My Routines',
                        selected: !_showDiscover,
                        accent: variant.accent,
                        onTap: () => setState(() => _showDiscover = false),
                      ),
                      const SizedBox(width: 16),
                      _RoutinesTab(
                        label: 'Discover',
                        selected: _showDiscover,
                        accent: variant.accent,
                        onTap: () => setState(() => _showDiscover = true),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _showDiscover
                      ? _DiscoverTab(
                          searchController: _discoverSearchController,
                          query: _discoverQuery,
                          onQueryChanged: (v) =>
                              setState(() => _discoverQuery = v),
                          onOpenCategory: (category) => context.push(
                            AppRoutes.workoutCategory(category.name),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
                          child: Column(
                            children: [
                              for (final r in routines) ...[
                                RoutineCard(
                                  routine: r,
                                  accent: variant.accent,
                                  onTap: () => widget.onOpenRoutine(r.id),
                                ),
                                const SizedBox(height: 12),
                              ],
                              if (routines.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 40),
                                  child: Text(
                                    'No routines yet for this time of day.',
                                    style: AppTextStyles.subtitle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                BottomNavBar(
                  active: AppNavTab.routines,
                  activeAccent: RoutinesVariantConfig.navActiveColor,
                  onTabSelected: (tab) {
                    switch (tab) {
                      case AppNavTab.today:
                        widget.onToday();
                      case AppNavTab.routines:
                        break;
                      case AppNavTab.coach:
                        widget.onCoach();
                      case AppNavTab.profile:
                        widget.onProfile();
                    }
                  },
                ),
              ],
            ),
            if (!_showDiscover)
              Positioned(
                right: 23,
                bottom: 109,
                child: Semantics(
                  button: true,
                  label: 'Create routine',
                  child: Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: widget.onCreateRoutine,
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: variant.accent,
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x40000000),
                              blurRadius: 8,
                              offset: Offset(0, 8),
                            ),
                          ],
                        ),
                        child: const Center(
                          child: AppIcon(
                            'plus',
                            size: 24,
                            color: AppColors.onSelected,
                          ),
                        ),
                      ),
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

class _RoutinesTab extends StatelessWidget {
  const _RoutinesTab({
    required this.label,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? accent : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              fontFamily: AppTextStyles.cardTitle.fontFamily,
            ),
          ),
        ),
      ),
    );
  }
}

/// The real "Discover" tab — browses the same live workout catalog as the
/// Today → Workout hub (`WorkoutHubScreen`), not a second/duplicate data
/// source: real category tiles with real workout/exercise counts, tapping
/// through to the exact same category-browse route
/// (`AppRoutes.workoutCategory`). This is deliberately reused rather than
/// reimplemented — "My Routines" (the other tab) is the user's own saved
/// routines; "Discover" is how they find something new to add.
class _DiscoverTab extends StatelessWidget {
  const _DiscoverTab({
    required this.searchController,
    required this.query,
    required this.onQueryChanged,
    required this.onOpenCategory,
  });

  final TextEditingController searchController;
  final String query;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<ExerciseCategory> onOpenCategory;

  @override
  Widget build(BuildContext context) {
    final categories = ExerciseCategory.values
        .where((c) => c.label.toLowerCase().contains(query.toLowerCase()))
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 96),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
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
                    controller: searchController,
                    onChanged: onQueryChanged,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search workouts...',
                      hintStyle: AppTextStyles.subtitle.copyWith(fontSize: 14),
                      border: InputBorder.none,
                      isCollapsed: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < categories.length; i++) ...[
            CategoryCardTile(
              category: categories[i],
              workoutCount: workoutsForCategory(categories[i]).length,
              exerciseCount: exercisesByPrimaryCategory(categories[i]).length,
              onTap: () => onOpenCategory(categories[i]),
            ),
            if (i != categories.length - 1) const SizedBox(height: 12),
          ],
          if (categories.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(
                'No workouts match "$query".',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
