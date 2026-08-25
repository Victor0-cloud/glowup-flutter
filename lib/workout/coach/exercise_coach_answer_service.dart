import '../../brain/safety/safety_flag.dart';
import '../../routine_player/models/exercise_definition.dart';

/// One suggested "Ask Coach about this exercise" question — [code] is the
/// structured id logged on [LearningEventType.exerciseQuestionAsked]
/// (never the answer text), [label] is the example copy the user taps.
class ExerciseCoachQuestion {
  const ExerciseCoachQuestion(this.code, this.label);
  final String code;
  final String label;
}

/// The exact example questions from the approved spec, plus one for the
/// exercise's benefit (its own approved field, [ExerciseDefinition.
/// benefitShort]/[VoiceScript.benefit]) since that's explicitly part of
/// the bounded context this panel is allowed to use.
const kExerciseCoachQuestions = [
  ExerciseCoachQuestion('howToPerform', 'How do I perform this correctly?'),
  ExerciseCoachQuestion('whereToFeel', 'Where should I feel this exercise?'),
  ExerciseCoachQuestion('breathing', 'Can you explain the breathing?'),
  ExerciseCoachQuestion('easierVariation', 'What is an easier variation?'),
  ExerciseCoachQuestion('benefit', "What's the benefit of this exercise?"),
  ExerciseCoachQuestion(
    'discomfort',
    'My [body area] feels uncomfortable. What should I do?',
  ),
];

/// Deterministic, template-based answers built *only* from one exercise's
/// approved [ExerciseDefinition] fields (name, poses/instructions,
/// benefit, body areas, voice script) plus that exercise's own active
/// safety flags — never a model call, never invented per-exercise
/// content. This is the service boundary the approved spec asks to keep
/// "ready for a future secure Coach provider": if a real provider is ever
/// connected, it would replace only the body of [answerExerciseQuestion],
/// never the bounded-context contract callers depend on.
///
/// A question that isn't recognized (unmatched free text) still gets a
/// real, honest answer built from the same approved data — see
/// [_matchQuestionCode] — never a generic "I don't understand" dead end
/// and never fabricated exercise-specific advice.
String answerExerciseQuestion({
  required ExerciseDefinition exercise,
  required String questionCode,
  List<SafetyFlag> activeSafetyFlagsForExercise = const [],
}) {
  final safetyPrefix = _safetyPrefix(activeSafetyFlagsForExercise);
  final body = switch (questionCode) {
    'howToPerform' => _howToPerform(exercise),
    'whereToFeel' => _whereToFeel(exercise),
    'breathing' => _breathing(exercise),
    'easierVariation' => _easierVariation(exercise),
    'benefit' => _benefit(exercise),
    'discomfort' => _discomfort(exercise),
    _ => _howToPerform(exercise),
  };
  return safetyPrefix == null ? body : '$safetyPrefix\n\n$body';
}

/// Best-effort mapping from a user's own typed question to one of
/// [kExerciseCoachQuestions]' codes, via simple keyword matching — never
/// an AI call. Falls back to `'howToPerform'`, always a safe, real answer
/// built from approved data rather than a dead end.
String matchFreeTextQuestionCode(String freeText) {
  final q = freeText.toLowerCase();
  if (q.contains('pain') ||
      q.contains('hurt') ||
      q.contains('uncomfortable') ||
      q.contains('sore')) {
    return 'discomfort';
  }
  if (q.contains('breath')) return 'breathing';
  if (q.contains('easier') || q.contains('variation') || q.contains('modif')) {
    return 'easierVariation';
  }
  if (q.contains('feel') || q.contains('where')) return 'whereToFeel';
  if (q.contains('benefit') || q.contains('why')) return 'benefit';
  return 'howToPerform';
}

String? _safetyPrefix(List<SafetyFlag> flags) {
  if (flags.isEmpty) return null;
  final now = DateTime.now();
  final active = flags.where((f) => f.isActiveAt(now)).toList();
  if (active.isEmpty) return null;
  final bodyArea = active.first.bodyArea;
  return "You've reported discomfort with this exercise before"
      '${bodyArea != null ? ' ($bodyArea)' : ''}. Please move carefully, '
      'ease off if anything feels wrong, and stop if it recurs — this note '
      'takes priority over the usual encouragement below.';
}

String _howToPerform(ExerciseDefinition ex) {
  final steps = ex.poses.toList()..sort((a, b) => a.order.compareTo(b.order));
  final lines = steps
      .map((p) => '${p.order}. ${p.label}: ${p.instruction}')
      .join('\n');
  return 'How to perform ${ex.displayName}:\n${ex.voiceScript.setupInstruction}\n$lines';
}

String _whereToFeel(ExerciseDefinition ex) {
  if (ex.bodyAreas.isEmpty) {
    return 'No specific target area is on file for ${ex.displayName}. You '
        'should feel normal muscular effort, never sharp or radiating pain.';
  }
  return 'You should feel ${ex.displayName} in: ${ex.bodyAreas.join(', ')}. '
      'If you feel sharp or radiating pain instead of normal muscular '
      'effort, stop and use the Pain or Discomfort option in exercise '
      'feedback.';
}

String _breathing(ExerciseDefinition ex) {
  if (ex.playbackType == 'breathing') {
    final steps = ex.poses.toList()..sort((a, b) => a.order.compareTo(b.order));
    final lines = steps.map((p) => '${p.label}: ${p.instruction}').join('\n');
    return 'Breathing pattern for ${ex.displayName}:\n$lines';
  }
  return 'There\'s no specific breathing pattern on file for '
      '${ex.displayName} — breathe naturally throughout and avoid holding '
      'your breath.';
}

String _easierVariation(ExerciseDefinition ex) {
  return 'There\'s no exercise-specific easier variation on file for '
      '${ex.displayName} yet. In general, you can reduce your range of '
      'motion, reduce repetitions or hold time, or take extra rest between '
      'rounds — and it\'s always fine to skip an exercise that doesn\'t '
      'feel right for you today.';
}

String _benefit(ExerciseDefinition ex) {
  final benefit = ex.voiceScript.benefit.isNotEmpty
      ? ex.voiceScript.benefit
      : ex.benefitShort;
  return benefit;
}

String _discomfort(ExerciseDefinition ex) {
  return '${ex.displayName} shouldn\'t cause pain. If you\'re feeling '
      'discomfort, ease off or stop the exercise, and use the Pain or '
      'Discomfort option in exercise feedback so your Coach can track it. '
      'This isn\'t a diagnosis — for persistent or severe pain, please '
      'consult a medical professional.';
}
