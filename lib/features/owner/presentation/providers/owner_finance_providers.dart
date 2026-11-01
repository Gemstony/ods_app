import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/finance_summary.dart';
import '../../../../shared/providers/repository_providers.dart';

/// The Owner's detailed finance summary.
///
/// Cached for the session. Refresh via `ref.invalidate(ownerFinanceProvider)` —
/// the Finance tab's pull-to-refresh does exactly that.
final ownerFinanceProvider = FutureProvider<FinanceSummary>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  final result = await repo.getSummary();

  return result.fold(
    onSuccess: (summary) => summary,
    onFailure: (failure) => throw failure,
  );
});