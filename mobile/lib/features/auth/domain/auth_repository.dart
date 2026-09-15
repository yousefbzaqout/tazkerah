import 'sign_in_flow_state.dart';
import 'user_profile.dart';

/// What the sign-in flow needs from the backend.
///
/// Declared here, in domain, so the controller and its tests do not depend on
/// how it is fulfilled. No implementation is wired yet — the endpoints below
/// are the contract this app expects, and the backend has not agreed it:
///
///   POST /auth/request-code  {identifier}        -> 204
///   POST /auth/verify-code   {identifier, code}  -> {refresh_token, ...}
///   GET  /me                                     -> {profile}
///   POST /auth/sign-out                          -> 204
///
/// Until an implementation is bound, [authRepositoryProvider] throws rather
/// than returning invented data. A fake that "succeeds" would make the flow
/// look finished and hide the missing integration.
abstract interface class AuthRepository {
  /// Asks the backend to send a verification code to [identifier].
  ///
  /// Completes normally whether or not the identifier is registered: telling
  /// the caller which addresses exist would turn this into an account
  /// enumeration oracle.
  Future<void> requestCode(String identifier);

  /// Exchanges a code for a session.
  ///
  /// Returns the refresh token on success. Throws [SignInException] with the
  /// matching [SignInFailure] otherwise.
  Future<String> verifyCode({required String identifier, required String code});

  /// The signed-in user's own account.
  ///
  /// Throws [UnauthorizedFailure] when the session is no longer valid, which
  /// the session layer treats as the signal to sign out.
  Future<UserProfile> fetchProfile();

  /// Tells the backend to revoke this device's session.
  ///
  /// Local material is wiped regardless of whether this succeeds — see
  /// [AuthController.signOut]. Revoking server-side is what stops a stolen
  /// refresh token being replayed, so it is attempted, but a user signing out
  /// on a flaky connection must not be left signed in.
  Future<void> revokeSession();
}

/// A sign-in step failed for a reason the UI should explain.
class SignInException implements Exception {
  const SignInException(this.failure, {this.debugMessage});

  final SignInFailure failure;
  final String? debugMessage;

  @override
  String toString() => 'SignInException($failure, $debugMessage)';
}
