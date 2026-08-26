import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/sub_screen_header.dart';
import '../data/step_source.dart';
import '../models/walking_models.dart';
import '../state/walking_controller.dart';
import '../widgets/step_progress_ring.dart';

/// Walking Home — Section 1 of the standalone Walking & Steps feature.
/// Today's real step count (phone sensor only, never Fitbit/Apple Watch),
/// goal progress, Start Walk, recent walks, and a weekly summary. An
/// unsupported step sensor (e.g. this Windows dev build) shows an honest
/// "not available on this device" state — the module stays visible
/// either way (never hidden), and "Start Walk" still works for real GPS
/// distance/pace even where steps aren't available.
class WalkingHomeScreen extends ConsumerWidget {
  const WalkingHomeScreen({super.key, this.onBack, required this.onStartWalk});

  final VoidCallback? onBack;
  final void Function(WalkRoutine? routine) onStartWalk;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final walkingAsync = ref.watch(walkingControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: Column(
          children: [
            SubScreenHeader(
              title: 'Walking & Steps',
              subtitle: 'Real steps from your phone — no wearable needed',
              onBack: onBack ?? () => Navigator.maybePop(context),
            ),
            Expanded(
              child: walkingAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.gold),
                ),
                error: (e, st) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      "Couldn't load Walking & Steps. Please restart the app.",
                      style: AppTextStyles.subtitle,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                data: (walkingState) => SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                  child: _Body(state: walkingState, onStartWalk: onStartWalk),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.onStartWalk});

  final WalkingState state;
  final void Function(WalkRoutine? routine) onStartWalk;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Column(
            children: [
              StepProgressRing(steps: state.todaySteps, goal: state.goal),
              const SizedBox(height: 12),
              if (state.stepCapability != StepSourceCapability.available)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _capabilityMessage(state.stepCapability),
                    style: AppTextStyles.caption.copyWith(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: Material(
            color: AppColors.gold,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showRoutinePicker(context),
              child: const Center(
                child: Text(
                  'Start Walk',
                  style: TextStyle(
                    color: Color(0xFF0A0B1E),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'This week',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        GlowCard(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeeklyStat(
                label: 'Walks',
                value: '${state.sessionsThisWeek.length}',
              ),
              _WeeklyStat(
                label: 'Steps (walks)',
                value: '${state.stepsThisWeekFromSessions}',
              ),
              _WeeklyStat(
                label: 'Time',
                value: _formatDuration(
                  state.sessionsThisWeek.fold<int>(0, (sum, s) => sum + s.durationSeconds),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Recent walks',
          style: AppTextStyles.captionBold.copyWith(
            color: AppColors.textSecondary,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 10),
        if (state.recentSessions.isEmpty)
          GlowCard(
            child: Text(
              'No walks yet. Tap "Start Walk" to log your first one.',
              style: AppTextStyles.subtitle.copyWith(fontSize: 13),
            ),
          )
        else
          for (final session in state.recentSessions.take(10)) ...[
            _WalkSessionRow(session: session),
            const SizedBox(height: 10),
          ],
      ],
    );
  }

  void _showRoutinePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _RoutinePickerSheet(onSelect: onStartWalk),
    );
  }

  static String _capabilityMessage(StepSourceCapability capability) => switch (capability) {
    StepSourceCapability.available => '',
    StepSourceCapability.unsupportedPlatform =>
      'Step counting isn\'t available on this device. You can still start a walk to track time and distance.',
    StepSourceCapability.permissionDenied =>
      'Motion & fitness access is needed for step counting. You can still start a walk to track time and distance.',
    StepSourceCapability.sensorUnavailable =>
      'The step sensor isn\'t responding right now. You can still start a walk to track time and distance.',
  };

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes < 60) return '${minutes}m';
    final hours = minutes ~/ 60;
    final remMinutes = minutes % 60;
    return '${hours}h ${remMinutes}m';
  }
}

class _WeeklyStat extends StatelessWidget {
  const _WeeklyStat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.cardTitleLg.copyWith(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.caption.copyWith(fontSize: 11)),
      ],
    );
  }
}

class _WalkSessionRow extends StatelessWidget {
  const _WalkSessionRow({required this.session});
  final WalkSession session;

  @override
  Widget build(BuildContext context) {
    final distanceKm = session.distanceMeters != null
        ? (session.distanceMeters! / 1000).toStringAsFixed(2)
        : null;
    return GlowCard(
      child: Row(
        children: [
          const Icon(Icons.directions_walk, color: AppColors.gold, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullDate(session.endedAt),
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    _formatDuration(session.durationSeconds),
                    if (session.steps != null) '${session.steps} steps',
                    if (distanceKm != null) '$distanceKm km',
                  ].join(' · '),
                  style: AppTextStyles.caption.copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }

  static String _fullDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '${months[d.month - 1]} ${d.day} · $hour12:${d.minute.toString().padLeft(2, '0')} $period';
  }
}

class _RoutinePickerSheet extends StatelessWidget {
  const _RoutinePickerSheet({required this.onSelect});
  final void Function(WalkRoutine? routine) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF181436),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Choose a walk', style: AppTextStyles.screenTitle.copyWith(fontSize: 18)),
          const SizedBox(height: 12),
          _RoutineTile(
            label: 'Open-ended Walk',
            subtitle: 'No target time — walk as long as you like',
            onTap: () {
              Navigator.of(context).pop();
              onSelect(null);
            },
          ),
          const SizedBox(height: 8),
          for (final routine in kWalkRoutines) ...[
            _RoutineTile(
              label: routine.title,
              subtitle: '${routine.durationMinutes} min target',
              onTap: () {
                Navigator.of(context).pop();
                onSelect(routine);
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({required this.label, required this.subtitle, required this.onTap});
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label, $subtitle',
      child: Material(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTextStyles.caption.copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
