import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/models/reward.dart';
import 'package:ods_app/data/repositories/reward_repository.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';
import 'package:ods_app/shared/providers/reward_providers.dart';

AuthUser _user({String role = 'distributor'}) => AuthUser(
      id: 42,
      name: 'Test',
      email: 'test@ods.test',
      phone: '0700000000',
      role: role,
      status: 'active',
      dispatcherEnabled: false,
      permissions: const [],
    );

AuthTokens _tokens() => const AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      tokenType: 'bearer',
      expiresIn: 3600,
    );

Reward _reward({int monthly = 5}) => Reward(
      id: 1,
      distributorId: 42,
      currentMonth: '2026-10',
      monthlyCount: monthly,
      tier1Available: false,
      rollingCount: 10,
      tier2Available: false,
    );

class _FakeRewardRepository extends RewardRepository {
  _FakeRewardRepository({this.getResult}) : super(dio: Dio());

  final ApiResult<Reward>? getResult;
  int callCount = 0;

  @override
  Future<ApiResult<Reward>> getMyProgress() async {
    callCount++;
    return getResult ??
        ApiFailure<Reward>(
          const Failure(type: FailureType.notFound, message: 'No reward record'),
        );
  }
}

Future<ProviderContainer> _signedIn({
  required AuthUser user,
  required _FakeRewardRepository repo,
}) async {
  final container = ProviderContainer(overrides: [
    secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
    rewardRepositoryProvider.overrideWithValue(repo),
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

  group('myRewardProgressProvider', () {
    test('returns null without fetching for non-distributor roles', () async {
      final repo = _FakeRewardRepository(getResult: ApiSuccess(_reward()));

      for (final role in ['owner', 'manager', 'rider', 'receiver']) {
        final container = await _signedIn(user: _user(role: role), repo: repo);
        addTearDown(container.dispose);

        final reward = await container.read(myRewardProgressProvider.future);

        expect(reward, isNull, reason: 'Role $role should return null');
      }

      expect(repo.callCount, 0);
    });

    test('returns null without fetching when signed out', () async {
      final repo = _FakeRewardRepository(getResult: ApiSuccess(_reward()));
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        rewardRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final reward = await container.read(myRewardProgressProvider.future);

      expect(reward, isNull);
      expect(repo.callCount, 0);
    });

    test('fetches and returns progress for distributor', () async {
      final repo = _FakeRewardRepository(
        getResult: ApiSuccess(_reward(monthly: 15)),
      );
      final container = await _signedIn(user: _user(), repo: repo);
      addTearDown(container.dispose);

      final reward = await container.read(myRewardProgressProvider.future);

      expect(reward?.monthlyCount, 15);
      expect(repo.callCount, 1);
    });

    test('returns null on failure (reward widget hides, no error UI)',
        () async {
      final repo = _FakeRewardRepository(
        getResult: ApiFailure<Reward>(
          const Failure(type: FailureType.network, message: 'Offline'),
        ),
      );
      final container = await _signedIn(user: _user(), repo: repo);
      addTearDown(container.dispose);

      final reward = await container.read(myRewardProgressProvider.future);

      expect(reward, isNull);
    });

    test('does not refetch on token refresh (same role)', () async {
      final repo = _FakeRewardRepository(getResult: ApiSuccess(_reward()));
      final container = await _signedIn(user: _user(), repo: repo);
      addTearDown(container.dispose);

      await container.read(myRewardProgressProvider.future);
      expect(repo.callCount, 1);

      await container.read(sessionProvider.notifier).signIn(
            user: _user(),
            tokens: _tokens(),
          );
      await container.read(myRewardProgressProvider.future);

      expect(repo.callCount, 1);
    });
  });
}