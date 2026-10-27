import 'package:dio/dio.dart';

import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_result.dart';
import '../models/app_notification.dart';

/// Talks to every `/api/v1/notifications/*` endpoint.
///
/// Notifications are per-user (backend scopes by JWT). In Phase 13 the
/// list screen shows unread-first, and the app badge reads `unreadCount`
/// on every session refresh.
class NotificationRepository {
  final Dio _dio;

  NotificationRepository({Dio? dio}) : _dio = dio ?? ApiClient.instance.dio;

  // ─── List ─────────────────────────────────────────────────
  /// GET /notifications
  ///
  /// Default ordering (backend): most recent first, unread first.
  /// Passing `unreadOnly: true` excludes read + dismissed entries.
  Future<ApiResult<List<AppNotification>>> list({
    bool unreadOnly = false,
    int? limit,
    int? offset,
  }) {
    return ApiResult.guard(() async {
      final response = await _dio.get<Map<String, dynamic>>(
        ApiEndpoints.notifications,
        queryParameters: {
          if (unreadOnly) 'unread_only': 'true',
          if (limit != null) 'limit': limit,
          if (offset != null) 'offset': offset,
        },
      );

      final data = _extractData(response);
      return _extractList(data, AppNotification.fromJson);
    });
  }

  // ─── Mark read ────────────────────────────────────────────
  /// PATCH /notifications/{id}/read
  ///
  /// Marks the notification as read and returns the updated record.
  /// Idempotent — calling on an already-read notification returns it
  /// unchanged (backend preserves the original `read_at` timestamp).
  Future<ApiResult<AppNotification>> markRead(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.notifications}/$id/read',
      );

      return AppNotification.fromJson(_extractData(response));
    });
  }

  // ─── Dismiss ──────────────────────────────────────────────
  /// PATCH /notifications/{id}/dismiss
  ///
  /// Hides the notification from default lists. Idempotent.
  Future<ApiResult<AppNotification>> dismiss(int id) {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.notifications}/$id/dismiss',
      );

      return AppNotification.fromJson(_extractData(response));
    });
  }

  // ─── Mark all read ────────────────────────────────────────
  /// PATCH /notifications/read-all
  ///
  /// Marks every unread notification for the current user as read.
  /// Returns the count that were actually updated (0 if already all read).
  Future<ApiResult<int>> markAllRead() {
    return ApiResult.guard(() async {
      final response = await _dio.patch<Map<String, dynamic>>(
        '${ApiEndpoints.notifications}/read-all',
      );

      final data = _extractData(response);
      final count = data['marked_count'];
      if (count is int) return count;
      if (count is String) return int.parse(count);
      return 0;
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