import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/bottom_nav_bar.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/coach_models.dart';
import '../state/coach_chat_controller.dart';
import '../theme/coach_variant_config.dart';
import '../widgets/chat_widgets.dart';

const _quickReplies = ['Show me a workout', 'Check my progress', 'Mood check'];

/// 23e_coach_chat (368:2674). Figma's header (368:2682) has no back
/// affordance and a broken fixed width (an 88px auto-layout container the
/// "AI Coach" title spills out of vertically in the live frame — a Figma
/// export glitch, not intended design). This reproduces the header's
/// intended full-width layout and adds a back button, since Chat is
/// reached by a forward push from the hub and needs a way back.
class CoachChatScreen extends ConsumerStatefulWidget {
  const CoachChatScreen({
    super.key,
    required this.onBack,
    required this.onToday,
    required this.onRoutines,
    required this.onProfile,
  });

  final VoidCallback onBack;
  final VoidCallback onToday;
  final VoidCallback onRoutines;
  final VoidCallback onProfile;

  @override
  ConsumerState<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends ConsumerState<CoachChatScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

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

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(coachChatControllerProvider);
    final messages = chat.messages;

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
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.cardStart, AppColors.cardEnd],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    alignment: Alignment.center,
                    child: const Text('🤖', style: TextStyle(fontSize: 20)),
                  ),
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
