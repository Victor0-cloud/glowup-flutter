import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';

/// Connected Apps. No health/fitness OAuth integration exists anywhere in
/// this app (no Apple Health, Google Fit, Fitbit, Garmin, or Spotify SDK
/// is wired) — every entry honestly shows "Not connected." Onboarding's
/// `HealthConnections` flags are a UI preference collected at signup, not
/// a verified authorization, so they are never surfaced here as
/// "Connected."
class ConnectedAppsScreen extends StatelessWidget {
  const ConnectedAppsScreen({super.key, this.onBack});

  final VoidCallback? onBack;

  static const _apps = [
    ('Apple Health', Icons.favorite_border),
    ('Google Fit', Icons.directions_run),
    ('Fitbit', Icons.watch_outlined),
    ('Garmin', Icons.watch_outlined),
    ('Spotify', Icons.music_note_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Connected Apps',
              subtitle: 'Connect your favorite apps and devices',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  children: [
                    for (final app in _apps) ...[
                      _AppRow(name: app.$1, icon: app.$2),
                      const SizedBox(height: 10),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppRow extends StatelessWidget {
  const _AppRow({required this.name, required this.icon});
  final String name;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.textSecondary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.cardTitle.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Not connected',
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Connect $name',
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(100),
              child: InkWell(
                borderRadius: BorderRadius.circular(100),
                onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$name isn\'t available yet.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                ),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Center(
                    child: Text(
                      'Connect',
                      style: AppTextStyles.captionBold.copyWith(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
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
