import 'package:audioplayers/audioplayers.dart';

/// Background-music toggle + ducking, independent of [VoiceCoach] (Section
/// 32/33). No royalty-cleared Glow Up music track exists in this project
/// yet — [trackAsset] is nullable and every playback call is a safe no-op
/// when it's unset, so the on/off + ducking *state machine* is real and
/// tested even though there's nothing audible to play. Wire a real asset
/// path here once one is approved.
///
/// The real `AudioPlayer` is constructed lazily, only the first time a
/// call actually needs it (i.e. once [trackAsset] is non-null) — touching
/// `AudioPlayer()` eagerly registers a native platform-channel listener,
/// which has nothing to talk to in a plain `flutter test` unit-test
/// environment (no widget binding / no real platform plugin) and hangs.
/// Since there is currently no track asset anywhere in the app, this also
/// means production never pays for an audio engine it isn't using yet.
class MusicManager {
  MusicManager({this.trackAsset, AudioPlayer? player})
    : _injectedPlayer = player;

  final String? trackAsset;
  final AudioPlayer? _injectedPlayer;
  AudioPlayer? _player;
  AudioPlayer get _playerInstance =>
      _player ??= _injectedPlayer ?? AudioPlayer();

  static const double _fullVolume = 0.6;
  static const double _duckedVolume = 0.15;
  bool _musicOn = true;
  bool _ducked = false;

  bool get musicOn => _musicOn;
  bool get isDucked => _ducked;

  Future<void> setMusicOn(bool on) async {
    _musicOn = on;
    if (trackAsset == null) return;
    if (on) {
      await _playerInstance.setReleaseMode(ReleaseMode.loop);
      await _playerInstance.play(AssetSource(trackAsset!));
      await _playerInstance.setVolume(_ducked ? _duckedVolume : _fullVolume);
    } else {
      await _playerInstance.stop();
    }
  }

  /// Smoothly (from the app's perspective — a single volume step, since
  /// audioplayers has no built-in tween) lowers music under coach speech.
  /// No-ops when music is off or there's no track — never lowers volume
  /// when nothing is speaking (Section 33).
  Future<void> duck() async {
    if (_ducked || !_musicOn) return;
    _ducked = true;
    if (trackAsset != null) await _playerInstance.setVolume(_duckedVolume);
  }

  Future<void> restore() async {
    if (!_ducked) return;
    _ducked = false;
    if (trackAsset != null && _musicOn)
      await _playerInstance.setVolume(_fullVolume);
  }

  Future<void> dispose() async {
    if (_player != null) await _player!.dispose();
  }
}
