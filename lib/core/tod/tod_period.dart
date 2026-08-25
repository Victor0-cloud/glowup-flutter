import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The four time-of-day states the approved Figma frames design for
/// (20a-20d). Named `TodPeriod` rather than `TimeOfDay` to avoid clashing
/// with Flutter's own `material.dart` `TimeOfDay` (hour/minute clock type).
enum TodPeriod { morning, afternoon, evening, night }

/// Central, configurable clock-to-period mapping. Every screen reads the
/// resolved period from [currentTodPeriodProvider] — nothing else in the
/// app should inspect `DateTime.now()` directly.
class TodPeriodResolver {
  const TodPeriodResolver();

  /// Boundaries are inclusive-start, exclusive-end, in local 24h hour.
  static const int morningStart = 5;
  static const int afternoonStart = 12;
  static const int eveningStart = 17;
  static const int nightStart = 21; // wraps back to morningStart

  TodPeriod resolve(DateTime now) {
    final hour = now.hour;
    if (hour >= morningStart && hour < afternoonStart) return TodPeriod.morning;
    if (hour >= afternoonStart && hour < eveningStart)
      return TodPeriod.afternoon;
    if (hour >= eveningStart && hour < nightStart) return TodPeriod.evening;
    return TodPeriod.night;
  }
}

/// Development-only manual override so every TOD state can be exercised
/// without changing the system clock. Never read outside [kDebugMode] —
/// see [currentTodPeriodProvider] — so it has no effect in a release build
/// even if left non-null.
final devTodPeriodOverrideProvider = StateProvider<TodPeriod?>((ref) => null);

/// The single source of truth the whole app reads for "what time-of-day
/// styling/content applies right now."
final currentTodPeriodProvider = Provider<TodPeriod>((ref) {
  if (kDebugMode) {
    final override = ref.watch(devTodPeriodOverrideProvider);
    if (override != null) return override;
  }
  return const TodPeriodResolver().resolve(DateTime.now());
});
