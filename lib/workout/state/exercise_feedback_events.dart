import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/events/learning_event.dart';
import '../../brain/events/learning_event_controller.dart';
import '../../brain/reactive/reactive_event_processor.dart';
import '../models/workout_completion_record.dart';

/// Emits the Tier 0 + Tier 1 events for one generalized per-exercise
/// feedback submission — the same ingest-then-process pattern
/// `RoutinePlayerScreen._emitBrainFeedbackEvents` already uses for
/// session-level feedback, generalized to work for *any* exercise (not
/// just the 4 with a specialized `ExerciseReflectionCard` config).
/// `exerciseFeedbackSubmitted` always fires; `painReported` only fires
/// when [feeling] is [WorkoutFeeling.painDiscomfort] and real pain
/// details were given — always its own separate event, never folded into
/// the general feedback event. Never calls an AI provider.
Future<void> submitExerciseFeedback({
  required WidgetRef ref,
  required String exerciseId,
  String? sessionId,
  required WorkoutFeeling feeling,
  List<String> chips = const [],
  String? note,
  PainDetails? painDetails,
}) async {
  final events = ref.read(learningEventControllerProvider.notifier);
  final reactive = ref.read(reactiveEventProcessorProvider);
  final now = DateTime.now();
  final idSuffix = now.microsecondsSinceEpoch;

  final feedbackEvent = LearningEvent.exerciseFeedback(
    id: 'exerciseFeedback_${exerciseId}_$idSuffix',
    userId: WorkoutCompletionRecord.localProfileId,
    exerciseId: exerciseId,
    feeling: feeling,
    note: note,
    chips: chips,
    sessionId: sessionId,
    occurredAt: now,
  );
  final saved = await events.ingest(feedbackEvent);
  if (saved != null) await reactive.process(saved);

  if (feeling == WorkoutFeeling.painDiscomfort &&
      painDetails != null &&
      !painDetails.isEmpty) {
    final painEvent = LearningEvent.painReport(
      id: 'painReported_${exerciseId}_$idSuffix',
      userId: WorkoutCompletionRecord.localProfileId,
      details: painDetails,
      exerciseId: exerciseId,
      sessionId: sessionId,
      occurredAt: now,
    );
    final savedPain = await events.ingest(painEvent);
    if (savedPain != null) await reactive.process(savedPain);
  }
}

/// Emits the Tier 0 event for "Ask Coach about this exercise" — a durable
/// record of what was asked, never the answer text. There is no Tier 1
/// reactive processing defined for this type (documented scope, matching
/// every other lifecycle-only event type) and this function never calls
/// an AI provider — the answer itself is already rendered client-side
/// from approved data (see `answerExerciseQuestion`) before this is ever
/// called.
Future<void> submitExerciseQuestionAsked({
  required WidgetRef ref,
  required String exerciseId,
  required String questionCode,
  String? freeTextQuestion,
  String? sessionId,
}) async {
  final events = ref.read(learningEventControllerProvider.notifier);
  final reactive = ref.read(reactiveEventProcessorProvider);
  final now = DateTime.now();
  final event = LearningEvent.exerciseQuestionAsked(
    id: 'exerciseQuestionAsked_${exerciseId}_${now.microsecondsSinceEpoch}',
    userId: WorkoutCompletionRecord.localProfileId,
    exerciseId: exerciseId,
    questionCode: questionCode,
    freeTextQuestion: freeTextQuestion,
    sessionId: sessionId,
    occurredAt: now,
  );
  final saved = await events.ingest(event);
  if (saved != null) await reactive.process(saved);
}
