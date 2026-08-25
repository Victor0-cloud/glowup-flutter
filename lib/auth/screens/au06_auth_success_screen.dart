import 'package:flutter/material.dart';

import '../../core/theme/app_text_styles.dart';
import '../../core/widgets/gradient_background.dart';
import '../../core/widgets/gradient_pill_button.dart';
import '../widgets/auth_widgets.dart';

/// AU06 Welcome to Glow Up — shown exactly once, right after AU05
/// completes. "Go to Dashboard" enters the real Today screen.
class AuthSuccessScreen extends StatelessWidget {
  const AuthSuccessScreen({super.key, required this.onGoToDashboard});

  final VoidCallback onGoToDashboard;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 3),
                const StarMascot(size: 140),
                const SizedBox(height: 32),
                Text(
                  'Welcome to Glow Up! ✨',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.screenTitle.copyWith(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  "You're all set. Let's build healthy habits and glow together.",
                  textAlign: TextAlign.center,
                  style: AppTextStyles.subtitleLg,
                ),
                const Spacer(flex: 4),
                GradientPillButton(
                  label: 'Go to Dashboard',
                  onPressed: onGoToDashboard,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
