import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_branch_form_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});
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

Dio _dioWith(_Adapter a) {
  final d = Dio(BaseOptions(
    baseUrl: 'http://localhost:8000/api/v1',
    validateStatus: (s) => s != null && s < 400,
  ));
  d.httpClientAdapter = a;
  d.interceptors.add(ErrorMappingInterceptor());
  return d;
}

Branch _branch() => const Branch(
      id: 5,
      name: 'Kariakoo Branch',
      code: 'KRK-01',
      address: '123 Kariakoo',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

Widget _wrap(BranchRepository repo) => ProviderScope(
      overrides: [branchRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: ManagerBranchFormScreen(initialBranch: _branch()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('pre-fills name, address, lat, lng', (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: const {'success': true, 'message': 'OK', 'data': {}},
    );
    await tester.pumpWidget(
      _wrap(BranchRepository(dio: _dioWith(adapter))),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo Branch'), findsOneWidget);
    expect(find.text('123 Kariakoo'), findsOneWidget);
    expect(find.text('-6.79'), findsOneWidget);
    expect(find.text('39.2'), findsOneWidget);
  });

  testWidgets('shows locked fields for code and status', (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: const {'success': true, 'message': 'OK', 'data': {}},
    );
    await tester.pumpWidget(
      _wrap(BranchRepository(dio: _dioWith(adapter))),
    );
    await tester.pumpAndSettle();

    expect(find.text('KRK-01'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Locked'), findsNWidgets(2));
  });

  testWidgets('validates empty name', (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: const {'success': true, 'message': 'OK', 'data': {}},
    );
    await tester.pumpWidget(
      _wrap(BranchRepository(dio: _dioWith(adapter))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Branch name'),
      '',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Branch name is required.'), findsOneWidget);
  });

  testWidgets('validates latitude range', (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: const {'success': true, 'message': 'OK', 'data': {}},
    );
    await tester.pumpWidget(
      _wrap(BranchRepository(dio: _dioWith(adapter))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Latitude'),
      '100',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(find.text('Must be between -90 and 90.'), findsOneWidget);
  });

  testWidgets('submits PUT /manager/branch with editable fields only',
      (tester) async {
    _useLargeViewport(tester);
    final adapter = _Adapter(
      statusCode: 200,
      body: {
        'success': true,
        'message': 'Branch updated.',
        'data': {
          'id': 5,
          'name': 'Updated Name',
          'code': 'KRK-01',
          'address': '456 New Address',
          'latitude': -6.85,
          'longitude': 39.25,
          'operating_hours': null,
          'status': 'active',
        },
      },
    );
    await tester.pumpWidget(
      _wrap(BranchRepository(dio: _dioWith(adapter))),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Branch name'),
      'Updated Name',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Address'),
      '456 New Address',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Save changes'));
    await tester.pumpAndSettle();

    expect(adapter.lastRequest!.path, '/manager/branch');
    expect(adapter.lastRequest!.method, 'PUT');
    final sent = adapter.lastRequest!.data as Map<String, dynamic>;
    expect(sent['name'], 'Updated Name');
    expect(sent['address'], '456 New Address');
    expect(sent.containsKey('code'), isFalse);
    expect(sent.containsKey('status'), isFalse);
  });
}