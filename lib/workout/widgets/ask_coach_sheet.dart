import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../brain/safety/safety_flag.dart';
import '../../brain/safety/safety_flag_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../routine_player/models/exercise_definition.dart';
import '../coach/exercise_coach_answer_service.dart';
import '../state/exercise_feedback_events.dart';

/// "Ask Coach about this exercise…" — bounded to exactly one exercise's
/// approved data (see `answerExerciseQuestion`). Opened from the active
/// exercise screen; never blocks playback since it's a dismissible sheet.
Future<void> showAskCoachSheet(
  BuildContext context,
  WidgetRef ref, {
  required ExerciseDefinition exercise,
  String? sessionId,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) =>
        _AskCoachSheet(exercise: exercise, sessionId: sessionId),
  );
}

class _AskCoachSheet extends ConsumerStatefulWidget {
  const _AskCoachSheet({required this.exercise, this.sessionId});
  final ExerciseDefinition exercise;
  final String? sessionId;

  @override
  ConsumerState<_AskCoachSheet> createState() => _AskCoachSheetState();
}

class _AskCoachSheetState extends ConsumerState<_AskCoachSheet> {
  final _controller = TextEditingController();
  String? _answer;
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SafetyFlag> _activeFlagsForExercise() {
    final flags =
        ref.read(safetyFlagControllerProvider).valueOrNull ?? const [];
    return flags.where((f) => f.exerciseId == widget.exercise.id).toList();
  }

  Future<void> _ask(String questionCode, {String? freeText}) async {
    final answer = answerExerciseQuestion(
      exercise: widget.exercise,
      questionCode: questionCode,
      activeSafetyFlagsForExercise: _activeFlagsForExercise(),
    );
    setState(() {
      _sending = true;
      _answer = answer;
    });
    await submitExerciseQuestionAsked(
      ref: ref,
      exerciseId: widget.exercise.id,
      questionCode: questionCode,
      freeTextQuestion: freeText,
      sessionId: widget.sessionId,
    );
    if (mounted) setState(() => _sending = false);
  }

  void _askFreeText() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final code = matchFreeTextQuestionCode(text);
    _controller.clear();
    _ask(code, freeText: text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.cardStart, AppColors.bgBottom],
          ),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.fromBorderSide(
            BorderSide(color: AppColors.cardBorder),
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ask Coach about ${widget.exercise.displayName}',
                style: AppTextStyles.screenTitle.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final q in kExerciseCoachQuestions)
                    Semantics(
                      button: true,
                      label: q.label,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(100),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(100),
                          onTap: _sending ? null : () => _ask(q.code),
                          child: Container(
                            constraints: const BoxConstraints(minHeight: 44),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(100),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Text(
                              q.label,
                              style: AppTextStyles.caption.copyWith(
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      label: 'Ask Coach about this exercise',
                      textField: true,
                      child: TextField(
                        controller: _controller,
                        style: AppTextStyles.subtitle.copyWith(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Ask Coach about this exercise…',
                          hintStyle: AppTextStyles.caption,
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.05),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 12,
                          ),
                        ),
                        onSubmitted: (_) => _askFreeText(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Semantics(
                    button: true,
                    label: 'Send question',
                    child: Material(
                      color: AppColors.blue,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: _sending ? null : _askFreeText,
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(
                            Icons.send,
                            size: 20,
                            color: Color(0xFF0A0B1E),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_answer != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    _answer!,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
