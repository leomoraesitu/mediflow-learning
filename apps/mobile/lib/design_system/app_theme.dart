import 'package:flutter/material.dart';

final class AppTheme {
  const AppTheme._();

  static const Color seedColor = Color(0xFF3559C7);

  static ThemeData get light {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );

    return ThemeData(colorScheme: colorScheme, useMaterial3: true);
  }
}
