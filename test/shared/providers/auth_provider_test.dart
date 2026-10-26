import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/network/token_service.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';

AuthUser _sampleUser({
  int id = 42,
  String role = 'owner',
  String name = 'Ahmed Juma',
  String status = 'active',
  List<String> permissions = const ['manage_users'],
}) {
  return AuthUser(
    id: id,
    name: name,
    email: 'ahmed@ods.test',
    phone: '0712345678',
    role: role,
    status: status,
    dispatcherEnabled: false,
    permissions: permissions,
  );
}

AuthTokens _sampleTokens() => AuthTokens(
      accessToken: 'access-abc',
      refreshToken: 'refresh-xyz-${'a' * 50}',
      tokenType: 'bearer',
      expiresIn: 3600,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('SessionNotifier — startup', () {
    test('starts in signed-out state (data(null))', () {
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: InMemorySecureStorage()),
      );
      expect(notifier.state.valueOrNull, isNull);
    });
  });

  group('SessionNotifier — signIn', () {
    test('persists tokens to storage and updates state', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
      );

      await notifier.signIn(user: _sampleUser(), tokens: _sampleTokens());

      final session = notifier.state.valueOrNull!;
      expect(session.user.id, 42);
      expect(session.user.role, 'owner');
      expect(session.tokens.accessToken, 'access-abc');

      expect(await storage.read('ods.auth.access_token'), 'access-abc');
      expect(await storage.read('ods.auth.refresh_token'),
          startsWith('refresh-xyz'));
      expect(await storage.read('ods.auth.role'), 'owner');
      expect(await storage.read('ods.auth.user_id'), '42');
      expect(await storage.read('ods.auth.display_name'), 'Ahmed Juma');
    });
  });

  group('SessionNotifier — signOut', () {
    test('clears storage and sets state to data(null)', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
      );

      await notifier.signIn(user: _sampleUser(), tokens: _sampleTokens());
      await notifier.signOut();

      expect(notifier.state.valueOrNull, isNull);
      expect(await storage.read('ods.auth.access_token'), isNull);
      expect(await storage.read('ods.auth.role'), isNull);
      expect(await storage.read('ods.auth.user_id'), isNull);
    });
  });

  group('SessionNotifier — handleSessionExpired', () {
    test('clears session state and tokens', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
      );

      await notifier.signIn(user: _sampleUser(), tokens: _sampleTokens());
      await notifier.handleSessionExpired();

      expect(notifier.state.valueOrNull, isNull);
      expect(await storage.read('ods.auth.access_token'), isNull);
    });
  });

  group('Derived providers', () {
    test('reflect session transitions', () async {
      final storage = InMemorySecureStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      expect(container.read(currentRoleProvider), isNull);
      expect(container.read(isAuthenticatedProvider), isFalse);
      expect(container.read(currentUserIdProvider), isNull);
      expect(container.read(currentUserProvider), isNull);

      await container
          .read(sessionProvider.notifier)
          .signIn(user: _sampleUser(role: 'manager'), tokens: _sampleTokens());

      expect(container.read(currentRoleProvider), 'manager');
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(currentUserIdProvider), '42');
      expect(container.read(currentUserProvider)?.id, 42);
      expect(container.read(currentUserProvider)?.permissions,
          contains('manage_users'));
    });

    test('signOut reverts currentRoleProvider to null', () async {
      final storage = InMemorySecureStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await container
          .read(sessionProvider.notifier)
          .signIn(user: _sampleUser(), tokens: _sampleTokens());
      expect(container.read(currentRoleProvider), 'owner');

      await container.read(sessionProvider.notifier).signOut();
      expect(container.read(currentRoleProvider), isNull);
    });
  });
}