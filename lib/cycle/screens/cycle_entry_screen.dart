import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../state/cycle_controller.dart';
import 'cycle_awareness_screen.dart';
import 'cycle_home_screen.dart';

/// The real `/cycle` entry point — branches to PC01 Cycle Awareness (never
/// set up, never declined) or PC03 Cycle Home (tracking enabled), based on
/// real stored [CycleSettings], never a route-time guess.
class CycleEntryScreen extends ConsumerWidget {
  const CycleEntryScreen({
    super.key,
    this.onBack,
    this.onSetUp,
    this.onSettings,
    this.onLogPeriod,
    this.onDailyCheckIn,
    this.onCalendar,
    this.onInsights,
  });

  final VoidCallback? onBack;
  final VoidCallback? onSetUp;
  final VoidCallback? onSettings;
  final VoidCallback? onLogPeriod;
  final VoidCallback? onDailyCheckIn;
  final VoidCallback? onCalendar;
  final VoidCallback? onInsights;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cycleAsync = ref.watch(cycleControllerProvider);

    return cycleAsync.when(
      loading: () => Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: Column(
            children: [
              SubScreenHeader(
                title: 'Period & Cycle',
                onBack: onBack ?? () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.purple),
                ),
              ),
            ],
          ),
        ),
      ),
      error: (e, st) => Scaffold(
        backgroundColor: Colors.transparent,
        body: GradientBackground(
          child: Column(
            children: [
              SubScreenHeader(
                title: 'Period & Cycle',
                onBack: onBack ?? () => Navigator.maybePop(context),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    "Couldn't load Period & Cycle.",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      data: (state) {
        final settings = state.settings;
        if (!settings.trackingEnabled) {
          // Shown whether tracking was never considered or was explicitly
          // declined ("Not applicable to me") — declining never force-shows
          // Cycle Home, it just means this screen doesn't nag with a modal.
          return CycleAwarenessScreen(
            onBack: onBack,
            onSetUp: onSetUp,
            onDismissed: onBack,
          );
        }
        return CycleHomeScreen(
          onBack: onBack,
          onSettings: onSettings,
          onLogPeriod: onLogPeriod,
          onDailyCheckIn: onDailyCheckIn,
          onCalendar: onCalendar,
          onInsights: onInsights,
        );
      },
    );
  }
}
