import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/earning.dart';

/// The payload of one `/rider/earnings` page: the earning rows plus the
/// server-computed summary totals.
class EarningsResult {
  final List<Earning> items;
  final double owedTsh;
  final double paidThisMonthTsh;
  final double paidTotalTsh;

  const EarningsResult({
    required this.items,
    required this.owedTsh,
    required this.paidThisMonthTsh,
    required this.paidTotalTsh,
  });

  factory EarningsResult.empty() => const EarningsResult(
        items: [],
        owedTsh: 0,
        paidThisMonthTsh: 0,
        paidTotalTsh: 0,
      );
}

/// Talks to `/api/v1/rider/earnings`.
///
/// Kept separate from [DashboardRepository] (which returns single KPI
/// objects) and [FinanceRepository] (Owner-facing). Earnings are a
/// distinct domain with pagination + signed amounts.
class EarningsRepository {
  final Dio _dio;

  EarningsRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /rider/earnings
  Future<ApiResult<EarningsResult>> listMine({
    EarningStatus? status,
    int? perPage,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.riderEarnings,
        queryParameters: {
          if (status != null) 'status': status.name,
          if (perPage != null) 'per_page': perPage,
        },
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }

      final rawList = data['data'];
      final items = rawList is List
          ? rawList
              .whereType<Map>()
              .map((j) => Earning.fromJson(Map<String, dynamic>.from(j)))
              .toList(growable: false)
          : const <Earning>[];

      final rawSummary = data['summary'];
      final summary = rawSummary is Map<String, dynamic>
          ? rawSummary
          : const <String, dynamic>{};

      return EarningsResult(
        items: items,
        owedTsh: (summary['owed_tsh'] as num?)?.toDouble() ?? 0,
        paidThisMonthTsh:
            (summary['paid_this_month_tsh'] as num?)?.toDouble() ?? 0,
        paidTotalTsh:
            (summary['paid_total_tsh'] as num?)?.toDouble() ?? 0,
      );
    });
  }
}