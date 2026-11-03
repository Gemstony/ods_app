import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/reward.dart';
import '../models/distributor_dashboard_kpis.dart';

/// Talks to every `/api/v1/rewards/*` endpoint.
///
/// Only the distributor's own progress is readable through this repository.
/// Reward **redemption** (turning a tier into a discount on a specific
/// delivery) lives in Phase 13 — its endpoints are still being designed,
/// so nothing here attempts to guess them.
class RewardRepository {
  final Dio _dio;

  RewardRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── My progress ──────────────────────────────────────────
  /// GET /rewards/me
  ///
  /// Returns the caller's reward progress — monthly count toward tier 1,
  /// rolling count toward tier 2, availability flags, and expiration
  /// timestamps. Backend creates the row on first fetch (mirrors
  /// `Reward::for()` from Phase 2.5).
  Future<ApiResult<Reward>> getMyProgress() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.rewardsMe,
      );

      final data = _extractData(response);

      // Tolerant of two response shapes:
      //   - {progress: {...}, thresholds: {...}} — current backend (7.7)
      //   - flat reward object                  — legacy shape (4.5 tests)
      final progressMap = data['progress'];
      if (progressMap is Map<String, dynamic>) {
        return Reward.fromJson(progressMap);
      }
      return Reward.fromJson(data);
    });
  }

  // ─── Envelope helper ─────────────────────────────────────
  Map<String, dynamic> _extractData(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw StateError('Empty response body');
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected envelope shape: $body');
    }
    return data;
  }

  // ─── Overview (progress + thresholds) ────────────────────
  /// GET /rewards/me — returns progress AND current thresholds.
  ///
  /// Used by the Rewards tab. Same endpoint as [getMyProgress] but
  /// returns the full payload including thresholds. The response shape
  /// matches [DistributorRewardKpis] (which is also what the dashboard
  /// endpoint nests under its `rewards` field).
  Future<ApiResult<DistributorRewardKpis>> getMyOverview() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.rewardsMe,
      );

      return DistributorRewardKpis.fromJson(_extractData(response));
    });
  }
}
