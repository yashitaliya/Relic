import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'screens/search_screen.dart';
import 'screens/image_generation_screen.dart';
import 'screens/home_screen.dart';
import 'screens/albums_screen.dart';
import 'screens/more_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/custom_bottom_nav.dart';
import 'services/settings_service.dart';
import 'services/selection_service.dart';
import 'screens/splash_screen.dart';
import 'widgets/app_lock_wrapper.dart';
import 'widgets/ai_floating_button.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const RelicApp());
}

class RelicApp extends StatelessWidget {
  const RelicApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Relic',
      theme: AppTheme.lightTheme.copyWith(
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        return AppLockWrapper(child: child!);
      },
      home: const SplashScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final SettingsService _settingsService = SettingsService();
  late PageController _pageController;
  int _currentIndex = 0;
  DateTime? _lastBackPress;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStartPage();
  }

  Future<void> _loadStartPage() async {
    final startPage = await _settingsService.getStartPage();
    if (mounted) {
      setState(() {
        _currentIndex = startPage;
        _pageController = PageController(initialPage: startPage);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    if (!_isLoading) {
      _pageController.dispose();
    }
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onItemTapped(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFAFAFA),
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation(Color(0xFFF37121)),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        final now = DateTime.now();
        final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
            _lastBackPress == null ||
            now.difference(_lastBackPress!) > const Duration(seconds: 2);

        if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
          _lastBackPress = now;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          // Exit the app
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: ValueListenableBuilder<bool>(
          valueListenable: SelectionService.instance.isSelectionMode,
          builder: (context, isSelectionMode, child) {
            if (isSelectionMode) return const SizedBox.shrink();
            return const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: AiFloatingButton(),
            );
          },
        ),
        body: PageView(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          scrollDirection: Axis.horizontal,
          children: const [
            HomeScreen(),
            SearchScreen(),
            ImageGenerationScreen(),
            AlbumsScreen(),
            MoreScreen(),
          ],
        ),
        bottomNavigationBar: CustomBottomNav(
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
        ),
        extendBody: true,
      ),
    );
  }
}
