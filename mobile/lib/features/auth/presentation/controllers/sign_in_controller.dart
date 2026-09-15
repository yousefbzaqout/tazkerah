import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/failure.dart';
import '../../../../app/config/app_config.dart';
import '../../../../core/providers/core_providers.dart';
import '../../data/dev_auth_repository.dart';
import '../../domain/auth_repository.dart';
import '../../domain/sign_in_flow_state.dart';
import 'auth_controller.dart';

/// Drives the two-step sign-in.
///
/// Holds the identifier between steps, tracks in-flight requests, and converts
/// transport failures into [SignInFailure] values the screens can render. On
/// success it hands the refresh token to [AuthController], which is what moves
/// the router — this controller never navigates.
class SignInController extends Notifier<SignInFlowState> {
  @override
  SignInFlowState build() => const SignInFlowState();

  AuthController get _auth => ref.read(authControllerProvider);

  /// Step one: send a code to [identifier], then advance to code entry.
  Future<void> submitIdentifier(String identifier) async {
    if (state.isSubmitting) return;
    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      await ref.read(authRepositoryProvider).requestCode(identifier);
      state = SignInFlowState(identifier: identifier, step: SignInStep.code);
    } on SignInException catch (e) {
      state = state.copyWith(isSubmitting: false, failure: e.failure);
    } on Failure catch (e) {
      state = state.copyWith(isSubmitting: false, failure: _map(e));
    } catch (e, stack) {
      // Catch-all so a step that fails for an unforeseen reason surfaces in
      // the UI rather than escaping as an uncaught zone error and taking the
      // app down. Resolving the repository can itself throw — an unbound
      // provider does — so that read lives inside the guard too.
      _report(e, stack);
      state = state.copyWith(
        isSubmitting: false,
        failure: SignInFailure.unknown,
      );
    }
  }

  /// Step two: exchange [code] for a session.
  Future<void> submitCode(String code) async {
    final identifier = state.identifier;
    if (identifier == null || state.isSubmitting) return;

    state = state.copyWith(isSubmitting: true, clearFailure: true);

    try {
      final refreshToken = await ref
          .read(authRepositoryProvider)
          .verifyCode(identifier: identifier, code: code);
      // Persisting the token flips auth state, and the router's redirect
      // moves the user. Nothing here calls `go`.
      await _auth.markAuthenticated(refreshToken: refreshToken);
      state = const SignInFlowState();
    } on SignInException catch (e) {
      state = state.copyWith(isSubmitting: false, failure: e.failure);
    } on Failure catch (e) {
      state = state.copyWith(isSubmitting: false, failure: _map(e));
    } catch (e, stack) {
      _report(e, stack);
      state = state.copyWith(
        isSubmitting: false,
        failure: SignInFailure.unknown,
      );
    }
  }

  /// Requests a fresh code for the identifier already in flight.
  Future<void> resendCode() async {
    final identifier = state.identifier;
    if (identifier == null) return;

    state = state.copyWith(clearFailure: true);
    try {
      await ref.read(authRepositoryProvider).requestCode(identifier);
    } on SignInException catch (e) {
      state = state.copyWith(failure: e.failure);
    } on Failure catch (e) {
      state = state.copyWith(failure: _map(e));
    } catch (e, stack) {
      _report(e, stack);
      state = state.copyWith(failure: SignInFailure.unknown);
    }
  }

  /// Logs an unexpected failure. Phase 8 points this at the crash reporter.
  void _report(Object error, StackTrace stack) {
    developer.log(
      'Sign-in step failed unexpectedly',
      name: 'auth',
      error: error,
      stackTrace: stack,
    );
  }

  /// Returns to step one so the user can correct a mistyped identifier.
  void editIdentifier() {
    state = SignInFlowState(identifier: state.identifier);
  }

  /// Translates a transport [Failure] into a sign-in reason.
  SignInFailure _map(Failure failure) => switch (failure) {
    NetworkFailure() || TimeoutFailure() => SignInFailure.network,
    RateLimitFailure() => SignInFailure.tooManyAttempts,
    UnauthorizedFailure() => SignInFailure.invalidCode,
    ValidationFailure() => SignInFailure.invalidIdentifier,
    _ => SignInFailure.unknown,
  };
}

/// Binds a concrete [AuthRepository].
///
/// There is no real implementation yet: the backend contract in
/// [AuthRepository] has not been agreed. Rather than ship canned success,
/// this binds [DevAuthRepository] in dev and staging so the flow is runnable
/// by hand, and throws in production so a release cannot ship without a real
/// implementation.
///
/// Replace the whole body with the real client once the endpoints exist.
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final config = ref.watch(appConfigProvider);

  if (config.environment == AppEnvironment.production) {
    throw UnimplementedError(
      'No production AuthRepository is bound. The backend contract '
      '(POST /auth/request-code, POST /auth/verify-code) is still open — see '
      'AuthRepository.',
    );
  }

  return DevAuthRepository();
});

final signInControllerProvider =
    NotifierProvider<SignInController, SignInFlowState>(SignInController.new);
