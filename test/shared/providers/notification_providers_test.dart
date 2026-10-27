import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/app_notification.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/notification_repository.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';
import 'package:ods_app/shared/providers/notification_providers.dart';
import 'package:ods_app/shared/providers/repository_providers.dart';

AuthUser _user({int id = 42}) => AuthUser(
      id: id,
      name: 'Test',
      email: 'test@ods.test',
      phone: '0700000000',
      role: 'manager',
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

AppNotification _notif(int id) => AppNotification(
      id: id,
      userId: 42,
      type: 'test',
      title: 'Test',
      channels: const ['in_app'],
      status: NotificationStatus.sent,
      priority: NotificationPriority.normal,
    );

class _FakeNotificationRepository extends NotificationRepository {
  _FakeNotificationRepository({this.listResult}) : super(dio: Dio());

  final ApiResult<List<AppNotification>>? listResult;
  int listCallCount = 0;
  bool? lastUnreadOnly;

  @override
  Future<ApiResult<List<AppNotification>>> list({
    bool unreadOnly = false,
    int? limit,
    int? offset,
  }) async {
    listCallCount++;
    lastUnreadOnly = unreadOnly;
    return listResult ??
        ApiSuccess<List<AppNotification>>(const <AppNotification>[]);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('unreadNotificationCountProvider', () {
    test('returns 0 without fetching when signed out', () async {
      final repo = _FakeNotificationRepository(
        listResult: ApiSuccess([_notif(1), _notif(2)]),
      );
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        notificationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      final count = await container.read(unreadNotificationCountProvider.future);

      expect(count, 0);
      expect(repo.listCallCount, 0);
    });

    test('returns count of unread notifications when signed in', () async {
      final repo = _FakeNotificationRepository(
        listResult: ApiSuccess([_notif(1), _notif(2), _notif(3)]),
      );
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        notificationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).signIn(
            user: _user(),
            tokens: _tokens(),
          );

      final count = await container.read(unreadNotificationCountProvider.future);

      expect(count, 3);
      expect(repo.listCallCount, 1);
      expect(repo.lastUnreadOnly, isTrue);
    });

    test('returns 0 on network failure (badge stays silent)', () async {
      final repo = _FakeNotificationRepository(
        listResult: ApiFailure<List<AppNotification>>(
          const Failure(type: FailureType.network, message: 'Offline'),
        ),
      );
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        notificationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).signIn(
            user: _user(),
            tokens: _tokens(),
          );

      final count = await container.read(unreadNotificationCountProvider.future);

      expect(count, 0);
    });

    test('returns 0 when no notifications exist', () async {
      final repo = _FakeNotificationRepository(
        listResult: ApiSuccess<List<AppNotification>>(const []),
      );
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        notificationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).signIn(
            user: _user(),
            tokens: _tokens(),
          );

      final count = await container.read(unreadNotificationCountProvider.future);

      expect(count, 0);
    });

    test('does not refetch when session re-emits signed-in state', () async {
      final repo = _FakeNotificationRepository(
        listResult: ApiSuccess([_notif(1)]),
      );
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(InMemorySecureStorage()),
        notificationRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).signIn(
            user: _user(),
            tokens: _tokens(),
          );
      await container.read(unreadNotificationCountProvider.future);
      expect(repo.listCallCount, 1);

      // Token refresh: still signed in, same user
      await container.read(sessionProvider.notifier).signIn(
            user: _user(),
            tokens: _tokens(),
          );
      await container.read(unreadNotificationCountProvider.future);

      // session.select kept isAuthenticated at true both times → no refetch.
      expect(repo.listCallCount, 1);
    });
  });
}