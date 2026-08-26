import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:pedometer/pedometer.dart' as pedometer;

/// Mirrors [ScanCapability]'s honest-states pattern for the step sensor —
/// the UI reads this and shows the correct experience rather than
/// guessing or silently failing.
enum StepSourceCapability { available, unsupportedPlatform, permissionDenied, sensorUnavailable }

/// One raw reading from the underlying step sensor: the cumulative step
/// count *since the device last booted* (this is what Android's
/// TYPE_STEP_COUNTER and iOS's CMPedometer both actually report — there
/// is no OS-level "steps today" primitive), plus when it was observed.
/// Converting this into a real calendar-day total is `WalkingRepository`'s
/// job (baseline tracking), never this class's.
class StepReading {
  const StepReading({required this.cumulativeSteps, required this.timestamp});
  final int cumulativeSteps;
  final DateTime timestamp;
}

/// The real provider boundary for "how many steps has the phone counted."
/// A future source (e.g. Health Connect/Apple Health for historical data)
/// can implement this same interface with zero UI change — this app has
/// no fake/demo implementation anywhere: where the sensor genuinely isn't
/// available, this honestly reports
/// [StepSourceCapability.unsupportedPlatform] rather than inventing a
/// step count.
abstract class StepSource {
  /// True only where a real on-device step sensor is actually available —
  /// Android/iOS via the `pedometer` plugin. False on every desktop
  /// target and Web (no such sensor exists there), so the UI can honestly
  /// show "step counting isn't available on this device" instead of a
  /// silently-frozen 0.
  bool get isSupported;

  Future<StepSourceCapability> checkCapability();

  /// Real cumulative-steps-since-boot readings, or an empty stream if
  /// unsupported. Never called before checking [isSupported].
  Stream<StepReading> get readings;
}

/// The only real implementation — backed entirely by the `pedometer`
/// plugin's `stepCountStream` (Android's TYPE_STEP_COUNTER sensor /
/// iOS's CMPedometer, both real OS-level step counters, no Fitbit/wearable
/// involved). NOT verified against real hardware by this session — no
/// physical Android/iOS device was available to test against; this is the
/// architecturally-correct wrapper around the plugin's documented API,
/// disclosed as untested-on-device in the feature's own report.
class PedometerStepSource implements StepSource {
  @override
  bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<StepSourceCapability> checkCapability() async {
    if (!isSupported) return StepSourceCapability.unsupportedPlatform;
    // The `pedometer` plugin has no separate "check permission" call —
    // like image_picker's camera, permission is requested implicitly by
    // the OS on first subscribe, and a denial surfaces as a stream error
    // (handled by callers of `readings`, never a fabricated "granted"
    // state here).
    return StepSourceCapability.available;
  }

  @override
  Stream<StepReading> get readings {
    if (!isSupported) return const Stream.empty();
    return pedometer.Pedometer.stepCountStream.map(
      (event) => StepReading(cumulativeSteps: event.steps, timestamp: event.timeStamp),
    );
  }
}
