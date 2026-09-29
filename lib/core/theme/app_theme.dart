import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF0B1017);
  static const panel = Color(0xFF131B25);
  static const panelRaised = Color(0xFF192431);
  static const line = Color(0xFF263543);
  static const muted = Color(0xFF91A1B2);
  static const cyan = Color(0xFF62D6E5);
  static const mint = Color(0xFF9CE3BD);

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: ink,
        colorScheme: const ColorScheme.dark(
          primary: cyan,
          secondary: mint,
          surface: panel,
          error: Color(0xFFFF6478),
        ),
        fontFamily: 'Avenir Next',
        appBarTheme: const AppBarTheme(backgroundColor: ink, foregroundColor: Colors.white, elevation: 0),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: panel,
          hintStyle: const TextStyle(color: muted),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: cyan, width: 1.4)),
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: panelRaised,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
}