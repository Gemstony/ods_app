import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/ledger_entries.dart';
import '../models/payment_detail.dart';
import '../models/reconciliation_report.dart';

/// Owner-only ledger + reconciliation endpoints (Phase 11.4 backend).
class OwnerLedgerRepository {
  final Dio _dio;

  OwnerLedgerRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── Payments ────────────────────────────────────────────
  Future<ApiResult<List<OwnerPaymentEntry>>> listPayments({
    List<String>? statuses,
    String? method,
    int? deliveryId,
    String? reference,
    DateTime? from,
    DateTime? to,
    int perPage = 20,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerPayments,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.join(','),
          if (method != null) 'method': method,
          if (deliveryId != null) 'delivery_id': deliveryId,
          if (reference != null && reference.isNotEmpty) 'reference': reference,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          'per_page': perPage,
          'page': page,
        },
      );

      final data = _extractData(response);
      return _extractList(data, OwnerPaymentEntry.fromJson);
    });
  }

  Future<ApiResult<PaymentDetail>> showPayment(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.ownerPayments}/$id',
      );
      return PaymentDetail.fromJson(_extractData(response));
    });
  }

  // ─── Earnings ────────────────────────────────────────────
  Future<ApiResult<List<OwnerEarningEntry>>> listEarnings({
    List<String>? statuses,
    List<String>? types,
    int? userId,
    int? deliveryId,
    DateTime? from,
    DateTime? to,
    int perPage = 20,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerEarnings,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.join(','),
          if (types != null && types.isNotEmpty) 'type': types.join(','),
          if (userId != null) 'user_id': userId,
          if (deliveryId != null) 'delivery_id': deliveryId,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          'per_page': perPage,
          'page': page,
        },
      );
      final data = _extractData(response);
      return _extractList(data, OwnerEarningEntry.fromJson);
    });
  }

  Future<ApiResult<OwnerEarningEntry>> showEarning(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.ownerEarnings}/$id',
      );
      return OwnerEarningEntry.fromJson(_extractData(response));
    });
  }

  // ─── Payouts ─────────────────────────────────────────────
  Future<ApiResult<List<OwnerPayoutEntry>>> listPayouts({
    List<String>? statuses,
    String? method,
    int? userId,
    DateTime? from,
    DateTime? to,
    int perPage = 20,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerPayouts,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.join(','),
          if (method != null) 'method': method,
          if (userId != null) 'user_id': userId,
          if (from != null) 'from': _date(from),
          if (to != null) 'to': _date(to),
          'per_page': perPage,
          'page': page,
        },
      );
      final data = _extractData(response);
      return _extractList(data, OwnerPayoutEntry.fromJson);
    });
  }

  Future<ApiResult<OwnerPayoutEntry>> showPayout(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.ownerPayouts}/$id',
      );
      return OwnerPayoutEntry.fromJson(_extractData(response));
    });
  }

  // ─── Reconciliation ──────────────────────────────────────
  Future<ApiResult<ReconciliationReport>> runReconciliation({
    DateTime? since,
    bool dryRun = false,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.ownerLedgerReconcile,
        data: {
          if (since != null) 'since': _date(since),
          'dry_run': dryRun,
        },
      );
      return ReconciliationReport.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<ReconciliationLastRun>> lastReconciliation() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.ownerLedgerReconcileLast,
      );
      return ReconciliationLastRun.fromJson(_extractData(response));
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

  String _date(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}