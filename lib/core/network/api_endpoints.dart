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
  static const String ownerFinanceSummary = '/owner/finance/summary';

  // ─── Owner ledger (Phase 11.6) ───────────────────────────────────
  static const String ownerPayments = '/owner/payments';
  static const String ownerEarnings = '/owner/earnings';
  static const String ownerPayouts = '/owner/payouts';
  static const String ownerLedgerReconcile = '/owner/ledger/reconcile';
  static const String ownerLedgerReconcileLast = '/owner/ledger/reconcile/last';

  // ─── Manager ─────────────────────────────────────────────────────
  static const String managerStaff = '/manager/staff';
  static const String managerDeliveries = '/manager/deliveries';
  static const String managerBranch = '/manager/branch';
  static const String managerPackages = '/manager/packages';

  // ─── Distributor ─────────────────────────────────────────────────
  static const String distributorDeliveries = '/distributor/deliveries';
  static const String distributorPricePreview = '/distributor/deliveries/price-preview';
  static const String distributorBranches = '/distributor/branches';
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