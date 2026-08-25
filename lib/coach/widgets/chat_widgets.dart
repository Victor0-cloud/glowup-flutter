import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/app_icon.dart';
import '../models/coach_models.dart';

/// Assistant/restored-historical timestamps arrive as UTC (Supabase
/// `timestamptz` — see `RemoteCoachBrainService`/`CoachThreadRepository`),
/// while a fresh local optimistic user bubble uses `DateTime.now()`
/// (already local). Formatting must always go through `.toLocal()` first
/// so every bubble reads in the device's local time regardless of origin
/// — the stored UTC value itself is never altered, only this display.
String _timeLabel(DateTime t) {
  final local = t.toLocal();
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  final period = local.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
}

/// One 23e chat bubble. `system` messages (the "not connected yet" notice)
/// render as a centered plain caption with no avatar/bubble chrome, so
/// they read unmistakably as app copy rather than a fabricated AI reply.
class ChatBubbleRow extends StatelessWidget {
  const ChatBubbleRow({super.key, required this.message, this.onFeedback});

  final ChatMessage message;

  /// Non-null only for real assistant messages — see
  /// `CoachChatScreen`. Never shown on user/system bubbles.
  final ValueChanged<int>? onFeedback;

  @override
  Widget build(BuildContext context) {
    if (message.sender == ChatSender.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Center(
          child: Text(
            message.text,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              fontSize: 12,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }

    final isUser = message.sender == ChatSender.user;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isUser ? AppColors.purple : const Color(0xFF181436),
        border: isUser ? null : Border.all(color: AppColors.cardBorder),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(16),
          topRight: const Radius.circular(16),
          bottomLeft: Radius.circular(isUser ? 16 : 4),
          bottomRight: Radius.circular(isUser ? 4 : 16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message.text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 20 / 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _timeLabel(message.sentAt),
            textAlign: TextAlign.right,
            style: TextStyle(
              color: Colors.white.withValues(alpha: isUser ? 0.5 : 0.6),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );

    if (isUser) {
      return Align(alignment: Alignment.centerRight, child: bubble);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: Color(0xFF181436),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Text('🤖', style: TextStyle(fontSize: 14)),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              bubble,
              if (onFeedback != null) ...[
                const SizedBox(height: 4),
                _FeedbackRow(rating: message.feedback, onFeedback: onFeedback!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Thumbs-up/thumbs-down for a real assistant message — writes to
/// `coach_feedback` (see `CoachChatController.sendFeedback`). [rating]
/// reflects what's actually persisted (or optimistically in flight);
/// never shown on a message that isn't a real, persisted assistant reply.
class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({required this.rating, required this.onFeedback});

  final int? rating;
  final ValueChanged<int> onFeedback;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _FeedbackButton(
            icon: Icons.thumb_up_outlined,
            selected: rating == 1,
            onTap: () => onFeedback(1),
          ),
          const SizedBox(width: 4),
          _FeedbackButton(
            icon: Icons.thumb_down_outlined,
            selected: rating == -1,
            onTap: () => onFeedback(-1),
          ),
        ],
      ),
    );
  }
}

class _FeedbackButton extends StatelessWidget {
  const _FeedbackButton({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Rate this reply',
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 14,
            color: selected
                ? AppColors.gold
                : Colors.white.withValues(alpha: 0.4),
          ),
        ),
      ),
    );
  }
}

/// A "Show me a workout" style quick-reply chip (368:2709) — tapping one
/// sends its label as a real outgoing message through the same pipeline
/// as typed text.
class ReplyChip extends StatelessWidget {
  const ReplyChip({super.key, required this.label, required this.onTap});

  final String label;

  /// Null while a send/retry is in flight — see `CoachChatScreen`.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: const Color(0xFF181436),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder),
            ),
            child: Text(
              label,
              style: AppTextStyles.captionBold.copyWith(
                color: AppColors.gold,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The "Ask me anything..." input + send button (368:2715).
class ChatInputField extends StatelessWidget {
  const ChatInputField({
    super.key,
    required this.controller,
    required this.onSend,
  });

  final TextEditingController controller;

  /// Null while a send/retry is already in flight — Section 7: "Disable
  /// the send button while the same request is in-flight." Disables both
  /// the send button and Enter-to-send.
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final enabled = onSend != null;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF181436),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              onSubmitted: enabled ? (_) => onSend!() : null,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Ask me anything...',
                hintStyle: AppTextStyles.subtitle.copyWith(fontSize: 14),
                border: InputBorder.none,
                isCollapsed: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Opacity(
            opacity: enabled ? 1 : 0.5,
            child: Semantics(
              button: true,
              label: 'Send',
              child: Material(
                color: AppColors.gold,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onSend,
                  child: const SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: AppIcon('arrow-right', size: 16)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
