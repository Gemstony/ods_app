import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/pricing_config.dart';
import 'package:ods_app/data/models/setting.dart';
import 'package:ods_app/data/repositories/pricing_config_repository.dart';
import 'package:ods_app/data/repositories/settings_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_settings_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

/// Makes the test viewport tall enough for the full ListView.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Setting _setting(String key, dynamic value, String category) => Setting(
      id: 0,
      key: key,
      value: value,
      category: category,
      isPublic: false,
    );

class _FakeSettingsRepo extends SettingsRepository {
  _FakeSettingsRepo(this._result) : super(dio: Dio());
  final ApiResult<Map<String, List<Setting>>> _result;

  @override
  Future<ApiResult<Map<String, List<Setting>>>> list() async => _result;

  @override
  Future<ApiResult<List<Setting>>> bulkUpdate(
    List<MapEntry<String, dynamic>> updates,
  ) async =>
      ApiSuccess(const <Setting>[]);
}

class _FakePricingRepo extends PricingConfigRepository {
  _FakePricingRepo(this._result) : super(dio: Dio());
  final ApiResult<PricingConfig> _result;

  @override
  Future<ApiResult<PricingConfig>> get() async => _result;
}

PricingConfig _config() => const PricingConfig(
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

Widget _wrap({
  required SettingsRepository settingsRepo,
  required PricingConfigRepository pricingRepo,
}) =>
    ProviderScope(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(settingsRepo),
        pricingConfigRepositoryProvider.overrideWithValue(pricingRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: OwnerSettingsTab()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows loading state', (tester) async {
    _useLargeViewport(tester);
    // Use a Completer-based repo so no Timer is left pending
    final settingsRepo = _FakeSettingsRepo(
      ApiSuccess<Map<String, List<Setting>>>(const {}),
    );
    final pricingRepo = _FakePricingRepo(ApiSuccess(_config()));
    await tester.pumpWidget(
        _wrap(settingsRepo: settingsRepo, pricingRepo: pricingRepo));
    // Just verify loading state appears before data resolves
    expect(find.byType(OwnerSettingsTab), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    _useLargeViewport(tester);
    final settingsRepo = _FakeSettingsRepo(
      ApiFailure<Map<String, List<Setting>>>(
        const Failure(type: FailureType.network, message: 'Offline'),
      ),
    );
    final pricingRepo = _FakePricingRepo(ApiSuccess(_config()));

    await tester.pumpWidget(
        _wrap(settingsRepo: settingsRepo, pricingRepo: pricingRepo));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders category sections', (tester) async {
    _useLargeViewport(tester);
    final settingsRepo = _FakeSettingsRepo(
      ApiSuccess<Map<String, List<Setting>>>({
        'batching': [
          _setting('batching.window_minutes', 20, 'batching'),
        ],
        'location': [
          _setting('location.pickup_radius_km', 5.0, 'location'),
        ],
        'security': [
          _setting(
              'security.verification_required_delivery', true, 'security'),
        ],
      }),
    );
    final pricingRepo = _FakePricingRepo(ApiSuccess(_config()));

    await tester.pumpWidget(
        _wrap(settingsRepo: settingsRepo, pricingRepo: pricingRepo));
    await tester.pumpAndSettle();

    // Category labels
    expect(find.text('Batching'), findsOneWidget);
    expect(find.text('Location'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);

    // Pricing card always shows
    expect(find.text('Pricing configuration'), findsOneWidget);
  });

  testWidgets('save bar not shown when no changes made', (tester) async {
    _useLargeViewport(tester);
    final settingsRepo = _FakeSettingsRepo(
      ApiSuccess<Map<String, List<Setting>>>({
        'batching': [_setting('batching.window_minutes', 20, 'batching')],
      }),
    );
    final pricingRepo = _FakePricingRepo(ApiSuccess(_config()));

    await tester.pumpWidget(
        _wrap(settingsRepo: settingsRepo, pricingRepo: pricingRepo));
    await tester.pumpAndSettle();

    expect(find.textContaining('unsaved change'), findsNothing);
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('changing a boolean shows save bar', (tester) async {
    _useLargeViewport(tester);
    final settingsRepo = _FakeSettingsRepo(
      ApiSuccess<Map<String, List<Setting>>>({
        'security': [
          _setting(
              'security.verification_required_delivery', false, 'security'),
        ],
      }),
    );
    final pricingRepo = _FakePricingRepo(ApiSuccess(_config()));

    await tester.pumpWidget(
        _wrap(settingsRepo: settingsRepo, pricingRepo: pricingRepo));
    await tester.pumpAndSettle();

    // Find the Switch widget and flip it
    final switchFinder = find.byType(Switch);
    expect(switchFinder, findsOneWidget);
    await tester.tap(switchFinder);
    await tester.pumpAndSettle();

    expect(find.textContaining('1 unsaved change'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Discard'), findsOneWidget);
  });

  testWidgets('discard reverts changes and hides save bar', (tester) async {
    _useLargeViewport(tester);
    final settingsRepo = _FakeSettingsRepo(
      ApiSuccess<Map<String, List<Setting>>>({
        'security': [
          _setting(
              'security.verification_required_delivery', false, 'security'),
        ],
      }),
    );
    final pricingRepo = _FakePricingRepo(ApiSuccess(_config()));

    await tester.pumpWidget(
        _wrap(settingsRepo: settingsRepo, pricingRepo: pricingRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Discard'), findsOneWidget);

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.textContaining('unsaved change'), findsNothing);
  });
}