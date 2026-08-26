import '../../core/tod/tod_period.dart';

enum ChatSender { ai, user, system }

/// One bubble in the 23e chat thread. `system` messages (not part of the
/// Figma design) are used only for the legacy "not connected yet" notice
/// shown when no backend is configured at all (dev/test builds) — see
/// [CoachBrainService] — and are rendered without a mascot avatar so
/// they're never mistaken for a real AI reply.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.sender,
    required this.text,
    required this.sentAt,
    this.feedback,
  });

  final String id;
  final ChatSender sender;
  final String text;
  final DateTime sentAt;

  /// -1 (thumbs down), 1 (thumbs up), or null (no feedback given yet).
  /// Only ever set on a real, persisted assistant message — see
  /// `CoachChatController.sendFeedback`.
  final int? feedback;

  ChatMessage copyWith({int? feedback}) => ChatMessage(
    id: id,
    sender: sender,
    text: text,
    sentAt: sentAt,
    feedback: feedback ?? this.feedback,
  );
}

/// One row in the hub's real "Recent Chats" list — built from a real
/// `CoachThreadSummary` (see `CoachThreadRepository.loadRecentThreadSummaries`),
/// never fabricated sample data. Tapping a row opens that specific real,
/// persisted thread (see `CoachChatController.openThread`).
class ConversationPreview {
  const ConversationPreview({
    required this.threadId,
    required this.title,
    required this.preview,
    required this.timeLabel,
  });

  final String threadId;
  final String title;
  final String preview;
  final String timeLabel;
}

/// One row on 23f (Your AI Plan). `colorHex`/`badgeColorHex` come straight
/// off each Plan-Card's exported Color-Bar / Badge fill — not reused from
/// the shared palette, since Hydration's blue (#0AABEB) and the mood
/// chart's green (#0AEB9A) don't match any existing AppColors token.
class CoachPlanItem {
  const CoachPlanItem({
    required this.title,
    required this.subtitle,
    required this.badgeLabel,
    required this.colorHex,
  });

  final String title;
  final String subtitle;
  final String badgeLabel;
  final int colorHex;
}

/// One day cell in 23g's "Daily Emotions" strip. Mood tracking itself
/// (Figma family 45) isn't built yet, so this — like every number on this
/// screen — is illustrative seed data reproduced verbatim from the
/// approved frame, not a real computed history.
class MoodDayEntry {
  const MoodDayEntry({
    required this.day,
    required this.emoji,
    this.dimmed = false,
  });

  final int day;
  final String emoji;
  final bool dimmed;
}

enum CoachPersonality { encouraging, toughLove, balanced }

extension CoachPersonalityLabel on CoachPersonality {
  String get label => switch (this) {
    CoachPersonality.encouraging => 'Encouraging',
    CoachPersonality.toughLove => 'Tough Love',
    CoachPersonality.balanced => 'Balanced',
  };
}

enum NotificationFrequency { gentle, regular, frequent }

extension NotificationFrequencyLabel on NotificationFrequency {
  String get label => switch (this) {
    NotificationFrequency.gentle => 'Gentle',
    NotificationFrequency.regular => 'Regular',
    NotificationFrequency.frequent => 'Frequent',
  };
}

/// AI Coach Voice setting (Section 3 of the female-TTS requirement) — MVP
/// keeps this to exactly two choices, matching the brief's own "keep it
/// simple" instruction.
enum CoachVoicePreference { femaleDefault, systemDefault }

extension CoachVoicePreferenceLabel on CoachVoicePreference {
  String get label => switch (this) {
    CoachVoicePreference.femaleDefault => 'Female (Default)',
    CoachVoicePreference.systemDefault => 'System Default',
  };
}

enum CoachSpeechSpeed { slow, normal, fast }

extension CoachSpeechSpeedLabel on CoachSpeechSpeed {
  String get label => switch (this) {
    CoachSpeechSpeed.slow => 'Slow',
    CoachSpeechSpeed.normal => 'Normal',
    CoachSpeechSpeed.fast => 'Fast',
  };
}

/// 23h's 5 toggles + 2 selectors, exactly as the frame seeds them: the
/// first three toggles on, Nutrition Tips off (confirmed via the distinct
/// `toggle`/`toggle1` exported track assets), Encouraging + Regular
/// pre-selected. [voicePreference]/[speechSpeed]/[autoReadReplies] are the
/// female-AI-Coach-TTS additions — defaults match the brief exactly:
/// Female voice on, Normal speed, auto-read off.
class CoachSettingsState {
  const CoachSettingsState({
    this.proactiveCheckins = true,
    this.dailyMotivation = true,
    this.workoutSuggestions = true,
    this.nutritionTips = false,
    this.sleepReminders = true,
    this.personality = CoachPersonality.encouraging,
    this.frequency = NotificationFrequency.regular,
    this.voicePreference = CoachVoicePreference.femaleDefault,
    this.speechSpeed = CoachSpeechSpeed.normal,
    this.autoReadReplies = false,
  });

  final bool proactiveCheckins;
  final bool dailyMotivation;
  final bool workoutSuggestions;
  final bool nutritionTips;
  final bool sleepReminders;
  final CoachPersonality personality;
  final NotificationFrequency frequency;
  final CoachVoicePreference voicePreference;
  final CoachSpeechSpeed speechSpeed;
  final bool autoReadReplies;

  CoachSettingsState copyWith({
    bool? proactiveCheckins,
    bool? dailyMotivation,
    bool? workoutSuggestions,
    bool? nutritionTips,
    bool? sleepReminders,
    CoachPersonality? personality,
    NotificationFrequency? frequency,
    CoachVoicePreference? voicePreference,
    CoachSpeechSpeed? speechSpeed,
    bool? autoReadReplies,
  }) {
    return CoachSettingsState(
      proactiveCheckins: proactiveCheckins ?? this.proactiveCheckins,
      dailyMotivation: dailyMotivation ?? this.dailyMotivation,
      workoutSuggestions: workoutSuggestions ?? this.workoutSuggestions,
      nutritionTips: nutritionTips ?? this.nutritionTips,
      sleepReminders: sleepReminders ?? this.sleepReminders,
      personality: personality ?? this.personality,
      frequency: frequency ?? this.frequency,
      voicePreference: voicePreference ?? this.voicePreference,
      speechSpeed: speechSpeed ?? this.speechSpeed,
      autoReadReplies: autoReadReplies ?? this.autoReadReplies,
    );
  }
}

/// Per-TOD copy + the one optional widget each hub variant shows below the
/// Quick Actions row (368:2405 Progress-Widget on 23b, 368:2586
/// Night-Metrics-Card on 23d; 23a/23c show neither).
enum CoachHubWidget { none, todaysTarget, sleepTarget }

class CoachHubCopy {
  const CoachHubCopy({
    required this.emoji,
    required this.greeting,
    required this.tip,
    required this.widget,
  });

  final String emoji;
  final String greeting;
  final String tip;
  final CoachHubWidget widget;
}

/// Per-TOD Coach Tip copy — deliberately generic wellness suggestions with
/// no invented personal metrics (no percentages, no claimed personal
/// trends/effects). Glow Up has no real per-user tip-generation engine yet,
/// so this is Option B from the stale-hub remediation ("an honest generic
/// wellness tip that contains no invented personal metrics"), not a real
/// Brain-derived tip — see `CoachTipCard`.
const Map<TodPeriod, CoachHubCopy> kCoachHubCopy = {
  TodPeriod.morning: CoachHubCopy(
    emoji: '☀️',
    greeting: 'Good morning! Ready to glow?',
    tip:
        '"A few minutes of gentle stretching can be a simple way to start your day."',
    widget: CoachHubWidget.none,
  ),
  TodPeriod.afternoon: CoachHubCopy(
    emoji: '🌤',
    greeting: "Afternoon check-in! How's your energy?",
    tip:
        '"A short walk or stretch break can be a good way to reset your energy this afternoon."',
    widget: CoachHubWidget.todaysTarget,
  ),
  TodPeriod.evening: CoachHubCopy(
    emoji: '🌅',
    greeting: 'Evening wind-down time.',
    tip:
        '"A few slow breaths can help your body start easing into the evening."',
    widget: CoachHubWidget.none,
  ),
  TodPeriod.night: CoachHubCopy(
    emoji: '🌙',
    greeting: 'Time to rest and recover.',
    tip:
        '"Dimming the lights and relaxing your shoulders can help signal that it\'s time to rest."',
    widget: CoachHubWidget.sleepTarget,
  ),
};

const kCoachPlanItems = [
  CoachPlanItem(
    title: 'Fitness',
    subtitle: '3x HIIT, 2x Yoga',
    badgeLabel: '80% completed',
    colorHex: 0xFFFF5E97,
  ),
  CoachPlanItem(
    title: 'Nutrition',
    subtitle: '2000 cal target, 5 meals',
    badgeLabel: 'On track',
    colorHex: 0xFFFFD043,
  ),
  CoachPlanItem(
    title: 'Mindfulness',
    subtitle: 'Daily 10 min meditation',
    badgeLabel: '3 days streak',
    colorHex: 0xFFC084FC,
  ),
  CoachPlanItem(
    title: 'Hydration',
    subtitle: '8 glasses daily',
    badgeLabel: '6/8 glasses done',
    colorHex: 0xFF0AABEB,
  ),
];

const kMoodDayEntries = [
  MoodDayEntry(day: 15, emoji: '😊'),
  MoodDayEntry(day: 16, emoji: '⚡'),
  MoodDayEntry(day: 17, emoji: '😴'),
  MoodDayEntry(day: 18, emoji: '😊'),
  MoodDayEntry(day: 19, emoji: '✨'),
  MoodDayEntry(day: 20, emoji: '🥺', dimmed: true),
  MoodDayEntry(day: 21, emoji: '🤩'),
];
