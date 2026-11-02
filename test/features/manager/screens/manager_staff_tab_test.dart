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
import 'package:ods_app/data/repositories/staff_repository.dart';
import 'package:ods_app/features/manager/presentation/screens/manager_staff_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

void _useLargeViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

AuthUser _user(
  int id, {
  String role = 'receiver',
  String status = 'active',
  bool dispatcher = false,
}) =>
    AuthUser(
      id: id,
      name: 'User $id',
      email: 'u$id@ods.test',
      phone: '0712345678',
      role: role,
      status: status,
      dispatcherEnabled: dispatcher,
      permissions: const [],
    );

class _FakeRepo extends StaffRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<AuthUser>> _result;
  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    String? search,
    int? perPage,
    int page = 1,
  }) async =>
      _result;
}

class _PendingRepo extends StaffRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<List<AuthUser>>>();
  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    String? search,
    int? perPage,
    int page = 1,
  }) =>
      _completer.future;
}

Widget _wrap(StaffRepository repo) => ProviderScope(
      overrides: [staffRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: ManagerStaffTab()),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  testWidgets('shows loading state', (tester) async {
    await tester.pumpWidget(_wrap(_PendingRepo()));
    await tester.pump();
    expect(find.byType(LoadingView), findsOneWidget);
  });

  testWidgets('shows empty state when no staff', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess(const []))));
    await tester.pumpAndSettle();

    expect(find.text('No staff found'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Add first staff'),
        findsOneWidget);
  });

  testWidgets('renders staff cards', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _user(1, role: 'receiver', dispatcher: true),
      _user(2, role: 'rider'),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);
    expect(find.text('Receiver'), findsWidgets);
    expect(find.text('Rider'), findsWidgets);
    expect(find.text('Dispatcher'), findsOneWidget); // badge for receiver 1
  });

  testWidgets('shows error state', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiFailure(
      const Failure(type: FailureType.network, message: 'Offline'),
    ))));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('filter chip updates provider', (tester) async {
    _useLargeViewport(tester);
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([_user(1)]))));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Riders'));
    await tester.pumpAndSettle();

    final chip =
        tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Riders'));
    expect(chip.selected, isTrue);
  });
}