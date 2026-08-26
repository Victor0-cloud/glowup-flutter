import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/coach_models.dart';
import '../state/coach_settings_controller.dart';
import '../theme/coach_identity.dart';
import '../state/coach_chat_controller.dart';
import '../state/coach_voice_input_controller.dart';
import '../theme/coach_variant_config.dart';
import '../voice/coach_voice_speaker.dart';
import '../widgets/chat_widgets.dart';

const _quickReplies = ['Show me a workout', 'Check my progress', 'Mood check'];

/// 23e_coach_chat (368:2674). Figma's header (368:2682) has no back
/// affordance and a broken fixed width (an 88px auto-layout container the
/// "AI Coach" title spills out of vertically in the live frame — a Figma
/// export glitch, not intended design). This reproduces the header's
/// intended full-width layout and adds a back button, since Chat is
/// reached by a forward push from the hub and needs a way back.
///
/// MVP freeze (owner decision, 2026-08-26): voice stays push-to-talk +
/// manual read-aloud only. A "continuous Voice Conversation Mode"
/// (auto-listen -> auto-send -> auto-speak -> auto-listen hands-free loop)
/// was built out in parallel elsewhere and explicitly rejected as not
/// reliable enough for MVP — do not reintroduce that state machine, its
/// panel widget, or its lifecycle hooks here without a fresh, explicit
/// go-ahead.
class CoachChatScreen extends ConsumerStatefulWidget {
  const CoachChatScreen({
    super.key,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onProfile,
    this.initialThreadId,
  });

  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  /// Set only when reached by tapping a specific real "Recent Chats" row
  /// on the hub — opens that exact persisted thread instead of whichever
  /// thread is most recent. Null for the ordinary "Chat" quick action.
  final String? initialThreadId;

  @override
  ConsumerState<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends ConsumerState<CoachChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  /// The id of the one message currently being read aloud, if any — drives
  /// the tapped bubble's speaker icon to a "stop" state (Section: "stop
  /// works", "selecting another reply stops previous speech").
  String? _speakingMessageId;

  @override
  void initState() {
    super.initState();
    final threadId = widget.initialThreadId;
    if (threadId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(coachChatControllerProvider.notifier).openThread(threadId);
      });
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// Section 2: tapping the speaker icon reads that reply aloud through the
  /// resolved female voice, honoring the current Speech Speed setting.
  /// Tapping the *same* message again while it's speaking stops it ("stop
  /// works"). [CoachVoiceSpeaker.speak] always stops whatever it was
  /// previously saying before starting a new utterance, so tapping a
  /// *different* message while one is speaking naturally satisfies
  /// "selecting another reply stops previous speech" too.
  Future<void> _toggleSpeak(String messageId, String text) async {
    final speaker = ref.read(coachVoiceSpeakerProvider);
    if (_speakingMessageId == messageId) {
      await speaker.stop();
      if (mounted) setState(() => _speakingMessageId = null);
      return;
    }
    // Section 9 (audio conflict management): TTS starting must stop any
    // active speech recognition — never let mic and speaker fight.
    await ref.read(coachVoiceInputControllerProvider.notifier).stopListening();
    setState(() => _speakingMessageId = messageId);
    final settings = ref.read(coachSettingsControllerProvider);
    await speaker.applySettings(
      preferFemale:
          settings.voicePreference == CoachVoicePreference.femaleDefault,
      speed: settings.speechSpeed,
    );
    await speaker.speak(text);
    if (mounted && _speakingMessageId == messageId) {
      setState(() => _speakingMessageId = null);
    }
  }

  /// Section 1/2/9 of the voice-input requirement: toggles listening on/
  /// off. Recognized *final* text is written into the same
  /// `_textController` the typed path uses (Section 7 — never a separate
  /// voice-only pipeline) and is never auto-sent (Section 2: "DO NOT
  /// automatically send partial speech"). Starting listening first stops
  /// any Coach speech currently playing (Section 9, the other direction).
  Future<void> _toggleMic() async {
    final voiceInput = ref.read(coachVoiceInputControllerProvider.notifier);
    if (ref.read(coachVoiceInputControllerProvider).status ==
        CoachListenStatus.listening) {
      await voiceInput.stopListening();
      return;
    }
    await voiceInput.startListening(
      onFinalResult: (text) {
        if (text.trim().isEmpty) return;
        _textController.text = text;
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      },
      onBeforeListen: () async {
        if (_speakingMessageId != null) {
          await ref.read(coachVoiceSpeakerProvider).stop();
          if (mounted) setState(() => _speakingMessageId = null);
        }
      },
    );
  }

  Future<void> _send(String text) async {
    if (text.trim().isEmpty) return;
    _textController.clear();
    await ref.read(coachChatControllerProvider.notifier).send(text);
    _scrollToBottom();
  }

  String _statusLabel(CoachConnectionStatus status) => switch (status) {
    CoachConnectionStatus.connecting => 'Connecting...',
    CoachConnectionStatus.connected => 'Connected',
    CoachConnectionStatus.thinking => 'Thinking...',
    CoachConnectionStatus.error => 'Error',
    CoachConnectionStatus.disconnected => 'Active Now',
  };

  /// Section 5: honest, non-repeating guidance on denial — shown once per
  /// transition into a non-listening terminal state, never looped.
  void _handleMicStatusChange(
    CoachListenStatus? previous,
    CoachListenStatus next,
  ) {
    if (previous == next) return;
    final message = switch (next) {
      CoachListenStatus.unavailable =>
        'Voice input isn\'t available on this device.',
      CoachListenStatus.permissionDenied =>
        'Microphone access is off. Enable it in Settings to use voice input.',
      CoachListenStatus.error => 'Voice input had a problem. Please try again.',
      _ => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        action: next == CoachListenStatus.permissionDenied
            ? SnackBarAction(
                label: 'Open Settings',
                onPressed: () => Geolocator.openAppSettings(),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(coachChatControllerProvider);
    final messages = chat.messages;
    ref.listen<CoachVoiceInputState>(
      coachVoiceInputControllerProvider,
      (previous, next) =>
          _handleMicStatusChange(previous?.status, next.status),
    );
    final micStatus = ref.watch(coachVoiceInputControllerProvider).status;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: const BoxDecoration(
                color: Color(0xFF181436),
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Semantics(
                    button: true,
                    label: 'Back',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: widget.onBack,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: AppIcon('chevron-left', size: 16),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const CoachAvatar(size: 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AI Coach',
                          style: AppTextStyles.screenTitleBlack.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (chat.status != CoachConnectionStatus.error)
                              const AppIcon('online-dot', size: 8)
                            else
                              const Icon(
                                Icons.error_outline,
                                size: 10,
                                color: AppColors.ctaStart,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              _statusLabel(chat.status),
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                                color:
                                    chat.status == CoachConnectionStatus.error
                                    ? AppColors.ctaStart
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: chat.status == CoachConnectionStatus.connecting
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.gold),
                    )
                  : SingleChildScrollView(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          for (var i = 0; i < messages.length; i++) ...[
                            ChatBubbleRow(
                              message: messages[i],
                              onFeedback: messages[i].sender == ChatSender.ai
                                  ? (rating) => ref
                                        .read(
                                          coachChatControllerProvider.notifier,
                                        )
                                        .sendFeedback(messages[i].id, rating)
                                  : null,
                              onSpeak: messages[i].sender == ChatSender.ai
                                  ? () => _toggleSpeak(
                                      messages[i].id,
                                      messages[i].text,
                                    )
                                  : null,
                              isSpeaking: _speakingMessageId == messages[i].id,
                            ),
                            if (i != messages.length - 1)
                              const SizedBox(height: 16),
                          ],
                          if (chat.status == CoachConnectionStatus.thinking)
                            const Padding(
                              padding: EdgeInsets.only(top: 16),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.gold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
            if (chat.status == CoachConnectionStatus.error)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.ctaStart.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.ctaStart.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.errorMessage ?? 'Something went wrong.',
                          style: AppTextStyles.caption.copyWith(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => ref
                            .read(coachChatControllerProvider.notifier)
                            .retry(),
                        child: Text(
                          'Try Again',
                          style: AppTextStyles.captionBold.copyWith(
                            color: AppColors.gold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final reply in _quickReplies)
                        ReplyChip(
                          label: reply,
                          onTap: chat.status == CoachConnectionStatus.thinking
                              ? null
                              : () => _send(reply),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ChatInputField(
                    controller: _textController,
                    // Section 7: one tap/send must create one message — the
                    // button (and Enter-to-send) is disabled for the whole
                    // round trip, not just re-entrant taps.
                    onSend: chat.status == CoachConnectionStatus.thinking
                        ? null
                        : () => _send(_textController.text),
                    micStatus: micStatus,
                    onMicTap: chat.status == CoachConnectionStatus.thinking
                        ? null
                        : _toggleMic,
                  ),
                ],
              ),
            ),
            BottomNavBar(
              active: AppNavTab.coach,
              activeAccent: CoachVariantConfig.navActiveColor,
              onTabSelected: (tab) {
                switch (tab) {
                  case AppNavTab.today:
                    widget.onToday();
                  case AppNavTab.routines:
                    widget.onRoutines();
                  case AppNavTab.coach:
                    break;
                  case AppNavTab.profile:
                    widget.onProfile();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
