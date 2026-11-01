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
import 'package:ods_app/data/repositories/user_repository.dart';
import 'package:ods_app/features/owner/presentation/screens/owner_users_tab.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/widgets/widgets.dart';

AuthUser _user(int id,
    {String role = 'manager',
    String status = 'active',
    String? branchName}) =>
    AuthUser(
      id: id,
      name: 'User $id',
      email: 'u$id@ods.test',
      phone: '0712345678',
      role: role,
      status: status,
      dispatcherEnabled: false,
      branch: branchName != null
          ? UserBranchRef(id: 1, name: branchName, code: 'BR-1')
          : null,
      permissions: const [],
    );

class _FakeRepo extends UserRepository {
  _FakeRepo(this._result) : super(dio: Dio());
  final ApiResult<List<AuthUser>> _result;

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    int? branchId,
    String? search,
    int? perPage,
    int page = 1,
  }) async =>
      _result;
}

class _PendingRepo extends UserRepository {
  _PendingRepo() : super(dio: Dio());
  final _completer = Completer<ApiResult<List<AuthUser>>>();

  @override
  Future<ApiResult<List<AuthUser>>> list({
    String? role,
    String? status,
    int? branchId,
    String? search,
    int? perPage,
    int page = 1,
  }) =>
      _completer.future;
}

Widget _wrap(UserRepository repo) => ProviderScope(
      overrides: [userRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(body: OwnerUsersTab()),
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

  testWidgets('shows empty state when no users and no filters', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess(const []))));
    await tester.pumpAndSettle();

    expect(find.text('No users found'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Add first user'), findsOneWidget);
  });

  testWidgets('renders user cards', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([
      _user(1, branchName: 'KRK'),
      _user(2, role: 'rider', branchName: 'DSM'),
    ]))));
    await tester.pumpAndSettle();

    expect(find.text('User 1'), findsOneWidget);
    expect(find.text('User 2'), findsOneWidget);
    expect(find.text('KRK'), findsOneWidget);
    expect(find.text('DSM'), findsOneWidget);
  });

  testWidgets('error state shows retry', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiFailure(
      const Failure(type: FailureType.network, message: 'Offline'),
    ))));
    await tester.pumpAndSettle();

    expect(find.byType(ErrorView), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('role filter chip updates provider', (tester) async {
    await tester.pumpWidget(_wrap(_FakeRepo(ApiSuccess([_user(1)]))));
    await tester.pumpAndSettle();

    // Tapping "Riders" chip should filter
    await tester.tap(find.text('Riders'));
    await tester.pumpAndSettle();

    // The chip is now selected
    final chip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Riders'));
    expect(chip.selected, isTrue);
  });
}