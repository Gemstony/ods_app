import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/dashboard_kpis.dart';
import 'package:ods_app/data/repositories/dashboard_repository.dart';

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

Map<String, dynamic> _successBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'branches': {'total_active': 5},
        'users': {
          'total_active': 59,
          'pending_approvals': 3,
          'managers': 5,
          'riders': 12,
          'receivers': 8,
          'distributors': 34,
        },
        'deliveries': {
          'today_count': 12,
          'today_delivered': 8,
          'active_count': 15,
          'this_week_count': 87,
        },
        'revenue': {
          'today_tsh': 24000.00,
          'this_week_tsh': 156000.00,
          'this_month_tsh': 892000.00,
        },
        'payables': {
          'rider_earnings_pending_tsh': 30000.00,
          'dispatcher_earnings_pending_tsh': 15000.00,
          'transport_fare_owed_tsh': 45000.00,
        },
        'disputes': {'open_count': 2},
        'generated_at': '2026-11-01T10:30:00+00:00',
      },
    };

void main() {
  group('DashboardRepository.getKpis', () {
    test('calls GET /owner/dashboard and parses the response', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successBody(),
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getKpis();

      expect(result, isA<ApiSuccess<DashboardKpis>>());
      final kpis = result.dataOrNull!;
      expect(kpis.branches.totalActive, 5);
      expect(kpis.users.pendingApprovals, 3);
      expect(kpis.revenue.todayTsh, 24000.0);
      expect(kpis.payables.totalTsh, 90000.0);
      expect(kpis.openDisputes, 2);
      expect(adapter.lastRequest!.path, '/owner/dashboard');
      expect(adapter.lastRequest!.method, 'GET');
    });

    test('maps 403 to an auth failure (non-Owner calling)', () async {
      final adapter = _CapturingAdapter(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'You do not have access to this resource.',
          'errors': null,
        },
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getKpis();

      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'auth');
    });

    test('maps 500 to a server failure', () async {
      final adapter = _CapturingAdapter(
        statusCode: 500,
        body: {
          'success': false,
          'message': 'Server error.',
          'errors': null,
        },
      );
      final repo = DashboardRepository(dio: _dioWith(adapter));

      final result = await repo.getKpis();

      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'server');
    });
  });
}