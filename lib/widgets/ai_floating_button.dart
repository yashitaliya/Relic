import 'package:flutter/material.dart';

import '../screens/ai_assistant_screen.dart';
import '../services/selection_service.dart';

class AiFloatingButton extends StatefulWidget {
  const AiFloatingButton({super.key});

  @override
  State<AiFloatingButton> createState() => _AiFloatingButtonState();
}

class _AiFloatingButtonState extends State<AiFloatingButton>
    with TickerProviderStateMixin {
  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();

    // Glow pulse animation
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.2, end: 0.55).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 390;
    final glowSize = isCompact ? 66.0 : 75.0;
    final buttonSize = isCompact ? 56.0 : 64.0;
    final shineTop = isCompact ? 7.0 : 8.0;
    final shineLeft = isCompact ? 15.0 : 18.0;
    final shineSize = isCompact ? 16.0 : 20.0;

    return ValueListenableBuilder<bool>(
      valueListenable: SelectionService.instance.isSelectionMode,
      builder: (context, isSelectionMode, child) {
        return AnimatedScale(
          scale: isSelectionMode ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOutBack,
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          const AiAssistantScreen(),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                            const begin = 0.8;
                            const end = 1.0;
                            const curve = Curves.easeOutBack;

                            var scaleAnimation = Tween(begin: begin, end: end)
                                .animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: curve,
                                  ),
                                );

                            var fadeAnimation = Tween(begin: 0.0, end: 1.0)
                                .animate(
                                  CurvedAnimation(
                                    parent: animation,
                                    curve: Curves.easeIn,
                                  ),
                                );

                            return ScaleTransition(
                              scale: scaleAnimation,
                              child: FadeTransition(
                                opacity: fadeAnimation,
                                child: child,
                              ),
                            );
                          },
                      transitionDuration: const Duration(milliseconds: 400),
                    ),
                  );
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: glowSize,
                      height: glowSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFFF37121,
                            ).withValues(alpha: _glowAnimation.value),
                            blurRadius: 20,
                            spreadRadius: isCompact ? 3 : 4,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: buttonSize,
                      height: buttonSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [Color(0xFFF37121), Color(0xFFFF8C42)],
                        ),
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                          BoxShadow(
                            color: const Color(
                              0xFFF37121,
                            ).withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const _AIIcon(),
                    ),
                    Positioned(
                      top: shineTop,
                      left: shineLeft,
                      child: Container(
                        width: shineSize,
                        height: shineSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0.6),
                              Colors.white.withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Custom AI Icon with only logo
class _AIIcon extends StatelessWidget {
  const _AIIcon();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: ClipOval(
        child: Image.asset('assets/logo/relic_logo.png', fit: BoxFit.cover),
      ),
    );
  }
}
