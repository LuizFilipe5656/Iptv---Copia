import 'package:flutter/material.dart';

abstract final class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF050B18),
    primaryColor: const Color(0xFF2196F3),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF2196F3),
      secondary: Color(0xFF42A5F5),
      surface: Color(0xFF10192D),
    ),
  );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF1565C0),
      secondary: Color(0xFF1976D2),
      surface: Colors.white,
    ),
  );
}
