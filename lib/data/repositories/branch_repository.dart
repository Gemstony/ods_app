import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/branch.dart';
import '../models/branch_input.dart';

/// Talks to every `/api/v1/owner/branches*` endpoint.
///
/// Used by:
///   - **Owner** (Phase 5) — full CRUD on branches.
///   - **Manager** (Phase 6) — reads own branch to populate dashboards.
///   - **Anyone with a branch picker** — `list()` for dropdowns.
///
/// Branch authorization (which branches a user can see) is enforced on the
/// **backend** via role + branch-scope middleware. This repository always
/// calls the same `/owner/branches` endpoint and trusts the server.
class BranchRepository {
  final Dio _dio;

  BranchRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── List ─────────────────────────────────────────────────
  /// GET /owner/branches
  ///
  /// Returns all branches the caller can see. When [status] is provided,
  /// the backend filters by that status.
  Future<ApiResult<List<Branch>>> list({BranchStatus? status}) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerBranches,
        queryParameters: {
          if (status != null) 'status': status.name,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Branch.fromJson);
    });
  }

  // ─── Get one ──────────────────────────────────────────────
  /// GET /owner/branches/{id}
  Future<ApiResult<Branch>> get(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.ownerBranches}/$id',
      );

      final data = _extractData(response);
      return Branch.fromJson(data);
    });
  }

  // ─── Create ───────────────────────────────────────────────
  /// POST /owner/branches
  Future<ApiResult<Branch>> create(BranchInput input) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.ownerBranches,
        data: input.toJson(),
      );

      final data = _extractData(response);
      return Branch.fromJson(data);
    });
  }

  // ─── Update ───────────────────────────────────────────────
  /// PUT /owner/branches/{id}
  Future<ApiResult<Branch>> update(int id, BranchInput input) {
    return ApiResult.guard(() async {
      final response = await _dio.put<Map<String, dynamic>>(
        '${ApiEndpoints.ownerBranches}/$id',
        data: input.toJson(),
      );

      final data = _extractData(response);
      return Branch.fromJson(data);
    });
  }

  // ─── Envelope helpers ────────────────────────────────────
  Map<String, dynamic> _extractData(Response<Map<String, dynamic>> response) {
    final body = response.data;
    if (body == null) throw StateError('Empty response body');
    final data = body['data'];
    if (data is! Map<String, dynamic>) {
      throw StateError('Unexpected envelope shape: $body');
    }
    return data;
  }

  /// Handles both raw-array payloads and `{data: [...], meta: {...}}`
  /// paginated payloads. The `data` field of `_extractData` can be either
  /// a list (raw collection) or a map with a `data` array (paginated).
  List<T> _extractList<T>(
    Map<String, dynamic> data,
    T Function(Map<String, dynamic> json) itemFromJson,
  ) {
    final raw = data['data'] ?? data;
    if (raw is! List) {
      throw StateError('Expected list in data, got ${raw.runtimeType}');
    }
    return raw
        .whereType<Map>()
        .map((j) => itemFromJson(Map<String, dynamic>.from(j)))
        .toList(growable: false);
  }
}