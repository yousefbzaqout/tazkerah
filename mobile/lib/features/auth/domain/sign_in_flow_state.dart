/// Where the user is in the two-step sign-in, and what the last attempt did.
///
/// One object rather than scattered booleans so impossible combinations —
/// submitting while showing an error, say — cannot be represented.
class SignInFlowState {
  const SignInFlowState({
    this.identifier,
    this.step = SignInStep.identifier,
    this.isSubmitting = false,
    this.failure,
  });

  /// The email or phone the code was sent to. Null before step one completes.
  final String? identifier;

  final SignInStep step;

  /// A request is in flight; the UI blocks re-submission.
  final bool isSubmitting;

  /// What went wrong, as a code the presentation layer localizes. Deliberately
  /// not a message: the screen owns wording, this owns meaning.
  final SignInFailure? failure;

  SignInFlowState copyWith({
    String? identifier,
    SignInStep? step,
    bool? isSubmitting,
    SignInFailure? failure,
    bool clearFailure = false,
  }) {
    return SignInFlowState(
      identifier: identifier ?? this.identifier,
      step: step ?? this.step,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      failure: clearFailure ? null : (failure ?? this.failure),
    );
  }
}

enum SignInStep {
  /// Entering an email or phone number.
  identifier,

  /// Entering the code that was sent.
  code,
}

/// Why a sign-in step failed.
///
/// Each maps to a distinct message, because the right user action differs:
/// a wrong code means retype, an expired one means resend, and a rate limit
/// means wait.
enum SignInFailure {
  /// The code did not match.
  invalidCode,

  /// The code was correct once but is past its window.
  expiredCode,

  /// Server-side rate limiting.
  tooManyAttempts,

  /// The identifier was rejected.
  invalidIdentifier,

  /// No connectivity.
  network,

  /// Anything else.
  unknown,
}
