// Coverage for connecting the real AI Coach Brain: `selectCoachBrainService`'s
// honest fallback with no backend configured (mirrors
// `selectScanAnalysisProvider`'s own test in food_scan_test.dart),
// `RemoteCoachBrainService`'s guarantee to never fabricate a reply, and
// `CoachBrainContext.toRequestJson()`'s bounded, privacy-safe payload.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:glow_up/coach/brain/coach_brain_context.dart';
import 'package:glow_up/coach/brain/coach_brain_service.dart';
import 'package:glow_up/coach/brain/remote_coach_brain_service.dart';
import 'package:glow_up/coach/config/coach_backend_config.dart';
import 'package:glow_up/coach/data/coach_feedback_repository.dart';
import 'package:glow_up/coach/data/coach_thread_repository.dart';
import 'package:glow_up/coach/models/coach_models.dart';
import 'package:glow_up/coach/state/coach_chat_controller.dart';
import 'package:glow_up/core/tod/tod_period.dart';
import 'package:glow_up/onboarding/models/onboarding_profile.dart';
import 'package:glow_up/workout/models/workout_completion_record.dart';

/// Fails the first call (simulating the exact production bug: reply
/// generated, persistence failed), succeeds on every call after —
/// `CoachChatController.retry()`'s no-duplicate-message guarantee is
/// tested against this. The failing call reports a real `threadId` (as
/// the deployed Edge Function now does — see coach-chat/index.ts's
/// `thread_id` field on every post-thread-creation error response),
/// matching how a real mid-request failure behaves so the retry-reuses-
/// the-same-thread fix can be verified for real.
class _FakeFailOnceBrain implements CoachBrainService {
  int callCount = 0;

  /// The `threadId` the controller actually passed on the most recent
  /// call — lets a test assert the retry sent the thread the failure
  /// reported, not null (which would create an orphaned second thread).
  String? lastReceivedThreadId;

  @override
  Future<CoachBrainResult> respond({
    required CoachBrainContext? context,
    required List<ChatMessage> conversation,
    required String userMessage,
    required String? threadId,
  }) async {
    callCount++;
    lastReceivedThreadId = threadId;
    if (callCount == 1) {
      return const CoachBrainError(
        'reply generated but could not be saved',
        threadId: 'server-thread-abc',
      );
    }
    return CoachBrainSuccess(
      message: ChatMessage(
        id: 'ai-reply-1',
        sender: ChatSender.ai,
        text: "Yes, I'm here!",
        sentAt: DateTime.now(),
      ),
      threadId: threadId ?? 'thread-1',
    );
  }
}

SupabaseClient _fakeSupabaseClient() => SupabaseClient(
  'https://this-project-does-not-exist.invalid',
  'fake-anon-key',
);

void main() {
  group(
    'selectCoachBrainService — honest fallback with no backend configured',
    () {
      test(
        'selects UnconnectedCoachBrainService when SUPABASE_URL/ANON_KEY are not set (the default in this build)',
        () {
          expect(CoachBackendConfig.isConfigured, isFalse);
          final service = selectCoachBrainService();
          expect(service, isA<UnconnectedCoachBrainService>());
        },
      );

      test(
        'coachBrainServiceProvider resolves to the same honest fallback',
        () {
          final container = ProviderContainer();
          addTearDown(container.dispose);
          final service = container.read(coachBrainServiceProvider);
          expect(service, isA<UnconnectedCoachBrainService>());
        },
      );
    },
  );

  group('UnconnectedCoachBrainService — never fabricates a reply', () {
    test('returns CoachBrainUnavailable, never a fabricated success', () async {
      const service = UnconnectedCoachBrainService();
      final result = await service.respond(
        context: null,
        conversation: const [],
        userMessage: 'Can you make me a workout plan?',
        threadId: null,
      );
      expect(result, isA<CoachBrainUnavailable>());
    });
  });

  group(
    'RemoteCoachBrainService — real network behavior, no fabricated reply on failure',
    () {
      test(
        'respond() with no signed-in session returns CoachBrainError immediately, never CoachBrainUnavailable or a fabricated success',
        () async {
          final service = RemoteCoachBrainService(
            client: SupabaseClient(
              'https://this-project-does-not-exist.invalid',
              'fake-anon-key',
            ),
          );
          final result = await service.respond(
            context: null,
            conversation: const [],
            userMessage: 'How many calories should I eat?',
            threadId: null,
          );
          // A configured backend that fails must report CoachBrainError —
          // never the legacy "not connected at all" state, and never a
          // CoachBrainSuccess it didn't earn.
          expect(result, isA<CoachBrainError>());
          expect(result, isNot(isA<CoachBrainUnavailable>()));
          expect(result, isNot(isA<CoachBrainSuccess>()));
        },
      );
    },
  );

  group('CoachBrainContext.toRequestJson — bounded, privacy-safe payload', () {
    test(
      'contains only the named, non-sensitive fields — never raw workout records, journal, or mood content',
      () {
        const context = CoachBrainContext(
          greetingName: 'Mia',
          period: TodPeriod.morning,
          primaryGoal: Goal.loseWeight,
          routinesScheduledToday: 3,
          routinesCompletedToday: 1,
          activeStreakCount: 2,
          recentWorkouts: [],
          latestWorkoutFeeling: WorkoutFeeling.challenging,
          hasRecentPainFlag: false,
          frequentlySkippedExerciseIds: ['ex-1', 'ex-2'],
          todayWaterMl: 500,
          todayWaterGoalMl: 2000,
        );

        final json = context.toRequestJson();

        const allowedKeys = {
          'greetingName',
          'period',
          'primaryGoal',
          'routinesScheduledToday',
          'routinesCompletedToday',
          'activeStreakCount',
          'recentWorkoutCount',
          'latestWorkoutFeeling',
          'hasRecentPainFlag',
          'todayWaterMl',
          'todayWaterGoalMl',
        };
        expect(allowedKeys.containsAll(json.keys), isTrue);

        // The raw per-exercise skip list and full workout records are
        // real user data that never needs to leave the device for a
        // coaching reply — only aggregate counts/flags do.
        expect(json.containsKey('frequentlySkippedExerciseIds'), isFalse);
        expect(json.containsKey('recentWorkouts'), isFalse);

        expect(json['greetingName'], 'Mia');
        expect(json['period'], 'morning');
        expect(json['primaryGoal'], 'loseWeight');
        expect(json['recentWorkoutCount'], 0);
        expect(json['latestWorkoutFeeling'], 'challenging');
        expect(json['hasRecentPainFlag'], isFalse);
      },
    );

    test('omits null-able fields entirely rather than sending null', () {
      const context = CoachBrainContext(
        greetingName: 'Guest',
        period: TodPeriod.night,
        primaryGoal: null,
        routinesScheduledToday: 0,
        routinesCompletedToday: 0,
        activeStreakCount: 0,
        recentWorkouts: [],
        latestWorkoutFeeling: null,
        hasRecentPainFlag: false,
        frequentlySkippedExerciseIds: [],
        todayWaterMl: 0,
        todayWaterGoalMl: 2000,
      );

      final json = context.toRequestJson();
      expect(json.containsKey('primaryGoal'), isFalse);
      expect(json.containsKey('latestWorkoutFeeling'), isFalse);
    });

    test(
      'includes real Period & Cycle fields when logged — the fix for the Coach '
      'falsely claiming it has no access to cycle data',
      () {
        final periodStart = DateTime.utc(2026, 8, 19);
        final predictedNext = DateTime.utc(2026, 9, 16);
        final context = CoachBrainContext(
          greetingName: 'Mia',
          period: TodPeriod.morning,
          primaryGoal: null,
          routinesScheduledToday: 0,
          routinesCompletedToday: 0,
          activeStreakCount: 0,
          recentWorkouts: const [],
          latestWorkoutFeeling: null,
          hasRecentPainFlag: false,
          frequentlySkippedExerciseIds: const [],
          todayWaterMl: 0,
          todayWaterGoalMl: 2000,
          cycleAwareSuggestionsEnabled: true,
          currentCycleDay: 5,
          latestPeriodStart: periodStart,
          predictedNextPeriodStart: predictedNext,
          todayCycleMood: 'tired',
          todayCycleEnergyLevel: 2,
          todayCyclePainIntensity: 4,
          todayCycleSymptoms: const ['cramps', 'headache'],
        );

        final json = context.toRequestJson();

        expect(json['cycleAwareSuggestionsEnabled'], isTrue);
        expect(json['currentCycleDay'], 5);
        expect(json['latestPeriodStart'], periodStart.toIso8601String());
        expect(
          json['predictedNextPeriodStart'],
          predictedNext.toIso8601String(),
        );
        expect(json['todayCycleMood'], 'tired');
        expect(json['todayCycleEnergyLevel'], 2);
        expect(json['todayCyclePainIntensity'], 4);
        expect(json['todayCycleSymptoms'], ['cramps', 'headache']);
      },
    );

    test('omits every cycle field when the user has no cycle data at all — the '
        'honest "missing data" case, never a fabricated 0/false', () {
      const context = CoachBrainContext(
        greetingName: 'Mia',
        period: TodPeriod.morning,
        primaryGoal: null,
        routinesScheduledToday: 0,
        routinesCompletedToday: 0,
        activeStreakCount: 0,
        recentWorkouts: [],
        latestWorkoutFeeling: null,
        hasRecentPainFlag: false,
        frequentlySkippedExerciseIds: [],
        todayWaterMl: 0,
        todayWaterGoalMl: 2000,
      );

      final json = context.toRequestJson();

      for (final key in [
        'cycleAwareSuggestionsEnabled',
        'currentCycleDay',
        'latestPeriodStart',
        'predictedNextPeriodStart',
        'todayCycleMood',
        'todayCycleEnergyLevel',
        'todayCyclePainIntensity',
        'todayCycleSymptoms',
      ]) {
        expect(
          json.containsKey(key),
          isFalse,
          reason: '$key must be omitted, not sent as null/0/false',
        );
      }
    });
  });

  group(
    'CoachChatController.retry — never duplicates the original user message',
    () {
      test(
        'a failed send followed by retry() shows the user message exactly once, matching the reported production bug ("Are u alive" x2)',
        () async {
          final brain = _FakeFailOnceBrain();
          final controller = CoachChatController(
            brain,
            () => null,
            CoachThreadRepository(client: _fakeSupabaseClient()),
            CoachFeedbackRepository(client: _fakeSupabaseClient()),
          );
          addTearDown(controller.dispose);

          await controller.send('Are u alive');
          expect(
            controller.state.messages
                .where((m) => m.text == 'Are u alive')
                .length,
            1,
          );
          expect(controller.state.status, CoachConnectionStatus.error);
          expect(brain.callCount, 1);
          // The failure reported a real thread — the controller must
          // remember it immediately, not leave threadId null.
          expect(controller.state.threadId, 'server-thread-abc');

          await controller.retry();
          expect(
            controller.state.messages
                .where((m) => m.text == 'Are u alive')
                .length,
            1,
            reason:
                'retry() must never append a second copy of the user message',
          );
          expect(controller.state.status, CoachConnectionStatus.connected);
          expect(brain.callCount, 2);
          // The retry must target the same thread the failed attempt
          // reported — never null, which would make the server start a
          // second, orphaned thread (the real production bug: two
          // separate single-message "Are u alive" threads).
          expect(brain.lastReceivedThreadId, 'server-thread-abc');
          expect(
            controller.state.messages.any((m) => m.text == "Yes, I'm here!"),
            isTrue,
          );
        },
      );

      test('send() is a no-op while a request is already in flight', () async {
        final brain = _FakeFailOnceBrain();
        final controller = CoachChatController(
          brain,
          () => null,
          CoachThreadRepository(client: _fakeSupabaseClient()),
          CoachFeedbackRepository(client: _fakeSupabaseClient()),
        );
        addTearDown(controller.dispose);

        final first = controller.send('Are u alive');
        expect(controller.isSending, isTrue);
        // A second send while the first is still in flight must not fire a
        // second request or append a second bubble.
        await controller.send('Are u alive');
        await first;

        expect(
          controller.state.messages
              .where((m) => m.text == 'Are u alive')
              .length,
          1,
        );
        expect(brain.callCount, 1);
      });
    },
  );
}
