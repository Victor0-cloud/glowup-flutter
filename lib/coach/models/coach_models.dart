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

/// One row in the hub's "Recent Chats" list (368:2327 etc). Figma doesn't
/// wire these to distinct threads — tapping any of them opens the single
/// 23e chat screen, which is the only conversation surface the design
/// defines.
class ConversationPreview {
  const ConversationPreview({
    required this.avatarEmoji,
    required this.title,
    required this.preview,
    required this.timeLabel,
  });

  final String avatarEmoji;
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

/// 23h's 5 toggles + 2 selectors, exactly as the frame seeds them: the
/// first three toggles on, Nutrition Tips off (confirmed via the distinct
/// `toggle`/`toggle1` exported track assets), Encouraging + Regular
/// pre-selected.
class CoachSettingsState {
  const CoachSettingsState({
    this.proactiveCheckins = true,
    this.dailyMotivation = true,
    this.workoutSuggestions = true,
    this.nutritionTips = false,
    this.sleepReminders = true,
    this.personality = CoachPersonality.encouraging,
    this.frequency = NotificationFrequency.regular,
  });

  final bool proactiveCheckins;
  final bool dailyMotivation;
  final bool workoutSuggestions;
  final bool nutritionTips;
  final bool sleepReminders;
  final CoachPersonality personality;
  final NotificationFrequency frequency;

  CoachSettingsState copyWith({
    bool? proactiveCheckins,
    bool? dailyMotivation,
    bool? workoutSuggestions,
    bool? nutritionTips,
    bool? sleepReminders,
    CoachPersonality? personality,
    NotificationFrequency? frequency,
  }) {
    return CoachSettingsState(
      proactiveCheckins: proactiveCheckins ?? this.proactiveCheckins,
      dailyMotivation: dailyMotivation ?? this.dailyMotivation,
      workoutSuggestions: workoutSuggestions ?? this.workoutSuggestions,
      nutritionTips: nutritionTips ?? this.nutritionTips,
      sleepReminders: sleepReminders ?? this.sleepReminders,
      personality: personality ?? this.personality,
      frequency: frequency ?? this.frequency,
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

const Map<TodPeriod, CoachHubCopy> kCoachHubCopy = {
  TodPeriod.morning: CoachHubCopy(
    emoji: '☀️',
    greeting: 'Good morning! Ready to glow?',
    tip:
        '"Your morning workouts boost energy by 40%. Start your day with 5 minutes of stretching."',
    widget: CoachHubWidget.none,
  ),
  TodPeriod.afternoon: CoachHubCopy(
    emoji: '🌤',
    greeting: "Afternoon check-in! How's your energy?",
    tip:
        '"You\'re 60% through today\'s goals — keep going! A quick walk outside now will defeat that afternoon slump."',
    widget: CoachHubWidget.todaysTarget,
  ),
  TodPeriod.evening: CoachHubCopy(
    emoji: '🌅',
    greeting: 'Evening wind-down time.',
    tip:
        '"Great job on today\'s workout! Tomorrow try adding 5 min stretching. Let\'s make sure tonight is calm."',
    widget: CoachHubWidget.none,
  ),
  TodPeriod.night: CoachHubCopy(
    emoji: '🌙',
    greeting: 'Time to rest and recover.',
    tip:
        '"You completed 85% of today\'s goals. Sleep well! Dim your lights now to boost natural melatonin."',
    widget: CoachHubWidget.sleepTarget,
  ),
};

const Map<TodPeriod, List<ConversationPreview>> kCoachRecentChats = {
  TodPeriod.morning: [
    ConversationPreview(
      avatarEmoji: '🤖',
      title: 'AI Mascot',
      preview: 'Awesome job on completing your Morning Stretch today!',
      timeLabel: '9:00 AM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Weekly Plan',
      preview: 'Your personalized wellness schedule has been finalized.',
      timeLabel: '8:15 AM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Daily Spark',
      preview: 'Remember to drink a full glass of water first thing.',
      timeLabel: '7:00 AM',
    ),
  ],
  TodPeriod.afternoon: [
    ConversationPreview(
      avatarEmoji: '🤖',
      title: 'AI Mascot',
      preview: 'You are doing great! Ready for your afternoon check-in?',
      timeLabel: '2:30 PM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Hydration Alert',
      preview: 'Time for glass #5. Keep those hydration targets on track.',
      timeLabel: '1:45 PM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Stretch Partner',
      preview: 'Quick desk stretch scheduled in 5 minutes.',
      timeLabel: '1:00 PM',
    ),
  ],
  TodPeriod.evening: [
    ConversationPreview(
      avatarEmoji: '🤖',
      title: 'AI Mascot',
      preview: "Wonderful evening! Let's reflect on your routine success.",
      timeLabel: '7:00 PM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Wind Down Prep',
      preview: 'Optimal breathing exercises prepared for tonight.',
      timeLabel: '6:15 PM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Wellness Reflection',
      preview: 'What made you smile today? Share with me.',
      timeLabel: '5:30 PM',
    ),
  ],
  TodPeriod.night: [
    ConversationPreview(
      avatarEmoji: '🤖',
      title: 'AI Mascot',
      preview: 'Rest is just as critical as training. Sleep well!',
      timeLabel: '10:30 PM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Sleep Prep',
      preview: 'Soft ambient music tracks selected for tonight.',
      timeLabel: '9:45 PM',
    ),
    ConversationPreview(
      avatarEmoji: '✨',
      title: 'Gratitude Journal',
      preview: 'Log your reflections before shutting down.',
      timeLabel: '9:00 PM',
    ),
  ],
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
