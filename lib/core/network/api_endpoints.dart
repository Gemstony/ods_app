/// Central catalogue of every ODS API path.
///
/// **Rule:** never replace this file wholesale without re-checking every
/// consumer. Each constant below is referenced by at least one repository
/// or provider. Dropping one silently breaks its caller at compile time
/// (e.g. the 13.7.1 regression that removed `ownerEarnings` and friends).
///
/// Paths are relative to [AppConfig.apiBaseUrl], which already includes
/// `/api/v1`. So an entry of `/health` resolves to `.../api/v1/health`.
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
  static const String updateProfile = '/auth/profile';
  static const String changePassword = '/auth/password';
  static const String registerDistributor = '/auth/register/distributor';

  // ─── Owner — core (Phase 5) ──────────────────────────────────────
  static const String ownerBranches = '/owner/branches';
  static const String ownerUsers = '/owner/users';
  static const String ownerSettings = '/owner/settings';
  static const String ownerPricingConfig = '/owner/pricing-config';
  static const String ownerFinanceSummary = '/owner/finance/summary';

  // ─── Owner — ledger (Phase 11.4) ─────────────────────────────────
  // Referenced by OwnerLedgerRepository (listPayments / showPayment /
  // listEarnings / showEarning / listPayouts / showPayout /
  // runReconciliation / lastReconciliation). Do not remove.
  static const String ownerPayments = '/owner/payments';
  static const String ownerEarnings = '/owner/earnings';
  static const String ownerPayouts = '/owner/payouts';
  static const String ownerLedgerReconcile = '/owner/ledger/reconcile';
  static const String ownerLedgerReconcileLast = '/owner/ledger/reconcile/last';

  // ─── Manager (Phase 6) ───────────────────────────────────────────
  static const String managerStaff = '/manager/staff';
  static const String managerDeliveries = '/manager/deliveries';
  static const String managerBranch = '/manager/branch';
  static const String managerPackages = '/manager/packages';
  static const String managerDashboard = '/manager/dashboard';

  // ─── Manager — payments (Phase 13.7) ─────────────────────────────
  // Referenced by ManualPaymentRepository (listPending / approve /
  // reject). Also accepts `/pending`, `/{id}/approve`, `/{id}/reject`
  // as suffixes. Do not remove.
  static const String managerPayments = '/manager/payments';

  // ─── Distributor (Phase 7) ───────────────────────────────────────
  static const String distributorDeliveries = '/distributor/deliveries';
  static const String distributorPricePreview =
      '/distributor/deliveries/price-preview';
  static const String distributorBranches = '/distributor/branches';

  // ─── Distributor — payments (Phase 11.2 + 13.7) ──────────────────
  // Referenced by PaymentRepository (initiate / manual / show / refresh).
  static const String distributorPayments = '/distributor/payments';
  static const String distributorPaymentsInitiate =
      '/distributor/payments/initiate';
  static const String distributorPaymentsManual =
      '/distributor/payments/manual';

  // ─── Rider (Phase 8) ─────────────────────────────────────────────
  static const String riderDashboard = '/rider/dashboard';
  static const String riderDeliveries = '/rider/deliveries';
  static const String riderEarnings = '/rider/earnings';
  static const String riderAvailability = '/rider/availability';
  static const String riderQueueStatus = '/rider/queue-status';

  // ─── Receiver (Phase 9) ──────────────────────────────────────────
  static const String receiverPackages = '/receiver/packages';
  static const String receiverRegional = '/receiver/regional';

  // ─── Notifications (Phase 13.1) ──────────────────────────────────
  static const String notifications = '/notifications';

  // ─── Rewards (Phase 7) ───────────────────────────────────────────
  static const String rewardsMe = '/rewards/me';
}
