import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/branch_repository.dart';
import '../../data/repositories/delivery_repository.dart';
import '../../data/repositories/notification_repository.dart';
import '../../data/repositories/payment_repository.dart';
import '../../data/repositories/reward_repository.dart';
import '../../data/repositories/dashboard_repository.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/pricing_config_repository.dart';


final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(),
);

final pricingConfigRepositoryProvider = Provider<PricingConfigRepository>(
  (ref) => PricingConfigRepository(),
);

/// Provides the app's [UserRepository].
final userRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);


/// Provides the app's [BranchRepository].
///
/// Override this in tests with a fake to control `list()` / `get()` /
/// `create()` without touching the network.
final branchRepositoryProvider = Provider<BranchRepository>(
  (ref) => BranchRepository(),
);

/// Provides the app's [DeliveryRepository].
final deliveryRepositoryProvider = Provider<DeliveryRepository>(
  (ref) => DeliveryRepository(),
);

/// Provides the app's [PaymentRepository].
final paymentRepositoryProvider = Provider<PaymentRepository>(
  (ref) => PaymentRepository(),
);

/// Provides the app's [NotificationRepository].
final notificationRepositoryProvider = Provider<NotificationRepository>(
  (ref) => NotificationRepository(),
);

/// Provides the app's [RewardRepository].
final rewardRepositoryProvider = Provider<RewardRepository>(
  (ref) => RewardRepository(),
);

/// Provides the app's [DashboardRepository].
final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(),
);