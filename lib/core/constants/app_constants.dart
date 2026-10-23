/// Application-wide constants that aren't specific to a single feature.
///
/// Rule of thumb: if a value is used by two or more features and isn't
/// environment-specific (that's `AppConfig`) or a UI token (that's
/// `AppSpacing`/`AppColors`), it belongs here.
class AppConstants {
  AppConstants._();

  // ─── Network ─────────────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 20);

  // ─── Session ─────────────────────────────────────────────────────
  /// How long the splash screen holds before auto-routing to login.
  static const Duration splashDuration = Duration(milliseconds: 1500);

  /// JWT access-token lifetime (mirrors the backend JWT_TTL in Phase 1.10).
  static const Duration accessTokenLifetime = Duration(minutes: 60);

  // ─── Pagination ──────────────────────────────────────────────────
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // ─── Validation ──────────────────────────────────────────────────
  static const int minPasswordLength = 8;
  static const int maxNameLength = 100;

  // ─── Delivery & pricing (Phase 10 defaults; overridable by Owner) ─
  static const int defaultBatchingWindowMinutes = 20;
  static const int minimumDeliveryFeeTsh = 1000;
  static const int roundingIncrementTsh = 500;

  // ─── Compensation defaults ───────────────────────────────────────
  static const double riderBaselinePercent = 0.80;
  static const double riderBonusPercent = 0.10;

  // ─── Rewards ─────────────────────────────────────────────────────
  static const int rewardTier1Count = 20; // 50% discount
  static const int rewardTier2Count = 50; // free eligible delivery
}