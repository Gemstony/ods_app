import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/branch.dart';
import 'package:ods_app/data/repositories/branch_repository.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/branch_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────

AuthUser _user({
  int id = 42,
  String role = 'manager',
  int? branchId,
}) =>
    AuthUser(
      id: id,
      name: 'Test',
      email: 'test@ods.test',
      phone: '0700000000',
      role: role,
      status: 'active',
      branchId: branchId,
      dispatcherEnabled: false,
      permissions: const [],
    );

AuthTokens _tokens() => const AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'bearer',
      expiresIn: 3600,
    );

Branch _branch({int id = 5}) => Branch(
      id: id,
      name: 'Branch $id',
      code: 'BR-$id',
      address: 'Address',
      latitude: -6.79,
      longitude: 39.20,
      status: BranchStatus.active,
    );

class _FakeBranchRepository extends BranchRepository {
  _FakeBranchRepository({this.getResult}) : super(dio: Dio());

  final ApiResult<Branch>? getResult;
  int getCallCount = 0;
  int? lastGetId;

  @override
  Future<ApiResult<Branch>> get(int id) async {
    getCallCount++;
    lastGetId = id;
    return getResult ??
        ApiFailure<Branch>(
          const Failure(
            type: FailureType.notFound,
            message: 'Branch not found',
          ),
        );
  }
}

Future<ProviderContainer> _containerWithSession({
  required AuthUser user,
  required _FakeBranchRepository branchRepo,
}) async {
  final container = ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
    branchRepositoryProvider.overrideWithValue(branchRepo),
  ]);
  await container.read(sessionProvider.notifier).signIn(
        user: user,
        tokens: _tokens(),
      );
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  // ─── currentBranchIdProvider ──────────────────────────────
  group('currentBranchIdProvider', () {
    test('is null when signed out', () {
      final container = ProviderContainer(
        overrides: [
          secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        ],
      );
      addTearDown(container.dispose);
      expect(container.read(currentBranchIdProvider), isNull);
    });

    test('is null for Owner', () async {
      final container = await _containerWithSession(
        user: _user(role: 'owner', branchId: null),
        branchRepo: _FakeBranchRepository(),
      );
      addTearDown(container.dispose);
      expect(container.read(currentBranchIdProvider), isNull);
    });

    test('is null for Distributor', () async {
      final container = await _containerWithSession(
        user: _user(role: 'distributor', branchId: null),
        branchRepo: _FakeBranchRepository(),
      );
      addTearDown(container.dispose);
      expect(container.read(currentBranchIdProvider), isNull);
    });

    test('returns branchId for Manager', () async {
      final container = await _containerWithSession(
        user: _user(role: 'manager', branchId: 5),
        branchRepo: _FakeBranchRepository(),
      );
      addTearDown(container.dispose);
      expect(container.read(currentBranchIdProvider), 5);
    });
  });

  // ─── currentBranchProvider ────────────────────────────────
  group('currentBranchProvider', () {
    test('returns null without fetching when signed out', () async {
      final repo = _FakeBranchRepository(getResult: ApiSuccess(_branch()));
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        branchRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final branch = await container.read(currentBranchProvider.future);

      expect(branch, isNull);
      expect(repo.getCallCount, 0);
    });

    test('returns null without fetching for Owner', () async {
      final repo = _FakeBranchRepository(getResult: ApiSuccess(_branch()));
      final container = await _containerWithSession(
        user: _user(role: 'owner'),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      final branch = await container.read(currentBranchProvider.future);

      expect(branch, isNull);
      expect(repo.getCallCount, 0);
    });

    test('fetches and returns branch for Manager', () async {
      final repo = _FakeBranchRepository(getResult: ApiSuccess(_branch(id: 5)));
      final container = await _containerWithSession(
        user: _user(role: 'manager', branchId: 5),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      final branch = await container.read(currentBranchProvider.future);

      expect(branch?.id, 5);
      expect(repo.getCallCount, 1);
      expect(repo.lastGetId, 5);
    });

    test('returns null when branch is 404 (deleted server-side)', () async {
      final repo = _FakeBranchRepository(
        getResult: ApiFailure<Branch>(
          const Failure(type: FailureType.notFound, message: 'Gone'),
        ),
      );
      final container = await _containerWithSession(
        user: _user(role: 'rider', branchId: 99),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      final branch = await container.read(currentBranchProvider.future);

      expect(branch, isNull);
      expect(repo.getCallCount, 1);
    });

    test('throws on network failure so UI can retry', () async {
      final repo = _FakeBranchRepository(
        getResult: ApiFailure<Branch>(
          const Failure(type: FailureType.network, message: 'Offline'),
        ),
      );
      final container = await _containerWithSession(
        user: _user(role: 'receiver', branchId: 5),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(currentBranchProvider.future),
        throwsA(isA<Failure>()),
      );
    });

    test('throws on auth failure so session expiry is handled', () async {
      final repo = _FakeBranchRepository(
        getResult: ApiFailure<Branch>(
          const Failure(type: FailureType.auth, message: 'Session dead'),
        ),
      );
      final container = await _containerWithSession(
        user: _user(role: 'manager', branchId: 5),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      await expectLater(
        container.read(currentBranchProvider.future),
        throwsA(
          isA<Failure>().having((f) => f.type, 'type', FailureType.auth),
        ),
      );
    });

    test('does not refetch when session re-emits with same branchId',
        () async {
      final repo = _FakeBranchRepository(getResult: ApiSuccess(_branch(id: 5)));
      final container = await _containerWithSession(
        user: _user(role: 'manager', branchId: 5),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      await container.read(currentBranchProvider.future);
      expect(repo.getCallCount, 1);

      // Simulate a token refresh: sign in again with a fresh token pair
      // but the same user identity.
      await container.read(sessionProvider.notifier).signIn(
            user: _user(role: 'manager', branchId: 5),
            tokens: _tokens(),
          );

      // Give the provider a chance to react if it wanted to.
      await container.read(currentBranchProvider.future);

      // session.select should have kept this at 1 — no refetch.
      expect(repo.getCallCount, 1);
    });

    test('refetches when branchId changes (role switch)', () async {
      final repo = _FakeBranchRepository(getResult: ApiSuccess(_branch(id: 7)));
      final container = await _containerWithSession(
        user: _user(role: 'manager', branchId: 5),
        branchRepo: repo,
      );
      addTearDown(container.dispose);

      await container.read(currentBranchProvider.future);
      expect(repo.getCallCount, 1);
      expect(repo.lastGetId, 5);

      // Now sign in as a different user with a different branch.
      await container.read(sessionProvider.notifier).signIn(
            user: _user(role: 'manager', branchId: 7),
            tokens: _tokens(),
          );

      await container.read(currentBranchProvider.future);

      expect(repo.getCallCount, 2);
      expect(repo.lastGetId, 7);
    });
  });
}