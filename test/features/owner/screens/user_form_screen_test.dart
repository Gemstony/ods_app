import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/api_interceptors.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/data/repositories/user_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/user_form_screen.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

// ─────────────────────────────────────────────────────────────────────
// Mock adapter (returns canned responses to every request)
// ─────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────
// Branches payload (needed for the branch dropdown to populate)
// ─────────────────────────────────────────────────────────────────────

Map<String, dynamic> _branchesBody() => {
      'success': true,
      'message': 'OK',
      'data': {
        'data': [
          {
            'id': 5,
            'name': 'KRK Branch',
            'code': 'KRK-01',
            'address': 'Kariakoo, DSM',
            'latitude': -6.79,
            'longitude': 39.20,
            'status': 'active',
          },
        ],
        'total': 1,
        'per_page': 20,
        'current_page': 1,
        'last_page': 1,
      },
    };

// ─────────────────────────────────────────────────────────────────────
// Harness
// ─────────────────────────────────────────────────────────────────────

/// Makes the test viewport tall enough that the entire `ListView` renders.
///
/// Without this, the "Create user" button and the role-specific fields
/// (NIDA, Vehicle, Dispatcher toggle) sit below the default 600px
/// viewport. Flutter's ListView lazily builds children, so
/// `find.widgetWithText(...)` and `find.text(...)` genuinely find
/// nothing — the widgets exist in the widget tree only if built.
void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _wrap({
  required UserRepository userRepo,
  required BranchRepository branchRepo,
}) =>
    ProviderScope(
      overrides: [
        userRepositoryProvider.overrideWithValue(userRepo),
        branchRepositoryProvider.overrideWithValue(branchRepo),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const UserFormScreen(),
      ),
    );

UserRepository _okUserRepo() => UserRepository(
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
            'role': 'manager',
            'status': 'active',
            'dispatcher_enabled': false,
            'permissions': <String>[],
          },
        },
      )),
    );

BranchRepository _okBranchRepo() => BranchRepository(
      dio: _dioWith(_Adapter(statusCode: 200, body: _branchesBody())),
    );

// ─────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('validates common fields on empty submit', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(userRepo: _okUserRepo(), branchRepo: _okBranchRepo()),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Create user'));
    await tester.pumpAndSettle();

    // Branch is checked first via a snackbar, before form validation
    expect(find.textContaining('Please select a branch'), findsOneWidget);
  });

  testWidgets('switches to Rider mode shows rider fields', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(userRepo: _okUserRepo(), branchRepo: _okBranchRepo()),
    );
    await tester.pumpAndSettle();

    // Default is Manager — no NIDA field
    expect(find.text('NIDA number'), findsNothing);

    // Switch to Rider
    await tester.tap(find.text('Rider'));
    await tester.pumpAndSettle();

    // Rider fields now present
    expect(find.text('NIDA number'), findsOneWidget);
    expect(find.text('Vehicle type'), findsOneWidget);
    expect(find.text('Vehicle color'), findsOneWidget);
    expect(find.text('Plate number'), findsOneWidget);
  });

  testWidgets('switches to Receiver mode shows dispatcher toggle',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(userRepo: _okUserRepo(), branchRepo: _okBranchRepo()),
    );
    await tester.pumpAndSettle();

    // Default is Manager — no dispatcher toggle
    expect(find.text('Dispatcher enabled'), findsNothing);

    await tester.tap(find.text('Receiver'));
    await tester.pumpAndSettle();

    expect(find.text('Dispatcher enabled'), findsOneWidget);
  });

  testWidgets('switching back to Manager hides role-specific fields',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(userRepo: _okUserRepo(), branchRepo: _okBranchRepo()),
    );
    await tester.pumpAndSettle();

    // Go to Rider
    await tester.tap(find.text('Rider'));
    await tester.pumpAndSettle();
    expect(find.text('NIDA number'), findsOneWidget);

    // Back to Manager
    await tester.tap(find.text('Manager'));
    await tester.pumpAndSettle();

    expect(find.text('NIDA number'), findsNothing);
    expect(find.text('Dispatcher enabled'), findsNothing);
  });
}