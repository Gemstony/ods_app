import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/models/pricing_config.dart';
import 'package:ods_app/data/repositories/pricing_config_repository.dart';

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

Dio _dioWith(_CapturingAdapter a) {
  final d = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  d.httpClientAdapter = a;
  d.interceptors.add(ErrorMappingInterceptor());
  return d;
}

Map<String, dynamic> _configJson() => {
      'id': 1,
      'local_rate_per_km': 500.0,
      'local_minimum_fee': 1000.0,
      'local_rounding_increment': 500,
      'regional_base_fee': 0.0,
      'regional_minimum_fee': 0.0,
      'regional_rounding_increment': 500,
      'rider_baseline_percent': 80.0,
      'rider_bonus_percent': 10.0,
      'dispatcher_compensation_model': 'flat_per_package',
      'dispatcher_flat_fee': 500.0,
      'dispatcher_shift_allowance': 0.0,
      'dispatcher_percent': 0.0,
      'reward_tier1_threshold': 20,
      'reward_tier1_discount_percent': 50.0,
      'reward_tier2_threshold': 50,
      'reward_rolling_window_days': 30,
      'updated_by': null,
    };

PricingConfig _sampleConfig() => const PricingConfig(
      id: 1,
      localRatePerKm: 500,
      localMinimumFee: 1000,
      localRoundingIncrement: 500,
      regionalBaseFee: 0,
      regionalMinimumFee: 0,
      regionalRoundingIncrement: 500,
      riderBaselinePercent: 80,
      riderBonusPercent: 10,
      dispatcherCompensationModel: DispatcherCompensationModel.flatPerPackage,
      dispatcherFlatFee: 500,
      dispatcherShiftAllowance: 0,
      dispatcherPercent: 0,
      rewardTier1Threshold: 20,
      rewardTier1DiscountPercent: 50,
      rewardTier2Threshold: 50,
      rewardRollingWindowDays: 30,
    );

void main() {
  group('PricingConfigRepository.get', () {
    test('GETs and parses the singleton config', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'OK',
          'data': _configJson(),
        },
      );
      final repo = PricingConfigRepository(dio: _dioWith(adapter));

      final result = await repo.get();

      expect(result, isA<ApiSuccess<PricingConfig>>());
      expect(result.dataOrNull!.localRatePerKm, 500.0);
      expect(adapter.lastRequest!.path, '/owner/pricing-config');
      expect(adapter.lastRequest!.method, 'GET');
    });
  });

  group('PricingConfigRepository.update', () {
    test('PUTs all 16 fields', () async {
      final adapter = _CapturingAdapter(
        statusCode: 200,
        body: {
          'success': true,
          'message': 'Pricing configuration updated.',
          'data': _configJson(),
        },
      );
      final repo = PricingConfigRepository(dio: _dioWith(adapter));

      final result = await repo.update(_sampleConfig());

      expect(result, isA<ApiSuccess<PricingConfig>>());
      expect(adapter.lastRequest!.method, 'PUT');
      final sent = adapter.lastRequest!.data as Map<String, dynamic>;
      expect(sent.length, 16); // exactly the 16 mutable fields
      expect(sent['local_rate_per_km'], 500);
      expect(sent['dispatcher_compensation_model'], 'flat_per_package');
      // Meta fields should NOT be in the payload
      expect(sent.containsKey('id'), isFalse);
      expect(sent.containsKey('created_at'), isFalse);
    });
  });
}