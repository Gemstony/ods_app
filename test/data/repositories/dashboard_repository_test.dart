import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/dashboard_kpis.dart';
import 'package:ods_app/data/models/manager_dashboard_kpis.dart';
import 'package:ods_app/data/repositories/dashboard_repository.dart';

/// Captures every request, so tests can find the exact call made
/// even when a follow-up request happens (same pattern from 5.7 fixup).
class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;
  final List<RequestOptions> captured = [];

  RequestOptions get lastGet {
    final gets = captured.where((r) => r.method == 'GET').toList();
    if (gets.isEmpty) {
      throw StateError(
        'No GET captured. Requests: '
        '${captured.map((r) => '${r.method} ${r.path}').toList()}',
      );
    }
    return gets.last;
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    captured.add(options);
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

Dio _dioWith(_CapturingAdapter a) {
  final d = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  d.httpClientAdapter = a;
  d.interceptors.add(ErrorMappingInterceptor());
  return d;
}

Map<String, dynamic> _ownerBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'branches': {'total_active': 5},
        'users': {'total_active': 10, 'pending_approvals': 2},
        'deliveries': {'today_count': 12},
        'revenue': {'today_tsh': 24000.0},
        'payables': {},
        'disputes': {'open_count': 0},
        'generated_at': '2026-11-04T14:00:00+00:00',
      },
    };

Map<String, dynamic> _managerBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'branch': {
          'id': 5,
          'name': 'Kariakoo Branch',
          'code': 'KRK-01',
          'status': 'active',
        },
        'staff': {'total_active': 5, 'receivers': 2, 'riders': 3},
        'deliveries': {
          'today_count': 12,
          'active_count': 3,
          'waiting_pickup': 2,
          'in_transit': 1,
          'delivered_today': 8,
        },
        'revenue': {'today_tsh': 24000.0},
        'generated_at': '2026-11-04T14:00:00+00:00',
      },
    };

void main() {
  group('DashboardRepository.getKpis (Owner)', () {
    test('GETs /owner/dashboard and parses', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _ownerBody(),
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getKpis();

      expect(result, isA<ApiSuccess<DashboardKpis>>());
      expect(result.dataOrNull!.branches.totalActive, 5);
      expect(adapter.lastGet.path, '/owner/dashboard');
    });
  });

  group('DashboardRepository.getManagerKpis', () {
    test('GETs /manager/dashboard and parses', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _managerBody(),
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getManagerKpis();

      expect(result, isA<ApiSuccess<ManagerDashboardKpis>>());
      final kpis = result.dataOrNull!;
      expect(kpis.branch!.name, 'Kariakoo Branch');
      expect(kpis.deliveries.waitingPickup, 2);
      expect(kpis.revenue.todayTsh, 24000.0);
      expect(adapter.lastGet.path, '/manager/dashboard');
    });

    test('maps 403 to auth failure', () async {
      final adapter = _CapturingAdapter(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'Forbidden',
          'errors': null,
        },
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getManagerKpis();
      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'auth');
    });

    test('handles null branch response', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'OK',
          'data': {
            'branch': null,
            'staff': {'total_active': 0},
            'deliveries': {},
            'revenue': {'today_tsh': 0},
          },
        },
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getManagerKpis();
      expect(result.dataOrNull!.branch, isNull);
      expect(result.dataOrNull!.hasBranch, isFalse);
    });
  });
}