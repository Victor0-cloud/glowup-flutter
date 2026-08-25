import 'package:flutter/material.dart';
import '../auth/state/auth_router_reactor.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_theme.dart';
import '../routing/app_router.dart';

/// The approved Figma frames are all 402px wide (00_splash through
/// 13_finish_setup). Everything below this renders full-bleed edge to
/// edge exactly like Figma; on a wider surface (desktop window, browser
/// tab) it's centered at its native width instead of stretching.
const double kMobileFrameWidth = 402;

class GlowUpApp extends StatelessWidget {
  const GlowUpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Glow Up',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
      builder: (context, child) {
        return AuthRouterReactor(
          child: ColoredBox(
            color: AppColors.bgBottom,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kMobileFrameWidth),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
