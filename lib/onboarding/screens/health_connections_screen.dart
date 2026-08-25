import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icon.dart';
import '../../core/widgets/glow_card.dart';
import '../models/onboarding_profile.dart';
import '../state/onboarding_controller.dart';
import '../widgets/onboarding_scaffold.dart';

/// 11_health_connections (node 368:667). Apple Health ships pre-linked on
/// the approved screen; Google Fit / Fitbit are tap-to-connect toggles.
class HealthConnectionsScreen extends ConsumerWidget {
  const HealthConnectionsScreen({super.key, required this.onNext});

  final VoidCallback onNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections = ref
        .watch(onboardingControllerProvider)
        .healthConnections;
    final controller = ref.read(onboardingControllerProvider.notifier);

    return OnboardingScaffold(
      title: 'Health Data 📊',
      subtitle:
          'Connect your companion fitness accounts to unlock precise AI insights.',
      progressIndex: 4,
      primaryLabel: 'Next',
      onPrimaryPressed: () {
        controller.advanceStep(OnboardingStep.personalization);
        onNext();
      },
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            _IntegrationRow(
              icon: 'heart-pulse',
              label: 'Apple Health',
              connected: connections.appleHealthLinked,
              connectedLabel: 'Linked',
              onTap: () => controller.updateHealthConnections(
                connections.copyWith(
                  appleHealthLinked: !connections.appleHealthLinked,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _IntegrationRow(
              icon: 'activity-google',
              label: 'Google Fit',
              connected: connections.googleFitConnected,
              connectedLabel: 'Connected',
              onTap: () => controller.updateHealthConnections(
                connections.copyWith(
                  googleFitConnected: !connections.googleFitConnected,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _IntegrationRow(
              icon: 'activity-fitbit',
              label: 'Fitbit Account',
              connected: connections.fitbitConnected,
              connectedLabel: 'Connected',
              onTap: () => controller.updateHealthConnections(
                connections.copyWith(
                  fitbitConnected: !connections.fitbitConnected,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Opacity(
              opacity: 0.6,
              child: Text(
                'We prioritize absolute privacy. Your biometric stats are fully encrypted '
                'and will never be shared without consent.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrationRow extends StatelessWidget {
  const _IntegrationRow({
    required this.icon,
    required this.label,
    required this.connected,
    required this.connectedLabel,
    required this.onTap,
  });

  final String icon;
  final String label;
  final bool connected;
  final String connectedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Center(child: AppIcon(icon, size: 24)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: AppTextStyles.cardTitleLg)),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: connected
                      ? AppColors.successSubtle
                      : Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                  border: Border.all(
                    color: connected
                        ? AppColors.success
                        : Colors.white.withValues(alpha: 0.13),
                  ),
                ),
                child: Text(
                  connected ? connectedLabel : 'Connect',
                  style: TextStyle(
                    color: connected ? AppColors.success : Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTextStyles.captionBold.fontFamily,
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
