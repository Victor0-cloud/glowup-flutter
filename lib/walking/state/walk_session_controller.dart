import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../routine_player/voice/flutter_tts_speaker.dart';
import '../../routine_player/voice/voice_speaker.dart';
import '../data/step_source.dart';
import '../models/walking_models.dart';

enum LocationCapability { available, unsupportedPlatform, permissionDenied, serviceDisabled }

/// The live state of an in-progress "Start Walk" session — Section 3/4 of
/// the approved spec. [steps]/[distanceMeters] are null only when their
/// underlying source is genuinely unavailable (never a fabricated 0 that
/// looks like a real reading of zero movement).
class WalkSessionState {
  const WalkSessionState({
    this.status = WalkSessionStatus.idle,
    this.routine,
    this.elapsedSeconds = 0,
    this.steps,
    this.distanceMeters,
    this.currentSpeedMps,
    this.locationCapability = LocationCapability.unsupportedPlatform,
    this.stepCapability = StepSourceCapability.unsupportedPlatform,
  });

  final WalkSessionStatus status;
  final WalkRoutine? routine;
  final int elapsedSeconds;
  final int? steps;
  final double? distanceMeters;
  final double? currentSpeedMps;
  final LocationCapability locationCapability;
  final StepSourceCapability stepCapability;

  /// Average pace in seconds-per-km — null until real distance has
  /// actually been covered (never divides by a near-zero distance into a
  /// misleadingly huge number).
  double? get averagePaceSecondsPerKm {
    final distance = distanceMeters;
    if (distance == null || distance < 10 || elapsedSeconds <= 0) return null;
    return elapsedSeconds / (distance / 1000);
  }

  WalkSessionState copyWith({
    WalkSessionStatus? status,
    WalkRoutine? routine,
    bool clearRoutine = false,
    int? elapsedSeconds,
    int? steps,
    double? distanceMeters,
    double? currentSpeedMps,
    LocationCapability? locationCapability,
    StepSourceCapability? stepCapability,
  }) => WalkSessionState(
    status: status ?? this.status,
    routine: clearRoutine ? null : (routine ?? this.routine),
    elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
    steps: steps ?? this.steps,
    distanceMeters: distanceMeters ?? this.distanceMeters,
    currentSpeedMps: currentSpeedMps ?? this.currentSpeedMps,
    locationCapability: locationCapability ?? this.locationCapability,
    stepCapability: stepCapability ?? this.stepCapability,
  );
}

/// Owns exactly one live "Start Walk" session at a time (Section 3/4) —
/// elapsed-time timer, real GPS distance/pace via `geolocator` (only ever
/// requested once a walk actually starts — Section 13's "don't request
/// location until genuinely needed"), and real steps-during-this-walk via
/// the same [StepSource] the daily aggregate uses (a bounded slice of the
/// same stream, never summed on top of the daily total — Section 5).
/// Voice cues reuse the existing `flutter_tts`-backed [VoiceSpeaker]
/// architecture from Routine Player — no second/duplicate voice stack.
class WalkSessionController extends StateNotifier<WalkSessionState> {
  WalkSessionController([StepSource? stepSource, VoiceSpeaker? speaker])
    : _stepSource = stepSource ?? PedometerStepSource(),
      _speaker = speaker ?? FlutterTtsSpeaker(),
      super(const WalkSessionState());

  final StepSource _stepSource;
  final VoiceSpeaker _speaker;

  Timer? _ticker;
  StreamSubscription<Position>? _positionSub;
  StreamSubscription<StepReading>? _stepSub;

  Position? _lastPosition;
  double _accumulatedDistanceMeters = 0;

  int? _stepsAtSegmentStart;
  int _stepsAccumulatedBeforeThisSegment = 0;

  bool _spokeHalfway = false;
  bool _spokeFiveMinRemaining = false;

  Future<void> start({WalkRoutine? routine}) async {
    if (state.status != WalkSessionStatus.idle) return;
    state = WalkSessionState(
      status: WalkSessionStatus.active,
      routine: routine,
    );
    _accumulatedDistanceMeters = 0;
    _lastPosition = null;
    _stepsAccumulatedBeforeThisSegment = 0;
    _stepsAtSegmentStart = null;
    _spokeHalfway = false;
    _spokeFiveMinRemaining = false;

    unawaited(_speaker.speak("Let's start walking."));
    _startTicker();
    unawaited(_startLocation());
    unawaited(_startSteps());
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (state.status != WalkSessionStatus.active) return;
      final elapsed = state.elapsedSeconds + 1;
      state = state.copyWith(elapsedSeconds: elapsed);
      _maybeSpeakMilestones(elapsed);
    });
  }

  void _maybeSpeakMilestones(int elapsed) {
    final target = state.routine?.durationMinutes;
    if (target == null) return;
    final targetSeconds = target * 60;
    if (!_spokeHalfway && elapsed >= targetSeconds ~/ 2) {
      _spokeHalfway = true;
      unawaited(_speaker.speak("You're halfway through."));
    }
    if (!_spokeFiveMinRemaining && targetSeconds - elapsed <= 300 && targetSeconds - elapsed > 0) {
      _spokeFiveMinRemaining = true;
      unawaited(_speaker.speak('Five minutes remaining.'));
    }
  }

  Future<void> _startLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        state = state.copyWith(locationCapability: LocationCapability.serviceDisabled);
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        state = state.copyWith(locationCapability: LocationCapability.permissionDenied);
        return;
      }
      state = state.copyWith(
        locationCapability: LocationCapability.available,
        distanceMeters: 0,
      );
      _positionSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 3, // meters — avoids GPS jitter inflating distance
        ),
      ).listen(_onPosition, onError: (_) {});
    } catch (_) {
      // GPS genuinely unsupported on this platform (e.g. no location
      // service compiled in) — honestly leaves distance/pace null rather
      // than a fabricated reading.
      state = state.copyWith(locationCapability: LocationCapability.unsupportedPlatform);
    }
  }

  void _onPosition(Position position) {
    if (state.status != WalkSessionStatus.active) return;
    final last = _lastPosition;
    if (last != null) {
      _accumulatedDistanceMeters += Geolocator.distanceBetween(
        last.latitude,
        last.longitude,
        position.latitude,
        position.longitude,
      );
    }
    _lastPosition = position;
    state = state.copyWith(
      distanceMeters: _accumulatedDistanceMeters,
      currentSpeedMps: position.speed >= 0 ? position.speed : null,
    );
  }

  Future<void> _startSteps() async {
    final capability = await _stepSource.checkCapability();
    state = state.copyWith(stepCapability: capability);
    if (capability != StepSourceCapability.available) return;
    _stepSub = _stepSource.readings.listen(_onStepReading, onError: (_) {
      state = state.copyWith(stepCapability: StepSourceCapability.sensorUnavailable);
    });
  }

  void _onStepReading(StepReading reading) {
    if (state.status != WalkSessionStatus.active) return;
    final segmentStart = _stepsAtSegmentStart;
    if (segmentStart == null || reading.cumulativeSteps < segmentStart) {
      // First reading of this active segment, or a reboot reset the
      // counter mid-walk — re-anchor rather than go negative.
      _stepsAtSegmentStart = reading.cumulativeSteps;
      state = state.copyWith(steps: _stepsAccumulatedBeforeThisSegment);
      return;
    }
    final segmentSteps = reading.cumulativeSteps - segmentStart;
    state = state.copyWith(steps: _stepsAccumulatedBeforeThisSegment + segmentSteps);
  }

  void pause() {
    if (state.status != WalkSessionStatus.active) return;
    state = state.copyWith(status: WalkSessionStatus.paused);
    _positionSub?.pause();
    _stepsAccumulatedBeforeThisSegment = state.steps ?? _stepsAccumulatedBeforeThisSegment;
    _stepsAtSegmentStart = null;
  }

  void resume() {
    if (state.status != WalkSessionStatus.paused) return;
    state = state.copyWith(status: WalkSessionStatus.active);
    _positionSub?.resume();
    _lastPosition = null; // avoid a distance jump from the pause gap
  }

  /// Ends the session and returns a real [WalkSession] record — the
  /// caller (the screen) is responsible for saving it via
  /// `WalkingController.recordSession`. Returns null if there was nothing
  /// to finish.
  Future<WalkSession?> finish() async {
    if (state.status == WalkSessionStatus.idle) return null;
    final finishedElapsed = state.elapsedSeconds;
    final finishedSteps = state.steps;
    final finishedDistance = state.distanceMeters;
    final routine = state.routine;
    final now = DateTime.now();
    final startedAt = now.subtract(Duration(seconds: finishedElapsed));

    _ticker?.cancel();
    await _positionSub?.cancel();
    await _stepSub?.cancel();
    unawaited(_speaker.speak('Walk complete.'));

    state = state.copyWith(status: WalkSessionStatus.finished);

    if (finishedElapsed <= 0) return null;
    return WalkSession(
      id: 'walk_${now.microsecondsSinceEpoch}',
      startedAt: startedAt,
      endedAt: now,
      durationSeconds: finishedElapsed,
      steps: finishedSteps,
      distanceMeters: finishedDistance,
      averagePaceSecondsPerKm: (finishedDistance != null && finishedDistance >= 10)
          ? finishedElapsed / (finishedDistance / 1000)
          : null,
      routineId: routine?.id,
    );
  }

  /// Discards the in-progress session without saving — e.g. the user
  /// backs out before finishing.
  Future<void> cancel() async {
    _ticker?.cancel();
    await _positionSub?.cancel();
    await _stepSub?.cancel();
    await _speaker.stop();
    state = const WalkSessionState();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _positionSub?.cancel();
    _stepSub?.cancel();
    super.dispose();
  }
}

final walkSessionControllerProvider =
    StateNotifierProvider.autoDispose<WalkSessionController, WalkSessionState>((ref) {
      return WalkSessionController();
    });
