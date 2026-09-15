import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/profile_state.dart';
import 'auth_controller.dart';
import 'sign_in_controller.dart';

/// Drives the profile screen.
///
/// Owns loading the account and signing out. Sign-out is the consequential
/// operation here, and its rule is deliberate: **local material is wiped even
/// if the server call fails.** A user who taps sign out on a flaky connection
/// must not be left signed in on the device in front of them.
class ProfileController extends Notifier<ProfileState> {
  int _requestToken = 0;
  bool _disposed = false;

  @override
  ProfileState build() {
    ref.onDispose(() => _disposed = true);
    Future.microtask(load);
    return const ProfileLoading();
  }

  Future<void> load() async {
    final token = ++_requestToken;
    state = const ProfileLoading();

    try {
      final profile = await ref.read(authRepositoryProvider).fetchProfile();
      if (_disposed || token != _requestToken) return;
      state = ProfileReady(profile);
    } on Failure catch (failure) {
      if (_disposed || token != _requestToken) return;
      state = ProfileFailed(failure);
    } catch (e, stack) {
      if (_disposed || token != _requestToken) return;
      developer.log(
        'Profile load failed unexpectedly',
        name: 'auth',
        error: e,
        stackTrace: stack,
      );
      state = ProfileFailed(UnknownFailure(debugMessage: e.toString()));
    }
  }

  /// Signs out on this device.
  ///
  /// Asks the backend to revoke the session first — that is what stops a
  /// stolen refresh token being replayed — then wipes local material
  /// regardless of the outcome. [AuthController.signOut] clears the refresh
  /// token, the device private key and the device id together; a session
  /// ended with key material left behind would leave a device that could
  /// still present passes.
  Future<void> signOut() async {
    final current = state;
    if (current is ProfileReady && current.isSigningOut) return;
    if (current is ProfileReady) {
      state = current.copyWith(isSigningOut: true);
    }

    try {
      await ref.read(authRepositoryProvider).revokeSession();
    } catch (e, stack) {
      // Deliberately swallowed. The local wipe below is what actually signs
      // the user out of this device, and refusing to do it because the
      // network is down would strand them.
      developer.log(
        'Session revocation failed; wiping locally anyway',
        name: 'auth',
        error: e,
        stackTrace: stack,
      );
    }

    // Not guarded by `_disposed`: the wipe must happen even if the screen has
    // already gone, and the router moves the user once auth state flips.
    await ref.read(authControllerProvider).signOut();
  }
}

final profileControllerProvider =
    NotifierProvider<ProfileController, ProfileState>(ProfileController.new);
