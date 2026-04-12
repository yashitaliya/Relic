import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _logoSlide;
  late Animation<double> _titleFade;
  late Animation<Offset> _titleSlide;
  late Animation<double> _subtitleFade;
  late Animation<double> _quoteFade;
  late Animation<double> _loaderFade;
  late Animation<double> _footerFade;

  @override
  void initState() {
    super.initState();
    // Set system UI overlay style for splash screen
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _bgFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _logoScale = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.05, 0.55, curve: Curves.easeOutBack),
      ),
    );

    _logoSlide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.05, 0.55, curve: Curves.easeOutCubic),
          ),
        );

    _titleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.25, 0.8, curve: Curves.easeOut),
    );

    _titleSlide = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.25, 0.8, curve: Curves.easeOutCubic),
          ),
        );

    _subtitleFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.38, 0.92, curve: Curves.easeOut),
    );

    _quoteFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.45, 0.98, curve: Curves.easeOut),
    );

    _loaderFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.60, 1.0, curve: Curves.easeOut),
    );

    _footerFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 1.0, curve: Curves.easeOut),
    );

    _controller.forward();

    // Navigate to main screen after animation and brief hold
    Future.delayed(const Duration(milliseconds: 2400), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                const MainScreen(),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  return FadeTransition(opacity: animation, child: child);
                },
            transitionDuration: const Duration(milliseconds: 800),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.creamBackground, Colors.white],
          ),
        ),
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final bgT = Curves.easeOut.transform(_controller.value);

            return Stack(
              fit: StackFit.expand,
              children: [
                // Soft themed glow shapes
                IgnorePointer(
                  child: Opacity(
                    opacity: _bgFade.value,
                    child: Stack(
                      children: [
                        Positioned(
                          top: -120 + (1 - bgT) * 18,
                          right: -120,
                          child: Container(
                            width: 260,
                            height: 260,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryOrange.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -140,
                          left: -110 + (1 - bgT) * 18,
                          child: Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.brownAccent.withValues(
                                alpha: 0.07,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 120,
                          left: 24,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.primaryOrange.withValues(
                                alpha: 0.25,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SafeArea(
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 20,
                        ),
                        child: Column(
                          children: [
                            const Spacer(flex: 3),

                            FadeTransition(
                              opacity: _bgFade,
                              child: SlideTransition(
                                position: _logoSlide,
                                child: ScaleTransition(
                                  scale: _logoScale,
                                  child: Container(
                                    width: 132,
                                    height: 132,
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(34),
                                      border: Border.all(
                                        color: AppTheme.primaryOrange
                                            .withValues(alpha: 0.28),
                                        width: 1.2,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.08,
                                          ),
                                          blurRadius: 24,
                                          offset: const Offset(0, 10),
                                        ),
                                        BoxShadow(
                                          color: AppTheme.primaryOrange
                                              .withValues(alpha: 0.12),
                                          blurRadius: 30,
                                          offset: const Offset(0, 14),
                                        ),
                                      ],
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(28),
                                      child: Image.asset(
                                        'assets/relic_app_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 18),

                            FadeTransition(
                              opacity: _titleFade,
                              child: SlideTransition(
                                position: _titleSlide,
                                child: Text(
                                  'Relic',
                                  style: TextStyle(
                                    fontSize: 38,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.brownAccent,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            FadeTransition(
                              opacity: _subtitleFade,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.78),
                                  borderRadius: BorderRadius.circular(18),
                                  border: Border.all(
                                    color: Colors.black.withValues(alpha: 0.04),
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'Your private memory vault',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.darkText.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    FadeTransition(
                                      opacity: _quoteFade,
                                      child: Text(
                                        '"Collect moments, not things."',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic,
                                          color: AppTheme.brownAccent
                                              .withValues(alpha: 0.70),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 26),

                            FadeTransition(
                              opacity: _loaderFade,
                              child: const SizedBox(
                                width: 26,
                                height: 26,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.6,
                                  valueColor: AlwaysStoppedAnimation(
                                    AppTheme.primaryOrange,
                                  ),
                                ),
                              ),
                            ),

                            const Spacer(flex: 2),

                            FadeTransition(
                              opacity: _footerFade,
                              child: Text(
                                'Crafted by Yash Italiya',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.brownAccent.withValues(
                                    alpha: 0.62,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
