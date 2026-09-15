import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/theme/app_typography.dart';
import '../extensions/build_context_x.dart';

/// What a status pill is reporting.
///
/// Named for meaning, not colour, so a caller says `AppStatusTone.degraded`
/// rather than picking amber — and a palette change never requires touching
/// call sites.
enum AppStatusTone {
  /// Live, confirmed, synced.
  live,

  /// Working but degraded: offline, cached, locked, clock drift.
  degraded,

  /// Failed: conflict, expired, invalid.
  failed,

  /// Informational, no judgement attached.
  neutral,
}

/// The small capsule used for machine status throughout the app:
/// `● LIVE PASSES`, `● CACHED`, `HTTP 423 · LOCKED`, `● SESSION TIMEOUT`.
///
/// Label text is mono and comes from the caller already localized — status
/// strings are short and this widget does not guess at wording.
class AppStatusPill extends StatelessWidget {
  const AppStatusPill({
    super.key,
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.showDot = true,
    this.icon,
  });

  final String label;
  final AppStatusTone tone;

  /// The leading dot. On by default — it is what makes these read as status
  /// rather than as a plain chip.
  final bool showDot;

  /// Optional trailing icon, as on the offline banner's struck-through wifi.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    final (Color foreground, Color background) = switch (tone) {
      AppStatusTone.live => (semantic.success, semantic.successContainer),
      AppStatusTone.degraded => (semantic.warning, semantic.warningContainer),
      AppStatusTone.failed => (context.colors.error, semantic.dangerContainer),
      AppStatusTone.neutral => (
        semantic.textTertiary,
        semantic.surfaceElevated,
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs + 1,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: foreground,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.sm - 2),
          ],
          Text(
            label,
            style: AppTypography.monoLabel.copyWith(color: foreground),
          ),
          if (icon != null) ...[
            const SizedBox(width: AppSpacing.sm - 2),
            Icon(icon, size: 13, color: foreground),
          ],
        ],
      ),
    );
  }
}
