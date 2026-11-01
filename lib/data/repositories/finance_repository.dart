import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_result.dart';
import '../models/finance_summary.dart';

class FinanceRepository {
  final Dio _dio;

  FinanceRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  /// GET /owner/finance/summary
  Future<ApiResult<FinanceSummary>> getSummary() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/owner/finance/summary',
      );

      final body = response.data;
      if (body == null) throw StateError('Empty response body');
      final data = body['data'];
      if (data is! Map<String, dynamic>) {
        throw StateError('Unexpected envelope shape: $body');
      }
      return FinanceSummary.fromJson(data);
    });
  }
}