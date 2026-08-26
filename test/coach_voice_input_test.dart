// Focused tests for AI Coach voice input (speech-to-text). Uses a fake
// CoachSpeechEngine — same pattern as Walking's FakeStepSource — so these
// never depend on a real microphone/OS speech engine.

import 'package:flutter_test/flutter_test.dart';

import 'package:glow_up/coach/state/coach_voice_input_controller.dart';
import 'package:glow_up/coach/voice/coach_speech_engine.dart';

class FakeCoachSpeechEngine implements CoachSpeechEngine {
  bool initializeResult = true;
  bool permissionResult = true;
  bool wasInitializeCalled = false;

  void Function(String message, bool isPermanent)? _onError;
  void Function(String status)? _onStatus;
  void Function(String text, bool isFinal)? _onResult;
  bool _listening = false;

  @override
  Future<bool> initialize({
    required void Function(String errorMessage, bool isPermanent) onError,
    required void Function(String status) onStatus,
  }) async {
    wasInitializeCalled = true;
    _onError = onError;
    _onStatus = onStatus;
    return initializeResult;
  }

  @override
  Future<bool> hasPermission() async => permissionResult;

  @override
  bool get isListening => _listening;

  @override
  Future<void> listen({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    _onResult = onResult;
    _listening = true;
  }

  @override
  Future<void> stop() async {
    _listening = false;
    _onStatus?.call('done');
  }

  @override
  Future<void> cancel() async {
    _listening = false;
  }

  void emitPartial(String text) => _onResult?.call(text, false);
  void emitFinal(String text) => _onResult?.call(text, true);
  void emitError(String message, {bool permanent = false}) =>
      _onError?.call(message, permanent);
}

void main() {
  group('CoachVoiceInputController — permission/availability states', () {
    test('3. permission denied: initialize fails and hasPermission is false', () async {
      final engine = FakeCoachSpeechEngine()
        ..initializeResult = false
        ..permissionResult = false;
      final controller = CoachVoiceInputController(engine);

      await controller.startListening(onFinalResult: (_) {});

      expect(controller.state.status, CoachListenStatus.permissionDenied);
    });

    test(
      'unavailable: initialize fails but permission is actually granted '
      '(no speech engine on this device at all)',
      () async {
        final engine = FakeCoachSpeechEngine()
          ..initializeResult = false
          ..permissionResult = true;
        final controller = CoachVoiceInputController(engine);

        await controller.startListening(onFinalResult: (_) {});

        expect(controller.state.status, CoachListenStatus.unavailable);
      },
    );

    test('4. permission allowed: initialize succeeds', () async {
      final engine = FakeCoachSpeechEngine()..initializeResult = true;
      final controller = CoachVoiceInputController(engine);

      await controller.startListening(onFinalResult: (_) {});

      expect(engine.wasInitializeCalled, isTrue);
    });
  });

  group('CoachVoiceInputController — listening lifecycle', () {
    test('5. start listening transitions to listening', () async {
      final engine = FakeCoachSpeechEngine();
      final controller = CoachVoiceInputController(engine);

      await controller.startListening(onFinalResult: (_) {});

      expect(controller.state.status, CoachListenStatus.listening);
    });

    test('6. stop listening returns to idle', () async {
      final engine = FakeCoachSpeechEngine();
      final controller = CoachVoiceInputController(engine);
      await controller.startListening(onFinalResult: (_) {});
      expect(controller.state.status, CoachListenStatus.listening);

      await controller.stopListening();

      expect(controller.state.status, CoachListenStatus.idle);
    });

    test(
      '7. recognized final text is handed back via onFinalResult (the same '
      'pipeline typed text uses — Section 7, never a separate voice system)',
      () async {
        final engine = FakeCoachSpeechEngine();
        final controller = CoachVoiceInputController(engine);
        String? received;
        await controller.startListening(onFinalResult: (text) => received = text);

        engine.emitFinal('how am I doing today');

        expect(received, 'how am I doing today');
      },
    );

    test(
      '8. partial recognition never triggers onFinalResult (no auto-send) — '
      'only updates state.partialText',
      () async {
        final engine = FakeCoachSpeechEngine();
        final controller = CoachVoiceInputController(engine);
        var finalResultCalls = 0;
        await controller.startListening(
          onFinalResult: (_) => finalResultCalls++,
        );

        engine.emitPartial('how am');
        engine.emitPartial('how am I doing');

        expect(finalResultCalls, 0);
        expect(controller.state.partialText, 'how am I doing');
        expect(controller.state.status, CoachListenStatus.listening);
      },
    );

    test(
      '9. after a final result, status returns to idle (never a locked/'
      'disabled input) — recognized text remains freely editable',
      () async {
        final engine = FakeCoachSpeechEngine();
        final controller = CoachVoiceInputController(engine);
        await controller.startListening(onFinalResult: (_) {});

        engine.emitFinal('done talking');

        expect(controller.state.status, CoachListenStatus.idle);
      },
    );

    test('a genuine engine error surfaces as CoachListenStatus.error, never a crash', () async {
      final engine = FakeCoachSpeechEngine();
      final controller = CoachVoiceInputController(engine);
      await controller.startListening(onFinalResult: (_) {});

      engine.emitError('recognition-failed', permanent: false);

      expect(controller.state.status, CoachListenStatus.error);
      expect(controller.state.errorMessage, 'recognition-failed');
    });
  });

  group('CoachVoiceInputController — audio conflict management (Section 9)', () {
    test(
      '10. microphone starting always awaits onBeforeListen first — the '
      'caller (CoachChatScreen) uses this hook to stop any active TTS '
      'before listening begins',
      () async {
        final engine = FakeCoachSpeechEngine();
        final controller = CoachVoiceInputController(engine);
        var beforeListenCalled = false;

        await controller.startListening(
          onFinalResult: (_) {},
          onBeforeListen: () async {
            beforeListenCalled = true;
            // Not yet listening at this point — onBeforeListen must run
            // strictly before the engine is touched.
            expect(controller.state.status, CoachListenStatus.idle);
          },
        );

        expect(beforeListenCalled, isTrue);
        expect(controller.state.status, CoachListenStatus.listening);
      },
    );
  });

  group('CoachVoiceInputController — real engine, unsupported platform', () {
    test(
      '13. RealCoachSpeechEngine on a platform/test-VM with no real speech '
      'channel degrades to an honest non-crashing state',
      () async {
        // flutter_test's VM has zero real platform channel implementations
        // — this genuinely exercises the "no engine available" path, not a
        // simulation of it.
        final controller = CoachVoiceInputController(RealCoachSpeechEngine());

        await controller.startListening(onFinalResult: (_) {});

        expect(
          controller.state.status,
          anyOf(
            CoachListenStatus.unavailable,
            CoachListenStatus.permissionDenied,
            CoachListenStatus.error,
          ),
        );
      },
    );
  });
}
