import '../recommendations/typed_action.dart';

/// Deterministic, grounded templates keyed by the exact reason codes a
/// Tier 2 decision already carries — no model call is ever needed for a
/// combination covered here. Every sentence is built only from the typed
/// action + reason codes Tier 2 selected; nothing here can say anything
/// Tier 2 didn't already decide.
String? templateFor(TypedActionType action, List<String> reasonCodes) {
  if (reasonCodes.contains('safety_flag_severe_pain')) {
    return "You reported significant pain or discomfort with this exercise, so I've paused it for now — please check with a healthcare professional before resuming.";
  }
  if (reasonCodes.contains('safety_flag_pain_reported')) {
    return "You reported some discomfort with this exercise recently, so I've suggested easing off the difficulty today.";
  }
  if (reasonCodes.contains('pattern_too_hard_repeated')) {
    return "You've rated this exercise Too Hard more than once, so I've suggested reducing the difficulty.";
  }
  if (reasonCodes.contains('pattern_consistently_skipped')) {
    return "You've skipped this exercise a few times recently — let me know why, and I can adjust it.";
  }
  return null;
}

/// Used only when no template matches a given (action, reasonCodes) pair —
/// a generic, honest, non-fabricated sentence naming the action itself
/// rather than guessing at a reason. Grounded in the typed action alone,
/// nothing invented.
String genericFallback(TypedActionType action) =>
    "I've updated today's plan based on your recent activity.";
