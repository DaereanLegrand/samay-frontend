import 'package:flutter/material.dart';

class SamayTheme {
  SamayTheme._();

  static const _gray3 = Color(0xFF666666);

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: Colors.black,
      primaryColor: Colors.white,
      colorScheme: const ColorScheme.dark(
        primary: Colors.white,
        onPrimary: Colors.black,
        secondary: Colors.white,
        onSecondary: Colors.black,
        surface: Colors.black,
        onSurface: Colors.white,
      ),
      fontFamily: 'Inter',
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 32),
        headlineMedium: TextStyle(fontWeight: FontWeight.bold, fontSize: 24),
        bodyLarge: TextStyle(fontWeight: FontWeight.w300, fontSize: 16),
        bodyMedium: TextStyle(fontWeight: FontWeight.w300, fontSize: 14),
        labelLarge: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2),
      ),
      appBarTheme: const AppBarTheme(
        elevation: 0,
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: _gray3,
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: false,
        showSelectedLabels: false,
      ),
    );
  }
}
