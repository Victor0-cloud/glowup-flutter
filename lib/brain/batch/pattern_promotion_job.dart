import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../workout/models/workout_completion_record.dart'
    show WorkoutCompletionRecord;
import '../events/learning_event_controller.dart';
import '../patterns/learned_pattern.dart';
import '../patterns/learned_pattern_controller.dart';
import '../patterns/pattern_detector.dart';
import 'batch_run_record.dart';
import '../../workout/state/workout_history_controller.dart'
    show sharedPreferencesProvider;

/// How often the lazy on-open check even considers running the job again —
/// "at most daily" per the amendment. There is no real background
/// scheduler in this local-first app (no backend — see the Architecture
/// Gap Report), so this interval is enforced by [BatchRunRepository]'s
/// stored `lastRunAt`, checked once per app session.
const kBatchCheckInterval = Duration(days: 1);

/// How far back to look when deciding whether this local profile counts as
/// "active" for Tier 4 purposes.
const kActiveUserLookbackDays = 30;

/// Tier 4 — fully deterministic in this slice (pattern promotion/expiry
/// only; no model call). Idempotent and safely rerunnable: recomputing
/// promotion/expiry from the currently-stored patterns always converges to
/// the same result no matter how many times it runs without new evidence.
class PatternPromotionJob {
  const PatternPromotionJob(this._detector);

  final PatternDetector _detector;

  Future<BatchRunRecord> run({
    required List<LearnedPattern> patterns,
    required Future<void> Function(LearnedPattern) apply,
    required String userId,
    required DateTime now,
    required String Function() newRecordId,
  }) async {
    var promoted = 0;
    var expired = 0;
    for (final pattern in patterns) {
      if (_detector.shouldPromote(pattern)) {
        await apply(pattern.copyWith(status: PatternStatus.active));
        promoted++;
      } else if (_detector.shouldExpire(pattern, now)) {
        await apply(pattern.copyWith(status: PatternStatus.expired));
        expired++;
      }
    }
    return BatchRunRecord(
      id: newRecordId(),
      userId: userId,
      startedAt: now,
      completedAt: DateTime.now(),
      patternsPromoted: promoted,
      patternsExpired: expired,
      version: 1,
    );
  }
}

/// The lazy on-open trigger: checks whether enough time has passed and the
/// local profile has recent activity, and if so runs [PatternPromotionJob]
/// once. Call this from app startup (after the profile is known to exist)
/// — it is intentionally not wired into any per-event path.
class BatchScheduler {
  const BatchScheduler(this._ref);

  final Ref _ref;
  static const _userId = WorkoutCompletionRecord.localProfileId;
  static const _job = PatternPromotionJob(PatternDetector());

  Future<BatchRunRecord?> runIfDue() async {
    final prefs = await _ref.read(sharedPreferencesProvider.future);
    final runRepo = BatchRunRepository(prefs);
    final now = DateTime.now();

    final lastRun = runRepo.lastRunAt();
    if (lastRun != null && now.difference(lastRun) < kBatchCheckInterval) {
      return null;
    }

    // Both controllers self-initialize asynchronously (SharedPreferences.
    // getInstance()) — awaiting `ready` here closes the same race the
    // Workout Module's completion save hit earlier this session: without
    // it, an active profile whose events/patterns simply hadn't finished
    // loading yet would be misread as empty and wrongly marked inactive
    // for the rest of today's `kBatchCheckInterval` window.
    final eventController = _ref.read(learningEventControllerProvider.notifier);
    final patternController = _ref.read(
      learnedPatternControllerProvider.notifier,
    );
    await eventController.ready;
    await patternController.ready;

    final recentEvents = eventController.boundedFor(
      userId: _userId,
      limit: 200,
      lookbackDays: kActiveUserLookbackDays,
    );
    if (recentEvents.isEmpty) {
      // Inactive user this window — record that we checked, without doing
      // any pattern work, so we don't re-check on every single launch.
      await prefs.setString('batch_last_run_at_v1', now.toIso8601String());
      return null;
    }

    final patterns = patternController.activeFor(limit: 1000);
    // Candidates matter here too (promotion targets candidates), not just
    // already-active ones — read the repository directly for the full set.
    final allPatterns =
        patternController.repository
            ?.loadAll()
            .where((p) => p.userId == _userId)
            .toList() ??
        patterns;

    final record = await _job.run(
      patterns: allPatterns,
      apply: patternController.apply,
      userId: _userId,
      now: now,
      newRecordId: () => 'batch_${now.microsecondsSinceEpoch}',
    );
    await runRepo.add(record);
    return record;
  }
}

final batchSchedulerProvider = Provider<BatchScheduler>(
  (ref) => BatchScheduler(ref),
);

/// The real live trigger, closing the Tier 4 connection gap: a
/// [FutureProvider] runs its body exactly once per app session (cached
/// for every subsequent watch/read, the same "run once" guarantee already
/// relied on for `sharedPreferencesProvider`) — `TodayScreen` watches this
/// once per app launch, which is what actually calls
/// [BatchScheduler.runIfDue] in the running app instead of leaving it
/// built-but-uncalled.
final batchOnStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(batchSchedulerProvider).runIfDue();
});
