import 'package:flutter/material.dart';
import '../../core/widgets/gradient_background.dart';

/// Full-screen shell for every RoutinePlayer screen. The workout occupies
/// the entire available viewport — never a small centered card, modal, or
/// debug-preview panel. On a phone-width window that's naturally
/// edge-to-edge. On a wide desktop/tablet window the content still uses
/// the full available width up to a generous cap (so paragraphs of coach
/// text and button rows stay readable on an ultra-wide monitor instead of
/// stretching edge-to-edge) — the CONTAINER adapts to the viewport, but
/// individual images inside it (see [MovementDisplay]) always preserve
/// their own aspect ratio rather than being stretched to fill it.
class RoutinePlayerScaffold extends StatelessWidget {
  const RoutinePlayerScaffold({super.key, required this.body, this.bottomBar});

  final Widget body;
  final Widget? bottomBar;

  /// Below this width, use the full viewport with no cap at all (phone).
  static const double _phoneBreakpoint = 600;

  /// Above the breakpoint, cap content width so text/controls don't
  /// stretch unreadably wide on an ultra-wide monitor — still dramatically
  /// larger than a "centered card" (previously 460).
  static const double _maxContentWidth = 1100;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GradientBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentWidth = constraints.maxWidth <= _phoneBreakpoint
                  ? constraints.maxWidth
                  : constraints.maxWidth.clamp(0, _maxContentWidth);
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: contentWidth.toDouble(),
                  ),
                  child: Column(
                    children: [
                      Expanded(child: SingleChildScrollView(child: body)),
                      ?bottomBar,
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
