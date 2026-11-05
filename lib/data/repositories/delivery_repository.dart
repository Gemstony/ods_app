import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/delivery.dart';
import '../models/delivery_input.dart';

/// Talks to every `/api/v1/{distributor,manager,rider}/*` delivery endpoint.
///
/// One repository per role would be cleaner in isolation — but the
/// endpoints, response shape, and model are identical across roles, so a
/// single repository is simpler to wire. Backend authorization ensures
/// a Distributor can only call `/distributor/*`, a Rider only `/rider/*`,
/// and so on.
class DeliveryRepository {
  final Dio _dio;

  DeliveryRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ────────────────────────────────────────────────────────
  // Distributor-facing (Phase 7)
  // ────────────────────────────────────────────────────────

  /// GET /distributor/deliveries
  Future<ApiResult<List<Delivery>>> listMine({
    DeliveryStatus? status,
    ServiceType? serviceType,
    int? limit,
    int? offset,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.distributorDeliveries,
        queryParameters: {
          if (status != null) 'status': status.name,
          if (serviceType != null) 'service_type': serviceType.name,
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  /// GET /distributor/deliveries/{id}
  Future<ApiResult<Delivery>> getMine(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.distributorDeliveries}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// POST /distributor/deliveries
  Future<ApiResult<Delivery>> create(CreateDeliveryInput input) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.distributorDeliveries,
        data: input.toJson(),
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// POST /distributor/deliveries/price-preview
  Future<ApiResult<PricePreviewResult>> pricePreview(
    PricePreviewInput input,
  ) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.distributorPricePreview,
        data: input.toJson(),
      );
      return PricePreviewResult.fromJson(_extractData(response));
    });
  }

  // ────────────────────────────────────────────────────────
  // Manager-facing (Phase 6)
  // ────────────────────────────────────────────────────────

  /// GET /manager/deliveries
  Future<ApiResult<List<Delivery>>> listForBranch({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
    int page = 1,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.managerDeliveries,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.map((s) => s.name).join(','),
          if (serviceType != null) 'service_type': serviceType.name,
          if (perPage != null) 'per_page': perPage,
          'page': page,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  /// GET /manager/deliveries/{id}
  Future<ApiResult<Delivery>> getForBranch(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.managerDeliveries}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// GET /manager/packages
  Future<ApiResult<List<Delivery>>> listAtBranch() {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '/manager/packages',
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  // ────────────────────────────────────────────────────────
  // Rider-facing (Phase 8)
  // ────────────────────────────────────────────────────────

  /// GET /rider/deliveries
  ///
  /// Filters mirror the backend (Phase 8.1):
  ///   - statuses: comma-separated list, e.g. `[accepted, picked_up]`
  ///   - serviceType: single type
  ///   - perPage: caps at 100 server-side
  Future<ApiResult<List<Delivery>>> listForRider({
    List<DeliveryStatus>? statuses,
    ServiceType? serviceType,
    int? perPage,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.riderDeliveries,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.map((s) => s.name).join(','),
          if (serviceType != null) 'service_type': serviceType.name,
          if (perPage != null) 'per_page': perPage,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  /// GET /rider/deliveries/{id}
  Future<ApiResult<Delivery>> getRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// POST /rider/deliveries/{id}/accept
  Future<ApiResult<Delivery>> acceptRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id/accept',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// POST /rider/deliveries/{id}/pickup
  Future<ApiResult<Delivery>> pickupRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id/pickup',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// POST /rider/deliveries/{id}/deliver
  ///
  /// Phase 8.1 ships this as a plain status transition — no verification
  /// code yet. Phase 12 will add a `verification_code` body field once
  /// the code-handover flow exists. When that lands, add a
  /// `verificationCode` parameter here; the widget layer already calls
  /// this via the rider controller, not directly.
  Future<ApiResult<Delivery>> deliverRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id/deliver',
      );
      return Delivery.fromJson(_extractData(response));
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
}