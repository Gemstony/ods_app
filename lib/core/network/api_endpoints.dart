/// Central catalogue of every ODS API path.
class ApiEndpoints {
  ApiEndpoints._();

  // ─── Diagnostics ─────────────────────────────────────────────────
  static const String health = '/health';

  // ─── Auth ────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String logoutAll = '/auth/logout-all';
  static const String refresh = '/auth/refresh';
  static const String me = '/auth/me';
  static const String registerDistributor = '/auth/register/distributor';

  // ─── Owner ───────────────────────────────────────────────────────
  static const String ownerBranches = '/owner/branches';
  static const String ownerUsers = '/owner/users';
  static const String ownerSettings = '/owner/settings';
  static const String ownerPricingConfig = '/owner/pricing-config';

  // ─── Manager ─────────────────────────────────────────────────────
  static const String managerStaff = '/manager/staff';
  static const String managerDeliveries = '/manager/deliveries';
  static const String managerBranch = '/manager/branch';
  static const String managerPackages = '/manager/packages';

  // ─── Distributor ─────────────────────────────────────────────────
  static const String distributorDeliveries = '/distributor/deliveries';
  static const String distributorPricePreview = '/distributor/deliveries/price-preview';
  static const String distributorBranches = '/distributor/branches';

  // ─── Distributor payments (Phase 11.5) ───────────────────────────
  // Server endpoints (Phase 11.2):
  //   POST /distributor/payments/initiate    → { delivery_id, phone_number?, stage? }
  //   GET  /distributor/payments/{id}
  //   POST /distributor/payments/{id}/refresh
  static const String distributorPayments = '/distributor/payments';
  static const String distributorPaymentsInitiate = '/distributor/payments/initiate';

  // ─── Rider ───────────────────────────────────────────────────────
  static const String riderDashboard = '/rider/dashboard';
  static const String riderDeliveries = '/rider/deliveries';
  static const String riderEarnings = '/rider/earnings';

  // ─── Receiver ────────────────────────────────────────────────────
  static const String receiverPackages = '/receiver/packages';
  static const String receiverRegional = '/receiver/regional';

  // ─── Notifications ───────────────────────────────────────────────
  static const String notifications = '/notifications';

  // ─── Rewards ─────────────────────────────────────────────────────
  static const String rewardsMe = '/rewards/me';
}