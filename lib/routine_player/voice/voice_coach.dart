import '../models/exercise_definition.dart';
import '../models/routine_player_state.dart';
import 'voice_speaker.dart';

/// Deterministic, named voice events (Section 30). The controller decides
/// *when* one fires (at most once per exercise occurrence — enforced by
/// [RoutinePlayerState.firedVoiceEvents], not by this class); this class
/// only decides *what text*, if any, that event says in the current
/// [VoiceMode].
abstract class VoiceEvent {
  /// Intro + benefit only ("Next: Lunges." + why it matters) — the FIRST
  /// segment of the ordered prepare sequence. Kept separate from
  /// [prepareInstruction] and [prepareReady] so each can be awaited to
  /// real completion in turn instead of being spoken as one run-on blob.
  static const exercisePrepare = 'exercise_prepare';

  /// Setup/form instruction — the SECOND prepare segment, spoken only
  /// after [exercisePrepare] has genuinely finished.
  static const prepareInstruction = 'prepare_instruction';

  /// "Ready?" — the THIRD and final prepare segment, spoken only after
  /// [prepareInstruction] has genuinely finished. Countdown begins only
  /// after this one completes too.
  static const prepareReady = 'prepare_ready';

  static const countdown3 = 'countdown_3';
  static const countdown2 = 'countdown_2';
  static const countdown1 = 'countdown_1';
  static const exerciseStart = 'exercise_start';

  /// ~25% elapsed — an early form reminder for exercises long enough to
  /// warrant one before the halfway cue (e.g. Plank). Coach On only.
  static const quarterCue = 'quarter_cue';

  static const halfway = 'halfway';
  static const timeRemaining10 = 'time_remaining_10';
  static const timeRemaining5 = 'time_remaining_5';
  static const finish3 = 'finish_3';
  static const finish2 = 'finish_2';
  static const finish1 = 'finish_1';
  static const exerciseDone = 'exercise_done';
  static const restStart = 'rest_start';
  static const restNextAnnouncement = 'rest_next_announcement';
  static const restFinish3 = 'rest_finish_3';
  static const restFinish2 = 'rest_finish_2';
  static const restFinish1 = 'rest_finish_1';
  static const routineComplete = 'routine_complete';
}

/// Resolves a [VoiceEvent] name into spoken text for the current
/// [VoiceMode], and speaks it through a [VoiceSpeaker] — silent mode never
/// calls the speaker at all, so it structurally cannot produce audio.
class VoiceCoach {
  VoiceCoach(this._speaker);

  final VoiceSpeaker _speaker;

  Future<void> stop() => _speaker.stop();

  /// Speaks pre-resolved text directly, bypassing the named-event lookup —
  /// used for [ExerciseDefinition.phaseSyncedVoice] exercises, whose cues
  /// come from the current [PoseDefinition] rather than a fixed event name.
  /// Silent mode never calls the speaker, same guarantee as [fire].
  Future<void> speakText(String? text, VoiceMode mode) async {
    if (mode == VoiceMode.silent || text == null) return;
    await _speaker.speak(text);
  }

  Future<void> fire(
    String event,
    VoiceMode mode, {
    required ExerciseDefinition exercise,
    ExerciseDefinition? nextExercise,
  }) async {
    if (mode == VoiceMode.silent) return;
    final text = mode == VoiceMode.coachOn
        ? _coachOnText(event, exercise, nextExercise)
        : _cuesOnlyText(event, exercise, nextExercise);
    if (text == null) return;
    await _speaker.speak(text);
  }

  String? _coachOnText(
    String event,
    ExerciseDefinition ex,
    ExerciseDefinition? next,
  ) => switch (event) {
    VoiceEvent.exercisePrepare =>
      '${ex.voiceScript.intro} ${ex.voiceScript.benefit}',
    VoiceEvent.prepareInstruction => ex.voiceScript.setupInstruction,
    VoiceEvent.prepareReady => 'Ready?',
    VoiceEvent.countdown3 => '3',
    VoiceEvent.countdown2 => '2',
    VoiceEvent.countdown1 => '1',
    VoiceEvent.exerciseStart => 'Start.',
    VoiceEvent.quarterCue => ex.voiceScript.quarterCue,
    VoiceEvent.halfway =>
      ex.voiceScript.switchSideCue ??
          (ex.voiceScript.formCues.isNotEmpty
              ? 'Halfway there. ${ex.voiceScript.formCues.first}'
              : 'Halfway there.'),
    VoiceEvent.timeRemaining10 => '10 seconds left.',
    VoiceEvent.timeRemaining5 => 'Five seconds.',
    VoiceEvent.finish3 => '3',
    VoiceEvent.finish2 => '2',
    VoiceEvent.finish1 => '1',
    VoiceEvent.exerciseDone => ex.voiceScript.finishCue,
    VoiceEvent.restStart => 'Rest.',
    VoiceEvent.restNextAnnouncement =>
      next == null ? null : 'Up next: ${next.displayName}.',
    VoiceEvent.restFinish3 => '3',
    VoiceEvent.restFinish2 => '2',
    VoiceEvent.restFinish1 => '1',
    VoiceEvent.routineComplete => 'Workout complete. Great work.',
    _ => null,
  };

  String? _cuesOnlyText(
    String event,
    ExerciseDefinition ex,
    ExerciseDefinition? next,
  ) => switch (event) {
    VoiceEvent.exercisePrepare => ex.displayName,
    VoiceEvent.prepareInstruction => null, // cues-only skips long explanations
    VoiceEvent.prepareReady => null,
    VoiceEvent.countdown3 => '3',
    VoiceEvent.countdown2 => '2',
    VoiceEvent.countdown1 => '1',
    VoiceEvent.exerciseStart => 'Start',
    VoiceEvent.quarterCue => null, // cues-only skips the early form reminder
    VoiceEvent.halfway =>
      ex.voiceScript.switchSideCue != null
          ? 'Halfway. Switch sides.'
          : 'Halfway',
    VoiceEvent.timeRemaining10 => '10 seconds left',
    VoiceEvent.timeRemaining5 => 'Five seconds',
    VoiceEvent.finish3 => '3',
    VoiceEvent.finish2 => '2',
    VoiceEvent.finish1 => '1',
    VoiceEvent.exerciseDone => 'Done',
    VoiceEvent.restNextAnnouncement => next?.displayName,
    VoiceEvent.restFinish3 => '3',
    VoiceEvent.restFinish2 => '2',
    VoiceEvent.restFinish1 => '1',
    VoiceEvent.routineComplete => 'Complete',
    _ => null,
  };
}
