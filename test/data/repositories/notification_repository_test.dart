import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/app_notification.dart';
import 'package:ods_app/data/repositories/notification_repository.dart';

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;

  RequestOptions? lastRequest;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastRequest = options;
    return ResponseBody.fromString(
      body == null ? '' : jsonEncode(body),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Dio _dioWith(_CapturingAdapter adapter) {
  final dio = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  dio.httpClientAdapter = adapter;
  dio.interceptors.add(ErrorMappingInterceptor());
  return dio;
}

Map<String, dynamic> _notificationJson({
  int id = 1,
  String type = 'delivery.assigned',
  String status = 'sent',
  String? readAt,
  String? dismissedAt,
}) =>
    {
      'id': id,
      'user_id': 42,
      'type': type,
      'title': 'New delivery assigned',
      'body': 'You have been assigned delivery ODS-20261024-ABC123',
      'data': {'delivery_id': 100},
      'channels': ['in_app'],
      'status': status,
      'priority': 'normal',
      'sent_at': '2026-10-24T07:01:00+00:00',
      'read_at': readAt,
      'dismissed_at': dismissedAt,
      'expires_at': null,
      'created_at': '2026-10-24T07:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _successEnvelope(Map<String, dynamic> data) => {
      'success': true,
      'message': 'OK',
      'data': data,
    };

void main() {
  // ─── list() ────────────────────────────────────────────────
  group('NotificationRepository.list', () {
    test('fetches notifications without filters', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [_notificationJson(id: 1), _notificationJson(id: 2)],
        }),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result, isA<ApiSuccess<List<AppNotification>>>());
      expect(result.dataOrNull!.length, 2);
      expect(adapter.lastRequest!.path, '/notifications');
      expect(adapter.lastRequest!.method, 'GET');
    });

    test('passes unread_only flag as string "true"', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      await repo.list(unreadOnly: true, limit: 20);

      expect(adapter.lastRequest!.queryParameters, {
        'unread_only': 'true',
        'limit': 20,
      });
    });

    test('omits unread_only when false', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'data': <Map<String, dynamic>>[]}),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      await repo.list(unreadOnly: false);

      expect(adapter.lastRequest!.queryParameters, isEmpty);
    });

    test('parses notifications with read state', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({
          'data': [
            _notificationJson(id: 1),
            _notificationJson(id: 2, readAt: '2026-10-24T08:00:00+00:00'),
          ],
        }),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.list();

      expect(result.dataOrNull![0].isRead, isFalse);
      expect(result.dataOrNull![1].isRead, isTrue);
    });
  });

  // ─── markRead() ────────────────────────────────────────────
  group('NotificationRepository.markRead', () {
    test('sends PATCH to /notifications/{id}/read', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_notificationJson(
          id: 5,
          readAt: '2026-10-24T09:00:00+00:00',
        )),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.markRead(5);

      expect(result, isA<ApiSuccess<AppNotification>>());
      expect(result.dataOrNull!.isRead, isTrue);
      expect(adapter.lastRequest!.path, '/notifications/5/read');
      expect(adapter.lastRequest!.method, 'PATCH');
    });
  });

  // ─── dismiss() ─────────────────────────────────────────────
  group('NotificationRepository.dismiss', () {
    test('sends PATCH to /notifications/{id}/dismiss', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_notificationJson(
          id: 7,
          dismissedAt: '2026-10-24T09:00:00+00:00',
        )),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.dismiss(7);

      expect(result, isA<ApiSuccess<AppNotification>>());
      expect(result.dataOrNull!.isDismissed, isTrue);
      expect(adapter.lastRequest!.path, '/notifications/7/dismiss');
    });
  });

  // ─── markAllRead() ─────────────────────────────────────────
  group('NotificationRepository.markAllRead', () {
    test('sends PATCH to /notifications/read-all and returns count', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'marked_count': 5}),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.markAllRead();

      expect(result, isA<ApiSuccess<int>>());
      expect(result.dataOrNull, 5);
      expect(adapter.lastRequest!.path, '/notifications/read-all');
      expect(adapter.lastRequest!.method, 'PATCH');
    });

    test('returns 0 when nothing to mark', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'marked_count': 0}),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.markAllRead();

      expect(result.dataOrNull, 0);
    });

    test('handles marked_count sent as string', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope({'marked_count': '3'}),
      );
      final repo = NotificationRepository(dio: _dioWith(adapter));

      final result = await repo.markAllRead();

      expect(result.dataOrNull, 3);
    });
  });
}