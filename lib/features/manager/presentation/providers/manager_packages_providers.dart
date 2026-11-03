import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/delivery.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Aging filter for the Packages tab.
enum PackageAgeFilter {
  all,
  fresh,   // < 4h
  aging,   // 4–24h
  stale,   // > 24h
}

final packageAgeFilterProvider =
    StateProvider<PackageAgeFilter>((ref) => PackageAgeFilter.all);

/// All packages currently at the manager's branch.
///
/// Fetches from `GET /manager/packages` — server orders oldest-first.
/// Client-side age filter is applied on the result.
final managerPackagesProvider = FutureProvider<List<Delivery>>((ref) async {
  final filter = ref.watch(packageAgeFilterProvider);
  final repo = ref.watch(deliveryRepositoryProvider);

  final result = await repo.listAtBranch();

  return result.fold(
    onSuccess: (packages) {
      if (filter == PackageAgeFilter.all) return packages;
      final target = filter.name;
      return packages
          .where((d) => d.packageAge == target)
          .toList(growable: false);
    },
    onFailure: (failure) => throw failure,
  );
});