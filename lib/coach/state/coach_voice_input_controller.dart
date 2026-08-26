import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../voice/coach_speech_engine.dart';

/// Mirrors [StepSourceCapability]'s honest-states pattern from the Walking
/// module: every non-`listening` state is a legitimate, non-crashing
/// outcome the UI must render honestly, never silently swallow.
enum CoachListenStatus {
  idle,
  listening,

  /// Brief state right after a final result arrives, before the caller has
  /// finished handling it — kept very short, mostly cosmetic.
  processing,

  /// No speech-recognition engine is available on this platform/device at
  /// all (unsupported platform, or genuinely no engine installed).
  unavailable,

  /// The platform supports speech recognition, but the user denied (or
  /// permanently denied) the microphone/speech permission.
  permissionDenied,

  error,
}

class CoachVoiceInputState {
  const CoachVoiceInputState({
    this.status = CoachListenStatus.idle,
    this.partialText = '',
    this.errorMessage,
  });

  final CoachListenStatus status;

  /// Progressively-updated recognized text while [status] is `listening` —
  /// mirrored into the real text field live (Section 6: "show recognized
  /// speech progressively if supported"), but never auto-sent.
  final String partialText;

  final String? errorMessage;

  CoachVoiceInputState copyWith({
    CoachListenStatus? status,
    String? partialText,
    String? errorMessage,
    bool clearError = false,
  }) => CoachVoiceInputState(
    status: status ?? this.status,
    partialText: partialText ?? this.partialText,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
  );
}

/// Owns one voice-input session for the AI Coach Chat screen. Recognized
/// text always flows into the SAME text field/send pipeline typed text
/// uses (Section 7) — this controller never sends a message itself, it
/// only ever hands text back to the screen via [onFinalResult]/state.
///
/// Audio conflict management (Section 9: "Do not let TTS speak while
/// microphone is listening... stop any active Coach TTS" before starting)
/// is the caller's responsibility via [onBeforeListen] — kept here as an
/// injected callback rather than a direct dependency on [CoachVoiceSpeaker]
/// so this controller stays testable without a real TTS engine too.
class CoachVoiceInputController extends StateNotifier<CoachVoiceInputState> {
  CoachVoiceInputController([CoachSpeechEngine? engine])
    : _engine = engine ?? RealCoachSpeechEngine(),
      super(const CoachVoiceInputState());

  final CoachSpeechEngine _engine;
  bool _everInitialized = false;

  Future<void> startListening({
    required void Function(String finalText) onFinalResult,
    Future<void> Function()? onBeforeListen,
  }) async {
    if (state.status == CoachListenStatus.listening) return;
    if (onBeforeListen != null) await onBeforeListen();

    if (!_everInitialized) {
      final available = await _engine.initialize(
        onError: (message, isPermanent) {
          state = CoachVoiceInputState(
            status: CoachListenStatus.error,
            errorMessage: message,
          );
        },
        onStatus: (status) {
          // The engine's own terminal statuses (timeout / silence / OS
          // cancel) — return to idle so the mic icon never looks "stuck"
          // listening after the engine has actually stopped.
          if ((status == 'done' || status == 'notListening') &&
              state.status == CoachListenStatus.listening) {
            state = state.copyWith(status: CoachListenStatus.idle);
          }
        },
      );
      _everInitialized = available;
      if (!available) {
        final hasPermission = await _engine.hasPermission();
        state = CoachVoiceInputState(
          status: hasPermission
              ? CoachListenStatus.unavailable
              : CoachListenStatus.permissionDenied,
        );
        return;
      }
    }

    state = const CoachVoiceInputState(status: CoachListenStatus.listening);
    await _engine.listen(
      onResult: (text, isFinal) {
        if (state.status != CoachListenStatus.listening) return;
        if (isFinal) {
          state = state.copyWith(
            status: CoachListenStatus.processing,
            partialText: text,
          );
          onFinalResult(text);
          state = const CoachVoiceInputState();
        } else {
          state = state.copyWith(partialText: text);
        }
      },
    );
  }

  Future<void> stopListening() async {
    if (state.status != CoachListenStatus.listening) return;
    await _engine.stop();
    state = const CoachVoiceInputState();
  }

  @override
  void dispose() {
    _engine.cancel();
    super.dispose();
  }
}

final coachVoiceInputControllerProvider =
    StateNotifierProvider.autoDispose<
      CoachVoiceInputController,
      CoachVoiceInputState
    >((ref) => CoachVoiceInputController());
