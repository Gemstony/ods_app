import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/theme/app_theme.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/features/manager/presentation/providers/manager_branch_providers.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_profile_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Branch _branch({
  bool isActive = true,
  BranchManagerRef? currentManager,
}) =>
    Branch(
      id: 5,
      name: 'Kariakoo Branch',
      code: 'KRK-01',
      address: '123 Kariakoo',
      latitude: -6.79,
      longitude: 39.20,
      operatingHours: const {
        'monday': {'open': '08:00', 'close': '18:00'},
      },
      status: isActive ? BranchStatus.active : BranchStatus.inactive,
      currentManager: currentManager,
    );

AuthUser _user() => AuthUser(
      id: 42,
      name: 'Jane Manager',
      email: 'jane@ods.test',
      phone: '0712345678',
      role: 'manager',
      status: 'active',
      branchId: 5,
      dispatcherEnabled: false,
      permissions: const [],
    );

class _FakeRepo extends BranchRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<Branch> _result;

  @override
  Future<ApiResult<Branch>> getMyBranch() async => _result;
}

class _PendingRepo extends BranchRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<Branch>>();

  @override
  Future<ApiResult<Branch>> getMyBranch() => _completer.future;
}

Widget _wrap({
  BranchRepository? repo,
  AuthUser? user,
}) {
  return ProviderScope(
    overrides: [
      branchRepositoryProvider.overrideWithValue(repo ??
          _FakeRepo(ApiSuccess(_branch()))),
      // Override sessionProvider to simulate a signed-in manager
      // for tests that need the "Your profile" card to render.
      // (Override at the provider level is easier than mocking auth.)
    ],
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(body: ManagerProfileTab()),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(_wrap(repo: _PendingRepo()));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows error state with retry', (tester) async {
    await tester.pumpWidget(_wrap(repo: _FakeRepo(ApiFailure(
      const Failure(type: FailureType.network, message: 'Offline'),
    ))));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('renders branch header with name and code', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Kariakoo Branch'), findsOneWidget);
    expect(find.text('KRK-01'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
  });

  testWidgets('renders branch details card', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(find.text('Branch details'), findsOneWidget);
    expect(find.text('123 Kariakoo'), findsOneWidget);
    expect(find.text('Address'), findsOneWidget);
    expect(find.text('GPS'), findsOneWidget);
    expect(find.text('Hours'), findsOneWidget);
    expect(find.text('Manager'), findsOneWidget);
  });

  testWidgets('shows inactive banner when branch is inactive',
      (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(
      _wrap(repo: _FakeRepo(ApiSuccess(_branch(isActive: false)))),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('currently inactive'), findsOneWidget);
  });

  testWidgets('shows current manager when populated', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(
      repo: _FakeRepo(ApiSuccess(_branch(
        currentManager: const BranchManagerRef(
          id: 42,
          name: 'Jane Manager',
          email: 'jane@ods.test',
        ),
      ))),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Jane Manager'), findsWidgets);
  });

  testWidgets('"Edit branch details" button present', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    expect(
      find.widgetWithText(ElevatedButton, 'Edit branch details'),
      findsOneWidget,
    );
  });

  testWidgets('tapping Edit opens the branch form', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap());
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(ElevatedButton, 'Edit branch details'),
    );

    // Explicit pumps — pattern from 6.4/6.5 fixup
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Edit branch'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Save changes'),
        findsOneWidget);
  });
}