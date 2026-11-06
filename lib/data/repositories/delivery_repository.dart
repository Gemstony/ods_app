import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/delivery.dart';
import '../models/delivery_input.dart';
import '../models/package_verify_result.dart';

/// Talks to every `/api/v1/{distributor,manager,rider,receiver}/*` delivery
/// endpoint.
class DeliveryRepository {
  final Dio _dio;

  DeliveryRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ────────────────────────────────────────────────────────
  // Distributor-facing (Phase 7)
  // ────────────────────────────────────────────────────────

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

  Future<ApiResult<Delivery>> getMine(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.distributorDeliveries}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Delivery>> create(CreateDeliveryInput input) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        ApiEndpoints.distributorDeliveries,
        data: input.toJson(),
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

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

  Future<ApiResult<Delivery>> getForBranch(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.managerDeliveries}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

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

  Future<ApiResult<Delivery>> getRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Delivery>> acceptRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id/accept',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Delivery>> pickupRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id/pickup',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Delivery>> deliverRiderDelivery(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.riderDeliveries}/$id/deliver',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  // ────────────────────────────────────────────────────────
  // Receiver-facing (Phase 9)
  // ────────────────────────────────────────────────────────

  Future<ApiResult<List<Delivery>>> listReceiverPackages({
    List<DeliveryStatus>? statuses,
    int? perPage,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.receiverPackages,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.map((s) => s.name).join(','),
          if (perPage != null) 'per_page': perPage,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  Future<ApiResult<PackageVerifyResult>> verifyReceiverPackage(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.receiverPackages}/$id/verify',
      );
      return PackageVerifyResult.fromJson(_extractData(response));
    });
  }

  Future<ApiResult<Delivery>> releaseReceiverPackage(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.receiverPackages}/$id/release',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  // ────────────────────────────────────────────────────────
  // Receiver — Regional dispatch (Phase 9.1 backend, 9.3 UI)
  // ────────────────────────────────────────────────────────

  /// GET /receiver/regional
  ///
  /// Returns regional deliveries at the receiver's branch. Backend
  /// requires `dispatcher_enabled = true` on the authenticated user.
  /// Default statuses (server-side) are `batched` + `assigned`; pass
  /// `statuses` to override.
  Future<ApiResult<List<Delivery>>> listReceiverRegional({
    List<DeliveryStatus>? statuses,
    int? perPage,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.receiverRegional,
        queryParameters: {
          if (statuses != null && statuses.isNotEmpty)
            'status': statuses.map((s) => s.name).join(','),
          if (perPage != null) 'per_page': perPage,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  /// POST /receiver/regional/{id}/assign
  ///
  /// Transitions `batched → assigned` and stamps `dispatcher_id`.
  Future<ApiResult<Delivery>> assignRegionalDispatcher(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.receiverRegional}/$id/assign',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// POST /receiver/regional/{id}/dispatch
  ///
  /// Transitions `assigned → dispatched` and creates a `DispatcherTicket`.
  /// `transportFare` falls back to `deliveries.bus_cargo_fare` on the
  /// backend when null.
  Future<ApiResult<Delivery>> dispatchRegionalProvider(
    int id, {
    required String providerName,
    required String providerType,
    required String ticketNumber,
    required String routeFrom,
    required String routeTo,
    double? transportFare,
    String? notes,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.post<Map<String, dynamic>>(
        '${ApiEndpoints.receiverRegional}/$id/dispatch',
        data: {
          'provider_name': providerName,
          'provider_type': providerType,
          'ticket_number': ticketNumber,
          'route_from': routeFrom,
          'route_to': routeTo,
          if (transportFare != null) 'transport_fare': transportFare,
          if (notes != null && notes.isNotEmpty) 'notes': notes,
        },
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