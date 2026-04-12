import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'scale_button.dart';

class CustomBottomNav extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const CustomBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Existing app icon set (icon-only nav)
    const tabs = <_NavTab>[
      _NavTab(icon: Icons.home_outlined, activeIcon: Icons.home),
      _NavTab(icon: Icons.search, activeIcon: Icons.search),
      _NavTab(icon: Icons.auto_awesome, activeIcon: Icons.auto_awesome),
      _NavTab(icon: Icons.photo_library_outlined, activeIcon: Icons.photo_library),
      _NavTab(icon: Icons.more_horiz_outlined, activeIcon: Icons.more_horiz),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding + 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = (constraints.maxWidth * 0.9)
              .clamp(300.0, constraints.maxWidth)
              .toDouble();
          const barHeight = 64.0;
          const horizontalInset = 14.0;
          final trackWidth = barWidth - (horizontalInset * 2);
          final tabWidth = trackWidth / tabs.length;

          // Icon-only capsule. Keep it compact and always <= tabWidth to avoid edge clipping.
          final capsuleWidth = (tabWidth * 0.78)
              .clamp(40.0, 68.0)
              .clamp(0.0, tabWidth)
              .toDouble();
          final capsuleHeight = barHeight - 16;
          final capsuleLeft =
              horizontalInset +
              (currentIndex * tabWidth) +
              (tabWidth - capsuleWidth) / 2;

          // Same "glass card" styling as the top bars (see GlassAppBar).
          final barBackground = Colors.white.withValues(alpha: isDark ? 0.10 : 0.20);
          final inactiveColor = AppTheme.brownAccent.withValues(alpha: 0.62);

          return SizedBox(
            height: barHeight + 4,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(barHeight / 2),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    width: barWidth,
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: barBackground,
                      borderRadius: BorderRadius.circular(barHeight / 2),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.white.withValues(alpha: 0.35),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: isDark ? 0.22 : 0.12,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 7),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeInOut,
                          left: capsuleLeft,
                          top: 8,
                          width: capsuleWidth,
                          height: capsuleHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppTheme.primaryOrange,
                              borderRadius: BorderRadius.circular(
                                capsuleHeight / 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryOrange.withValues(
                                    alpha: 0.34,
                                  ),
                                  blurRadius: 12,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: horizontalInset,
                          ),
                          child: Row(
                            children: List.generate(tabs.length, (index) {
                              final tab = tabs[index];
                              final isActive = index == currentIndex;
                              return Expanded(
                                child: SizedBox(
                                  height: barHeight,
                                  child: ScaleButton(
                                    onTap: () => onTap(index),
                                    scale: 0.95,
                                    child: Center(
                                      child: AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 240,
                                        ),
                                        switchInCurve: Curves.easeInOut,
                                        switchOutCurve: Curves.easeInOut,
                                        transitionBuilder: (child, animation) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                        child: isActive
                                            ? Icon(
                                                key: ValueKey('active-$index'),
                                                tab.activeIcon,
                                                color: Colors.white,
                                                size: 23,
                                              )
                                            : Icon(
                                                key: ValueKey('inactive-$index'),
                                                tab.icon,
                                                color: inactiveColor,
                                                size: 23,
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NavTab {
  final IconData icon;
  final IconData activeIcon;

  const _NavTab({
    required this.icon,
    required this.activeIcon,
  });
}
