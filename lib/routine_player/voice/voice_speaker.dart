/// Abstraction over "how spoken text actually reaches the user" — kept
/// separate from [VoiceCoach]'s scheduling logic so the scheduler is
/// unit-testable without a real TTS engine, and so the app can degrade
/// gracefully if on-device TTS isn't available.
abstract class VoiceSpeaker {
  Future<void> speak(String text);
  Future<void> stop();
}

/// Used for [VoiceMode.silent] and in tests — never produces audio, but
/// still records what *would* have been said so tests can assert on it.
class SilentSpeaker implements VoiceSpeaker {
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> stop() async {}
}
