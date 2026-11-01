import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/finance_summary.dart';
import 'package:ods_app/data/repositories/finance_repository.dart';

/// Adapter that captures EVERY request (not just the last one) so tests
/// can find the specific request they want. See the fixup note in 5.7:
/// any follow-up requests (e.g. after `ref.invalidate`) would otherwise
/// overwrite `lastRequest`.
class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;
  final List<RequestOptions> captured = [];

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

Dio _dioWith(_Adapter a) {
  final d = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  d.httpClientAdapter = a;
  d.interceptors.add(ErrorMappingInterceptor());
  return d;
}

Map<String, dynamic> _body() => {
      'success': true,
      'message': 'OK',
      'data': {
        'revenue': {
          'today_tsh': 24000.0,
          'this_week_tsh': 156000.0,
          'this_month_tsh': 892000.0,
          'all_time_tsh': 5000000.0,
        },
        'payables': {
          'rider_pending_tsh': 30000.0,
          'rider_approved_tsh': 15000.0,
          'dispatcher_pending_tsh': 8000.0,
          'dispatcher_approved_tsh': 2000.0,
          'transport_fare_owed_tsh': 45000.0,
        },
        'payouts': {
          'this_month_count': 12,
          'this_month_tsh': 250000.0,
          'pending_count': 3,
          'pending_tsh': 45000.0,
        },
        'transport_paid': {'this_month_tsh': 35000.0},
        'expenses': {'this_month_tsh': 75000.0, 'all_time_tsh': 300000.0},
        'reconciliation': {
          'revenue_this_month_tsh': 892000.0,
          'minus_payouts_this_month_tsh': 250000.0,
          'minus_transport_paid_this_month_tsh': 35000.0,
          'minus_expenses_this_month_tsh': 75000.0,
          'operating_surplus_tsh': 532000.0,
        },
        'recent_payouts': <Map<String, dynamic>>[],
        'generated_at': '2026-11-04T14:00:00+00:00',
      },
    };

void main() {
  group('FinanceRepository.getSummary', () {
    test('GETs /owner/finance/summary and parses the response', () async {
      final adapter = _Adapter(statusCode: 200, body: _body());
      final repo = FinanceRepository(dio: _dioWith(adapter));

      final result = await repo.getSummary();

      expect(result, isA<ApiSuccess<FinanceSummary>>());
      final s = result.dataOrNull!;
      expect(s.revenue.thisMonthTsh, 892000);
      expect(s.payables.totalTsh, 100000);
      expect(s.reconciliation.operatingSurplusTsh, 532000);
      expect(s.reconciliation.isPositive, isTrue);

      // Confirm the exact request was made
      final getRequests =
          adapter.captured.where((r) => r.method == 'GET').toList();
      expect(getRequests, isNotEmpty);
      expect(
        getRequests.any((r) => r.path == '/owner/finance/summary'),
        isTrue,
      );
    });

    test('maps 403 to auth failure', () async {
      final adapter = _Adapter(
        statusCode: 403,
        body: {
          'success': false,
          'message': 'Forbidden',
          'errors': null,
        },
      );
      final repo = FinanceRepository(dio: _dioWith(adapter));

      final result = await repo.getSummary();
      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'auth');
    });

    test('maps 500 to server failure', () async {
      final adapter = _Adapter(
        statusCode: 500,
        body: {
          'success': false,
          'message': 'Server error.',
          'errors': null,
        },
      );
      final repo = FinanceRepository(dio: _dioWith(adapter));

      final result = await repo.getSummary();
      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'server');
    });
  });
}