import 'package:speech_to_text/speech_to_text.dart';

/// Thin, testable seam over `speech_to_text`'s concrete [SpeechToText]
/// class — same pattern as `StepSource`/`PedometerStepSource` in the
/// Walking module: a real implementation for the app, a fake for tests, so
/// unit tests never need a real microphone/OS speech engine.
abstract class CoachSpeechEngine {
  /// Triggers the OS permission prompt on Android/iOS the first time it's
  /// called, and reports whether a speech-recognition engine is available
  /// on this platform/device at all. `onStatus` receives the package's own
  /// status strings, including `'done'`/`'notListening'` when a listen
  /// session ends (timeout, silence, or [stop]/[cancel]).
  Future<bool> initialize({
    required void Function(String errorMessage, bool isPermanent) onError,
    required void Function(String status) onStatus,
  });

  /// Only meaningful to call after [initialize] returns `false` — lets the
  /// caller tell "permission denied" apart from "no speech engine exists
  /// on this device/platform at all".
  Future<bool> hasPermission();

  bool get isListening;

  /// [onResult] fires for both partial and final recognition — `isFinal`
  /// distinguishes them (Section: "partial recognition does not
  /// auto-send", "final recognition remains editable").
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  });

  Future<void> stop();
  Future<void> cancel();
}

/// Real device/OS speech recognition. Every call is defensively wrapped —
/// an engine that throws (unsupported platform, no mic hardware, plugin
/// not registered) degrades to an honest "unavailable" result rather than
/// crashing the Chat screen (Section: "unsupported platform does not
/// crash").
class RealCoachSpeechEngine implements CoachSpeechEngine {
  final SpeechToText _stt = SpeechToText();

  @override
  Future<bool> initialize({
    required void Function(String errorMessage, bool isPermanent) onError,
    required void Function(String status) onStatus,
  }) async {
    try {
      return await _stt.initialize(
        onError: (e) => onError(e.errorMsg, e.permanent),
        onStatus: onStatus,
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> hasPermission() async {
    try {
      return await _stt.hasPermission;
    } catch (_) {
      return false;
    }
  }

  @override
  bool get isListening => _stt.isListening;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    try {
      await _stt.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
        ),
      );
    } catch (_) {
      // Degrades to silence — the controller's own timeout/status handling
      // still returns the UI to idle.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _stt.stop();
    } catch (_) {}
  }

  @override
  Future<void> cancel() async {
    try {
      await _stt.cancel();
    } catch (_) {}
  }
}
