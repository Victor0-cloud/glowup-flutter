import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tod/tod_period.dart';
import '../theme/app_text_styles.dart';

/// Debug-only TOD override control — extracted from Today's own original
/// private copy so every screen with time-of-day variants (Today, Water
/// Tracker, ...) shares the exact same widget/state instead of each
/// re-implementing it. Never rendered when [kDebugMode] is false (the
/// caller is responsible for that gate, matching Today's own usage), so
/// it cannot appear in a release/production build.
class DevTodPicker extends ConsumerWidget {
  const DevTodPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final override = ref.watch(devTodPeriodOverrideProvider);
    final actual = ref.watch(currentTodPeriodProvider);
    return Container(
      width: double.infinity,
      color: Colors.black.withValues(alpha: 0.35),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Text('DEV TOD:', style: AppTextStyles.caption.copyWith(fontSize: 10)),
          const SizedBox(width: 6),
          Expanded(
            child: Wrap(
              spacing: 6,
              children: [
                for (final p in TodPeriod.values)
                  _DevChip(
                    label: p.name,
                    selected: actual == p && override != null,
                    onTap: () =>
                        ref.read(devTodPeriodOverrideProvider.notifier).state =
                            p,
                  ),
                _DevChip(
                  label: 'auto',
                  selected: override == null,
                  onTap: () =>
                      ref.read(devTodPeriodOverrideProvider.notifier).state =
                          null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DevChip extends StatelessWidget {
  const _DevChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
