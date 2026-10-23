import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ods_app/core/constants/storage_keys.dart';
import 'package:ods_app/data/local/secure_storage.dart';
import 'package:ods_app/shared/providers/auth_provider.dart';

/// Waits one microtask for the notifier's async init to complete.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('SessionNotifier — startup', () {
    test('transitions loading → data(null) when storage is empty', () async {
      final notifier = SessionNotifier(storage: InMemorySecureStorage());
      expect(notifier.state.isLoading, isTrue);
      await _settle();
      expect(notifier.state.valueOrNull, isNull);
    });

    test('restores a persisted session from storage', () async {
      final storage = InMemorySecureStorage();
      await storage.write(StorageKeys.accessToken, 'tok');
      await storage.write(StorageKeys.userRole, 'owner');
      await storage.write(StorageKeys.userId, 'u-1');
      await storage.write(StorageKeys.displayName, 'Ahmed');

      final notifier = SessionNotifier(storage: storage);
      await _settle();

      final session = notifier.state.valueOrNull;
      expect(session, isNotNull);
      expect(session!.role, 'owner');
      expect(session.userId, 'u-1');
      expect(session.accessToken, 'tok');
      expect(session.displayName, 'Ahmed');
    });

    test('partial data (missing role) → treated as signed out', () async {
      final storage = InMemorySecureStorage();
      await storage.write(StorageKeys.accessToken, 'tok');
      await storage.write(StorageKeys.userId, 'u-1');
      // No role written.

      final notifier = SessionNotifier(storage: storage);
      await _settle();
      expect(notifier.state.valueOrNull, isNull);
    });
  });

  group('SessionNotifier — signIn', () {
    test('persists all values and updates state', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(storage: storage);
      await _settle();

      await notifier.signIn(
        userId: 'u-42',
        role: 'rider',
        accessToken: 'tok-42',
        refreshToken: 'ref-42',
        displayName: 'Rider Dev',
      );

      expect(notifier.state.valueOrNull?.role, 'rider');
      expect(await storage.read(StorageKeys.accessToken), 'tok-42');
      expect(await storage.read(StorageKeys.refreshToken), 'ref-42');
      expect(await storage.read(StorageKeys.userRole), 'rider');
      expect(await storage.read(StorageKeys.userId), 'u-42');
      expect(await storage.read(StorageKeys.displayName), 'Rider Dev');
    });
  });

  group('SessionNotifier — signOut', () {
    test('clears storage and sets state to data(null)', () async {
      final storage = InMemorySecureStorage();
      final notifier = SessionNotifier(storage: storage);
      await _settle();
      await notifier.signIn(
        userId: 'u-1',
        role: 'owner',
        accessToken: 'tok',
        refreshToken: 'ref',
        displayName: 'Owner',
      );

      await notifier.signOut();

      expect(notifier.state.valueOrNull, isNull);
      expect(await storage.read(StorageKeys.accessToken), isNull);
      expect(await storage.read(StorageKeys.refreshToken), isNull);
      expect(await storage.read(StorageKeys.userRole), isNull);
      expect(await storage.read(StorageKeys.userId), isNull);
    });
  });

  group('Derived providers', () {
    test('currentRoleProvider reflects session transitions', () async {
      final storage = InMemorySecureStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await _settle();
      expect(container.read(currentRoleProvider), isNull);
      expect(container.read(isAuthenticatedProvider), isFalse);

      await container.read(sessionProvider.notifier).signIn(
            userId: 'u-1',
            role: 'manager',
            accessToken: 'tok',
          );

      expect(container.read(currentRoleProvider), 'manager');
      expect(container.read(isAuthenticatedProvider), isTrue);
      expect(container.read(currentUserIdProvider), 'u-1');
    });

    test('signOut reverts currentRoleProvider to null', () async {
      final storage = InMemorySecureStorage();
      final container = ProviderContainer(
        overrides: [secureStorageProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);

      await _settle();
      final notifier = container.read(sessionProvider.notifier);
      await notifier.signIn(
        userId: 'u-1',
        role: 'rider',
        accessToken: 'tok',
      );
      expect(container.read(currentRoleProvider), 'rider');

      await notifier.signOut();
      expect(container.read(currentRoleProvider), isNull);
    });
  });
}