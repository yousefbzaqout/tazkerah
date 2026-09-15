import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../core/providers/core_providers.dart';
import '../../../../core/storage/secure_storage.dart';
import '../../../../core/storage/storage_keys.dart';
import '../../domain/auth_state.dart';

/// Owns whether the app has a session, and exposes it as a [Listenable] so
/// the router can re-run its redirect when it changes.
///
/// Scope is deliberately narrow: it reports session presence and can clear it.
/// Signing in — sending credentials, handling the response, registering the
/// device key — belongs to the sign-in use case in Phase 2, which will call
/// [markAuthenticated] once the backend contract exists. Nothing here talks to
/// the network.
class AuthController extends ChangeNotifier {
  AuthController(this._storage) {
    // Kick off the startup read immediately; the router waits on `unknown`.
    unawaited(restore());
  }

  final SecureStorage _storage;

  bool _disposed = false;

  AuthStatus _status = AuthStatus.unknown;
  AuthStatus get status => _status;

  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Reads persisted session material to decide the launch destination.
  ///
  /// The presence of a refresh token is the signal — the access token lives
  /// in memory only and is always absent at launch. Whether that refresh
  /// token is still *valid* is the server's call; a rejected refresh comes
  /// back as a 401, and the interceptor calls [signOut].
  Future<void> restore() async {
    try {
      final token = await _storage.read(StorageKeys.refreshToken);
      _set(
        token != null && token.isNotEmpty
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated,
      );
    } on StorageFailure {
      // Keystore material can be invalidated by a biometric or lock-screen
      // change. That is not a crash — it means this device must sign in
      // again.
      _set(AuthStatus.unauthenticated);
    }
  }

  /// Called by the sign-in flow once the backend has issued a session.
  Future<void> markAuthenticated({required String refreshToken}) async {
    await _storage.write(StorageKeys.refreshToken, refreshToken);
    _set(AuthStatus.authenticated);
  }

  /// Clears every piece of session material on this device.
  ///
  /// Wipes the device signing key along with the tokens: it is bound to this
  /// account, and leaving it behind would let the next user of the handset
  /// hold key material that is not theirs.
  Future<void> signOut() async {
    try {
      await _storage.delete(StorageKeys.refreshToken);
      await _storage.delete(StorageKeys.devicePrivateKey);
      await _storage.delete(StorageKeys.deviceId);
    } on StorageFailure {
      // Fall through: the user asked to sign out, so the app must end the
      // session regardless of whether the delete succeeded.
    }
    _set(AuthStatus.unauthenticated);
  }

  void _set(AuthStatus next) {
    // `restore` is async and can land after the provider is torn down, which
    // happens routinely in tests. Notifying a disposed notifier throws.
    if (_disposed || _status == next) return;
    _status = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// The app's session state.
///
/// A plain [Provider] rather than `ChangeNotifierProvider`, which Riverpod 3
/// moved to `legacy.dart`. The controller is still a [ChangeNotifier] because
/// GoRouter's `refreshListenable` requires a [Listenable]; this provider just
/// owns its lifecycle.
final authControllerProvider = Provider<AuthController>((ref) {
  final controller = AuthController(ref.watch(secureStorageProvider));
  ref.onDispose(controller.dispose);
  return controller;
});
