import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/glow_card.dart';
import '../../core/widgets/gradient_background.dart';
import '../models/walking_models.dart';
import '../state/walk_session_controller.dart';
import '../state/walking_controller.dart';

/// The live "Start Walk" experience — Section 3/4 of the approved spec.
/// Elapsed time, steps during this walk, distance, pace, pause/resume,
/// finish. On finish, saves a real [WalkSession] via
/// [walkingControllerProvider] and shows the "Walk complete" summary —
/// never invents calories (not tracked at all here) or a distance/pace
/// figure the phone didn't actually measure.
class WalkSessionScreen extends ConsumerStatefulWidget {
  const WalkSessionScreen({super.key, this.routine, this.onDone});

  final WalkRoutine? routine;
  final VoidCallback? onDone;

  @override
  ConsumerState<WalkSessionScreen> createState() => _WalkSessionScreenState();
}

class _WalkSessionScreenState extends ConsumerState<WalkSessionScreen> {
  WalkSession? _completedSession;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_started) {
        _started = true;
        ref.read(walkSessionControllerProvider.notifier).start(routine: widget.routine);
      }
    });
  }

  Future<void> _finish() async {
    final session = await ref.read(walkSessionControllerProvider.notifier).finish();
    if (session != null) {
      await ref.read(walkingControllerProvider.notifier).recordSession(session);
    }
    if (!mounted) return;
    setState(() => _completedSession = session);
  }

  Future<void> _cancel() async {
    await ref.read(walkSessionControllerProvider.notifier).cancel();
    widget.onDone?.call();
  }

  @override
  Widget build(BuildContext context) {
    final session = _completedSession;
    if (session != null) {
      return _WalkCompleteView(session: session, onDone: widget.onDone);
    }

    final state = ref.watch(walkSessionControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.routine?.title ?? 'Walk',
                      style: AppTextStyles.screenTitle.copyWith(fontSize: 20),
                    ),
                    Semantics(
                      button: true,
                      label: 'Cancel walk',
                      child: IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: _cancel,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  _formatElapsed(state.elapsedSeconds),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 56,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  state.status == WalkSessionStatus.paused ? 'Paused' : 'Elapsed time',
                  style: AppTextStyles.caption.copyWith(fontSize: 13),
                ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Steps',
                        value: state.steps?.toString() ?? '—',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Distance',
                        value: state.distanceMeters != null
                            ? '${(state.distanceMeters! / 1000).toStringAsFixed(2)} km'
                            : '—',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Pace',
                        value: _formatPace(state.averagePaceSecondsPerKm),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        label: 'Speed',
                        value: state.currentSpeedMps != null
                            ? '${(state.currentSpeedMps! * 3.6).toStringAsFixed(1)} km/h'
                            : '—',
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: _RoundButton(
                        label: state.status == WalkSessionStatus.paused ? 'Resume' : 'Pause',
                        icon: state.status == WalkSessionStatus.paused
                            ? Icons.play_arrow
                            : Icons.pause,
                        onTap: () {
                          final notifier = ref.read(walkSessionControllerProvider.notifier);
                          if (state.status == WalkSessionStatus.paused) {
                            notifier.resume();
                          } else {
                            notifier.pause();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _RoundButton(
                        label: 'Finish',
                        icon: Icons.check,
                        primary: true,
                        onTap: _finish,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _formatPace(double? secondsPerKm) {
    if (secondsPerKm == null) return '—';
    final m = (secondsPerKm ~/ 60);
    final s = (secondsPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.cardTitleLg.copyWith(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: primary ? AppColors.gold : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: primary ? const Color(0xFF0A0B1E) : Colors.white),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: primary ? const Color(0xFF0A0B1E) : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

class _WalkCompleteView extends StatelessWidget {
  const _WalkCompleteView({required this.session, this.onDone});
  final WalkSession session;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final distanceKm = session.distanceMeters != null
        ? (session.distanceMeters! / 1000).toStringAsFixed(2)
        : null;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),
                Icon(Icons.check_circle, color: AppColors.gold, size: 48),
                const SizedBox(height: 16),
                Text('Walk complete', style: AppTextStyles.screenTitle.copyWith(fontSize: 24)),
                const SizedBox(height: 20),
                GlowCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SummaryRow(label: 'Duration', value: _formatElapsed(session.durationSeconds)),
                      _SummaryRow(
                        label: 'Steps',
                        value: session.steps?.toString() ?? 'Not available',
                      ),
                      _SummaryRow(label: 'Distance', value: distanceKm != null ? '$distanceKm km' : 'Not available'),
                      _SummaryRow(
                        label: 'Average pace',
                        value: session.averagePaceSecondsPerKm != null
                            ? _formatPace(session.averagePaceSecondsPerKm!)
                            : 'Not available',
                      ),
                      _SummaryRow(label: 'Started', value: _time(session.startedAt)),
                      _SummaryRow(label: 'Ended', value: _time(session.endedAt)),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: Material(
                    color: AppColors.gold,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: onDone,
                      child: const Center(
                        child: Text(
                          'Done',
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
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String _formatElapsed(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  static String _formatPace(double secondsPerKm) {
    final m = (secondsPerKm ~/ 60);
    final s = (secondsPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')} /km';
  }

  static String _time(DateTime d) {
    final hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'PM' : 'AM';
    return '$hour12:${d.minute.toString().padLeft(2, '0')} $period';
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTextStyles.subtitle.copyWith(fontSize: 14)),
          Text(
            value,
            style: AppTextStyles.subtitle.copyWith(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
