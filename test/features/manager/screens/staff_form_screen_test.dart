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
import 'package:ods_app/data/repositories/staff_repository.dart';
import 'package:ods_app/features/manager/presentation/screens/staff_form_screen.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_branch_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

class _Adapter implements HttpClientAdapter {
  _Adapter({required this.statusCode, required this.body});
  final int statusCode;
  final Map<String, dynamic>? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
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

StaffRepository _okRepo() => StaffRepository(
      dio: _dioWith(_Adapter(
        statusCode: 201,
        body: const {
          'success': true,
          'message': 'OK',
          'data': {
            'id': 1,
            'name': 'X',
            'email': 'x@ods.test',
            'phone': '0712345678',
            'role': 'receiver',
            'status': 'active',
            'dispatcher_enabled': false,
            'permissions': <String>[],
          },
        },
      )),
    );

final _branch = Branch(
  id: 5,
  name: 'Kariakoo',
  code: 'KRK-01',
  address: 'Addr',
  latitude: -6.79,
  longitude: 39.20,
  status: BranchStatus.active,
);

Widget _wrap({StaffRepository? repo}) => ProviderScope(
      overrides: [
        staffRepositoryProvider.overrideWithValue(repo ?? _okRepo()),
        managerBranchProvider.overrideWith((ref) async => _branch),      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const StaffFormScreen(),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows branch context banner', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.textContaining('Kariakoo'), findsOneWidget);
    expect(find.textContaining('KRK-01'), findsOneWidget);
  });

  testWidgets('Receiver mode by default, no rider fields', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Dispatcher enabled'), findsOneWidget);
    expect(find.text('NIDA number'), findsNothing);
    expect(find.text('Vehicle type'), findsNothing);
  });

  testWidgets('switches to Rider mode shows rider fields', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rider'));
    await tester.pumpAndSettle();

    expect(find.text('NIDA number'), findsOneWidget);
    expect(find.text('Vehicle type'), findsOneWidget);
    expect(find.text('Plate number'), findsOneWidget);
    expect(find.text('Dispatcher enabled'), findsNothing);
  });

  testWidgets('validates required fields on empty submit', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(
        find.widgetWithText(ElevatedButton, 'Create staff member'));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required.'), findsOneWidget);
    expect(find.text('Email is required.'), findsOneWidget);
    expect(find.text('Phone is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });
}