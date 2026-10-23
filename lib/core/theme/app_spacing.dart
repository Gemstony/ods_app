/// Spacing, radius, and motion tokens.
///
/// Every layout gap, padding value, and corner radius in the app must come
/// from here — never hardcoded numbers in widgets. This is what keeps spacing
/// visually consistent across all five role dashboards.
class AppSpacing {
  AppSpacing._();

  // ─── Spacing scale (4-pt grid) ─────────────────────────────────────
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  // ─── Screen padding ────────────────────────────────────────────────
  /// Standard horizontal padding for full-screen content.
  static const double screenH = 20;

  /// Standard vertical padding for full-screen content.
  static const double screenV = 16;

  // ─── Corner radii ──────────────────────────────────────────────────
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 24;
  static const double radiusPill = 999;
}

/// Elevation levels used with [Material] and [Card].
class AppElevation {
  AppElevation._();

  static const double none = 0;
  static const double sm = 1;
  static const double md = 2;
  static const double lg = 4;
}

/// Standard animation durations.
class AppDuration {
  AppDuration._();

  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}