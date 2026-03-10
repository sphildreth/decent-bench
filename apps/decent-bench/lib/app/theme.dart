import 'package:flutter/material.dart';

ThemeData buildDecentBenchTheme() {
  const parchment = Color(0xFFF7F1E7);
  const ink = Color(0xFF12202B);
  const rust = Color(0xFFC35C2E);
  const teal = Color(0xFF2E7C78);
  const panel = Color(0xFFFFFBF5);
  const surfaceVariant = Color(0xFFE8DDD0);

  final colorScheme =
      ColorScheme.fromSeed(
        seedColor: rust,
        brightness: Brightness.light,
        primary: rust,
        secondary: teal,
        surface: panel,
      ).copyWith(
        surface: panel,
        surfaceContainerHighest: surfaceVariant,
        onSurface: ink,
        onSurfaceVariant: const Color(0xFF57636D),
        outlineVariant: const Color(0xFFD8C9B9),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: parchment,
    cardTheme: const CardThemeData(color: panel),
    textTheme: Typography.material2021().black.apply(
      bodyColor: ink,
      displayColor: ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      side: BorderSide(color: colorScheme.outlineVariant),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    ),
  );
}
