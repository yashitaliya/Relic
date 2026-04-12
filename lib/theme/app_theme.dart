import 'package:flutter/material.dart';

class AppTheme {
  // Colors from the Relic logo
  static const Color primaryOrange = Color(0xFFF37121);
  static const Color brownAccent = Color(0xFF6B3E26);
  static const Color creamBackground = Color(0xFFF5F1E8);
  static const Color darkText = Color(0xFF2C2C2C);
  static const Color lightGray = Color(0xFFE5E5E5);
  static const double selectionFabBottomPadding = 60;
  static const double selectionFabBottomPaddingWithBottomNav = 110;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.light(
        primary: primaryOrange,
        secondary: brownAccent,
        surface: creamBackground,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkText,
      ),
      scaffoldBackgroundColor: creamBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: creamBackground,
        foregroundColor: darkText,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: brownAccent,
          fontSize: 32,
          fontWeight: FontWeight.bold,
          fontFamily: 'Serif',
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryOrange,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      iconTheme: const IconThemeData(color: darkText),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: brownAccent,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: darkText,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: darkText, fontSize: 16),
        bodyMedium: TextStyle(color: darkText, fontSize: 14),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
