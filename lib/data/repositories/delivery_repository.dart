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
///
/// Phase 7 builds the Distributor-facing screens. Phase 6 builds the
/// Manager branch view. Phase 8 builds the Rider flow.
class DeliveryRepository {
  final Dio _dio;

  DeliveryRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ────────────────────────────────────────────────────────
  // Distributor-facing (Phase 7)
  // ────────────────────────────────────────────────────────

  /// GET /distributor/deliveries
  ///
  /// Filters are optional. Passing `null` means "no filter for this
  /// dimension". Backend supports `status`, `service_type`, and pagination
  /// (`limit`, `offset`).
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
  ///
  /// Creates the delivery and returns it in `pending_payment` status.
  /// The caller follows up with `PaymentRepository.initiate()` (Phase 4.5)
  /// to actually pay.
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
  ///
  /// Returns the fee breakdown without creating a delivery. Used by the
  /// "New delivery" form to show the distributor what they'll be charged
  /// before they confirm.
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
  ///
  /// Branch-scoped by the backend's branch middleware. Returns all
  /// deliveries associated with the manager's branch.
  Future<ApiResult<List<Delivery>>> listForBranch({
    DeliveryStatus? status,
    ServiceType? serviceType,
    int? limit,
    int? offset,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.managerDeliveries,
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

  // ────────────────────────────────────────────────────────
  // Rider-facing (Phase 8)
  // ────────────────────────────────────────────────────────

  /// GET /rider/tasks
  ///
  /// Returns the rider's currently assigned tasks. No pagination by
  /// default — a rider has few active tasks at a time.
  Future<ApiResult<List<Delivery>>> listForRider({
    DeliveryStatus? status,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.riderTasks,
        queryParameters: {
          if (status != null) 'status': status.name,
        },
      );

      final data = _extractData(response);
      return _extractList(data, Delivery.fromJson);
    });
  }

  /// GET /rider/tasks/{id}
  Future<ApiResult<Delivery>> getRiderTask(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        '${ApiEndpoints.riderTasks}/$id',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// PATCH /rider/tasks/{id}/accept
  ///
  /// Marks the delivery as `accepted`. Backend verifies:
  ///   - The rider owns this task
  ///   - The task is still in `assigned` state
  ///   - The assignment hasn't expired
  Future<ApiResult<Delivery>> acceptTask(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.riderTasks}/$id/accept',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// PATCH /rider/tasks/{id}/pickup
  ///
  /// Marks the delivery as `picked_up`. Typically requires a Receiver to
  /// confirm the handover at the branch (Phase 9). The exact contract is
  /// finalized in Phase 8, so this method may gain a `verificationCode`
  /// parameter later.
  Future<ApiResult<Delivery>> pickupTask(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.riderTasks}/$id/pickup',
      );
      return Delivery.fromJson(_extractData(response));
    });
  }

  /// PATCH /rider/tasks/{id}/deliver
  ///
  /// Marks the delivery as `delivered`. Requires the DISTRIBUTOR_CODE or
  /// RECIPIENT_CODE the recipient shares with the rider. The code is
  /// verified **server-side** — this method only sends it.
  Future<ApiResult<Delivery>> deliverTask({
    required int id,
    required String verificationCode,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.riderTasks}/$id/deliver',
        data: {'verification_code': verificationCode},
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