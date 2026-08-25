import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../workout/brain/workout_brain.dart';
import '../../workout/models/workout_completion_record.dart';
import '../../workout/models/workout_models.dart';
import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../../workout/state/exercise_feedback_events.dart';
import '../../workout/state/workout_history_controller.dart';
import '../../workout/widgets/ask_coach_sheet.dart';
import '../../workout/widgets/exercise_feedback_card.dart';
import '../../workout/widgets/exercise_reflection_card.dart';
import '../../workout/widgets/post_workout_feedback_card.dart';
import '../../workout/widgets/workout_widgets.dart' show WorkoutTimerRing;
import '../data/routine_player_registry.dart';
import '../models/exercise_definition.dart';
import '../models/routine_player_state.dart';
import '../state/routine_player_controller.dart';
import '../widgets/movement_display.dart';
import '../widgets/routine_player_scaffold.dart';

/// Starts a routine exactly once and then renders [RoutinePlayerScreen].
/// Uses `initState` (runs exactly once per widget lifetime) rather than a
/// `ref.read(...) == null` check inside a plain build method — that
/// pattern re-registers its post-frame callback on every rebuild that
/// happens before the first callback has actually fired (e.g. GoRouter's
/// own transition rebuild), starting the routine twice and orphaning the
/// first run's Timer.
class RoutinePlayerQaEntry extends ConsumerStatefulWidget {
  const RoutinePlayerQaEntry({
    super.key,
    required this.onExit,
    this.startExerciseId,
    this.routine,
    this.sourceWorkout,
  });
  final VoidCallback onExit;

  /// Which routine to start — null defaults to the 9-exercise Phase 1 QA
  /// routine ([kRoutinePlayerPhase1Qa] is a real, non-const list, so it
  /// can't be a literal default parameter value). Production flows (e.g.
  /// Core Crusher's real 7-exercise sequence) pass their own real routine,
  /// resolved through [routinePlayerExerciseById], instead of a
  /// second/duplicate player.
  final List<ExerciseDefinition>? routine;

  /// The originating [Workout] — null for the dev-only QA entry point.
  /// Threaded straight through to [RoutinePlayerController.startRoutine]
  /// so the completion summary/history save has the real routine name and
  /// static calorie estimate to work with.
  final Workout? sourceWorkout;

  /// QA-only convenience (e.g. `/dev/routine-player-qa?exercise=EX012`):
  /// jumps straight to the matching exercise (and every one after it in
  /// [routine]'s order) instead of waiting through the entire routine from
  /// its first exercise — manual visual review of a single newly added
  /// exercise otherwise means waiting several minutes through every prior
  /// exercise's full prepare+active+rest. Unknown/omitted id falls back to
  /// the full routine, unchanged from before this existed.
  final String? startExerciseId;

  @override
  ConsumerState<RoutinePlayerQaEntry> createState() =>
      _RoutinePlayerQaEntryState();
}

class _RoutinePlayerQaEntryState extends ConsumerState<RoutinePlayerQaEntry> {
  bool _precached = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final fullRoutine = widget.routine ?? kRoutinePlayerPhase1Qa;
      final startIndex = widget.startExerciseId == null
          ? -1
          : fullRoutine.indexWhere((e) => e.id == widget.startExerciseId);
      final routine = startIndex <= 0
          ? fullRoutine
          : fullRoutine.sublist(startIndex);
      ref
          .read(routinePlayerControllerProvider.notifier)
          .startRoutine(routine, sourceWorkout: widget.sourceWorkout);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Precache every real frame asset used by the routine (Section 13) so
    // nothing flashes/blanks the first time ACTIVE reaches it — matters
    // most for Lunges' 12-frame animation, which would otherwise decode
    // each new frame mid-loop.
    if (_precached) return;
    _precached = true;
    for (final exercise in widget.routine ?? kRoutinePlayerPhase1Qa) {
      final assets = <String>{
        for (final pose in exercise.poses)
          if (pose.approvedAsset != null) pose.approvedAsset!,
        if (exercise.bilateralFrames case final bilateral?) ...[
          for (final pose in bilateral.left)
            if (pose.approvedAsset != null) pose.approvedAsset!,
          for (final pose in bilateral.right)
            if (pose.approvedAsset != null) pose.approvedAsset!,
        ],
      };
      for (final asset in assets) {
        precacheImage(AssetImage(asset), context);
      }
    }
  }

  @override
  Widget build(BuildContext context) =>
      RoutinePlayerScreen(onExit: widget.onExit);
}

/// Single phase router for the whole RoutinePlayer engine — every screen
/// below reads only from [RoutinePlayerState]; none resolves exercise
/// imagery, timing, or voice state on its own (Section 16/23).
class RoutinePlayerScreen extends ConsumerWidget {
  const RoutinePlayerScreen({super.key, required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(routinePlayerControllerProvider);
    if (state == null) return RoutinePlayerScaffold(body: Container());
    return switch (state.phase) {
      RoutinePlayerPhase.loading => const RoutinePlayerScaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      RoutinePlayerPhase.error => _ErrorView(state: state, onExit: onExit),
      RoutinePlayerPhase.prepare => _PrepareView(state: state),
      RoutinePlayerPhase.countdown => _CountdownView(state: state),
      RoutinePlayerPhase.active ||
      RoutinePlayerPhase.paused => _ActiveView(state: state, onExit: onExit),
      RoutinePlayerPhase.rest ||
      RoutinePlayerPhase.restPaused => _RestView(state: state),
      RoutinePlayerPhase.complete => _CompleteView(
        state: state,
        onExit: onExit,
      ),
      RoutinePlayerPhase.exitConfirmation => _ExitConfirmationView(
        state: state,
        onExit: onExit,
      ),
    };
  }
}

class _VoiceModeChips extends ConsumerWidget {
  const _VoiceModeChips({required this.current});
  final VoiceMode current;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(routinePlayerControllerProvider.notifier);
    Widget chip(VoiceMode mode, String label) {
      final selected = current == mode;
      return Material(
        color: selected ? AppColors.gold : const Color(0xFF181436),
        borderRadius: BorderRadius.circular(100),
        child: InkWell(
          borderRadius: BorderRadius.circular(100),
          onTap: () => controller.setVoiceMode(mode),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                fontSize: 11,
                color: selected ? const Color(0xFF0A0B1E) : Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        chip(VoiceMode.coachOn, 'COACH ON'),
        const SizedBox(width: 8),
        chip(VoiceMode.cuesOnly, 'CUES ONLY'),
        const SizedBox(width: 8),
        chip(VoiceMode.silent, 'SILENT'),
      ],
    );
  }
}

class _PrepareView extends ConsumerWidget {
  const _PrepareView({required this.state});
  final RoutinePlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(routinePlayerControllerProvider.notifier);
    final ex = state.currentExercise;
    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EXERCISE ${state.exerciseIndex + 1} OF ${state.routine.length}',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.gold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              ex.displayName,
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            MovementDisplay(
              pose: ex.firstPose,
              orientation: ex.visualOrientation,
              aspectRatio: ex.visualAspectRatio,
              sizeBudget: 340,
            ),
            const SizedBox(height: 16),
            Text(
              ex.benefitShort,
              style: AppTextStyles.subtitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF181436),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GET INTO POSITION',
                    style: AppTextStyles.caption.copyWith(fontSize: 11),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    ex.voiceScript.setupInstruction,
                    style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              ex.reps != null
                  ? '${ex.reps} reps · ${ex.durationSeconds}s'
                  : '${ex.durationSeconds}s',
              style: AppTextStyles.caption.copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),
            _VoiceModeChips(current: state.voiceMode),
          ],
        ),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: controller.skipPrepare,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                "I'm Ready",
                style: TextStyle(
                  color: Color(0xFF0A0B1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownView extends StatelessWidget {
  const _CountdownView({required this.state});
  final RoutinePlayerState state;

  @override
  Widget build(BuildContext context) {
    final ex = state.currentExercise;
    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Text(
              ex.displayName,
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 40),
            WorkoutTimerRing(
              progress: (3 - state.countdownSecondsLeft) / 3,
              size: 180,
              strokeWidth: 10,
              child: Text(
                '${state.countdownSecondsLeft}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 80,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'GET READY',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActiveView extends ConsumerWidget {
  const _ActiveView({required this.state, required this.onExit});
  final RoutinePlayerState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(routinePlayerControllerProvider.notifier);
    final ex = state.currentExercise;
    final paused = state.phase == RoutinePlayerPhase.paused;
    final pose = currentPoseFor(
      ex,
      state.activeElapsedSeconds,
      frameDurationOverrideMs: state.debugFrameDurationMs,
    );

    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ex.displayName,
                    style: AppTextStyles.cardTitle.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Ask Coach about this exercise',
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => showAskCoachSheet(
                      context,
                      ref,
                      exercise: ex,
                      sessionId:
                          '${state.sourceWorkout?.id ?? 'qa-routine'}_${state.startedAt.millisecondsSinceEpoch}',
                    ),
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.chat_bubble_outline,
                        size: 20,
                        color: AppColors.gold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'EXERCISE ${state.exerciseIndex + 1} OF ${state.routine.length}',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.gold,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: state.activeProgress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.07),
                valueColor: const AlwaysStoppedAnimation(AppColors.gold),
              ),
            ),
            const SizedBox(height: 12),
            MovementDisplay(
              pose: pose,
              orientation: ex.visualOrientation,
              aspectRatio: ex.visualAspectRatio,
              sizeBudget: 420,
              crossfade: ex.crossfadeFrames,
            ),
            const SizedBox(height: 12),
            Text(
              'STEP ${pose.order} OF ${ex.poses.length} · ${pose.label}',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.gold,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              pose.instruction,
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              textAlign: TextAlign.center,
            ),
            if (paused) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Text(
                  'PAUSED',
                  style: AppTextStyles.captionBold.copyWith(fontSize: 12),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Center(
              child: WorkoutTimerRing(
                progress: state.activeProgress,
                size: 110,
                strokeWidth: 8,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${state.activeRemainingSeconds.ceil()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (ex.reps != null)
                      Text(
                        '${ex.reps} REPS',
                        style: AppTextStyles.caption.copyWith(fontSize: 10),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Center(child: _VoiceModeChips(current: state.voiceMode)),
          ],
        ),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundIconButton(
                  icon: 'chevron-left',
                  semanticLabel: 'Previous exercise',
                  onTap: state.exerciseIndex == 0
                      ? null
                      : controller.previousExercise,
                ),
                const SizedBox(width: 40),
                Semantics(
                  button: true,
                  label: paused ? 'Resume' : 'Pause',
                  child: Material(
                    color: AppColors.gold,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: controller.togglePause,
                      child: SizedBox(
                        width: 72,
                        height: 72,
                        child: paused
                            ? const Icon(
                                Icons.play_arrow,
                                color: Color(0xFF0A0B1E),
                                size: 28,
                              )
                            : const AppIcon(
                                'pause',
                                size: 24,
                                color: Color(0xFF0A0B1E),
                              ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                _RoundIconButton(
                  icon: 'chevron-right',
                  semanticLabel: 'Skip exercise',
                  onTap: controller.skipExercise,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RestView extends ConsumerWidget {
  const _RestView({required this.state});
  final RoutinePlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(routinePlayerControllerProvider.notifier);
    final justCompleted = state.exerciseIndex > 0
        ? state.routine[state.exerciseIndex - 1]
        : null;
    final next = state
        .currentExercise; // exerciseIndex already advanced when rest begins
    final paused = state.phase == RoutinePlayerPhase.restPaused;

    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'REST',
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.textSecondary,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 16),
            WorkoutTimerRing(
              progress: state.restProgress,
              size: 160,
              strokeWidth: 10,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${state.restRemainingSeconds.ceil()}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'SECONDS',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Semantics(
                  button: true,
                  label: paused ? 'Resume rest' : 'Pause rest',
                  child: Material(
                    color: const Color(0xFF181436),
                    borderRadius: BorderRadius.circular(100),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: controller.togglePause,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          paused ? 'Resume' : 'Pause',
                          style: AppTextStyles.captionBold.copyWith(
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: const Color(0xFF181436),
                  borderRadius: BorderRadius.circular(100),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(100),
                    onTap: () => controller.addRestTime(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        '+20 SEC',
                        style: AppTextStyles.captionBold.copyWith(fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (justCompleted != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF10CD00).withValues(alpha: 0.14),
                  border: Border.all(
                    color: const Color(0xFF10CD00).withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppIcon(
                      'check-circle',
                      size: 16,
                      color: Color(0xFF10CD00),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${justCompleted.displayName} completed',
                        style: const TextStyle(
                          color: Color(0xFF10CD00),
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (justCompleted != null &&
                kExerciseReflectionConfigs.containsKey(justCompleted.id)) ...[
              ExerciseReflectionCard(
                key: ValueKey(
                  'reflection_${justCompleted.id}_${state.exerciseIndex}',
                ),
                config: kExerciseReflectionConfigs[justCompleted.id]!,
                onSave: (summary) => ref
                    .read(workoutSignalLogProvider.notifier)
                    .log(
                      WorkoutSignalType.exerciseNoteSaved,
                      detail: '${justCompleted.id}: $summary',
                    ),
              ),
              const SizedBox(height: 20),
            ],
            if (justCompleted != null) ...[
              ExerciseFeedbackCard(
                key: ValueKey(
                  'feedback_${justCompleted.id}_${state.exerciseIndex}',
                ),
                onSubmit: (feeling, chips, note, painDetails) =>
                    submitExerciseFeedback(
                      ref: ref,
                      exerciseId: justCompleted.id,
                      sessionId:
                          '${state.sourceWorkout?.id ?? 'qa-routine'}_${state.startedAt.millisecondsSinceEpoch}',
                      feeling: feeling,
                      chips: chips,
                      note: note,
                      painDetails: painDetails,
                    ),
                onSkip: () {},
              ),
              const SizedBox(height: 20),
            ],
            // ONE clean Up Next card — real registry lookup, no duplicated
            // title, no empty image container (fixes the Section E bug).
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.cardStart, AppColors.cardEnd],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'UP NEXT',
                    style: AppTextStyles.captionBold.copyWith(
                      color: AppColors.gold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                  MovementDisplay(
                    pose: next.previewPose,
                    orientation: next.previewAssetPath != null
                        ? ExerciseVisualOrientation.landscape
                        : next.visualOrientation,
                    aspectRatio: next.previewAssetPath != null
                        ? next.previewAspectRatio!
                        : next.visualAspectRatio,
                    sizeBudget: 240,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    next.displayName,
                    style: AppTextStyles.screenTitle.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next.reps != null
                        ? '${next.reps} reps · ${next.durationSeconds}s'
                        : '${next.durationSeconds}s',
                    style: AppTextStyles.subtitle.copyWith(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: controller.skipRest,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                'Skip Rest',
                style: TextStyle(
                  color: Color(0xFF0A0B1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _CompleteStep { summary, feedback }

/// Real workout-completion flow (Phase 1): summary -> post-workout
/// feedback -> exit. The completion record is saved exactly once, as soon
/// as this widget first mounts (true completion — `RoutinePlayerPhase.
/// complete` is only ever reached by [RoutinePlayerController]
/// `_finishActiveExercise` on the real last exercise, never on early exit,
/// so there is no "interrupted workout marked complete" case to guard
/// against here). [_savedRecordId] is set exactly once and gates every
/// later save attempt — a `ConsumerState` survives rebuilds within this
/// same phase, so repeated taps/rebuilds can never create a second stored
/// record; [WorkoutHistoryRepository.add]'s id-based de-dup is the second,
/// storage-level line of defense.
class _CompleteView extends ConsumerStatefulWidget {
  const _CompleteView({required this.state, required this.onExit});
  final RoutinePlayerState state;
  final VoidCallback onExit;

  @override
  ConsumerState<_CompleteView> createState() => _CompleteViewState();
}

class _CompleteViewState extends ConsumerState<_CompleteView> {
  _CompleteStep _step = _CompleteStep.summary;
  String? _savedRecordId;
  bool _saving = false;
  String? _feedbackError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _saveCompletion());
  }

  Future<void> _saveCompletion() async {
    if (_savedRecordId != null) return;
    final s = widget.state;
    final workout = s.sourceWorkout;
    final recordId =
        '${workout?.id ?? 'qa-routine'}_${s.startedAt.millisecondsSinceEpoch}';
    _savedRecordId = recordId;
    final notifier = ref.read(workoutHistoryControllerProvider.notifier);
    // The durable store resolves asynchronously (SharedPreferences.
    // getInstance()) — awaiting `ready` here closes a real race: without
    // it, a save attempted before the very first read of this provider
    // has finished initializing would silently no-op (recordCompletion
    // returns null when `_repo` is still null), losing the completion
    // record.
    await notifier.ready;
    if (!mounted) return;
    await notifier.recordCompletion(
      id: recordId,
      workoutId: workout?.id ?? 'qa-routine',
      workoutName: workout?.title ?? 'Workout',
      startedAt: s.startedAt,
      completedAt: s.finishedAt ?? DateTime.now(),
      totalDurationSeconds: (s.finishedAt ?? DateTime.now())
          .difference(s.startedAt)
          .inSeconds,
      completedExerciseIds: s.completedIds.toList(),
      skippedExerciseIds: s.skippedIds.toList(),
      status: WorkoutCompletionStatus.completed,
      calories: workout?.calories,
    );
  }

  Future<void> _submitFeedback(
    WorkoutFeeling feeling,
    PainDetails? painDetails,
    String? note,
  ) async {
    final recordId = _savedRecordId;
    if (recordId == null || _saving) return;
    setState(() {
      _saving = true;
      _feedbackError = null;
    });
    try {
      final saved = await ref
          .read(workoutHistoryControllerProvider.notifier)
          .saveFeedback(
            recordId: recordId,
            feeling: feeling,
            painDetails: painDetails,
            note: note,
          );
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _saving = false;
          _feedbackError = 'Could not save feedback. Please try again.';
        });
        return;
      }
      await _emitBrainFeedbackEvents(
        feeling: feeling,
        painDetails: painDetails,
        note: note,
      );
      widget.onExit();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _feedbackError = 'Could not save feedback. Please try again.';
      });
    }
  }

  /// Tier 0 ingest + Tier 1 reactive processing for this session's real
  /// feedback — reuses the exact same [WorkoutFeeling]/[PainDetails] the
  /// durable `WorkoutHistoryController` save above already captured; a
  /// `painReported` event is always separate from the general feedback
  /// event, never folded into it (pain is never just "too difficult").
  Future<void> _emitBrainFeedbackEvents({
    required WorkoutFeeling feeling,
    PainDetails? painDetails,
    String? note,
  }) async {
    final recordId = _savedRecordId;
    if (recordId == null) return;
    final s = widget.state;
    final workoutId = s.sourceWorkout?.id ?? 'qa-routine';
    final events = ref.read(learningEventControllerProvider.notifier);
    final reactive = ref.read(reactiveEventProcessorProvider);

    final sessionEvent = LearningEvent.sessionFeedback(
      id: 'sessionFeedback_$recordId',
      userId: WorkoutCompletionRecord.localProfileId,
      workoutId: workoutId,
      feeling: feeling,
      note: note,
      sessionId: recordId,
      occurredAt: DateTime.now(),
    );
    final savedSessionEvent = await events.ingest(sessionEvent);
    if (savedSessionEvent != null) await reactive.process(savedSessionEvent);

    if (feeling == WorkoutFeeling.painDiscomfort &&
        painDetails != null &&
        !painDetails.isEmpty) {
      final painEvent = LearningEvent.painReport(
        id: 'painReported_$recordId',
        userId: WorkoutCompletionRecord.localProfileId,
        details: painDetails,
        sessionId: recordId,
        occurredAt: DateTime.now(),
      );
      final savedPainEvent = await events.ingest(painEvent);
      if (savedPainEvent != null) await reactive.process(savedPainEvent);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final duration = (state.finishedAt ?? DateTime.now()).difference(
      state.startedAt,
    );
    final workout = state.sourceWorkout;
    final completedAt = state.finishedAt ?? DateTime.now();
    final dateLabel =
        '${completedAt.month}/${completedAt.day}/${completedAt.year} '
        '${completedAt.hour.toString().padLeft(2, '0')}:${completedAt.minute.toString().padLeft(2, '0')}';

    if (_step == _CompleteStep.feedback) {
      return RoutinePlayerScaffold(
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              Text(
                'One Last Thing',
                style: AppTextStyles.screenTitle.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              PostWorkoutFeedbackCard(
                onSubmit: _submitFeedback,
                onSkip: widget.onExit,
                saving: _saving,
                errorMessage: _feedbackError,
              ),
            ],
          ),
        ),
      );
    }

    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              '🎉 ${workout?.title ?? 'Routine'} Complete!',
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 26,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Status: Completed',
              style: AppTextStyles.cardTitle.copyWith(
                fontSize: 15,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Exercises: ${state.routine.length}',
              style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed: ${state.completedIds.length}'
              '${state.skippedIds.isNotEmpty ? ' · Skipped: ${state.skippedIds.length}' : ''}',
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Duration: ${duration.inMinutes}m ${duration.inSeconds % 60}s',
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Completed on $dateLabel',
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            if (workout != null) ...[
              const SizedBox(height: 4),
              Text(
                'Calories: ${workout.calories}',
                style: AppTextStyles.subtitle.copyWith(fontSize: 14),
              ),
            ],
          ],
        ),
      ),
      bottomBar: Padding(
        padding: const EdgeInsets.all(24),
        child: Material(
          color: AppColors.gold,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _step = _CompleteStep.feedback),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              child: const Text(
                'Continue',
                style: TextStyle(
                  color: Color(0xFF0A0B1E),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ExitConfirmationView extends ConsumerWidget {
  const _ExitConfirmationView({required this.state, required this.onExit});
  final RoutinePlayerState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(routinePlayerControllerProvider.notifier);
    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'End this routine?',
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your progress on this session will not be saved.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: controller.cancelExit,
                    child: const Text('Keep Going'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onExit,
                    child: const Text('End Routine'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.state, required this.onExit});
  final RoutinePlayerState state;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return RoutinePlayerScaffold(
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),
            Text(
              'Something went wrong',
              style: AppTextStyles.screenTitle.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              state.errorMessage ?? 'Unknown error.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 14),
            ),
            const SizedBox(height: 24),
            ElevatedButton(onPressed: onExit, child: const Text('Exit')),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
  });

  final String icon;
  final VoidCallback? onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Semantics(
        button: true,
        label: semanticLabel,
        child: Material(
          color: const Color(0xFF181436),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 48,
              height: 48,
              child: Center(child: AppIcon(icon, size: 20)),
            ),
          ),
        ),
      ),
    );
  }
}
