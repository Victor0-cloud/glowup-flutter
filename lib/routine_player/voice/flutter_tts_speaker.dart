import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'voice_speaker.dart';

/// Real on-device TTS via `flutter_tts`. Kept out of [VoiceCoach] itself
/// so the coach's scheduling/dedup logic stays testable without a real
/// speech engine — this class is the only place that touches the plugin.
/// Desktop TTS engine availability varies by machine, so every call is
/// defensively guarded: a missing/broken platform voice degrades to
/// silence instead of crashing the workout session.
///
/// [speak] awaits REAL completion (the platform's completion callback),
/// not just "speech started" — `flutter_tts`'s own `speak()` future
/// resolves as soon as the request is queued on some platforms, which is
/// exactly what let PREPARE speech get cut off by a fixed-duration timer
/// racing ahead of it. A safety timeout guards against a platform whose
/// completion callback never fires, so a broken TTS engine degrades to
/// "waits a bounded amount then continues" instead of hanging forever.
class FlutterTtsSpeaker implements VoiceSpeaker {
  FlutterTtsSpeaker() {
    _tts.setSpeechRate(0.5);
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts = FlutterTts();

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.stop(); // never let two cues overlap (Section 33)
      final completer = Completer<void>();
      _tts.setCompletionHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      _tts.setCancelHandler(() {
        if (!completer.isCompleted) completer.complete();
      });
      _tts.setErrorHandler((_) {
        if (!completer.isCompleted) completer.complete();
      });
      await _tts.speak(text);
      // Safety bound: ~70ms/char (matches the estimate used for the reading
      // floor elsewhere), capped, in case this platform never calls back.
      final safetyTimeout = Duration(
        milliseconds: (text.length * 90).clamp(1000, 15000),
      );
      await completer.future.timeout(safetyTimeout, onTimeout: () {});
    } catch (e) {
      debugPrint('[VoiceCoach] TTS unavailable, degrading to silent: $e');
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}
