import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import '../errors/failure.dart';
import '../errors/failure_messages.dart';

/// The standard way to render a [Failure].
///
/// Takes the failure rather than a string so the message stays localized and
/// consistent, and so no screen invents its own wording for a network error.
///
/// [onRetry] is optional because not every failure is worth retrying — a 404
/// will stay a 404.
class AppErrorView extends StatelessWidget {
  const AppErrorView({super.key, required this.failure, this.onRetry});

  final Failure failure;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final onRetry = this.onRetry;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _iconFor(failure),
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              failure.localizedMessage(l10n),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.xl),
              FilledButton(onPressed: onRetry, child: Text(l10n.commonRetry)),
            ],
          ],
        ),
      ),
    );
  }

  IconData _iconFor(Failure failure) => switch (failure) {
    NetworkFailure() => Icons.wifi_off_outlined,
    TimeoutFailure() => Icons.hourglass_empty_outlined,
    UnauthorizedFailure() || ForbiddenFailure() => Icons.lock_outline,
    NotFoundFailure() => Icons.search_off_outlined,
    _ => Icons.error_outline,
  };
}
