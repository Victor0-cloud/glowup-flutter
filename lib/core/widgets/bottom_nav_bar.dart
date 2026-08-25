import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_icon.dart';

enum AppNavTab { today, routines, coach, profile }

class _TabSpec {
  const _TabSpec(this.tab, this.icon, this.label);
  final AppNavTab tab;
  final String icon;
  final String label;
}

const _tabs = [
  _TabSpec(AppNavTab.today, 'nav-home', 'Today'),
  _TabSpec(AppNavTab.routines, 'nav-routines', 'Routines'),
  _TabSpec(AppNavTab.coach, 'nav-coach', 'Coach'),
  _TabSpec(AppNavTab.profile, 'nav-profile', 'Profile'),
];

/// The 4-tab bottom navigation (368:963 "Bottom-Nav-Bar") used across every
/// authenticated screen. Built once, reused everywhere — never duplicated
/// per screen. The active tab's icon+label take [activeAccent] (which
/// shifts with the Today time-of-day variant per the approved frames);
/// inactive tabs always stay the same muted color regardless of variant,
/// confirmed by diffing the exported icons across all 4 Today frames.
class BottomNavBar extends StatelessWidget {
  const BottomNavBar({
    super.key,
    required this.active,
    required this.activeAccent,
    required this.onTabSelected,
  });

  final AppNavTab active;
  final Color activeAccent;
  final ValueChanged<AppNavTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0E2B),
            border: Border(top: BorderSide(color: AppColors.bgMid)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final t in _tabs)
                _NavTabItem(
                  spec: t,
                  selected: t.tab == active,
                  accent: activeAccent,
                  onTap: () => onTabSelected(t.tab),
                ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          color: const Color(0xFF0D0E2B),
          child: Center(
            child: Container(
              width: 140,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(100),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NavTabItem extends StatelessWidget {
  const _NavTabItem({
    required this.spec,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final _TabSpec spec;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? accent : AppColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: spec.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SizedBox(
              width: 64,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIcon(spec.icon, size: 24, color: color),
                  const SizedBox(height: 4),
                  Text(
                    spec.label,
                    style: TextStyle(
                      color: color,
                      fontSize: 11,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
