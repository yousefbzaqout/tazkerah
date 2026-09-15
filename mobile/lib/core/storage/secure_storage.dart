import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../errors/failure.dart';

/// Contract for OS-backed encrypted storage.
///
/// Declared as an interface for one concrete reason, not for its own sake:
/// tests must run without a platform channel, and the plugin has no usable
/// fake. Features depend on this type; only [FlutterSecureStorageAdapter]
/// mentions the plugin.
///
/// This is for *small secrets* — tokens, key material, the database key. It is
/// backed by Keychain / EncryptedSharedPreferences, which are not databases.
/// Ticket records belong in an encrypted local database (Phase 5), keyed by a
/// value kept here.
abstract interface class SecureStorage {
  /// Returns the value for [key], or `null` when absent.
  Future<String?> read(String key);

  /// Writes [value] under [key], replacing anything already there.
  Future<void> write(String key, String value);

  /// Removes [key]. Succeeds whether or not it was present.
  Future<void> delete(String key);

  /// Removes everything this app stored. Used on sign-out and on first run
  /// after reinstall.
  Future<void> deleteAll();

  /// Whether [key] currently holds a value.
  Future<bool> containsKey(String key);
}

/// [SecureStorage] backed by the platform keystore.
///
/// Storage options are set deliberately:
///
/// - iOS `first_unlock_this_device_only`: entries never sync to iCloud and
///   never restore onto a different device. A ticket's device key is bound to
///   *this* handset by design — see the security model.
/// - Android `encryptedSharedPreferences`: routes through the Keystore rather
///   than a plaintext XML file.
///
/// Keychain entries survive app uninstall on iOS. [clearOnReinstall] exists so
/// bootstrap can drop material orphaned by a previous install.
class FlutterSecureStorageAdapter implements SecureStorage {
  FlutterSecureStorageAdapter({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
            iOptions: IOSOptions(
              // Readable after the first unlock following a reboot — a
              // background notification tap must still find the token — but
              // never restored onto a different device.
              accessibility: KeychainAccessibility.first_unlock_this_device,
              synchronizable: false,
            ),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } catch (e) {
      // A read can fail for a security-relevant reason: on Android, changing
      // the lock screen or biometric enrolment can invalidate Keystore keys.
      // Surfacing it as a Failure lets bootstrap re-provision instead of the
      // app dying on launch.
      throw StorageFailure(debugMessage: 'read($key) failed: $e');
    }
  }

  @override
  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } catch (e) {
      throw StorageFailure(debugMessage: 'write($key) failed: $e');
    }
  }

  @override
  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } catch (e) {
      throw StorageFailure(debugMessage: 'delete($key) failed: $e');
    }
  }

  @override
  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw StorageFailure(debugMessage: 'deleteAll failed: $e');
    }
  }

  @override
  Future<bool> containsKey(String key) async {
    try {
      return await _storage.containsKey(key: key);
    } catch (e) {
      throw StorageFailure(debugMessage: 'containsKey($key) failed: $e');
    }
  }
}

/// In-memory [SecureStorage] for tests and for widget previews.
///
/// Not secure, and not meant to be — it exists so test code never touches a
/// platform channel.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<void> deleteAll() async => _values.clear();

  @override
  Future<bool> containsKey(String key) async => _values.containsKey(key);
}
