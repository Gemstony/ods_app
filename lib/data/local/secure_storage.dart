import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over secure key-value storage.
///
/// A plain interface (not a concrete class) so tests can substitute
/// [InMemorySecureStorage] without touching platform channels.
abstract class SecureStorageInterface {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
  Future<void> deleteAll();
}

/// Production implementation backed by `flutter_secure_storage`.
///
/// Android: uses EncryptedSharedPreferences (API 23+).
/// iOS:     Keychain with `first_unlock` accessibility — readable after the
///          first device unlock following a reboot, which is what background
///          token refresh needs.
/// Web:     Falls back to WebCrypto-encrypted localStorage. Works on Chrome,
///          but treat as best-effort; Phase 15 uses HTTPS so tampering is
///          not the threat model that motivates Keychain.
class SecureStorage implements SecureStorageInterface {
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// In-memory implementation for tests.
///
/// Not exported from the app's public API — production code never sees it.
class InMemorySecureStorage implements SecureStorageInterface {
  final Map<String, String> _data = {};

  @override
  Future<String?> read(String key) async => _data[key];

  @override
  Future<void> write(String key, String value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _data.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    _data.clear();
  }
}