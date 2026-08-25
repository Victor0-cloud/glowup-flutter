import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../models/today_models.dart';

/// 368:937 "Daily-Progress-Container". Bar fill color is the per-variant
/// accent (gold morning / purple afternoon+night / pink evening).
class DailyProgressCard extends StatelessWidget {
  const DailyProgressCard({
    super.key,
    required this.rows,
    required this.barColor,
  });

  final List<QuickActionStatus> rows;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DAILY PROGRESS',
            style: AppTextStyles.captionBold.copyWith(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          GlowCard(
            borderColor: AppColors.cardBorder,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  _ProgressRow(status: rows[i], barColor: barColor),
                  if (i != rows.length - 1) const SizedBox(height: 12),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({required this.status, required this.barColor});

  final QuickActionStatus status;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final doneText = status.done == status.done.roundToDouble()
        ? status.done.toInt().toString()
        : status.done.toString();
    final totalText = status.total == status.total.roundToDouble()
        ? status.total.toInt().toString()
        : status.total.toString();
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            status.label,
            style: AppTextStyles.fieldLabel.copyWith(fontSize: 14),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: status.fraction,
                minHeight: 8,
                backgroundColor: AppColors.cardEnd,
                valueColor: AlwaysStoppedAnimation(barColor),
              ),
            ),
          ),
        ),
        SizedBox(
          width: 60,
          child: RichText(
            textAlign: TextAlign.right,
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$doneText/$totalText ',
                  style: AppTextStyles.fieldLabel.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextSpan(
                  text: status.unit,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0x99B0B5E3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
