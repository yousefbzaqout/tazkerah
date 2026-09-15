import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../extensions/build_context_x.dart';
import 'app_status_pill.dart';

/// Full-width inline notice.
///
/// Covers the recurring banner in the design: the offline bar, the screenshot
/// intercept, the clock-drift warning, and the seat-conflict error. They share
/// one anatomy — leading icon, optional mono eyebrow, title, optional body,
/// optional trailing action — so they are one widget rather than four.
///
/// [AppStatusTone] picks the colour, so callers name the meaning and never the
/// hue.
class AppBanner extends StatelessWidget {
  const AppBanner({
    super.key,
    required this.title,
    this.tone = AppStatusTone.degraded,
    this.eyebrow,
    this.message,
    this.icon,
    this.onDismiss,
    this.action,
    this.trailing,
  });

  /// The single-line headline: "Seat just taken — pick another".
  final String title;

  final AppStatusTone tone;

  /// Small mono label above the title: `CONFLICT · HTTP 409`.
  final String? eyebrow;

  /// Explanatory copy under the title.
  final String? message;

  /// Leading icon. Defaults to a sensible glyph for [tone].
  final IconData? icon;

  /// Shows a close button when provided.
  final VoidCallback? onDismiss;

  /// A call to action rendered under the message — "Check connection".
  final Widget? action;

  /// Trailing widget opposite the eyebrow, such as a timestamp.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final textStyles = context.textStyles;

    final (Color accent, Color background) = switch (tone) {
      AppStatusTone.live => (semantic.success, semantic.successContainer),
      AppStatusTone.degraded => (semantic.warning, semantic.warningContainer),
      AppStatusTone.failed => (context.colors.error, semantic.dangerContainer),
      AppStatusTone.neutral => (
        semantic.textSecondary,
        semantic.surfaceElevated,
      ),
    };

    final effectiveIcon = icon ?? _defaultIcon(tone);
    final eyebrow = this.eyebrow;
    final message = this.message;
    final action = this.action;
    final trailing = this.trailing;
    final onDismiss = this.onDismiss;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(effectiveIcon, size: 18, color: accent),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (eyebrow != null || trailing != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Row(
                      children: [
                        if (eyebrow != null)
                          Expanded(
                            child: Text(
                              eyebrow,
                              style: AppTypography.monoLabel.copyWith(
                                color: accent,
                              ),
                            ),
                          )
                        else
                          const Spacer(),
                        ?trailing,
                      ],
                    ),
                  ),
                Text(
                  title,
                  style: textStyles.titleSmall?.copyWith(
                    color: context.colors.onSurface,
                  ),
                ),
                if (message != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    style: textStyles.bodySmall?.copyWith(
                      color: semantic.textSecondary,
                    ),
                  ),
                ],
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  action,
                ],
              ],
            ),
          ),
          if (onDismiss != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
              child: InkResponse(
                onTap: onDismiss,
                radius: 20,
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: semantic.textTertiary,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static IconData _defaultIcon(AppStatusTone tone) => switch (tone) {
    AppStatusTone.live => Icons.check_circle_outline,
    AppStatusTone.degraded => Icons.warning_amber_rounded,
    AppStatusTone.failed => Icons.error_outline,
    AppStatusTone.neutral => Icons.info_outline,
  };
}
