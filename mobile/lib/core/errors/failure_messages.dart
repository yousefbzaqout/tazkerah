import '../../l10n/generated/app_localizations.dart';
import 'failure.dart';

/// Turns a [Failure] into text a user should actually read.
///
/// Kept apart from [Failure] itself so the error vocabulary stays free of
/// Flutter and of localization concerns — a failure is data, its wording is a
/// presentation decision.
///
/// Never surfaces `debugMessage`: it is unlocalized and may leak internals.
extension FailureMessage on Failure {
  String localizedMessage(AppLocalizations l10n) => switch (this) {
    NetworkFailure() => l10n.errorNetwork,
    TimeoutFailure() => l10n.errorTimeout,
    ServerFailure() => l10n.errorServer,
    UnauthorizedFailure() => l10n.errorUnauthorized,
    LockedFailure() => l10n.errorLocked,
    // Deliberately share the generic wording for now. Features that need
    // specific copy (a taken seat, an expired hold) should branch on `code`
    // locally rather than growing this shared switch.
    ForbiddenFailure() ||
    NotFoundFailure() ||
    ConflictFailure() ||
    ValidationFailure() ||
    RateLimitFailure() ||
    StorageFailure() ||
    CancelledFailure() ||
    UnknownFailure() => l10n.errorUnexpected,
  };
}
