import 'dart:async';

import '../domain/auth_repository.dart';
import '../domain/user_profile.dart';
import '../domain/sign_in_flow_state.dart';

/// A stand-in [AuthRepository] for running the app before the backend exists.
///
/// **Not a production implementation.** It issues no real codes, contacts no
/// server, and its "session" is a placeholder string. [AppConfig] gates it to
/// non-production builds so a release cannot pick it up by accident.
///
/// It is deliberately unhelpful in one way: it accepts exactly one code, and
/// rejects everything else with a real error. A stub that accepted any input
/// would make the failure paths untestable by hand, which is most of what
/// there is to look at on this screen.
class DevAuthRepository implements AuthRepository {
  DevAuthRepository({this.latency = const Duration(milliseconds: 600)});

  /// Simulated round-trip, so loading states are visible on a device rather
  /// than flashing past.
  final Duration latency;

  /// The only code this stub accepts.
  static const String acceptedCode = '123456';

  /// Identifiers that trigger a failure instead of a code, so each error
  /// state can be reached by hand:
  ///
  /// - `expired@test.com`   → the code is rejected as expired
  /// - `limited@test.com`   → rate limited
  /// - `offline@test.com`   → network failure
  static const String expiredIdentifier = 'expired@test.com';
  static const String limitedIdentifier = 'limited@test.com';
  static const String offlineIdentifier = 'offline@test.com';

  String? _pendingIdentifier;

  @override
  Future<void> requestCode(String identifier) async {
    await Future<void>.delayed(latency);

    if (identifier == offlineIdentifier) {
      throw const SignInException(SignInFailure.network);
    }
    if (identifier == limitedIdentifier) {
      throw const SignInException(SignInFailure.tooManyAttempts);
    }

    _pendingIdentifier = identifier;
  }

  @override
  Future<String> verifyCode({
    required String identifier,
    required String code,
  }) async {
    await Future<void>.delayed(latency);

    if (identifier == expiredIdentifier) {
      throw const SignInException(SignInFailure.expiredCode);
    }
    if (code != acceptedCode) {
      throw const SignInException(SignInFailure.invalidCode);
    }
    if (_pendingIdentifier != identifier) {
      // No code was requested for this identifier. The real backend enforces
      // the same thing, so the stub should not be more permissive.
      throw const SignInException(SignInFailure.invalidCode);
    }

    return 'dev-refresh-token';
  }

  @override
  Future<UserProfile> fetchProfile() async {
    await Future<void>.delayed(latency);

    final identifier = _pendingIdentifier ?? 'tariq@example.com';
    return UserProfile(
      id: 'usr_dev_1',
      displayName: 'Tariq Al-Mansoor',
      identifier: identifier,
      email: identifier.contains('@') ? identifier : null,
      phone: identifier.contains('@') ? null : identifier,
      memberSince: DateTime.utc(2024, 3, 14),
      deviceId: '#TZ-8841-A',
    );
  }

  @override
  Future<void> revokeSession() async {
    await Future<void>.delayed(latency);
    _pendingIdentifier = null;
  }
}
