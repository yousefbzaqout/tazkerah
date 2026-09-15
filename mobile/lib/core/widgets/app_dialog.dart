import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../l10n/generated/app_localizations.dart';
import '../extensions/build_context_x.dart';
import 'app_status_pill.dart';

/// Shows a themed dialog.
///
/// Thin by design — `dialogTheme` already carries the colours and shape, so
/// this only fixes the barrier and insets.
Future<T?> showAppDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) {
  return showDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: builder(context),
    ),
  );
}

/// A confirmation dialog with an icon, title, message, and two actions.
///
/// Returns `true` when confirmed, `false` when dismissed or cancelled.
class AppConfirmDialog extends StatelessWidget {
  const AppConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    this.cancelLabel,
    this.tone = AppStatusTone.neutral,
    this.icon,
  });

  final String title;
  final String message;

  /// Localized by the caller — wording is specific to each decision.
  final String confirmLabel;

  /// Falls back to the shared "Cancel" string.
  final String? cancelLabel;

  /// Tints the icon and confirm button. Use [AppStatusTone.failed] for a
  /// destructive choice, such as cancelling a held reservation.
  final AppStatusTone tone;

  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final semantic = context.semantic;
    final icon = this.icon;

    final accent = switch (tone) {
      AppStatusTone.live => semantic.success,
      AppStatusTone.degraded => semantic.warning,
      AppStatusTone.failed => context.colors.error,
      AppStatusTone.neutral => context.colors.primary,
    };

    return AlertDialog(
      icon: icon == null
          ? null
          : Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: 24),
            ),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(message, textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: tone == AppStatusTone.failed
                    ? FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: context.colors.onError,
                      )
                    : null,
                child: Text(confirmLabel),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(cancelLabel ?? l10n.commonCancel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
