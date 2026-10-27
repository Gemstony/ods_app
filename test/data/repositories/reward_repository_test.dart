import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/data/repositories/reward_repository.dart';

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

Map<String, dynamic> _rewardJson({
  int monthlyCount = 0,
  int rollingCount = 0,
  bool tier1Available = false,
  bool tier2Available = false,
}) =>
    {
      'id': 1,
      'distributor_id': 42,
      'current_month': '2026-10',
      'monthly_count': monthlyCount,
      'tier1_available': tier1Available,
      'tier1_reached_at':
          tier1Available ? '2026-10-24T07:00:00+00:00' : null,
      'tier1_expires_at': tier1Available
          ? DateTime.now().add(const Duration(days: 30)).toIso8601String()
          : null,
      'rolling_count': rollingCount,
      'rolling_window_start': '2026-09-24T00:00:00+00:00',
      'tier2_available': tier2Available,
      'tier2_reached_at':
          tier2Available ? '2026-10-24T07:00:00+00:00' : null,
      'tier2_expires_at': tier2Available
          ? DateTime.now().add(const Duration(days: 30)).toIso8601String()
          : null,
      'created_at': '2026-09-24T00:00:00+00:00',
      'updated_at': '2026-10-24T07:00:00+00:00',
    };

Map<String, dynamic> _successEnvelope(Map<String, dynamic> data) => {
      'success': true,
      'message': 'OK',
      'data': data,
    };

void main() {
  group('RewardRepository.getMyProgress', () {
    test('fetches /rewards/me with fresh progress', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_rewardJson()),
      );
      final repo = RewardRepository(dio: _dioWith(adapter));

      final result = await repo.getMyProgress();

      expect(result, isA<ApiSuccess<Reward>>());
      final reward = result.dataOrNull!;
      expect(reward.distributorId, 42);
      expect(reward.monthlyCount, 0);
      expect(reward.rollingCount, 0);
      expect(reward.hasAnyAvailable, isFalse);
      expect(adapter.lastRequest!.path, '/rewards/me');
      expect(adapter.lastRequest!.method, 'GET');
    });

    test('parses mid-progress state (10/20 monthly)', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_rewardJson(monthlyCount: 10)),
      );
      final repo = RewardRepository(dio: _dioWith(adapter));

      final result = await repo.getMyProgress();

      expect(result.dataOrNull!.monthlyCount, 10);
      expect(result.dataOrNull!.progressToTier1(20), 0.5);
      expect(result.dataOrNull!.remainingForTier1(20), 10);
      expect(result.dataOrNull!.isTier1Usable, isFalse);
    });

    test('parses tier1 available state', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_rewardJson(
          monthlyCount: 20,
          tier1Available: true,
        )),
      );
      final repo = RewardRepository(dio: _dioWith(adapter));

      final result = await repo.getMyProgress();

      final reward = result.dataOrNull!;
      expect(reward.monthlyCount, 20);
      expect(reward.tier1Available, isTrue);
      expect(reward.isTier1Usable, isTrue);
      expect(reward.hasAnyAvailable, isTrue);
      expect(reward.progressToTier1(20), 1.0);
      expect(reward.remainingForTier1(20), 0);
    });

    test('parses both tiers available state', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: _successEnvelope(_rewardJson(
          monthlyCount: 25,
          rollingCount: 55,
          tier1Available: true,
          tier2Available: true,
        )),
      );
      final repo = RewardRepository(dio: _dioWith(adapter));

      final result = await repo.getMyProgress();

      final reward = result.dataOrNull!;
      expect(reward.isTier1Usable, isTrue);
      expect(reward.isTier2Usable, isTrue);
      expect(reward.hasAnyAvailable, isTrue);
    });

    test('maps 401 to auth failure when session expired', () async {
      final adapter = _CapturingAdapter(
        statusCode: 401,
        body: {
          'success': false,
          'message': 'Unauthenticated.',
          'errors': null,
        },
      );
      final repo = RewardRepository(dio: _dioWith(adapter));

      final result = await repo.getMyProgress();

      expect(result, isA<ApiFailure>());
      expect(result.failureOrNull!.type.name, 'auth');
    });
  });
}