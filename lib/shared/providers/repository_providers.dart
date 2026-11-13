import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/earnings_repository.dart';
import '../../data/repositories/finance_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/owner_ledger_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/pricing_config_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/staff_repository.dart';
import '../../data/repositories/user_repository.dart';

final staffRepositoryProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(),
);

final financeRepositoryProvider = Provider<FinanceRepository>(
  (ref) => FinanceRepository(),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

final pricingConfigRepositoryProvider = Provider<PricingConfigRepository>(
  (ref) => PricingConfigRepository(),
);

final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);

final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => BranchRepository(),
);

final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(),
);

final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(),
);

final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(),
);

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);

final earningsRepositoryProvider = Provider<EarningsRepository>(
  (ref) => EarningsRepository(),
);

final ownerLedgerRepositoryProvider = Provider<OwnerLedgerRepository>(
  (ref) => OwnerLedgerRepository(),
);