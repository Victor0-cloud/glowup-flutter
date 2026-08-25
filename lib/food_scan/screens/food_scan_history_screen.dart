import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../models/food_scan_models.dart';
import '../state/food_scan_controller.dart';

/// Confirmed-meal history with real delete controls (both the entry and
/// its private image, if any) — an honest empty state, never fabricated
/// rows.
class FoodScanHistoryScreen extends ConsumerWidget {
  const FoodScanHistoryScreen({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(foodScanControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Meal History',
              subtitle: 'Every meal you\'ve confirmed',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: entries.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load your meal history. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (list) => _HistoryBody(entries: list),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryBody extends ConsumerWidget {
  const _HistoryBody({required this.entries});
  final List<FoodScanEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (entries.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.restaurant_outlined,
                size: 36,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text('No meals logged yet', style: AppTextStyles.cardTitle),
              const SizedBox(height: 6),
              Text(
                'Confirmed meals will show up here.',
                style: AppTextStyles.subtitle,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final sorted = [...entries]
      ..sort((a, b) => b.confirmedAt.compareTo(a.confirmedAt));
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      itemCount: sorted.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final entry = sorted[index];
        return GlowCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.imagePath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: File(entry.imagePath!).existsSync()
                      ? Image.file(
                          File(entry.imagePath!),
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: 48,
                          height: 48,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                ),
              if (entry.imagePath != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.items.map((i) => i.name).join(', '),
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullDate(entry.confirmedAt),
                      style: AppTextStyles.cardSubtitle,
                    ),
                    if (entry.totalEstimatedCalories != null)
                      Text(
                        '~${entry.totalEstimatedCalories} cal (estimate)',
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Delete meal',
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => ref
                      .read(foodScanControllerProvider.notifier)
                      .deleteEntry(entry.id),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _fullDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day} · $hour12:${d.minute.toString().padLeft(2, '0')} $period';
  }
}
