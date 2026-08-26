import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../brain/coach_brain_context.dart';
import '../brain/coach_brain_service.dart';
import '../config/coach_backend_config.dart';
import '../data/coach_feedback_repository.dart';
import '../data/coach_thread_repository.dart';
import '../models/coach_models.dart';
import '../voice/coach_voice_speaker.dart';
import 'coach_settings_controller.dart';
import 'coach_voice_input_controller.dart';

/// Truthful, user-visible connection states (Section H) — never displays
/// the legacy "AI Brain not connected yet" copy once a backend is
/// actually configured; that copy is reserved for [disconnected].
enum CoachConnectionStatus {
  /// A backend is configured and the most recent thread/history is still
  /// being restored from Supabase.
  connecting,

  /// Idle and ready — the last request (if any) succeeded.
  connected,

  /// A `send()` is in flight.
  thinking,

  /// A backend is configured, a request was actually attempted, and it
  /// failed (network/rate-limit/provider) — see [errorMessage].
  error,

  /// No backend is configured at all (dev/test build without
  /// SUPABASE_URL/ANON_KEY) — the one state where the legacy seed
  /// conversation and "not connected yet" notice are shown.
  disconnected,
}

class CoachChatState {
  const CoachChatState({
    required this.messages,
    required this.status,
    this.threadId,
    this.errorMessage,
    this.lastFailedUserMessage,
  });

  final List<ChatMessage> messages;
  final CoachConnectionStatus status;
  final String? threadId;
  final String? errorMessage;

  /// The exact text of the message that just failed to send — lets "Try
  /// Again" resend precisely that text, never a guess.
  final String? lastFailedUserMessage;

  CoachChatState copyWith({
    List<ChatMessage>? messages,
    CoachConnectionStatus? status,
    String? threadId,
    bool clearThreadId = false,
    String? errorMessage,
    bool clearError = false,
    String? lastFailedUserMessage,
    bool clearLastFailedUserMessage = false,
  }) => CoachChatState(
    messages: messages ?? this.messages,
    status: status ?? this.status,
    threadId: clearThreadId ? null : (threadId ?? this.threadId),
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    lastFailedUserMessage: clearLastFailedUserMessage
        ? null
        : (lastFailedUserMessage ?? this.lastFailedUserMessage),
  );
}

/// Seeds the 23e thread with the exact 3-message conversation shown on the
/// approved frame — illustrative history, same pattern as Routines'
/// completion seed, not something the user "sent." Only ever used when
/// [CoachBackendConfig.isConfigured] is false (see [CoachChatState]'s
/// [CoachConnectionStatus.disconnected]) — a real, configured backend
/// always starts from the user's real (possibly empty) history instead.
List<ChatMessage> _seedThread() {
  final base = DateTime.now().subtract(const Duration(hours: 1));
  return [
    ChatMessage(
      id: 'seed-1',
      sender: ChatSender.ai,
      text:
          'Great job completing your Morning Yoga Flow, Mia! Ready to tackle your targets?',
      sentAt: base,
    ),
    ChatMessage(
      id: 'seed-2',
      sender: ChatSender.user,
      text:
          'Yes! I want a workout suggestion to burn a few extra calories today. Something short but intense.',
      sentAt: base.add(const Duration(minutes: 2)),
    ),
    ChatMessage(
      id: 'seed-3',
      sender: ChatSender.ai,
      text:
          "I highly recommend a 15-minute HIIT Blast session. It's fast-paced, pumps up your heart rate, and keeps your glow on peak today!",
      sentAt: base.add(const Duration(minutes: 3)),
    ),
  ];
}

/// Owns the single 23e conversation thread. When a real backend is
/// configured, this restores the user's actual thread/messages from
/// Supabase on startup (Section I: conversation must survive navigation
/// *and* app restarts, not just live in memory) and every `send()` goes
/// through the real, deployed `coach-chat` Edge Function.
class CoachChatController extends StateNotifier<CoachChatState> {
  CoachChatController(
    this._brain,
    this._contextRead,
    this._threadRepository,
    this._feedbackRepository, [
    this._onAssistantReply,
  ]) : super(
        CoachBackendConfig.isConfigured
            ? const CoachChatState(
                messages: [],
                status: CoachConnectionStatus.connecting,
              )
            : CoachChatState(
                messages: _seedThread(),
                status: CoachConnectionStatus.disconnected,
              ),
      ) {
    if (CoachBackendConfig.isConfigured) _init();
  }

  final CoachBrainService _brain;
  final CoachBrainContext? Function() _contextRead;
  final CoachThreadRepository _threadRepository;
  final CoachFeedbackRepository _feedbackRepository;

  /// Fired once per genuinely new assistant reply (never for restored
  /// history on `_init`/`openThread`) — wired by the provider below to
  /// honor Auto-read Replies (Section 3 of the female-voice requirement:
  /// "Auto-read replies — Off by default, On optional").
  final void Function(String text)? _onAssistantReply;

  Future<void> _init() async {
    final loaded = await _threadRepository.loadMostRecentThread();
    state = state.copyWith(
      messages: loaded.messages,
      threadId: loaded.threadId,
      status: CoachConnectionStatus.connected,
    );
  }

  /// Loads a specific real, persisted thread — used when the hub's
  /// "Recent Chats" row for an older (not-most-recent) conversation is
  /// tapped, so it opens that actual conversation rather than always
  /// falling back to whichever thread is most recent. A no-op if [threadId]
  /// already matches the thread currently shown.
  Future<void> openThread(String threadId) async {
    if (!CoachBackendConfig.isConfigured || threadId == state.threadId) {
      return;
    }
    state = state.copyWith(status: CoachConnectionStatus.connecting);
    final loaded = await _threadRepository.loadThread(threadId);
    state = state.copyWith(
      messages: loaded.messages,
      threadId: loaded.threadId,
      status: CoachConnectionStatus.connected,
    );
  }

  /// True while a send/retry is in flight — the screen disables the send
  /// button on this so one tap can never fire two overlapping requests
  /// (Section 7: "Disable the send button while the same request is
  /// in-flight").
  bool get isSending => state.status == CoachConnectionStatus.thinking;

  Future<void> send(String text) async {
    if (isSending) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final userMessage = ChatMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      sender: ChatSender.user,
      text: trimmed,
      sentAt: DateTime.now(),
    );
    state = state.copyWith(
      messages: [...state.messages, userMessage],
      status: CoachConnectionStatus.thinking,
      clearError: true,
      clearLastFailedUserMessage: true,
    );
    await _sendToBackend(trimmed);
  }

  /// Retries exactly the text that just failed — see
  /// [CoachChatState.lastFailedUserMessage]. Never appends a new local
  /// user bubble: the original attempt's bubble is already in
  /// [CoachChatState.messages] from when [send] first added it, and the
  /// Edge Function itself is retry-safe (it reuses the already-persisted
  /// user message row for an identical immediate retry rather than
  /// inserting a second copy — see coach-chat/index.ts step 7). Appending
  /// another local bubble here is exactly the duplicate-message bug this
  /// method exists to avoid.
  Future<void> retry() async {
    if (isSending) return;
    final text = state.lastFailedUserMessage;
    if (text == null) return;
    state = state.copyWith(
      status: CoachConnectionStatus.thinking,
      clearError: true,
      clearLastFailedUserMessage: true,
    );
    await _sendToBackend(text);
  }

  Future<void> _sendToBackend(String userMessage) async {
    final result = await _brain.respond(
      context: _contextRead(),
      conversation: state.messages,
      userMessage: userMessage,
      threadId: state.threadId,
    );

    switch (result) {
      case CoachBrainSuccess(:final message, :final threadId):
        state = state.copyWith(
          messages: [...state.messages, message],
          threadId: threadId,
          status: CoachConnectionStatus.connected,
        );
        _onAssistantReply?.call(message.text);
      case CoachBrainUnavailable():
        state = state.copyWith(
          messages: [
            ...state.messages,
            ChatMessage(
              id: 'system-${DateTime.now().microsecondsSinceEpoch}',
              sender: ChatSender.system,
              text:
                  "🧠 AI Brain not connected yet — your message was saved to context. Real coaching replies will appear here once it's live.",
              sentAt: DateTime.now(),
            ),
          ],
          status: CoachConnectionStatus.disconnected,
        );
      case CoachBrainError(:final message, :final threadId):
        state = state.copyWith(
          status: CoachConnectionStatus.error,
          errorMessage: message,
          lastFailedUserMessage: userMessage,
          // If the failure happened after the server already created/
          // resolved a thread (see coach-chat/index.ts), remember it so
          // retry() continues that same thread instead of leaving
          // state.threadId null and causing the server to start a brand
          // new, orphaned one.
          threadId: threadId,
        );
    }
  }

  /// [rating] must be -1 or 1. Optimistically updates local state; if the
  /// write fails (message not real/owned, network failure), the local
  /// state is reverted so the UI never shows a rating that wasn't
  /// actually saved.
  Future<void> sendFeedback(String messageId, int rating) async {
    final index = state.messages.indexWhere((m) => m.id == messageId);
    if (index == -1) return;
    final previous = state.messages[index];
    final optimistic = [...state.messages];
    optimistic[index] = previous.copyWith(feedback: rating);
    state = state.copyWith(messages: optimistic);

    final ok = await _feedbackRepository.submit(
      messageId: messageId,
      rating: rating,
    );
    if (!ok) {
      final reverted = [...state.messages];
      final currentIndex = reverted.indexWhere((m) => m.id == messageId);
      if (currentIndex != -1) {
        reverted[currentIndex] = previous;
        state = state.copyWith(messages: reverted);
      }
    }
  }
}

final coachThreadRepositoryProvider = Provider<CoachThreadRepository>(
  (ref) => CoachThreadRepository(),
);

final coachFeedbackRepositoryProvider = Provider<CoachFeedbackRepository>(
  (ref) => CoachFeedbackRepository(),
);

final coachChatControllerProvider =
    StateNotifierProvider<CoachChatController, CoachChatState>((ref) {
      final brain = ref.watch(coachBrainServiceProvider);
      return CoachChatController(
        brain,
        () => ref.read(coachBrainContextProvider),
        ref.watch(coachThreadRepositoryProvider),
        ref.watch(coachFeedbackRepositoryProvider),
        (text) {
          final settings = ref.read(coachSettingsControllerProvider);
          if (!settings.autoReadReplies) return;
          final speaker = ref.read(coachVoiceSpeakerProvider);
          // Section 9 (audio conflict management): auto-read starting TTS
          // must stop any active speech recognition first.
          unawaited(
            ref
                .read(coachVoiceInputControllerProvider.notifier)
                .stopListening()
                .then(
                  (_) => speaker
                      .applySettings(
                        preferFemale:
                            settings.voicePreference ==
                            CoachVoicePreference.femaleDefault,
                        speed: settings.speechSpeed,
                      )
                      .then((_) => speaker.speak(text)),
                ),
          );
        },
      );
    });

/// Real recent-thread summaries for the Coach hub's "Recent Chats" list
/// (Section 5 of the stale-hub remediation) — refetched fresh every time
/// the hub screen is opened (`autoDispose`), rather than cached forever,
/// so a just-sent message shows up next time the hub is visited. Returns
/// an empty list (rendered as an honest empty state, never fabricated
/// rows) when no backend is configured or the user has no threads yet.
final coachRecentThreadsProvider =
    FutureProvider.autoDispose<List<CoachThreadSummary>>((ref) async {
      if (!CoachBackendConfig.isConfigured) return const [];
      final repo = ref.watch(coachThreadRepositoryProvider);
      return repo.loadRecentThreadSummaries();
    });
