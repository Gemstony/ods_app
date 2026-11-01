import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/pricing_config.dart';
import 'package:ods_app/data/repositories/pricing_config_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/pricing_config_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

/// Makes the test viewport tall enough for the full ListView to render.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
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

/// Captures every request the adapter sees so tests can look up the PUT
/// specifically — the screen's success handler invalidates the provider,
/// which triggers a subsequent GET that would otherwise overwrite
/// `lastRequest`.
class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;
  final List<RequestOptions> captured = [];

  /// Returns the last captured PUT request, or throws a helpful error
  /// listing every request that was made (surfaces "why didn't PUT fire"
  /// failures clearly).
  RequestOptions get lastPut {
    final puts = captured.where((r) => r.method == 'PUT').toList();
    if (puts.isEmpty) {
      throw StateError(
        'No PUT request was captured. Requests made: '
        '${captured.map((r) => '${r.method} ${r.path}').toList()}',
      );
    }
    return puts.last;
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

Dio _dioWith(_Adapter a) {
  final d = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  d.httpClientAdapter = a;
  d.interceptors.add(ErrorMappingInterceptor());
  return d;
}

Widget _wrap(PricingConfigRepository repo) => ProviderScope(
      overrides: [pricingConfigRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const PricingConfigScreen(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('pre-fills all 16 fields with current values', (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: {'success': true, 'message': 'OK', 'data': _configJson()},
    );
    final repo = PricingConfigRepository(dio: _dioWith(adapter));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Section headers
    expect(find.text('Local delivery'), findsOneWidget);
    expect(find.text('Regional delivery'), findsOneWidget);
    expect(find.text('Compensation'), findsOneWidget);
    expect(find.text('Rewards'), findsOneWidget);

    // Sample values pre-populated
    expect(find.text('500'), findsWidgets);
    expect(find.text('80'), findsWidgets);
    expect(find.text('10'), findsWidgets);
    expect(find.text('20'), findsWidgets);
    expect(find.text('50'), findsWidgets);
  });

  testWidgets('save submits all 16 fields', (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: {
        'success': true,
        'message': 'Pricing configuration updated.',
        'data': _configJson(),
      },
    );
    final repo = PricingConfigRepository(dio: _dioWith(adapter));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Tap Save
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
    await tester.pumpAndSettle();

    // Look up the PUT specifically — the screen's success handler will
    // have triggered a follow-up GET via `ref.invalidate`, so we can't
    // just check "the last request".
    final putRequest = adapter.lastPut;
    final sent = putRequest.data as Map<String, dynamic>;

    expect(sent.length, 16);
    expect(sent['local_rate_per_km'], 500);
    expect(sent['dispatcher_compensation_model'], 'flat_per_package');
    // Meta fields must NOT be present in the update payload
    expect(sent.containsKey('id'), isFalse);
    expect(sent.containsKey('created_at'), isFalse);
    expect(sent.containsKey('updated_at'), isFalse);
    expect(sent.containsKey('updated_by'), isFalse);
  });

  testWidgets('dispatcher model dropdown reveals conditional field',
      (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: {'success': true, 'message': 'OK', 'data': _configJson()},
    );
    final repo = PricingConfigRepository(dio: _dioWith(adapter));

    await tester.pumpWidget(_wrap(repo));
    await tester.pumpAndSettle();

    // Default model shows the flat-fee field
    expect(find.text('Dispatcher fee per package (TZS)'), findsOneWidget);

    // Switch to shift allowance
    await tester.tap(find.text('Fixed amount per package'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shift allowance').last);
    await tester.pumpAndSettle();

    // Conditional field swapped
    expect(find.text('Dispatcher fee per package (TZS)'), findsNothing);
    expect(find.text('Shift allowance (TZS)'), findsOneWidget);
  });
}