import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/config/app_config.dart';
import 'package:ods_app/core/errors/failure.dart';
import 'package:ods_app/core/network/api_result.dart';
import 'package:ods_app/core/network/token_service.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/data/models/auth/auth_login_result.dart';
import 'package:ods_app/data/models/auth/auth_tokens.dart';
import 'package:ods_app/data/models/auth/auth_user.dart';
import 'package:ods_app/data/repositories/auth_repository.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';

// ─── Fixtures ─────────────────────────────────────────────────────────

AuthUser _user({
  int id = 42,
  String role = 'owner',
  String name = 'Ahmed Juma',
  List<String> permissions = const ['manage_users'],
}) =>
    AuthUser(
      id: id,
      name: name,
      email: 'ahmed@ods.test',
      phone: '0712345678',
      role: role,
      status: 'active',
      dispatcherEnabled: false,
      permissions: permissions,
    );

AuthTokens _tokens() => const AuthTokens(
      accessToken: 'access-abc',
      refreshToken: 'refresh-xyz',
      tokenType: 'bearer',
      expiresIn: 3600,
    );

/// Minimal AuthRepository stub. Tests override the `me()` and other
/// methods' behaviour through a subclass.
class _FakeAuthRepo extends AuthRepository {
  _FakeAuthRepo({ApiResult<AuthUser>? meResult}) : _me = meResult;

  final ApiResult<AuthUser>? _me;

  @override
  Future<ApiResult<AuthUser>> me() async =>
      _me ?? ApiFailure<AuthUser>(const Failure(
        type: FailureType.network,
        message: 'no stub configured',
      ));
}

// ─── Tests ────────────────────────────────────────────────────────────

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(AppConfig.initialize);

  group('SessionNotifier — startup', () {
    test('starts in loading state', () {
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: InMemorySecureStorage()),
        authRepository: _FakeAuthRepo(),
      );
      expect(notifier.state.isLoading, isTrue);
    });
  });

  group('SessionNotifier — restoreSession', () {
    test('no stored tokens → data(null)', () async {
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: InMemorySecureStorage()),
        authRepository: _FakeAuthRepo(),
      );

      final restored = await notifier.restoreSession();

      expect(restored, isNull);
      expect(notifier.state.valueOrNull, isNull);
    });

    test('valid tokens + /me success → data(Session)', () async {
      final storage = InMemorySecureStorage();
      await storage.write('ods.auth.access_token', 'tok');
      await storage.write('ods.auth.refresh_token', 'ref');

      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
        authRepository: _FakeAuthRepo(
          meResult: ApiSuccess<AuthUser>(_user(role: 'owner')),
        ),
      );

      final restored = await notifier.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.role, 'owner');
      expect(notifier.state.valueOrNull?.user.role, 'owner');
      expect(notifier.state.valueOrNull?.tokens.accessToken, 'tok');
    });

    test('/me auth-failure → clears tokens + data(null)', () async {
      final storage = InMemorySecureStorage();
      await storage.write('ods.auth.access_token', 'tok');
      await storage.write('ods.auth.refresh_token', 'ref');

      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
        authRepository: _FakeAuthRepo(
          meResult: ApiFailure<AuthUser>(const Failure(
            type: FailureType.auth,
            message: 'Session dead',
          )),
        ),
      );

      final restored = await notifier.restoreSession();

      expect(restored, isNull);
      expect(await storage.read('ods.auth.access_token'), isNull);
      expect(await storage.read('ods.auth.refresh_token'), isNull);
    });

    test('/me network-failure → keeps tokens but data(null)', () async {
      final storage = InMemorySecureStorage();
      await storage.write('ods.auth.access_token', 'tok');
      await storage.write('ods.auth.refresh_token', 'ref');

      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
        authRepository: _FakeAuthRepo(
          meResult: ApiFailure<AuthUser>(const Failure(
            type: FailureType.network,
            message: 'Offline',
          )),
        ),
      );

      final restored = await notifier.restoreSession();

      expect(restored, isNull);
      expect(await storage.read('ods.auth.access_token'), 'tok');
      expect(await storage.read('ods.auth.refresh_token'), 'ref');
    });
  });

  group('SessionNotifier — signIn', () {
    test('persists tokens + transitions to data(Session)', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
        authRepository: _FakeAuthRepo(),
      );

      await notifier.signIn(user: _user(), tokens: _tokens());

      expect(notifier.state.valueOrNull?.user.id, 42);
      expect(await storage.read('ods.auth.access_token'), 'access-abc');
      expect(await storage.read('ods.auth.role'), 'owner');
    });
  });

  group('SessionNotifier — signOut', () {
    test('clears storage + data(null)', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
        authRepository: _FakeAuthRepo(),
      );

      await notifier.signIn(user: _user(), tokens: _tokens());
      await notifier.signOut();

      expect(notifier.state.valueOrNull, isNull);
      expect(await storage.read('ods.auth.access_token'), isNull);
    });
  });

  group('SessionNotifier — handleSessionExpired', () {
    test('clears storage + data(null)', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(
        tokenService: TokenService(storage: storage),
        authRepository: _FakeAuthRepo(),
      );

      await notifier.signIn(user: _user(), tokens: _tokens());
      await notifier.handleSessionExpired();

      expect(notifier.state.valueOrNull, isNull);
      expect(await storage.read('ods.auth.access_token'), isNull);
    });
  });

  group('Derived providers', () {
    test('reflect session transitions', () async {
      final storage = InMemorySecureStorage();
      final container = ProviderContainer(overrides: [
        secureStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(_FakeAuthRepo()),
      ]);
      addTearDown(container.dispose);

      await container.read(sessionProvider.notifier).signIn(
            user: _user(role: 'manager'),
            tokens: _tokens(),
          );

      expect(container.read(currentRoleProvider), 'manager');
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(currentUserIdProvider), '42');
    });
  });

  // Suppress unused import warning.
  // ignore: unused_element
  AuthLoginResult _unused() => AuthLoginResult(user: _user(), tokens: _tokens());
}