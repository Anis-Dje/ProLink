import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF1a2332);
  static const Color secondary = Color(0xFF2d4a6b);
  static const Color accent = Color(0xFF00b4d8);
  static const Color background = Color(0xFF0f1923);
  static const Color surface = Color(0xFF1e2d42);
  static const Color textPrimary = Color(0xFFffffff);
  static const Color textSecondary = Color(0xFF8faabf);
  static const Color error = Color(0xFFcf6679);
  static const Color success = Color(0xFF4caf50);
  static const Color warning = Color(0xFFff9800);
  static const Color gold = Color(0xFFffd700);
  static const Color cardBorder = Color(0xFF2d4a6b);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, secondary],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [accent, Color(0xFF0096c7)],
  );

  static const LinearGradient idCardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1a2332), Color(0xFF2d4a6b), Color(0xFF1a2332)],
    stops: [0.0, 0.5, 1.0],
  );
}
