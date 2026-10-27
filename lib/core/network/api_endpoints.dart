/// Central catalogue of every ODS API path.
///
/// All repositories must use these constants — no string paths in repository
/// or widget code. When the API contract changes, it changes here once.
///
/// Paths are relative to [AppConfig.apiBaseUrl], which already includes
/// `/api/v1`. So an entry of `/health` resolves to `.../api/v1/health`.
class ApiEndpoints {
  ApiEndpoints._();

  // ─── Diagnostics ─────────────────────────────────────────────────
  static const String health = '/health';

  // ─── Auth (populated in Phase 3) ─────────────────────────────────
  // ─── Auth ────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String registerDistributor = '/auth/register/distributor';

  // ─── Owner (populated in Phase 5) ────────────────────────────────
  static const String ownerBranches = '/owner/branches';
  static const String ownerUsers = '/owner/users';
  static const String ownerSettings = '/owner/settings';

  // ─── Manager (populated in Phase 6) ──────────────────────────────
  static const String managerStaff = '/manager/staff';
  static const String managerDeliveries = '/manager/deliveries';

  // ─── Distributor (populated in Phase 7) ──────────────────────────
  static const String distributorDeliveries = '/distributor/deliveries';
  static const String distributorPricePreview =
      '/distributor/deliveries/price-preview';

  // ─── Rider (populated in Phase 8) ────────────────────────────────
  static const String riderTasks = '/rider/tasks';
  static const String riderEarnings = '/rider/earnings';

  // ─── Receiver (populated in Phase 9) ─────────────────────────────
  static const String receiverPackages = '/receiver/packages';

  // ─── Payments (populated in Phase 11) ────────────────────────────
  // ─── Payments ────────────────────────────────────────────────────
  static const String payments = '/payments';
  static const String paymentsInitiate = '/payments/initiate';

  // ─── Notifications ───────────────────────────────────────────────
  static const String notifications = '/notifications';

  // ─── Rewards ─────────────────────────────────────────────────────
  static const String rewardsMe = '/rewards/me';
}
