import 'package:flutter/material.dart';

/// Material 3 text theme tuned for ODS.
///
/// The font family is intentionally left null (platform default) for now.
/// Phase 15 can bundle a custom font (e.g., Inter) and set `fontFamily` here
/// without touching a single screen.
class AppTypography {
  AppTypography._();

  static TextTheme get textTheme {
    return const TextTheme(
      // ─── Display (hero text, splash) ──────────────────────────────
      displayLarge: TextStyle(
        fontSize: 57, height: 1.12, fontWeight: FontWeight.w800,
        letterSpacing: -0.25,
      ),
      displayMedium: TextStyle(
        fontSize: 45, height: 1.16, fontWeight: FontWeight.w800,
      ),
      displaySmall: TextStyle(
        fontSize: 36, height: 1.22, fontWeight: FontWeight.w700,
      ),

      // ─── Headline (screen titles) ─────────────────────────────────
      headlineLarge: TextStyle(
        fontSize: 32, height: 1.25, fontWeight: FontWeight.w700,
      ),
      headlineMedium: TextStyle(
        fontSize: 28, height: 1.29, fontWeight: FontWeight.w700,
      ),
      headlineSmall: TextStyle(
        fontSize: 24, height: 1.33, fontWeight: FontWeight.w600,
      ),

      // ─── Title (section headers, card titles) ─────────────────────
      titleLarge: TextStyle(
        fontSize: 22, height: 1.27, fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 16, height: 1.50, fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      titleSmall: TextStyle(
        fontSize: 14, height: 1.43, fontWeight: FontWeight.w600,
        letterSpacing: 0.10,
      ),

      // ─── Body (paragraph copy) ────────────────────────────────────
      bodyLarge: TextStyle(
        fontSize: 16, height: 1.50, fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
      ),
      bodyMedium: TextStyle(
        fontSize: 14, height: 1.43, fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
      ),
      bodySmall: TextStyle(
        fontSize: 12, height: 1.33, fontWeight: FontWeight.w400,
        letterSpacing: 0.40,
      ),

      // ─── Label (buttons, chips, tags) ─────────────────────────────
      labelLarge: TextStyle(
        fontSize: 14, height: 1.43, fontWeight: FontWeight.w600,
        letterSpacing: 0.10,
      ),
      labelMedium: TextStyle(
        fontSize: 12, height: 1.33, fontWeight: FontWeight.w600,
        letterSpacing: 0.50,
      ),
      labelSmall: TextStyle(
        fontSize: 11, height: 1.45, fontWeight: FontWeight.w600,
        letterSpacing: 0.50,
      ),
    );
  }
}