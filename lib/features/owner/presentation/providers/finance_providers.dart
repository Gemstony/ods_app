import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/finance_summary.dart';
import '../../../../shared/providers/repository_providers.dart';

/// Finance summary for the Owner Finance tab.
///
/// Pulls from `GET /owner/finance/summary` (Phase 11.4 backend).
/// Refresh via `ref.invalidate(financeSummaryProvider)` — the Finance
/// tab's pull-to-refresh does exactly that.
final financeSummaryProvider = FutureProvider<FinanceSummary>((ref) async {
  final repo = ref.watch(financeRepositoryProvider);
  final result = await repo.getSummary();
  return result.fold(
    onSuccess: (summary) => summary,
    onFailure: (failure) => throw failure,
  );
});