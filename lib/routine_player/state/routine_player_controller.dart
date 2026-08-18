import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../audio/music_manager.dart';
import '../models/exercise_definition.dart';
import '../models/pose_definition.dart';
import '../models/routine_player_state.dart';
import '../voice/flutter_tts_speaker.dart';
import '../voice/voice_coach.dart';

/// The RoutinePlayer's single authoritative clock and state machine
/// (Sections 7-8). One `Timer.periodic` ticks every 100ms; every derived
/// value (progress bar, current pose, voice events) is computed from real
/// elapsed wall-clock milliseconds accumulated in [RoutinePlayerState], so
/// nothing can drift out of sync. Pausing simply stops accumulating that
/// elapsed time — every dependent system (progress, movement, voice)
/// freezes automatically because they all read from it.
class RoutinePlayerController extends StateNotifier<RoutinePlayerState?> {
  RoutinePlayerController(this._coach, this._music) : super(null);

  final VoiceCoach _coach;
  final MusicManager _music;
  Timer? _ticker;

  void _cancelAllPendingTimers() {
    for (final t in _pendingRestoreTimers) {
      t.cancel();
    }
    _pendingRestoreTimers.clear();
    for (final t in _pendingPrepareTimers) {
      t.cancel();
    }
    _pendingPrepareTimers.clear();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _prepareToken = null;
    _cancelAllPendingTimers();
    super.dispose();
  }

  void startRoutine(List<ExerciseDefinition> routine, {VoiceMode voiceMode = VoiceMode.coachOn}) {
    if (routine.isEmpty) {
      state = RoutinePlayerState(routine: routine, exerciseIndex: 0, phase: RoutinePlayerPhase.error, startedAt: DateTime.now(), errorMessage: 'No exercises in routine.');
      return;
    }
    state = RoutinePlayerState(routine: routine, exerciseIndex: 0, phase: RoutinePlayerPhase.prepare, voiceMode: voiceMode, startedAt: DateTime.now());
    _startTicker();
    _runPrepareSequence();
  }

  static const _tickPeriod = Duration(milliseconds: 100);

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(_tickPeriod, (_) => _tick());
  }

  void _tick() {
    // Deliberately NOT measured via DateTime.now() diffing: Flutter's test
    // framework fakes this Timer's *firing* (so tester.pump(duration) fires
    // it the correct number of times for that virtual duration) but does
    // NOT fake the wall clock, so a burst of fake-time-driven fires would
    // all measure a ~0ms real-world gap and elapsed time would never
    // actually advance under test. The ticker's own nominal period is the
    // correct unit of elapsed time in both production (where it fires
    // close enough to every 100ms) and tests (where FakeAsync's fire count
    // is the thing being simulated).
    const deltaMs = 100;
    final s = state;
    if (s == null) return;
    switch (s.phase) {
      case RoutinePlayerPhase.countdown:
        _tickCountdown(deltaMs);
      case RoutinePlayerPhase.active:
        _tickActive(deltaMs);
      case RoutinePlayerPhase.rest:
        _tickRest(deltaMs);
      case RoutinePlayerPhase.prepare:
      // PREPARE is deliberately NOT tick-driven — see _runPrepareSequence.
      // A fixed-duration timer here is exactly the bug this fixes: it would
      // race ahead of real (variable-length) coach speech and cut it off.
      case RoutinePlayerPhase.paused:
      case RoutinePlayerPhase.restPaused:
      case RoutinePlayerPhase.complete:
      case RoutinePlayerPhase.loading:
      case RoutinePlayerPhase.error:
      case RoutinePlayerPhase.exitConfirmation:
        break; // time-frozen/non-ticking phases — this IS the pause guarantee (Section 8/19)
    }
  }

  int _countdownAccumMs = 0;

  /// The single legal entry point into COUNTDOWN for a normal exercise
  /// start — reached only from [_runPrepareSequence]'s natural completion
  /// or [skipPrepare]'s intentional cancellation. Nothing else transitions
  /// PREPARE -> COUNTDOWN.
  void _beginCountdown() {
    final s = state!;
    _countdownAccumMs = 0;
    state = s.copyWith(phase: RoutinePlayerPhase.countdown, countdownSecondsLeft: 3);
    _fireOnce(VoiceEvent.countdown3);
  }

  /// Estimated minimum time to read/hear one prepare segment, based on its
  /// own text length (~55ms/char, clamped) — NOT a fixed guess like the
  /// bug this replaces. It's a floor alongside the real speech-completion
  /// await in [_runPrepareSequence], so it only matters if TTS resolves
  /// suspiciously fast (e.g. silently unavailable) or in Silent/Cues-only
  /// modes where nothing is actually spoken but the same text is still
  /// shown on screen and deserves real reading time.
  Duration _readingFloor(String text) => Duration(milliseconds: (text.length * 55).clamp(400, 6000));

  Object? _prepareToken;
  final List<Timer> _pendingPrepareTimers = [];

  /// A `Future.delayed` that can actually be cancelled — bare
  /// `Future.delayed` keeps its underlying Timer running regardless of
  /// whether anything still cares about the result, which is exactly the
  /// kind of leak `endSession`/`dispose` need to prevent (production leak;
  /// fails test teardown's pending-timer check), same as
  /// [_pendingRestoreTimers] for music ducking.
  Future<void> _cancellableDelay(Duration d) {
    final completer = Completer<void>();
    late final Timer t;
    t = Timer(d, () {
      _pendingPrepareTimers.remove(t);
      if (!completer.isCompleted) completer.complete();
    });
    _pendingPrepareTimers.add(t);
    return completer.future;
  }

  /// The ordered, cancellable, completion-driven start sequence (replaces
  /// the old fixed-3-second PREPARE timer that raced ahead of real coach
  /// speech and cut it off): intro+benefit -> setup instruction -> "Ready?"
  /// -> COUNTDOWN. Each segment is awaited to real completion (or its
  /// reading-time floor, whichever is longer) before the next begins.
  /// [_prepareToken] lets an intentional cancellation (skipPrepare, or
  /// leaving PREPARE entirely) make a stale in-flight sequence a safe
  /// no-op even after it eventually resumes from an await.
  Future<void> _runPrepareSequence() async {
    final startState = state;
    if (startState == null || startState.phase != RoutinePlayerPhase.prepare) return;
    final token = Object();
    _prepareToken = token;
    final ex = startState.currentExercise;
    bool cancelled() => _prepareToken != token || state?.phase != RoutinePlayerPhase.prepare;

    Future<void> speakSegment(String event, String text) async {
      if (state != null && !state!.eventFired(event)) {
        state = state!.copyWith(firedVoiceEvents: {...state!.firedVoiceEvents, '${state!.exerciseIndex}:$event'});
        await Future.wait([
          _coach.fire(event, startState.voiceMode, exercise: ex, nextExercise: startState.nextExercise),
          _cancellableDelay(_readingFloor(text)),
        ]);
        if (startState.voiceMode != VoiceMode.silent) _duckThenRestore();
      }
    }

    await speakSegment(VoiceEvent.exercisePrepare, '${ex.voiceScript.intro} ${ex.voiceScript.benefit}');
    if (cancelled()) return;
    await speakSegment(VoiceEvent.prepareInstruction, ex.voiceScript.setupInstruction);
    if (cancelled()) return;
    await speakSegment(VoiceEvent.prepareReady, 'Ready?');
    if (cancelled()) return;
    _beginCountdown();
  }

  void _tickCountdown(int deltaMs) {
    _countdownAccumMs += deltaMs;
    if (_countdownAccumMs < 1000) return;
    _countdownAccumMs = 0;
    final s = state!;
    final next = s.countdownSecondsLeft - 1;
    if (next <= 0) {
      _fireOnce(VoiceEvent.exerciseStart);
      state = s.copyWith(phase: RoutinePlayerPhase.active, activeElapsedMs: 0, clearLastAnnouncedPoseId: true);
      return;
    }
    state = s.copyWith(countdownSecondsLeft: next);
    _fireOnce(next == 2 ? VoiceEvent.countdown2 : VoiceEvent.countdown1);
  }

  void _tickActive(int deltaMs) {
    final s = state!;
    final ex = s.currentExercise;
    final newElapsedMs = (s.activeElapsedMs + deltaMs).clamp(0, ex.durationSeconds * 1000);
    state = s.copyWith(activeElapsedMs: newElapsedMs);
    final remaining = s.activeRemainingSeconds;
    final elapsed = s.activeElapsedSeconds;

    if (ex.phaseSyncedVoice) {
      // Breathing-style exercises: the pose itself drives the cue, fired
      // once per pose-entry and repeating every cycle — never the generic
      // once-per-exercise workout cues below (an abrupt "3... 2... 1...
      // Done" would break a calm breathing rhythm).
      final pose = currentPoseFor(ex, elapsed);
      if (pose.poseId != s.lastAnnouncedPoseId) {
        state = state!.copyWith(lastAnnouncedPoseId: pose.poseId);
        final text = s.voiceMode == VoiceMode.coachOn ? pose.voiceCue : (s.voiceMode == VoiceMode.cuesOnly ? pose.cuesOnlyVoiceCue : null);
        if (text != null) {
          _coach.speakText(text, s.voiceMode);
          _duckThenRestore();
        }
      }
    } else {
      if (ex.voiceScript.quarterCue != null && ex.durationSeconds > 16 && elapsed >= ex.durationSeconds / 4 && elapsed < ex.durationSeconds / 2) {
        _fireOnce(VoiceEvent.quarterCue);
      }
      if (ex.durationSeconds > 20 && elapsed >= ex.durationSeconds / 2) _fireOnce(VoiceEvent.halfway);
      if (ex.durationSeconds > 15 && remaining <= 10 && remaining > 5) _fireOnce(VoiceEvent.timeRemaining10);
      if (ex.durationSeconds > 8 && remaining <= 5 && remaining > 3) _fireOnce(VoiceEvent.timeRemaining5);
      if (remaining <= 3 && remaining > 2) _fireOnce(VoiceEvent.finish3);
      if (remaining <= 2 && remaining > 1) _fireOnce(VoiceEvent.finish2);
      if (remaining <= 1 && remaining > 0) _fireOnce(VoiceEvent.finish1);
    }

    if (newElapsedMs >= ex.durationSeconds * 1000) {
      _fireOnce(VoiceEvent.exerciseDone);
      _finishActiveExercise(skipped: false);
    }
  }

  void _tickRest(int deltaMs) {
    final s = state!;
    final newElapsedMs = (s.restElapsedMs + deltaMs).clamp(0, s.restTotalSeconds * 1000);
    state = s.copyWith(restElapsedMs: newElapsedMs);
    final remaining = s.restRemainingSeconds;
    if (s.restTotalSeconds >= 5) {
      if (remaining <= 3 && remaining > 2) _fireOnce(VoiceEvent.restFinish3);
      if (remaining <= 2 && remaining > 1) _fireOnce(VoiceEvent.restFinish2);
      if (remaining <= 1 && remaining > 0) _fireOnce(VoiceEvent.restFinish1);
    }
    if (newElapsedMs >= s.restTotalSeconds * 1000) {
      state = s.copyWith(phase: RoutinePlayerPhase.prepare, activeElapsedMs: 0);
      _runPrepareSequence();
    }
  }

  void _finishActiveExercise({required bool skipped}) {
    final s = state!;
    final completedSet = {...s.completedIds, if (!skipped) s.currentExercise.id};
    final skippedSet = {...s.skippedIds, if (skipped) s.currentExercise.id};
    if (s.isLastExercise) {
      _fireOnce(VoiceEvent.routineComplete);
      state = s.copyWith(phase: RoutinePlayerPhase.complete, completedIds: completedSet, skippedIds: skippedSet, finishedAt: DateTime.now());
      return;
    }
    _fireOnce(VoiceEvent.restStart);
    _fireOnce(VoiceEvent.restNextAnnouncement);
    state = s.copyWith(
      phase: RoutinePlayerPhase.rest,
      exerciseIndex: s.exerciseIndex + 1,
      restElapsedMs: 0,
      restTotalSeconds: 30,
      completedIds: completedSet,
      skippedIds: skippedSet,
    );
  }

  final List<Timer> _pendingRestoreTimers = [];

  /// Ducks music now, restoring after a short fixed window — real TTS
  /// completion callbacks would be more precise, but this keeps ducking
  /// bounded and simple to reason about/test. Tracked so endSession/
  /// dispose can cancel it — an un-cancelled Future.delayed Timer
  /// otherwise outlives the session (leaks in production, fails test
  /// teardown's pending-timer check).
  void _duckThenRestore() {
    _music.duck();
    late final Timer t;
    t = Timer(const Duration(seconds: 2), () {
      _pendingRestoreTimers.remove(t);
      _music.restore();
    });
    _pendingRestoreTimers.add(t);
  }

  void _fireOnce(String event) {
    final s = state;
    if (s == null || s.eventFired(event)) return;
    state = s.copyWith(firedVoiceEvents: {...s.firedVoiceEvents, '${s.exerciseIndex}:$event'});
    final next = s.nextExercise;
    _coach.fire(event, s.voiceMode, exercise: s.currentExercise, nextExercise: next);
    if (s.voiceMode != VoiceMode.silent) _duckThenRestore();
  }

  // ---- User actions ----

  /// Prepare screen's "I'm Ready" — jumps straight to the countdown
  /// instead of waiting out [prepareSeconds] (Section 9).
  /// Prepare screen's "I'm Ready" — an intentional user action, so (unlike
  /// the normal sequence) it's allowed to cancel in-flight prepare speech
  /// (Section "VOICE CANCELLATION RULES") and jump straight to countdown.
  void skipPrepare() {
    final s = state;
    if (s == null || s.phase != RoutinePlayerPhase.prepare) return;
    _prepareToken = null; // invalidates any in-flight _runPrepareSequence
    _coach.stop();
    _beginCountdown();
  }

  void togglePause() {
    final s = state;
    if (s == null) return;
    if (s.phase == RoutinePlayerPhase.active) {
      _coach.stop();
      state = s.copyWith(phase: RoutinePlayerPhase.paused);
    } else if (s.phase == RoutinePlayerPhase.paused) {
      state = s.copyWith(phase: RoutinePlayerPhase.active);
    } else if (s.phase == RoutinePlayerPhase.rest) {
      state = s.copyWith(phase: RoutinePlayerPhase.restPaused);
    } else if (s.phase == RoutinePlayerPhase.restPaused) {
      state = s.copyWith(phase: RoutinePlayerPhase.rest);
    }
  }

  void previousExercise() {
    final s = state;
    if (s == null || s.phase != RoutinePlayerPhase.active || s.exerciseIndex == 0) return;
    _coach.stop();
    state = s.copyWith(exerciseIndex: s.exerciseIndex - 1, activeElapsedMs: 0);
  }

  void skipExercise() {
    final s = state;
    if (s == null || (s.phase != RoutinePlayerPhase.active && s.phase != RoutinePlayerPhase.paused)) return;
    _coach.stop(); // no audio from the skipped exercise may continue (Section 21)
    _finishActiveExercise(skipped: true);
  }

  /// Rest's "+20 sec" — adds exactly 20 seconds to the CURRENT remaining
  /// rest, never restarts it (Section 24).
  void addRestTime(int seconds) {
    final s = state;
    if (s == null || (s.phase != RoutinePlayerPhase.rest && s.phase != RoutinePlayerPhase.restPaused)) return;
    state = s.copyWith(restTotalSeconds: s.restTotalSeconds + seconds);
  }

  void skipRest() {
    final s = state;
    if (s == null || (s.phase != RoutinePlayerPhase.rest && s.phase != RoutinePlayerPhase.restPaused)) return;
    _coach.stop();
    state = s.copyWith(phase: RoutinePlayerPhase.prepare, activeElapsedMs: 0);
    _runPrepareSequence();
  }

  void setVoiceMode(VoiceMode mode) {
    final s = state;
    if (s == null) return;
    if (mode == VoiceMode.silent) _coach.stop();
    state = s.copyWith(voiceMode: mode);
  }

  void setMusicOn(bool on) {
    final s = state;
    if (s == null) return;
    _music.setMusicOn(on);
    state = s.copyWith(musicOn: on);
  }

  /// QA-only (Section 15): slows bilateral frame animation so each frame
  /// can be inspected individually. Never called by production code paths
  /// — pass null to return to normal speed.
  void setDebugFrameDuration(int? ms) {
    final s = state;
    if (s == null) return;
    state = s.copyWith(debugFrameDurationMs: ms, clearDebugFrameDurationMs: ms == null);
  }

  void requestExit() {
    final s = state;
    if (s == null || s.phase == RoutinePlayerPhase.exitConfirmation) return;
    _coach.stop(); // intentional user action — allowed to cancel in-flight prepare speech
    state = s.copyWith(phase: RoutinePlayerPhase.exitConfirmation, phaseBeforeExit: s.phase);
  }

  void cancelExit() {
    final s = state;
    if (s == null || s.phaseBeforeExit == null) return;
    state = s.copyWith(phase: s.phaseBeforeExit, clearPhaseBeforeExit: true);
  }

  void endSession() {
    _ticker?.cancel();
    _ticker = null;
    _prepareToken = null;
    _cancelAllPendingTimers();
    _coach.stop();
    state = null;
  }
}

/// Selects which real, verified pose to display right now for [exercise]
/// at the given active-phase [elapsedSeconds] — the ONE place pose imagery
/// is resolved, shared by every RoutinePlayer screen (Section 16/23).
/// [frameDurationOverrideMs] is QA-only (Section 15's slow-motion
/// inspection mode) — production code never passes it.
PoseDefinition currentPoseFor(ExerciseDefinition exercise, double elapsedSeconds, {int? frameDurationOverrideMs}) {
  final bilateral = exercise.bilateralFrames;
  if (bilateral != null) {
    return bilateralPoseFor(bilateral, elapsedSeconds, exercise.durationSeconds.toDouble(), frameDurationOverrideMs: frameDurationOverrideMs);
  }
  switch (exercise.loopMode) {
    case LoopMode.continuousLoop:
      final cycleElapsed = elapsedSeconds % exercise.loopCycleSeconds;
      final perPose = exercise.loopCycleSeconds / exercise.poses.length;
      final idx = (cycleElapsed / perPose).floor().clamp(0, exercise.poses.length - 1);
      return exercise.poses[idx];

    case LoopMode.timedCycle:
      final totalCycle = exercise.poses.fold<double>(0, (sum, p) => sum + (p.phaseSeconds ?? 1));
      var cycleElapsed = totalCycle == 0 ? 0.0 : elapsedSeconds % totalCycle;
      for (final pose in exercise.poses) {
        final dur = pose.phaseSeconds ?? 1;
        if (cycleElapsed < dur) return pose;
        cycleElapsed -= dur;
      }
      return exercise.poses.last;

    case LoopMode.holdAfterSetup:
      final settle = exercise.poses.where((p) => p.purpose != PosePurpose.hold && p.purpose != PosePurpose.finish).toList();
      final finish = exercise.finishPoses;
      // Each finish pose defaults to a 1-second slot (Tree Pose/Savasana's
      // single un-timed RESET/RECOVERY frame, unchanged from before this
      // sum-based lookup existed) but honors its own [PoseDefinition.
      // phaseSeconds] when set — needed for a multi-frame controlled exit
      // (Legs Up Wall/Reclined Butterfly's BEND_KNEES_EXIT+RECOVERY /
      // CLOSE_KNEES+RESET) where a flat 1s-per-frame split would cut the
      // exit short instead of the approved 3s+2s split.
      final finishSeconds = finish.fold<double>(0, (sum, p) => sum + (p.phaseSeconds ?? 1));
      final remaining = exercise.durationSeconds - elapsedSeconds;
      if (finish.isNotEmpty && remaining <= finishSeconds) {
        var into = finishSeconds - remaining;
        for (final pose in finish) {
          final dur = pose.phaseSeconds ?? 1;
          if (into < dur) return pose;
          into -= dur;
        }
        return finish.last;
      }
      if (settle.isNotEmpty && elapsedSeconds < exercise.loopCycleSeconds) {
        final perPose = exercise.loopCycleSeconds / settle.length;
        final idx = (elapsedSeconds / perPose).floor().clamp(0, settle.length - 1);
        return settle[idx];
      }
      return exercise.holdPose;

    case LoopMode.reversibleCycle:
      // Forward through every pose, then backward excluding both ends —
      // 01,02,03,04,05,06,05,04,03,02,(01 again completing the cycle) —
      // never repeating frame 1 or the last frame back-to-back at the
      // turnaround. A true mirror-image reverse.
      final poses = exercise.poses;
      final sequence = [...poses, for (var i = poses.length - 2; i >= 1; i--) poses[i]];
      final totalCycle = sequence.fold<double>(0, (sum, p) => sum + (p.phaseSeconds ?? 1));
      var cycleElapsed = totalCycle == 0 ? 0.0 : elapsedSeconds % totalCycle;
      for (final pose in sequence) {
        final dur = pose.phaseSeconds ?? 1;
        if (cycleElapsed < dur) return pose;
        cycleElapsed -= dur;
      }
      return sequence.last;

    case LoopMode.customSequence:
      // Exercise-authored pose order (Dead Bug V2:
      // 01,02,03,04,05,06,04,01,repeat — returns only as far as frame 4,
      // not a full mirror-reverse, since frame 4 and frame 1 are both
      // tabletop positions and the jump between them reads as seamless).
      final byOrder = {for (final pose in exercise.poses) pose.order: pose};
      final sequence = [for (final order in exercise.customLoopOrder!) byOrder[order]!];
      final totalCycle = sequence.fold<double>(0, (sum, p) => sum + (p.phaseSeconds ?? 1));
      var cycleElapsed = totalCycle == 0 ? 0.0 : elapsedSeconds % totalCycle;
      for (final pose in sequence) {
        final dur = pose.phaseSeconds ?? 1;
        if (cycleElapsed < dur) return pose;
        cycleElapsed -= dur;
      }
      return sequence.last;
  }
}

/// Resolves the current frame for a bilateral (left/right) exercise —
/// currently only Lunges. The first half of [totalDurationSeconds] plays
/// only [seq.left] frames in order (01→02→03→04→05→06→01...), the second
/// half only [seq.right] — never mixed, never reordered, never a mirrored
/// copy of the other side (Section 4/5). The frame whose purpose is
/// [PosePurpose.active] (the "bottom" position) is held for
/// [BilateralFrameSequence.bottomHoldMultiplier]x as long as a
/// transitional frame, per Section 3.
PoseDefinition bilateralPoseFor(BilateralFrameSequence seq, double elapsedSeconds, double totalDurationSeconds, {int? frameDurationOverrideMs}) {
  final half = totalDurationSeconds / 2;
  final onRightSide = elapsedSeconds >= half;
  final frames = onRightSide ? seq.right : seq.left;
  final localElapsedMs = (onRightSide ? elapsedSeconds - half : elapsedSeconds) * 1000;
  final frameMs = (frameDurationOverrideMs ?? seq.frameDurationMs).toDouble();
  final weights = [for (final f in frames) f.purpose == PosePurpose.active ? frameMs * seq.bottomHoldMultiplier : frameMs];
  final totalCycleMs = weights.fold<double>(0, (a, b) => a + b);
  var cursor = totalCycleMs == 0 ? 0.0 : localElapsedMs % totalCycleMs;
  for (var i = 0; i < frames.length; i++) {
    if (cursor < weights[i]) return frames[i];
    cursor -= weights[i];
  }
  return frames.last;
}

/// Real production wiring — on-device TTS (degrades to silence if
/// unavailable, see [FlutterTtsSpeaker]) and the music manager (currently
/// a real on/off + ducking state machine with no track asset — see
/// [MusicManager]'s doc). Tests override this provider with a
/// [SilentSpeaker]-backed controller so assertions can inspect exactly
/// what would have been spoken.
final routinePlayerControllerProvider = StateNotifierProvider<RoutinePlayerController, RoutinePlayerState?>((ref) {
  final controller = RoutinePlayerController(VoiceCoach(FlutterTtsSpeaker()), MusicManager());
  ref.onDispose(controller.endSession);
  return controller;
});
