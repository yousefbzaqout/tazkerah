import 'package:tazkerah/features/auth/domain/auth_repository.dart';
import 'package:tazkerah/features/auth/domain/user_profile.dart';
import 'package:tazkerah/features/auth/domain/sign_in_flow_state.dart';

/// Scriptable [AuthRepository] for tests.
///
/// Exists only under `test/` — the production provider deliberately throws, so
/// nothing ships a fake that makes an unfinished flow look complete.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    this.requestCodeFailure,
    this.verifyFailure,
    this.refreshToken = 'fake-refresh-token',
  });

  /// Thrown by [requestCode] when set.
  SignInFailure? requestCodeFailure;

  /// Thrown by [verifyCode] when set.
  SignInFailure? verifyFailure;

  /// Returned by a successful [verifyCode].
  String refreshToken;

  final List<String> requestedIdentifiers = [];
  final List<String> verifiedCodes = [];

  @override
  Future<void> requestCode(String identifier) async {
    requestedIdentifiers.add(identifier);
    final failure = requestCodeFailure;
    if (failure != null) throw SignInException(failure);
  }

  @override
  Future<String> verifyCode({
    required String identifier,
    required String code,
  }) async {
    verifiedCodes.add(code);
    final failure = verifyFailure;
    if (failure != null) throw SignInException(failure);
    return refreshToken;
  }

  /// Returned by [fetchProfile]. A default is built on demand.
  UserProfile? profile;

  /// Thrown by [fetchProfile] when set.
  Object? profileFailure;

  /// Thrown by [revokeSession] when set — how a test reaches the
  /// "revoke failed, wipe anyway" path.
  Object? revokeFailure;

  int revokeCalls = 0;

  @override
  Future<UserProfile> fetchProfile() async {
    final failure = profileFailure;
    if (failure != null) throw failure;
    return profile ??
        UserProfile(
          id: 'usr_1',
          displayName: 'Tariq Al-Mansoor',
          identifier: 'tariq@example.com',
          email: 'tariq@example.com',
          memberSince: DateTime.utc(2024, 3, 14),
          deviceId: '#TZ-8841-A',
        );
  }

  @override
  Future<void> revokeSession() async {
    revokeCalls++;
    final failure = revokeFailure;
    if (failure != null) throw failure;
  }
}
