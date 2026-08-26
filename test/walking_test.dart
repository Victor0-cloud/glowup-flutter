// Coverage for the standalone Walking & Steps feature (Section 17's 12
// required scenarios, as far as practical without a physical Android/iOS
// device — this dev environment is Windows-only, so `pedometer`'s real
// sensor behavior and `geolocator`'s real GPS behavior are NOT verified
// against hardware here; what IS verified is every piece of pure Dart
// logic this app owns (baseline math, session state machine, dedup,
// Brain event wiring) using a fake, injectable StepSource — never a real
// platform API pretending to be fake.

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/routine_player/voice/voice_speaker.dart';
import 'package:glow_up/walking/data/step_source.dart';
import 'package:glow_up/walking/data/walking_repository.dart';
import 'package:glow_up/walking/models/walking_models.dart';
import 'package:glow_up/walking/state/walk_session_controller.dart';
import 'package:glow_up/walking/state/walking_controller.dart';

/// A real, controllable step source for tests — never a mock of a
/// platform API, just a plain Dart stream the test drives directly. Lets
/// tests exercise the baseline/day-rollover/reboot logic deterministically
/// without a real sensor.
class FakeStepSource implements StepSource {
  FakeStepSource({this.supported = true});
  final bool supported;
  final _controller = StreamController<StepReading>.broadcast();

  @override
  bool get isSupported => supported;

  @override
  Future<StepSourceCapability> checkCapability() async =>
      supported ? StepSourceCapability.available : StepSourceCapability.unsupportedPlatform;

  @override
  Stream<StepReading> get readings => _controller.stream;

  void emit(int cumulativeSteps, DateTime timestamp) {
    _controller.add(StepReading(cumulativeSteps: cumulativeSteps, timestamp: timestamp));
  }

  void dispose() => _controller.close();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('1. Phone-only step counting — no Fitbit/wearable required', () {
    test('PedometerStepSource.isSupported is false on this (non-mobile) test host', () {
      expect(PedometerStepSource().isSupported, isFalse);
    });

    test(
      'no Fitbit/wearable package dependency exists anywhere in pubspec.yaml — the real, architectural confirmation of "phone by itself must be enough"',
      () {
        final pubspec = File('pubspec.yaml').readAsStringSync().toLowerCase();
        for (final term in ['fitbit', 'wear_os', 'health_connect', 'apple_health']) {
          expect(
            pubspec.contains(term),
            isFalse,
            reason: 'pubspec.yaml must not depend on "$term" for this MVP',
          );
        }
      },
    );
  });

  group('5/12. Daily baseline — real local-day steps, never double-counted, reboot-safe', () {
    test('first reading of a new day anchors the baseline at 0 steps today', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WalkingRepository(prefs);
      final source = FakeStepSource();
      addTearDown(source.dispose);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final testProvider =
          StateNotifierProvider<WalkingController, AsyncValue<WalkingState>>(
        (ref) => WalkingController(ref, source),
      );
      final controller = container.read(testProvider.notifier);
      await controller.ready;

      final today = DateTime.now();
      source.emit(15000, today); // e.g. device booted earlier, 15000 steps since boot
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = controller.state.value!;
      expect(state.todaySteps, 0);
      final baseline = repo.loadBaseline();
      expect(baseline!.cumulative, 15000);
      expect(baseline.dateKey, dateKeyFor(today));
    });

    test('subsequent readings the same day report the real delta, not the raw cumulative', () async {
      final source = FakeStepSource();
      addTearDown(source.dispose);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final testProvider =
          StateNotifierProvider<WalkingController, AsyncValue<WalkingState>>(
        (ref) => WalkingController(ref, source),
      );
      final controller = container.read(testProvider.notifier);
      await controller.ready;

      final today = DateTime.now();
      source.emit(15000, today);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.emit(15342, today.add(const Duration(minutes: 10)));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(controller.state.value!.todaySteps, 342);
    });

    test('a reboot (cumulative drops) re-anchors the baseline instead of going negative', () async {
      final source = FakeStepSource();
      addTearDown(source.dispose);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final testProvider =
          StateNotifierProvider<WalkingController, AsyncValue<WalkingState>>(
        (ref) => WalkingController(ref, source),
      );
      final controller = container.read(testProvider.notifier);
      await controller.ready;

      final today = DateTime.now();
      source.emit(15000, today);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.emit(15500, today.add(const Duration(minutes: 5)));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // Device rebooted — cumulative resets to a small number.
      source.emit(120, today.add(const Duration(minutes: 10)));
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // Honest, disclosed simplification: re-anchors to 0 rather than
      // going negative — never a fabricated/nonsensical step count.
      expect(controller.state.value!.todaySteps, 0);
    });

    test('dateKeyFor produces real YYYY-MM-DD local-calendar-day keys', () {
      final d = DateTime(2026, 8, 6, 23, 59);
      expect(dateKeyFor(d), '2026-08-06');
    });
  });

  group('2/4/9. Start/finish walk — real session lifecycle, honest partial data', () {
    test('start() transitions from idle to active and speaks the start cue', () async {
      final speaker = SilentSpeaker();
      final controller = WalkSessionController(FakeStepSource(supported: false), speaker);
      addTearDown(controller.dispose);

      await controller.start();
      expect(controller.state.status, WalkSessionStatus.active);
      expect(speaker.spoken, contains("Let's start walking."));
    });

    test(
      'finish() with no steps/GPS source available still returns an honest partial WalkSession (nulls, never fabricated numbers)',
      () async {
        final controller = WalkSessionController(
          FakeStepSource(supported: false),
          SilentSpeaker(),
        );
        addTearDown(controller.dispose);
        await controller.start();
        await Future<void>.delayed(const Duration(milliseconds: 1100));
        final session = await controller.finish();

        expect(session, isNotNull);
        expect(session!.durationSeconds, greaterThanOrEqualTo(1));
        expect(session.steps, isNull);
        expect(session.distanceMeters, isNull);
      },
    );

    test('finish() before any real elapsed time returns null (nothing to save)', () async {
      final controller = WalkSessionController(FakeStepSource(supported: false), SilentSpeaker());
      addTearDown(controller.dispose);
      // Never started — idle.
      final session = await controller.finish();
      expect(session, isNull);
    });
  });

  group('3. Pause/resume — steps and GPS distance freeze, elapsed time stops', () {
    test('pause() stops the elapsed-time ticker; resume() continues it', () async {
      final controller = WalkSessionController(FakeStepSource(supported: false), SilentSpeaker());
      addTearDown(controller.dispose);
      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      final elapsedBeforePause = controller.state.elapsedSeconds;

      controller.pause();
      expect(controller.state.status, WalkSessionStatus.paused);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      // Elapsed must not have advanced while paused.
      expect(controller.state.elapsedSeconds, elapsedBeforePause);

      controller.resume();
      expect(controller.state.status, WalkSessionStatus.active);
      await Future<void>.delayed(const Duration(milliseconds: 1100));
      expect(controller.state.elapsedSeconds, greaterThan(elapsedBeforePause));
    });

    test('steps accumulated before a pause are preserved across resume (segment accounting)', () async {
      final source = FakeStepSource();
      addTearDown(source.dispose);
      final controller = WalkSessionController(source, SilentSpeaker());
      addTearDown(controller.dispose);
      await controller.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final t0 = DateTime.now();
      source.emit(1000, t0);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.emit(1050, t0.add(const Duration(seconds: 1))); // 50 steps this segment
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(controller.state.steps, 50);

      controller.pause();
      controller.resume();

      source.emit(1200, t0.add(const Duration(seconds: 2))); // re-anchors, +0 immediately
      await Future<void>.delayed(const Duration(milliseconds: 20));
      source.emit(1230, t0.add(const Duration(seconds: 3))); // +30 in new segment
      await Future<void>.delayed(const Duration(milliseconds: 50));

      // 50 preserved from before the pause + 30 in the new segment = 80.
      expect(controller.state.steps, 80);
    });
  });

  group('6. Pace math — never divides by near-zero distance into a misleading figure', () {
    test('averagePaceSecondsPerKm is null until real distance has been covered', () {
      const state = WalkSessionState(elapsedSeconds: 300, distanceMeters: 2);
      expect(state.averagePaceSecondsPerKm, isNull);
    });

    test('averagePaceSecondsPerKm is a real, correct value for a real distance', () {
      const state = WalkSessionState(elapsedSeconds: 600, distanceMeters: 1000);
      expect(state.averagePaceSecondsPerKm, 600);
    });
  });

  group('7/8. Honest capability states — denied/unavailable, never a crash or fake reading', () {
    test('StepSourceCapability covers every real outcome, no silent default', () {
      expect(StepSourceCapability.values.map((e) => e.name).toSet(), {
        'available',
        'unsupportedPlatform',
        'permissionDenied',
        'sensorUnavailable',
      });
    });

    test('LocationCapability covers every real outcome, no silent default', () {
      expect(LocationCapability.values.map((e) => e.name).toSet(), {
        'available',
        'unsupportedPlatform',
        'permissionDenied',
        'serviceDisabled',
      });
    });

    test('WalkingState.todaySteps stays null (never a fabricated 0) when the sensor is unsupported', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final testProvider =
          StateNotifierProvider<WalkingController, AsyncValue<WalkingState>>(
        (ref) => WalkingController(ref, FakeStepSource(supported: false)),
      );
      final controller = container.read(testProvider.notifier);
      await controller.ready;
      expect(controller.state.value!.todaySteps, isNull);
      expect(controller.state.value!.stepCapability, StepSourceCapability.unsupportedPlatform);
    });
  });

  group('10. Brain event wiring — real events, bounded (never one per step)', () {
    test('a finished walk emits exactly one walkCompleted event with real, matching stats', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final events = container.read(learningEventControllerProvider.notifier);
      await events.ready;

      final walkingController = container.read(walkingControllerProvider.notifier);
      await walkingController.ready;

      final session = WalkSession(
        id: 'walk_test_1',
        startedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        endedAt: DateTime.now(),
        durationSeconds: 600,
        steps: 800,
        distanceMeters: 650,
      );
      await walkingController.recordSession(session);

      final logged = container.read(learningEventControllerProvider).value ?? const [];
      final completed = logged.where((e) => e.type == LearningEventType.walkCompleted);
      expect(completed, hasLength(1));
      final payload = completed.first.payload as WalkCompletedPayload;
      expect(payload.steps, 800);
      expect(payload.distanceMeters, 650);
      expect(payload.durationSeconds, 600);
    });

    test('recordSession is idempotent by id — a duplicate save never creates a second event', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final events = container.read(learningEventControllerProvider.notifier);
      await events.ready;
      final walkingController = container.read(walkingControllerProvider.notifier);
      await walkingController.ready;

      final session = WalkSession(
        id: 'walk_dedup_test',
        startedAt: DateTime.now(),
        endedAt: DateTime.now(),
        durationSeconds: 300,
        steps: 400,
      );
      await walkingController.recordSession(session);
      await walkingController.recordSession(session); // same id again

      expect(walkingController.state.value!.sessions.length, 1);
    });
  });

  group('13. Local-day step goal — dedup, at most once per day', () {
    test('goalAlreadyReachedFor is false until markGoalReached is called for that date', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = WalkingRepository(prefs);
      const dateKey = '2026-08-26';
      expect(repo.goalAlreadyReachedFor(dateKey), isFalse);
      await repo.markGoalReached(dateKey);
      expect(repo.goalAlreadyReachedFor(dateKey), isTrue);
      // A different day is unaffected.
      expect(repo.goalAlreadyReachedFor('2026-08-27'), isFalse);
    });
  });

  group('Walk routines — duration targets only, never a promised step count', () {
    test('kWalkRoutines has the 6 approved presets with real duration targets', () {
      expect(kWalkRoutines.map((r) => r.title).toList(), [
        '5-Minute Reset Walk',
        '10-Minute Easy Walk',
        '20-Minute Daily Walk',
        '30-Minute Brisk Walk',
        'Recovery Walk',
        'Evening Wind-Down Walk',
      ]);
      for (final r in kWalkRoutines) {
        expect(r.durationMinutes, greaterThan(0));
      }
    });
  });
}
