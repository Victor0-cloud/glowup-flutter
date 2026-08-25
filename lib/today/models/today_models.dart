import '../../core/tod/tod_period.dart';

/// The 4 tappable Today quick-action shortcuts (Workout/Water/Mood/Journal).
/// Distinct from [ProgressMetric] below — the "Daily Progress" card tracks
/// a different, overlapping set (Workouts/Water/Steps, no Mood or Journal),
/// exactly as the approved Figma frame shows.
enum QuickActionType { workout, water, mood, journal }

/// What a "Daily Progress" row measures.
enum ProgressMetric { workouts, water, steps }

/// One row of the "Daily Progress" card. `done`/`total`/`unit` are placeholder
/// figures (matching the exact static numbers on the approved Figma mock —
/// 2/3 workouts, 5/8 glasses, 6.2k/10k steps) until the Workout/Water
/// modules exist to report real counts; wiring those is a later pass, not
/// this one.
class QuickActionStatus {
  const QuickActionStatus({
    required this.metric,
    required this.label,
    required this.done,
    required this.total,
    required this.unit,
  });

  final ProgressMetric metric;
  final String label;
  final num done;
  final num total;
  final String unit;

  double get fraction => total == 0 ? 0 : (done / total).clamp(0, 1).toDouble();
}

/// The "Up Next" card — today's single highlighted recommendation. Content
/// is period-specific per the approved Figma copy (Morning Yoga Flow, HIIT
/// Cardio Blast, Evening Stretch, Bedtime Meditation).
class DailyPlan {
  const DailyPlan({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

/// A single typed recommendation the future Brain recommendation engine
/// will generate (workout swap, hydration nudge, bedtime reminder, etc).
/// Not yet produced by any real engine in this pass — this type exists so
/// [DailyPlan]/[BrainInsight] have a documented upgrade path instead of
/// being permanently hardcoded strings.
class DailyRecommendation {
  const DailyRecommendation({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    this.relevantPeriod,
  });

  final String id;
  final String title;
  final String message;
  final String category; // e.g. "workout", "hydration", "sleep", "nutrition"
  final TodPeriod? relevantPeriod;
}

/// The AI Coach Tip card content. Exact copy for now comes straight from
/// the approved Figma frame per period — no external AI call is made.
class BrainInsight {
  const BrainInsight({required this.message, required this.source});

  final String message;

  /// Where this insight came from — "figma_static" today, will become
  /// "brain_engine" once a real recommendation engine exists.
  final String source;
}

/// The Glow Score card's data. `score`/`message` are the exact placeholder
/// values shown on every approved Today frame (72, "You're doing fantastic
/// today!..."). Real scoring inputs documented below for the future Tier 2
/// engine — this pass only wires the type through, not the algorithm.
///
/// Future GlowScoreSummary inputs (not implemented yet):
/// - workout adherence (sessions completed vs. planned)
/// - hydration adherence
/// - mood check-in consistency + trend
/// - journal frequency
/// - sleep quality (once Sleep module exists)
/// - nutrition adherence (once Nutrition module exists)
/// - goal-weighted blending per the user's selected [Goal]s from onboarding
class GlowScoreSummary {
  const GlowScoreSummary({required this.score, required this.message});

  final int score; // 0-100
  final String message;
}

/// Everything the Today screen needs to render, for the resolved
/// [TodPeriod], derived from onboarding/profile + (future) live feature
/// state. This is the one object screens/widgets read — no widget should
/// reach into onboarding or brain state directly.
class TodayState {
  const TodayState({
    required this.period,
    required this.greetingName,
    required this.glowScore,
    required this.plan,
    required this.progress,
    required this.coachTip,
  });

  final TodPeriod period;
  final String greetingName;
  final GlowScoreSummary glowScore;
  final DailyPlan plan;
  final List<QuickActionStatus> progress;
  final BrainInsight coachTip;
}
