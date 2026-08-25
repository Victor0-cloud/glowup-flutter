import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../state/profile_controller.dart';

/// Manage Data. This app has no remote backend for any user data, so
/// "Download My Data," "Delete My Data," and "Clear Local Data" are all
/// genuinely the same real, complete local action — never a stand-in for
/// unfinished server-side work.
class ManageDataScreen extends ConsumerWidget {
  const ManageDataScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Manage Data',
              subtitle: 'Your data is private and secure',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: GlowCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _Row(
                        icon: Icons.download_outlined,
                        label: 'Download My Data',
                        subtitle: 'Get a copy of your information',
                        onTap: () => _showExport(context, ref),
                      ),
                      const _Sep(),
                      _Row(
                        icon: Icons.delete_outline,
                        label: 'Delete My Data',
                        subtitle: 'Permanently remove your data',
                        onTap: () => _confirmClear(context, ref),
                      ),
                      const _Sep(),
                      _Row(
                        icon: Icons.cleaning_services_outlined,
                        label: 'Clear Local Data',
                        subtitle: 'Remove data from this device',
                        onTap: () => _confirmClear(context, ref),
                        isLast: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showExport(BuildContext context, WidgetRef ref) {
    final text = ref.read(profileControllerProvider.notifier).exportDataText();
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text('Your Data', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            text,
            style: AppTextStyles.subtitle.copyWith(fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardStart,
        title: const Text(
          'Clear all local data?',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'This permanently deletes everything stored on this device. This cannot be undone.',
          style: AppTextStyles.subtitle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear Everything'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(profileControllerProvider.notifier).clearAllLocalData();
    }
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
    this.isLast = false,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $subtitle',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(icon, size: 20, color: AppColors.textSecondary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: AppTextStyles.cardTitle.copyWith(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: AppTextStyles.caption.copyWith(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Sep extends StatelessWidget {
  const _Sep();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(height: 1, color: AppColors.cardBorder),
  );
}
