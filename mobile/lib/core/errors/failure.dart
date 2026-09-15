/// The error vocabulary the rest of the app speaks.
///
/// Nothing above the data layer should ever see a [DioException], a
/// [PlatformException], or a raw status code. Data sources catch those and
/// translate them into a [Failure], so presentation can switch on a small,
/// closed set of cases and render the right message.
///
/// [code] mirrors the backend error envelope (`error.code`) where one was
/// supplied, so feature code can branch on documented values such as
/// `SEAT_UNAVAILABLE` or `HOLD_EXPIRED` without parsing strings.
sealed class Failure implements Exception {
  const Failure({this.code, this.debugMessage});

  /// Machine-readable code from the backend envelope, when present.
  final String? code;

  /// Developer-facing detail. Never shown to users — it is not localized and
  /// may contain technical noise. Use it for logs and crash reports.
  final String? debugMessage;

  @override
  String toString() => '$runtimeType(code: $code, debug: $debugMessage)';
}

/// The device could not reach the server: no connectivity, DNS failure,
/// connection refused.
class NetworkFailure extends Failure {
  const NetworkFailure({super.code, super.debugMessage});
}

/// The request was sent but exceeded its time budget.
class TimeoutFailure extends Failure {
  const TimeoutFailure({super.code, super.debugMessage});
}

/// The server answered with 5xx.
class ServerFailure extends Failure {
  const ServerFailure({this.statusCode, super.code, super.debugMessage});

  final int? statusCode;
}

/// Authentication is missing, invalid, or expired (401). The session layer
/// treats this as the signal to refresh, and failing that, to sign out.
class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({super.code, super.debugMessage});
}

/// The caller is authenticated but not permitted (403).
class ForbiddenFailure extends Failure {
  const ForbiddenFailure({super.code, super.debugMessage});
}

/// The requested resource does not exist (404).
class NotFoundFailure extends Failure {
  const NotFoundFailure({super.code, super.debugMessage});
}

/// The request conflicts with current server state (409) — for example a seat
/// taken between rendering the map and submitting the hold.
class ConflictFailure extends Failure {
  const ConflictFailure({super.code, super.debugMessage});
}

/// Request rejected for shape or content reasons (422), with per-field detail
/// where the backend supplied it.
class ValidationFailure extends Failure {
  const ValidationFailure({
    this.fieldErrors = const {},
    super.code,
    super.debugMessage,
  });

  /// Field name to the messages that field failed on.
  final Map<String, List<String>> fieldErrors;
}

/// The resource is locked and cannot be acted on (423).
///
/// Distinct from [ForbiddenFailure]: the caller is permitted in principle, but
/// the organizer has withheld this sector — for production allocation or
/// artist delegation — so the answer is "not this one", not "not you". The
/// seat map renders it as an overlay offering other sectors rather than as a
/// permission error.
class LockedFailure extends Failure {
  const LockedFailure({this.reason, super.code, super.debugMessage});

  /// Backend-supplied reason code shown in the overlay: `BR-007`.
  final String? reason;
}

/// The client is being throttled (429).
class RateLimitFailure extends Failure {
  const RateLimitFailure({this.retryAfter, super.code, super.debugMessage});

  final Duration? retryAfter;
}

/// Reading or writing local storage failed.
class StorageFailure extends Failure {
  const StorageFailure({super.code, super.debugMessage});
}

/// The user aborted the operation. Presentation should stay silent for this
/// one — a cancellation is not an error the user needs told about.
class CancelledFailure extends Failure {
  const CancelledFailure({super.code, super.debugMessage});
}

/// Anything that did not match a known case. Worth logging: a recurring
/// [UnknownFailure] usually means a case is missing above.
class UnknownFailure extends Failure {
  const UnknownFailure({super.code, super.debugMessage});
}
