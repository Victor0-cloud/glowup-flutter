import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../routine_player/voice/voice_speaker.dart';
import '../models/coach_models.dart' show CoachSpeechSpeed;

/// Broad, multi-entry heuristic — never a single device-specific name (see
/// the FEMALE AI COACH TTS requirement: "Do not hardcode one voice name
/// that only exists on one device"). Used only as a *fallback* signal when
/// a platform's voice metadata has no explicit `gender` field (this covers
/// Android, Windows/SAPI, and Web/SpeechSynthesis — none of which expose
/// gender through `flutter_tts`; only iOS/macOS do). These are real,
/// commonly-shipped female voice names across many different OEMs/engines/
/// browsers, not one specific device's voice.
const _kKnownFemaleVoiceNameTokens = [
  'female',
  'woman',
  'samantha',
  'karen',
  'moira',
  'tessa',
  'veena',
  'fiona',
  'zira',
  'hazel',
  'susan',
  'kate',
  'serena',
  'allison',
  'ava',
  'victoria',
  'salli',
  'joanna',
  'kimberly',
  'ivy',
  'kendra',
  'nicole',
  'emma',
  'amy',
  'aria',
  'jenny',
  'michelle',
  'sara',
  'zoe',
  'catherine',
  'linda',
  'heather',
  'eva',
  'sonia',
  'olivia',
];

/// A `flutter_tts` voice quality hint counts as "natural" for tier 3
/// (Section 5: prefer natural/warm over robotic) when it's not the bare
/// default/compact tier.
bool _isEnhancedQuality(Map<String, dynamic> voice) {
  final quality = (voice['quality'] as String?)?.toLowerCase() ?? '';
  return quality.contains('enhanced') ||
      quality.contains('premium') ||
      quality.contains('high');
}

bool _isFemale(Map<String, dynamic> voice) {
  final gender = (voice['gender'] as String?)?.toLowerCase();
  if (gender != null && gender.isNotEmpty) return gender.contains('female');
  final name = (voice['name'] as String?)?.toLowerCase() ?? '';
  return _kKnownFemaleVoiceNameTokens.any(name.contains);
}

/// How the currently-active Coach voice was chosen — surfaced to Settings
/// and the owner test report (Section 6: "Report: selected voice name,
/// locale, platform, fallback behavior, speech rate").
enum CoachVoiceTier {
  /// Tier 1: a female voice whose locale matches the device/app locale.
  localeMatchedFemale,

  /// Tier 2: a female voice, but only an English one (no locale match).
  englishFemale,

  /// Tier 3: no female voice could be identified at all on this device —
  /// fell back to the best-quality non-robotic voice available, of any
  /// gender, rather than an arbitrary/robotic one.
  bestNaturalAnyGender,

  /// Tier 4: no voice enumeration/selection worked at all (platform
  /// doesn't expose it, or none was found) — using whatever the OS/browser
  /// already has active as its own default. Never a crash.
  platformDefault,
}

class ResolvedCoachVoice {
  const ResolvedCoachVoice({
    required this.tier,
    this.name,
    this.locale,
    this.fallbackReason,
  });

  final CoachVoiceTier tier;
  final String? name;
  final String? locale;

  /// Set only on [CoachVoiceTier.platformDefault] when voice enumeration
  /// itself failed/threw or returned nothing — an honest, human-readable
  /// reason for the report, never silently swallowed.
  final String? fallbackReason;

  String get summary {
    final voice = name == null ? 'platform default voice' : name!;
    final localePart = locale == null ? '' : ' ($locale)';
    return '$voice$localePart — ${tier.name}';
  }
}

/// Real female-voice selection + adjustable speech rate for the AI Coach's
/// spoken replies. Implements the SAME [VoiceSpeaker] interface already
/// used by Routine Player's [FlutterTtsSpeaker] (see
/// `lib/routine_player/voice/flutter_tts_speaker.dart`) — reusing the
/// established abstraction rather than inventing a second one — but owns
/// its own `FlutterTts` instance and its own voice-selection/rate logic,
/// since Coach's needs (female-voice preference, user-adjustable speed,
/// enumerate-and-pick) are a real superset of Routine Player's fixed-rate
/// canned-cue playback, which stays untouched so workout narration timing
/// is never put at risk by this change.
///
/// `flutter_tts`'s own doc comments claim `getVoices`/`setVoice` are
/// "Android, iOS, and macOS supported only" — reading the plugin's actual
/// native source (Windows SAPI + Web SpeechSynthesis implementations, both
/// checked directly) shows that claim is stale: both are really
/// implemented today. Rather than trust either the doc comment or an
/// assumption, every call here is wrapped defensively so an actually-
/// unsupported platform (or one with zero installed voices) degrades to
/// [CoachVoiceTier.platformDefault] instead of throwing.
class CoachVoiceSpeaker implements VoiceSpeaker {
  CoachVoiceSpeaker() {
    // Never manipulate pitch to fake a female voice (Section 5's explicit
    // instruction) — always the neutral default.
    _tts.setPitch(1.0);
  }

  final FlutterTts _tts = FlutterTts();
  ResolvedCoachVoice? _resolved;
  bool _preferFemaleApplied = false;

  ResolvedCoachVoice? get resolvedVoice => _resolved;

  /// Applies the user's current Settings (Section 3) — call before every
  /// speak so a mid-session settings change always takes effect
  /// immediately, without extra reactive plumbing.
  Future<void> applySettings({
    required bool preferFemale,
    required CoachSpeechSpeed speed,
  }) async {
    try {
      await _tts.setSpeechRate(speed.ttsRate);
    } catch (_) {
      // A platform that rejects a rate change still speaks at whatever
      // rate is already active — never a crash.
    }

    if (!preferFemale) {
      if (_resolved?.tier != CoachVoiceTier.platformDefault ||
          _preferFemaleApplied) {
        try {
          await _tts.clearVoice();
        } catch (_) {}
        _resolved = const ResolvedCoachVoice(
          tier: CoachVoiceTier.platformDefault,
        );
      }
      _preferFemaleApplied = false;
      return;
    }

    if (_preferFemaleApplied) return; // already resolved this session
    _preferFemaleApplied = true;
    _resolved = await _resolveFemaleVoice();
  }

  Future<ResolvedCoachVoice> _resolveFemaleVoice() async {
    try {
      final raw = await _tts.getVoices;
      if (raw is! List || raw.isEmpty) {
        return const ResolvedCoachVoice(
          tier: CoachVoiceTier.platformDefault,
          fallbackReason: 'no voices reported by this platform/engine',
        );
      }
      final voices = <Map<String, dynamic>>[
        for (final v in raw)
          if (v is Map) Map<String, dynamic>.from(v),
      ];
      if (voices.isEmpty) {
        return const ResolvedCoachVoice(
          tier: CoachVoiceTier.platformDefault,
          fallbackReason: 'voice entries had an unexpected shape',
        );
      }

      final deviceLocale = PlatformDispatcher.instance.locale
          .toLanguageTag();

      Map<String, dynamic>? pick(
        bool Function(Map<String, dynamic>) test,
      ) {
        for (final v in voices) {
          if (test(v)) return v;
        }
        return null;
      }

      // Tier 1: female + exact locale match.
      var chosen = pick(
        (v) =>
            _isFemale(v) &&
            (v['locale'] as String? ?? '').toLowerCase() ==
                deviceLocale.toLowerCase(),
      );
      var tier = CoachVoiceTier.localeMatchedFemale;

      // Tier 2: female + English (any English locale).
      if (chosen == null) {
        chosen = pick(
          (v) =>
              _isFemale(v) &&
              (v['locale'] as String? ?? '').toLowerCase().startsWith('en'),
        );
        tier = CoachVoiceTier.englishFemale;
      }

      // Tier 2b: female, any locale at all (still better than giving up on
      // "female" entirely before trying every English fallback fails —
      // e.g. a device whose only installed voices are non-English).
      if (chosen == null) {
        chosen = pick(_isFemale);
        tier = CoachVoiceTier.englishFemale;
      }

      // Tier 3: no female voice identifiable at all — best natural
      // (enhanced/premium-quality) voice of any gender, never an
      // arbitrarily-picked robotic one when a better one is available.
      if (chosen == null) {
        chosen = pick(_isEnhancedQuality);
        tier = CoachVoiceTier.bestNaturalAnyGender;
      }

      if (chosen == null) {
        return const ResolvedCoachVoice(
          tier: CoachVoiceTier.platformDefault,
          fallbackReason: 'no female or enhanced-quality voice found',
        );
      }

      final name = chosen['name'] as String?;
      final locale = chosen['locale'] as String?;
      if (name == null || locale == null) {
        return const ResolvedCoachVoice(
          tier: CoachVoiceTier.platformDefault,
          fallbackReason: 'matched voice was missing a name/locale',
        );
      }

      await _tts.setVoice({'name': name, 'locale': locale});
      return ResolvedCoachVoice(tier: tier, name: name, locale: locale);
    } catch (e) {
      return ResolvedCoachVoice(
        tier: CoachVoiceTier.platformDefault,
        fallbackReason: 'voice selection unavailable on this platform: $e',
      );
    }
  }

  @override
  Future<void> speak(String text) async {
    try {
      await _tts.stop();
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
      final safetyTimeout = Duration(
        milliseconds: (text.length * 90).clamp(1000, 20000),
      );
      await completer.future.timeout(safetyTimeout, onTimeout: () {});
    } catch (_) {
      // Degrades to silence — never crashes the Chat screen over TTS.
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

/// Maps the user-facing [CoachSpeechSpeed] choice to `flutter_tts`'s 0.0-1.0
/// rate range. Deliberately moderate at every setting (Section 5: "avoid...
/// extremely... exaggerated speech rate") — `normal` matches the same 0.5
/// default already used by Routine Player's [FlutterTtsSpeaker].
extension CoachSpeechSpeedRate on CoachSpeechSpeed {
  double get ttsRate => switch (this) {
    CoachSpeechSpeed.slow => 0.38,
    CoachSpeechSpeed.normal => 0.5,
    CoachSpeechSpeed.fast => 0.62,
  };
}

/// One long-lived speaker for the whole Coach module — real TTS engines
/// are relatively expensive to spin up repeatedly, and reusing a single
/// instance also means [CoachVoiceSpeaker.resolvedVoice] (shown in
/// Settings) reflects what was actually last spoken, not a fresh re-guess.
final coachVoiceSpeakerProvider = Provider<CoachVoiceSpeaker>(
  (ref) => CoachVoiceSpeaker(),
);
