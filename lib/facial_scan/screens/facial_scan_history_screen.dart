import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../../scan/widgets/scan_image_preview.dart';
import '../models/facial_scan_models.dart';
import '../state/facial_scan_controller.dart';

/// Check-in history with real delete controls — comparison-ready in the
/// sense that every entry keeps its own timestamp and photo (if any) in
/// order, so a future "compare over time" view has real data to read;
/// nothing here computes or displays any score/trend, since this app
/// makes no such assessment.
class FacialScanHistoryScreen extends ConsumerWidget {
  const FacialScanHistoryScreen({super.key, this.onBack});
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scanState = ref.watch(facialScanControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Check-In History',
              subtitle: 'Your private wellness check-ins',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: scanState.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.blue),
                ),
                error: (err, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load Skin & Acne Scan history. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (data) => _HistoryBody(entries: data.entries),
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
  final List<FacialCheckIn> entries;

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
                Icons.face_retouching_natural_outlined,
                size: 36,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              Text('No check-ins yet', style: AppTextStyles.cardTitle),
              const SizedBox(height: 6),
              Text(
                'Confirmed check-ins will show up here.',
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
                  child: ScanImagePreview(
                    path: entry.imagePath!,
                    width: 48,
                    height: 48,
                    showNotFoundLabel: false,
                  ),
                ),
              if (entry.imagePath != null) const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.selfReportedAreas.isEmpty
                          ? 'Check-in'
                          : entry.selfReportedAreas.join(', '),
                      style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _fullDate(entry.confirmedAt),
                      style: AppTextStyles.cardSubtitle,
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Delete check-in',
                child: IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () => ref
                      .read(facialScanControllerProvider.notifier)
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
