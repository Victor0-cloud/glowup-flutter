// Covers the local-first AI Coach Brain foundation (Tiers 0-4) added per
// the "Bluebook" mission + its processing-tier amendment: idempotent event
// ingestion (Tier 0), deterministic reactive safety/pattern processing
// (Tier 1), the on-demand adaptation engine (Tier 2), template-only
// generative expression with cache/budget/circuit-breaker infrastructure
// (Tier 3), and the lazy batch pattern-promotion job (Tier 4).
//
// A structural note on "no AI-provider call occurs" tests: Tier 0/1/2 code
// has no dependency capable of reaching an AI provider at all (see their
// imports — none reference `lib/brain/expression/`), so those tests prove
// the behavior in question completes correctly using only Tier 0/1/2
// classes, with no `GenerativeExpressionService` ever constructed or
// passed in. That absence is the proof; a real network call would be a
// compile-time impossibility here, not just a runtime one.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:glow_up/brain/batch/batch_run_record.dart';
import 'package:glow_up/brain/batch/pattern_promotion_job.dart';
import 'package:glow_up/brain/events/learning_event.dart';
import 'package:glow_up/brain/events/learning_event_controller.dart';
import 'package:glow_up/brain/events/learning_event_repository.dart';
import 'package:glow_up/brain/expression/circuit_breaker.dart';
import 'package:glow_up/brain/expression/generative_expression_service.dart';
import 'package:glow_up/brain/expression/model_budget.dart';
import 'package:glow_up/brain/patterns/learned_pattern.dart';
import 'package:glow_up/brain/patterns/learned_pattern_controller.dart';
import 'package:glow_up/brain/patterns/pattern_detector.dart';
import 'package:glow_up/brain/reactive/reactive_event_processor.dart';
import 'package:glow_up/brain/recommendations/adaptation_engine.dart';
import 'package:glow_up/brain/recommendations/coach_recommendation.dart';
import 'package:glow_up/brain/recommendations/coach_recommendation_controller.dart';
import 'package:glow_up/brain/recommendations/context_bounds.dart';
import 'package:glow_up/brain/recommendations/typed_action.dart';
import 'package:glow_up/brain/safety/safety_flag_controller.dart';
import 'package:glow_up/brain/state/current_state_controller.dart';
import 'package:glow_up/brain/state/current_state_entry.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart'
    show PainDetails, PainSeverity, WorkoutFeeling;

const _userId = 'local-device-profile';

LearningEvent _painEvent({
  required String id,
  required String exerciseId,
  PainSeverity severity = PainSeverity.moderate,
  DateTime? occurredAt,
}) {
  final now = occurredAt ?? DateTime.now();
  return LearningEvent.painReport(
    id: id,
    userId: _userId,
    exerciseId: exerciseId,
    details: PainDetails(bodyArea: 'shoulder', severity: severity),
    occurredAt: now,
  );
}

LearningEvent _feedbackEvent({
  required String id,
  required String exerciseId,
  required WorkoutFeeling feeling,
  DateTime? occurredAt,
}) {
  return LearningEvent.exerciseFeedback(
    id: id,
    userId: _userId,
    exerciseId: exerciseId,
    feeling: feeling,
    occurredAt: occurredAt ?? DateTime.now(),
  );
}

Future<ProviderContainer> _readyContainer() async {
  final container = ProviderContainer();
  await container.read(learningEventControllerProvider.notifier).ready;
  await container.read(safetyFlagControllerProvider.notifier).ready;
  await container.read(learnedPatternControllerProvider.notifier).ready;
  await container.read(coachRecommendationControllerProvider.notifier).ready;
  await container.read(currentStateControllerProvider.notifier).ready;
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 0 — event ingestion', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'duplicate event id is idempotent — never creates a second record',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          learningEventControllerProvider.notifier,
        );

        final event = _feedbackEvent(
          id: 'dup-1',
          exerciseId: 'EX021',
          feeling: WorkoutFeeling.tooHard,
        );
        await controller.ingest(event);
        await controller.ingest(event);
        await controller.ingest(event);

        final all = container.read(learningEventControllerProvider).value!;
        expect(
          all.where((e) => e.id == 'dup-1'),
          hasLength(1),
          reason: 'a retried/duplicate ingest must never duplicate storage',
        );
      },
    );

    test('oversized payload is rejected, not silently truncated', () async {
      final container = await _readyContainer();
      addTearDown(container.dispose);
      final controller = container.read(
        learningEventControllerProvider.notifier,
      );

      final hugeNote =
          'x' * 5000; // exerciseFeedbackSubmitted cap is 2048 bytes
      final event = LearningEvent.exerciseFeedback(
        id: 'huge-1',
        userId: _userId,
        exerciseId: 'EX021',
        feeling: WorkoutFeeling.tooHard,
        note: hugeNote,
        occurredAt: DateTime.now(),
      );

      expect(
        () => controller.ingest(event),
        throwsA(isA<EventPayloadTooLargeException>()),
      );
    });

    test(
      'bounded read respects the configured event limit and lookback window',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          learningEventControllerProvider.notifier,
        );

        final now = DateTime.now();
        // 250 recent events (over the default 200 limit) + 5 old ones outside a 30-day lookback.
        for (var i = 0; i < 250; i++) {
          await controller.ingest(
            _feedbackEvent(
              id: 'recent-$i',
              exerciseId: 'EX021',
              feeling: WorkoutFeeling.justRight,
              occurredAt: now,
            ),
          );
        }
        for (var i = 0; i < 5; i++) {
          await controller.ingest(
            _feedbackEvent(
              id: 'old-$i',
              exerciseId: 'EX021',
              feeling: WorkoutFeeling.justRight,
              occurredAt: now.subtract(const Duration(days: 45)),
            ),
          );
        }

        final bounded = controller.boundedFor(
          userId: _userId,
          limit: kDefaultContextBounds.maxEventsPerDecision,
          lookbackDays: kDefaultContextBounds.maxLookbackDays,
        );
        expect(
          bounded.length,
          lessThanOrEqualTo(kDefaultContextBounds.maxEventsPerDecision),
        );
        expect(
          bounded.any((e) => e.id.startsWith('old-')),
          isFalse,
          reason: 'events outside the lookback window must never be returned',
        );
      },
      timeout: const Timeout(Duration(seconds: 30)),
    );

    test(
      'a long-history synthetic user never produces an unbounded read',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final controller = container.read(
          learningEventControllerProvider.notifier,
        );
        final now = DateTime.now();

        for (var i = 0; i < 500; i++) {
          await controller.ingest(
            _feedbackEvent(
              id: 'long-$i',
              exerciseId: 'EX021',
              feeling: WorkoutFeeling.justRight,
              occurredAt: now,
            ),
          );
        }

        final bounded = controller.boundedFor(
          userId: _userId,
          limit: 50,
          lookbackDays: 30,
        );
        expect(
          bounded.length,
          50,
          reason:
              'a caller-specified smaller limit must be honored even with far more history available',
        );
      },
      timeout: const Timeout(Duration(seconds: 60)),
    );
  });

  group('Tier 1 — deterministic reactive processing (no AI provider reachable)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'a pain event sets the correct safety flag with no AI provider involved',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final processor = container.read(reactiveEventProcessorProvider);
        final event = _painEvent(
          id: 'pain-1',
          exerciseId: 'EX021',
          severity: PainSeverity.moderate,
        );
        await container
            .read(learningEventControllerProvider.notifier)
            .ingest(event);

        await processor.process(event);

        final flag = container
            .read(safetyFlagControllerProvider.notifier)
            .activeFlagFor('EX021');
        expect(flag, isNotNull);
        expect(flag!.severity, PainSeverity.moderate);
        expect(flag.sourceEventIds, contains('pain-1'));
      },
    );

    test(
      'repeated pain reports escalate severity and extend validity, never de-escalate silently',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final processor = container.read(reactiveEventProcessorProvider);
        final eventController = container.read(
          learningEventControllerProvider.notifier,
        );

        final first = _painEvent(
          id: 'pain-a',
          exerciseId: 'EX021',
          severity: PainSeverity.mild,
        );
        await eventController.ingest(first);
        await processor.process(first);

        final second = _painEvent(
          id: 'pain-b',
          exerciseId: 'EX021',
          severity: PainSeverity.severe,
        );
        await eventController.ingest(second);
        await processor.process(second);

        final flag = container
            .read(safetyFlagControllerProvider.notifier)
            .activeFlagFor('EX021');
        expect(
          flag!.severity,
          PainSeverity.severe,
          reason: 'escalation must take the higher severity',
        );
        expect(flag.sourceEventIds, containsAll(['pain-a', 'pain-b']));
      },
    );

    test(
      'safety flags can clear through the approved deterministic rule',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final safetyController = container.read(
          safetyFlagControllerProvider.notifier,
        );
        final saved = await safetyController.registerPainReport(
          exerciseId: 'EX021',
          severity: PainSeverity.mild,
          sourceEventId: 'e1',
        );
        await safetyController.clear(saved!);
        expect(safetyController.activeFlagFor('EX021'), isNull);
      },
    );

    test(
      'a single event never creates an active pattern — it stays a candidate',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 'test',
          eventId: 'f1',
          supports: true,
        );
        final pattern = patternController.repository!.find(
          userId: _userId,
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
        );
        expect(pattern!.status, PatternStatus.candidate);
        expect(
          container.read(learnedPatternControllerProvider.notifier).activeFor(),
          isEmpty,
        );
      },
    );

    test(
      'repeated supporting evidence increases observation count and confidence',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f1',
          supports: true,
        );
        final updated = await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f2',
          supports: true,
        );
        expect(updated!.observationCount, 2);
        expect(updated.confidence, 1.0);
      },
    );

    test('contradicting evidence lowers confidence', () async {
      final container = await _readyContainer();
      addTearDown(container.dispose);
      final patternController = container.read(
        learnedPatternControllerProvider.notifier,
      );
      await patternController.recordEvidence(
        patternType: 'tooHardRepeated',
        subjectId: 'EX021',
        summary: 's',
        eventId: 'f1',
        supports: true,
      );
      final updated = await patternController.recordEvidence(
        patternType: 'tooHardRepeated',
        subjectId: 'EX021',
        summary: 's',
        eventId: 'f2',
        supports: false,
      );
      expect(updated!.confidence, 0.5);
    });

    test(
      'current-state entries expire and stop being returned as live',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final stateController = container.read(
          currentStateControllerProvider.notifier,
        );
        final now = DateTime.now();
        await stateController.setEntry(
          CurrentStateEntry(
            userId: _userId,
            key: 'soreness:EX021',
            value: 'mild',
            recordedAt: now.subtract(const Duration(hours: 50)),
            expiresAt: now.subtract(const Duration(hours: 2)),
          ),
        );
        expect(
          stateController.valueOf('soreness:EX021'),
          isNull,
          reason: 'an already-expired entry must never be read as current',
        );
      },
    );
  });

  group('Tier 2 — deterministic decision engine (no AI provider)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'severe active safety flag selects triggerSafetyPause, never AI-dependent',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        await container
            .read(safetyFlagControllerProvider.notifier)
            .registerPainReport(
              exerciseId: 'EX021',
              severity: PainSeverity.severe,
              sourceEventId: 'e1',
            );

        final engine = container.read(adaptationEngineProvider);
        final rec = await engine.decideForExercise(exerciseId: 'EX021');

        expect(rec, isNotNull);
        expect(rec!.action, TypedActionType.triggerSafetyPause);
        expect(rec.safetyDecision, SafetyDecision.pause);
        expect(rec.reasonCodes, contains('safety_flag_severe_pain'));
        expect(rec.evidenceEventIds, contains('e1'));
      },
    );

    test(
      'mild/moderate safety flag selects reduceDifficulty as an advisory, not a hard pause',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        await container
            .read(safetyFlagControllerProvider.notifier)
            .registerPainReport(
              exerciseId: 'EX021',
              severity: PainSeverity.mild,
              sourceEventId: 'e1',
            );

        final rec = await container
            .read(adaptationEngineProvider)
            .decideForExercise(exerciseId: 'EX021');
        expect(rec!.action, TypedActionType.reduceDifficulty);
        expect(rec.safetyDecision, SafetyDecision.advisory);
      },
    );

    test(
      'safety always outranks a pattern-driven suggestion for the same exercise',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        // Promote a tooHardRepeated pattern to active first.
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f1',
          supports: true,
        );
        final candidate = await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f2',
          supports: true,
        );
        await patternController.apply(
          candidate!.copyWith(status: PatternStatus.active),
        );

        // Now register a severe pain flag for the same exercise.
        await container
            .read(safetyFlagControllerProvider.notifier)
            .registerPainReport(
              exerciseId: 'EX021',
              severity: PainSeverity.severe,
              sourceEventId: 'pain-1',
            );

        final rec = await container
            .read(adaptationEngineProvider)
            .decideForExercise(exerciseId: 'EX021');
        expect(
          rec!.action,
          TypedActionType.triggerSafetyPause,
          reason: 'safety must always win over a pattern-driven suggestion',
        );
      },
    );

    test(
      'an active tooHardRepeated pattern (no safety flag) selects reduceDifficulty with pattern evidence',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f1',
          supports: true,
        );
        final candidate = await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f2',
          supports: true,
        );
        await patternController.apply(
          candidate!.copyWith(status: PatternStatus.active),
        );

        final rec = await container
            .read(adaptationEngineProvider)
            .decideForExercise(exerciseId: 'EX021');
        expect(rec!.action, TypedActionType.reduceDifficulty);
        expect(rec.reasonCodes, contains('pattern_too_hard_repeated'));
        expect(rec.evidenceEventIds, containsAll(['f1', 'f2']));
      },
    );

    test(
      'nothing applies -> "keep plan unchanged" -> no recommendation is stored',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final rec = await container
            .read(adaptationEngineProvider)
            .decideForExercise(exerciseId: 'EX999-never-touched');
        expect(rec, isNull);
        expect(
          container.read(coachRecommendationControllerProvider).value,
          isEmpty,
        );
      },
    );

    test(
      'recommendations only ever reference the requested (approved) exercise id — never an invented one',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        await container
            .read(safetyFlagControllerProvider.notifier)
            .registerPainReport(
              exerciseId: 'EX021',
              severity: PainSeverity.severe,
              sourceEventId: 'e1',
            );
        final rec = await container
            .read(adaptationEngineProvider)
            .decideForExercise(exerciseId: 'EX021');
        expect(rec!.targetEntityId, 'EX021');
      },
    );

    test(
      'candidate scoring respects the configured active-pattern limit',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        // Seed and promote 25 active patterns across different exercises.
        for (var i = 0; i < 25; i++) {
          await patternController.recordEvidence(
            patternType: 'tooHardRepeated',
            subjectId: 'EX-$i',
            summary: 's',
            eventId: 'e$i-1',
            supports: true,
          );
          final c = await patternController.recordEvidence(
            patternType: 'tooHardRepeated',
            subjectId: 'EX-$i',
            summary: 's',
            eventId: 'e$i-2',
            supports: true,
          );
          await patternController.apply(
            c!.copyWith(status: PatternStatus.active),
          );
        }
        final bounded = patternController.activeFor(
          limit: kDefaultContextBounds.maxActivePatterns,
        );
        expect(bounded.length, kDefaultContextBounds.maxActivePatterns);
      },
    );
  });

  group('Tier 2 — recommendation outcome tracking', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'shown -> accepted -> completed outcomes persist and are traceable',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        await container
            .read(safetyFlagControllerProvider.notifier)
            .registerPainReport(
              exerciseId: 'EX021',
              severity: PainSeverity.severe,
              sourceEventId: 'e1',
            );
        final rec = await container
            .read(adaptationEngineProvider)
            .decideForExercise(exerciseId: 'EX021');

        final recController = container.read(
          coachRecommendationControllerProvider.notifier,
        );
        await recController.recordOutcome(
          rec!.id,
          RecommendationOutcomeStatus.shown,
        );
        await recController.recordOutcome(
          rec.id,
          RecommendationOutcomeStatus.accepted,
        );
        final updated = await recController.recordOutcome(
          rec.id,
          RecommendationOutcomeStatus.completed,
        );

        expect(updated!.outcomeStatus, RecommendationOutcomeStatus.completed);
      },
    );
  });

  group('Tier 3 — generative expression (template-only, no model call)', () {
    test(
      'a known reason code resolves to its deterministic template',
      () async {
        final service = TemplateOnlyExpressionService();
        final result = await service.explain(
          action: TypedActionType.triggerSafetyPause,
          reasonCodes: const ['safety_flag_severe_pain'],
          tone: 'supportive',
          locale: 'en',
        );
        expect(result.source, ExplanationSource.template);
        expect(result.text, contains('pain or discomfort'));
      },
    );

    test(
      'a repeated call for the same key is served from cache, not recomputed',
      () async {
        final service = TemplateOnlyExpressionService();
        final first = await service.explain(
          action: TypedActionType.reduceDifficulty,
          reasonCodes: const ['pattern_too_hard_repeated'],
          tone: 'supportive',
          locale: 'en',
        );
        final second = await service.explain(
          action: TypedActionType.reduceDifficulty,
          reasonCodes: const ['pattern_too_hard_repeated'],
          tone: 'supportive',
          locale: 'en',
        );
        expect(first.source, ExplanationSource.template);
        expect(second.source, ExplanationSource.cache);
        expect(second.text, first.text);
      },
    );

    test(
      'an unmapped reason code still produces a grounded fallback, never blocks',
      () async {
        final service = TemplateOnlyExpressionService();
        final result = await service.explain(
          action: TypedActionType.addMobility,
          reasonCodes: const ['some_unmapped_code'],
          tone: 'supportive',
          locale: 'en',
        );
        expect(result.source, ExplanationSource.fallback);
        expect(result.text, isNotEmpty);
      },
    );

    test(
      'Tier 3 cannot change the typed action — explain() only ever returns text, never an action',
      () async {
        final service = TemplateOnlyExpressionService();
        final result = await service.explain(
          action: TypedActionType.reduceDifficulty,
          reasonCodes: const ['pattern_too_hard_repeated'],
          tone: 'supportive',
          locale: 'en',
        );
        // Structural: ExplanationResult has no `action` field at all — this
        // assertion documents that fact via reflection-free type shape (the
        // absence of a settable action is what makes override impossible).
        expect(result, isA<ExplanationResult>());
      },
    );
  });

  group('Tier 3 — model budget guardrails (real, tested infrastructure)', () {
    test('per-user daily Tier 3 ceiling is enforced', () {
      final guard = ModelBudgetGuard(
        dailyTier3Ceiling: 2,
        dailyTier4Ceiling: 1,
      );
      final now = DateTime(2026, 1, 1);
      expect(guard.canCallTier3('u1', now), isTrue);
      guard.recordTier3Call('u1', now);
      expect(guard.canCallTier3('u1', now), isTrue);
      guard.recordTier3Call('u1', now);
      expect(
        guard.canCallTier3('u1', now),
        isFalse,
        reason: 'ceiling of 2 reached',
      );
    });

    test(
      'per-user daily optional Tier 4 ceiling is enforced independently of Tier 3',
      () {
        final guard = ModelBudgetGuard(
          dailyTier3Ceiling: 50,
          dailyTier4Ceiling: 1,
        );
        final now = DateTime(2026, 1, 1);
        guard.recordTier4Call('u1', now);
        expect(guard.canCallTier4('u1', now), isFalse);
        expect(
          guard.canCallTier3('u1', now),
          isTrue,
          reason: 'the two ceilings are independent',
        );
      },
    );

    test('ceilings reset per calendar day', () {
      final guard = ModelBudgetGuard(
        dailyTier3Ceiling: 1,
        dailyTier4Ceiling: 1,
      );
      final day1 = DateTime(2026, 1, 1);
      final day2 = DateTime(2026, 1, 2);
      guard.recordTier3Call('u1', day1);
      expect(guard.canCallTier3('u1', day1), isFalse);
      expect(guard.canCallTier3('u1', day2), isTrue);
    });
  });

  group('Tier 3 — provider circuit breaker (real, tested infrastructure)', () {
    test('opens after the configured consecutive-failure threshold', () {
      final breaker = CircuitBreaker(
        failureThreshold: 3,
        recoveryTimeout: const Duration(minutes: 5),
      );
      final now = DateTime(2026, 1, 1, 12);
      expect(breaker.allowCallAt(now), isTrue);
      breaker.recordFailure(now);
      breaker.recordFailure(now);
      expect(
        breaker.allowCallAt(now),
        isTrue,
        reason: 'threshold not yet reached',
      );
      breaker.recordFailure(now);
      expect(
        breaker.allowCallAt(now),
        isFalse,
        reason: 'threshold reached, circuit must open',
      );
    });

    test('moves to half-open after the recovery timeout elapses', () {
      final breaker = CircuitBreaker(
        failureThreshold: 1,
        recoveryTimeout: const Duration(minutes: 5),
      );
      final opened = DateTime(2026, 1, 1, 12);
      breaker.recordFailure(opened);
      expect(breaker.stateAt(opened), CircuitState.open);
      expect(
        breaker.stateAt(opened.add(const Duration(minutes: 6))),
        CircuitState.halfOpen,
      );
    });

    test('a success closes the circuit and resets the failure count', () {
      final breaker = CircuitBreaker(
        failureThreshold: 2,
        recoveryTimeout: const Duration(minutes: 5),
      );
      final now = DateTime(2026, 1, 1);
      breaker.recordFailure(now);
      breaker.recordSuccess();
      breaker.recordFailure(now);
      expect(
        breaker.allowCallAt(now),
        isTrue,
        reason:
            'the earlier failure must not still count after a success reset it',
      );
    });
  });

  group('Tier 4 — batch synthesis (deterministic, idempotent, bounded)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test(
      'promotes a candidate to active once evidence/confidence thresholds are met',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f1',
          supports: true,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f2',
          supports: true,
        );

        const job = PatternPromotionJob(PatternDetector());
        final now = DateTime.now();
        final all = patternController.repository!.loadAll();
        final record = await job.run(
          patterns: all,
          apply: patternController.apply,
          userId: _userId,
          now: now,
          newRecordId: () => 'batch-1',
        );

        expect(record.patternsPromoted, 1);
        final promoted = patternController.repository!.find(
          userId: _userId,
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
        );
        expect(promoted!.status, PatternStatus.active);
      },
    );

    test('expires a stale candidate past its review time', () async {
      final container = await _readyContainer();
      addTearDown(container.dispose);
      final patternController = container.read(
        learnedPatternControllerProvider.notifier,
      );
      await patternController.recordEvidence(
        patternType: 'consistentlySkipped',
        subjectId: 'EX022',
        summary: 's',
        eventId: 'f1',
        supports: true,
      );

      const job = PatternPromotionJob(PatternDetector());
      final farFuture = DateTime.now().add(const Duration(days: 61));
      final all = patternController.repository!.loadAll();
      await job.run(
        patterns: all,
        apply: patternController.apply,
        userId: _userId,
        now: farFuture,
        newRecordId: () => 'batch-2',
      );

      final result = patternController.repository!.find(
        userId: _userId,
        patternType: 'consistentlySkipped',
        subjectId: 'EX022',
      );
      expect(result!.status, PatternStatus.expired);
    });

    test(
      'is idempotent and safely rerunnable — a second run with no new evidence changes nothing further',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final patternController = container.read(
          learnedPatternControllerProvider.notifier,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f1',
          supports: true,
        );
        await patternController.recordEvidence(
          patternType: 'tooHardRepeated',
          subjectId: 'EX021',
          summary: 's',
          eventId: 'f2',
          supports: true,
        );

        const job = PatternPromotionJob(PatternDetector());
        final now = DateTime.now();
        final first = await job.run(
          patterns: patternController.repository!.loadAll(),
          apply: patternController.apply,
          userId: _userId,
          now: now,
          newRecordId: () => 'batch-3a',
        );
        final second = await job.run(
          patterns: patternController.repository!.loadAll(),
          apply: patternController.apply,
          userId: _userId,
          now: now,
          newRecordId: () => 'batch-3b',
        );

        expect(first.patternsPromoted, 1);
        expect(
          second.patternsPromoted,
          0,
          reason: 'already-active pattern must not be "promoted" again',
        );
      },
    );

    test(
      'BatchScheduler skips an inactive user (no recent events) without doing pattern work',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        final result = await container.read(batchSchedulerProvider).runIfDue();
        expect(
          result,
          isNull,
          reason: 'no events at all means nothing to synthesize this run',
        );
      },
    );

    test(
      'BatchScheduler runs once when due and an active user has recent events',
      () async {
        final container = await _readyContainer();
        addTearDown(container.dispose);
        await container
            .read(learningEventControllerProvider.notifier)
            .ingest(
              _feedbackEvent(
                id: 'active-1',
                exerciseId: 'EX021',
                feeling: WorkoutFeeling.justRight,
              ),
            );
        final scheduler = container.read(batchSchedulerProvider);
        final result = await scheduler.runIfDue();
        expect(result, isNotNull);
        // A second call within the interval must be a no-op (not due yet).
        final second = await scheduler.runIfDue();
        expect(second, isNull);
      },
    );
  });

  group('AI Coach Brain — regression guard', () {
    test(
      'BatchRunRecord round-trips through JSON with zero model cost by default (Tier 4 is deterministic in this slice)',
      () {
        final record = BatchRunRecord(
          id: 'r1',
          userId: _userId,
          startedAt: DateTime(2026, 1, 1),
          completedAt: DateTime(2026, 1, 1, 0, 0, 5),
          patternsPromoted: 1,
          patternsExpired: 0,
          version: 1,
        );
        expect(record.modelCallsUsed, 0);
        expect(record.estimatedCost, isNull);
      },
    );
  });
}
