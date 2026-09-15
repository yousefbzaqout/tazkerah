import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../extensions/build_context_x.dart';
import 'app_status_pill.dart';

/// Presents a modal bottom sheet with the app's chrome.
///
/// Wraps `showModalBottomSheet` so every sheet gets the same safe-area
/// handling, scroll behaviour and padding, rather than each caller
/// reassembling it. Colours and shape come from `bottomSheetTheme`.
Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isDismissible = true,
  bool isScrollControlled = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isDismissible: isDismissible,
    isScrollControlled: isScrollControlled,
    // Lets a tall sheet grow without covering the status bar.
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        // Keeps content clear of the keyboard when a sheet contains a field.
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: builder(context),
      ),
    ),
  );
}

/// The standard sheet body: an optional status pill and close button, a title,
/// a message, optional detail rows, and stacked actions.
///
/// This is the "Sector locked by organizer" sheet from the design, generalised
/// to the shape every sheet in the flow shares.
class AppSheetContent extends StatelessWidget {
  const AppSheetContent({
    super.key,
    required this.title,
    this.statusLabel,
    this.statusTone = AppStatusTone.degraded,
    this.message,
    this.icon,
    this.details,
    this.primaryAction,
    this.secondaryAction,
    this.onClose,
  });

  final String title;

  /// Mono status shown at the top: `HTTP 423 · LOCKED`.
  final String? statusLabel;
  final AppStatusTone statusTone;

  final String? message;

  /// Leading icon beside the title.
  final IconData? icon;

  /// Label/value rows in a recessed block — target sector, lock reason, and
  /// so on. Callers pass localized labels and preformatted values.
  final List<AppSheetDetail>? details;

  final Widget? primaryAction;
  final Widget? secondaryAction;

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final textStyles = context.textStyles;

    final statusLabel = this.statusLabel;
    final message = this.message;
    final icon = this.icon;
    final details = this.details;
    final primaryAction = this.primaryAction;
    final secondaryAction = this.secondaryAction;
    final onClose = this.onClose;

    final accent = switch (statusTone) {
      AppStatusTone.live => semantic.success,
      AppStatusTone.degraded => semantic.warning,
      AppStatusTone.failed => context.colors.error,
      AppStatusTone.neutral => semantic.textSecondary,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (statusLabel != null || onClose != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: [
                  if (statusLabel != null)
                    AppStatusPill(label: statusLabel, tone: statusTone)
                  else
                    const Spacer(),
                  const Spacer(),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.close, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(icon, color: accent, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: textStyles.titleMedium),
                    if (message != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        message,
                        style: textStyles.bodySmall?.copyWith(
                          color: semantic.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (details != null && details.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            _DetailBlock(details: details),
          ],
          if (primaryAction != null) ...[
            const SizedBox(height: AppSpacing.xl),
            SizedBox(width: double.infinity, child: primaryAction),
          ],
          if (secondaryAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(width: double.infinity, child: secondaryAction),
          ],
        ],
      ),
    );
  }
}

/// One label/value pair inside a sheet's detail block.
@immutable
class AppSheetDetail {
  const AppSheetDetail({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;

  /// Tints the value — amber for a lock reason, emerald for an alternative.
  final Color? valueColor;
}

class _DetailBlock extends StatelessWidget {
  const _DetailBlock({required this.details});

  final List<AppSheetDetail> details;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        children: [
          for (final (index, detail) in details.indexed) ...[
            if (index > 0) const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    detail.label,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: semantic.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    detail.value,
                    textAlign: TextAlign.end,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: detail.valueColor ?? context.colors.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
