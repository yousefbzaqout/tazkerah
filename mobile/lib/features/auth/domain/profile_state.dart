import '../../../core/errors/failure.dart';
import 'user_profile.dart';

/// What the profile screen is showing.
sealed class ProfileState {
  const ProfileState();
}

class ProfileLoading extends ProfileState {
  const ProfileLoading();
}

class ProfileReady extends ProfileState {
  const ProfileReady(this.profile, {this.isSigningOut = false});

  final UserProfile profile;

  /// Sign-out is in flight. The screen blocks a second attempt — signing out
  /// twice is harmless, but a half-wiped keystore is not something to race.
  final bool isSigningOut;

  ProfileReady copyWith({UserProfile? profile, bool? isSigningOut}) =>
      ProfileReady(
        profile ?? this.profile,
        isSigningOut: isSigningOut ?? this.isSigningOut,
      );
}

class ProfileFailed extends ProfileState {
  const ProfileFailed(this.failure);

  final Failure failure;
}
