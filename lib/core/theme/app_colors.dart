import 'package:flutter/material.dart';

/// ODS brand palette.
///
/// All colors in the app should come from here. Do NOT hardcode hex values
/// in widgets. If a new color is needed, add it here with a clear name.
///
/// Reference: Phase 0 branding decision — primary #0F9D58, accent #22C55E,
/// surface #ECFDF5. Chosen for good contrast on both light green and white,
/// and for a modern, friendly feel rather than a corporate dark green.
class AppColors {
  AppColors._();

  // ─── Brand ─────────────────────────────────────────────────────────
  /// Primary brand green — buttons, app bar, key accents.
  static const Color primary = Color(0xFF0F9D58);

  /// Darker green for pressed states, headers, and emphasis.
  static const Color primaryDark = Color(0xFF0B7A43);

  /// Lighter green for tints, highlights, and quiet backgrounds.
  static const Color primaryLight = Color(0xFF48C78E);

  /// Accent green — secondary CTAs, success highlights, "add" actions.
  static const Color accent = Color(0xFF22C55E);

  // ─── Surfaces ──────────────────────────────────────────────────────
  /// Mint-tinted scaffold background — the app's default "paper" tone.
  static const Color surface = Color(0xFFECFDF5);

  /// Slightly lighter than [surface], used for subtle layered panels.
  static const Color surfaceVariant = Color(0xFFF7FBF9);

  /// Cards, sheets, and elevated containers.
  static const Color card = Color(0xFFFFFFFF);

  // ─── Text & icons ──────────────────────────────────────────────────
  /// High-emphasis text — headlines, primary content.
  static const Color onSurface = Color(0xFF0F1F17);

  /// Medium-emphasis text — body copy, form labels.
  static const Color onSurfaceMuted = Color(0xFF4B5F55);

  /// Low-emphasis text — helper text, timestamps, disabled labels.
  static const Color onSurfaceSubtle = Color(0xFF7A8C82);

  /// Text/icons rendered on top of [primary] or [primaryDark].
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ─── Borders & dividers ────────────────────────────────────────────
  /// Default border for inputs, cards, and outlined buttons.
  static const Color border = Color(0xFFD6E7DE);

  /// Fainter border for internal dividers.
  static const Color borderSubtle = Color(0xFFE5EEEA);

  // ─── Status ────────────────────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color errorSurface = Color(0xFFFEE2E2);

  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);

  static const Color success = Color(0xFF16A34A);
  static const Color successSurface = Color(0xFFDCFCE7);

  static const Color info = Color(0xFF0EA5E9);
  static const Color infoSurface = Color(0xFFE0F2FE);

  // ─── Feedback states ───────────────────────────────────────────────
  static const Color disabled = Color(0xFFB8C7BF);
  static const Color disabledSurface = Color(0xFFEDF3EF);
}