import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/pricing_config.dart';
import '../../../../data/models/setting.dart';
import '../../../../shared/providers/repository_providers.dart';

/// All settings grouped by category.
final ownerSettingsProvider =
    FutureProvider<Map<String, List<Setting>>>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  final result = await repo.list();

  return result.fold(
    onSuccess: (grouped) => grouped,
    onFailure: (failure) => throw failure,
  );
});

/// The platform's singleton pricing configuration.
final ownerPricingConfigProvider =
    FutureProvider<PricingConfig>((ref) async {
  final repo = ref.watch(pricingConfigRepositoryProvider);
  final result = await repo.get();

  return result.fold(
    onSuccess: (config) => config,
    onFailure: (failure) => throw failure,
  );
});