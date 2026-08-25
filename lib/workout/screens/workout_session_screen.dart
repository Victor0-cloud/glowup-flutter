import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/workout_models.dart';
import '../state/workout_controller.dart';
import 'workout_active_screen.dart';
import 'workout_complete_screen.dart';
import 'workout_get_ready_screen.dart';
import 'workout_rest_screen.dart';
import 'workout_summary_screen.dart';
import 'workout_up_next_screen.dart';

/// Hosts the entire 32b -> 32c -> 32d -> 32e -> ... -> 33a -> 33b session
/// as ONE route that switches on [WorkoutSessionState.phase] rather than
/// pushing a new route per exercise transition — there's no meaningful
/// "back stack" between poses in Figma's own flow (32c has no back
/// control at all), and this keeps session state trivially alive across
/// every phase change since it's the same provider, same widget subtree.
class WorkoutSessionScreen extends ConsumerStatefulWidget {
  const WorkoutSessionScreen({
    super.key,
    required this.onExitToHub,
    required this.onExitToToday,
  });

  final VoidCallback onExitToHub;
  final VoidCallback onExitToToday;

  @override
  ConsumerState<WorkoutSessionScreen> createState() =>
      _WorkoutSessionScreenState();
}

class _WorkoutSessionScreenState extends ConsumerState<WorkoutSessionScreen> {
  bool _showingSummary = false;
  WorkoutSessionResult? _capturedResult;

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(workoutSessionControllerProvider);
    final controller = ref.read(workoutSessionControllerProvider.notifier);

    if (session == null) {
      // Session already ended (e.g. "Back to Home"/"Done" already fired) —
      // avoid rendering a stale/empty screen while navigation completes.
      return const SizedBox.shrink();
    }

    if (session.phase == WorkoutPhase.complete && _showingSummary) {
      final result = _capturedResult ?? controller.buildResult();
      if (result == null) return const SizedBox.shrink();
      return WorkoutSummaryScreen(
        result: result,
        onBack: () => setState(() => _showingSummary = false),
        onDone: () {
          controller.endSession();
          widget.onExitToToday();
        },
      );
    }

    switch (session.phase) {
      case WorkoutPhase.getReady:
        return const WorkoutGetReadyScreen();
      case WorkoutPhase.active:
        return const WorkoutActiveScreen();
      case WorkoutPhase.resting:
        return const WorkoutRestScreen();
      case WorkoutPhase.upNext:
        return WorkoutUpNextScreen(
          onBack: () {
            controller.endSession();
            widget.onExitToHub();
          },
        );
      case WorkoutPhase.complete:
        return WorkoutCompleteScreen(
          onBackToHome: () {
            controller.endSession();
            widget.onExitToToday();
          },
          onViewSummary: () {
            _capturedResult = controller.buildResult();
            setState(() => _showingSummary = true);
          },
        );
    }
  }
}
