import 'package:flutter_test/flutter_test.dart';
import 'package:tazkerah/core/storage/secure_storage.dart';
import 'package:tazkerah/core/storage/storage_keys.dart';

void main() {
  group('InMemorySecureStorage', () {
    late SecureStorage storage;

    setUp(() => storage = InMemorySecureStorage());

    test('returns null for a key never written', () async {
      expect(await storage.read('absent'), isNull);
    });

    test('round-trips a value', () async {
      await storage.write(StorageKeys.refreshToken, 'token-abc');

      expect(await storage.read(StorageKeys.refreshToken), 'token-abc');
      expect(await storage.containsKey(StorageKeys.refreshToken), isTrue);
    });

    test('overwrites rather than appending', () async {
      await storage.write(StorageKeys.deviceId, 'first');
      await storage.write(StorageKeys.deviceId, 'second');

      expect(await storage.read(StorageKeys.deviceId), 'second');
    });

    test('delete removes one key and leaves the rest', () async {
      await storage.write(StorageKeys.deviceId, 'device');
      await storage.write(StorageKeys.refreshToken, 'token');

      await storage.delete(StorageKeys.deviceId);

      expect(await storage.read(StorageKeys.deviceId), isNull);
      expect(await storage.read(StorageKeys.refreshToken), 'token');
    });

    test('deleting an absent key is not an error', () async {
      await expectLater(storage.delete('absent'), completes);
    });

    test('deleteAll clears everything — the sign-out path', () async {
      await storage.write(StorageKeys.refreshToken, 'token');
      await storage.write(StorageKeys.devicePrivateKey, 'key');
      await storage.write(StorageKeys.databaseKey, 'dbkey');

      await storage.deleteAll();

      expect(await storage.read(StorageKeys.refreshToken), isNull);
      expect(await storage.read(StorageKeys.devicePrivateKey), isNull);
      expect(await storage.read(StorageKeys.databaseKey), isNull);
    });
  });

  group('StorageKeys', () {
    test('are unique — a collision would have one feature clobber another', () {
      const keys = [
        StorageKeys.refreshToken,
        StorageKeys.deviceId,
        StorageKeys.devicePrivateKey,
        StorageKeys.databaseKey,
        StorageKeys.clockOffsetMillis,
        StorageKeys.clockSyncedAt,
        StorageKeys.installSentinel,
      ];

      expect(keys.toSet(), hasLength(keys.length));
    });
  });
}
