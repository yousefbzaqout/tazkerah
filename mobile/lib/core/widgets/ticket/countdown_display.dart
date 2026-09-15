import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../extensions/build_context_x.dart';
import '../app_status_pill.dart';

/// The `MM:SS` readout used for the seat hold and the checkout window.
///
/// Presentation only — it renders the [text] it is given and runs no timer.
/// The countdown itself must be driven from the server's `expires_at`, and a
/// widget that ticked its own clock would drift while the app is backgrounded
/// and show a deadline that never matches the server's.
///
/// Mono with tabular figures, so the digits do not shift the layout each
/// second.
class CountdownDisplay extends StatelessWidget {
  const CountdownDisplay({
    super.key,
    required this.text,
    this.label,
    this.tone = AppStatusTone.live,
    this.compact = false,
  });

  /// Preformatted remaining time: `09:41`, `00:00`.
  final String text;

  /// Small label above the digits: `HOLD TIMER`, `SEATS HELD`.
  final String? label;

  /// Turns amber as the window narrows and red once it expires. The caller
  /// decides when to change it — that is a business rule, not a visual one.
  final AppStatusTone tone;

  /// Inline form for a toolbar, rather than the stacked hero form.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final label = this.label;

    final color = switch (tone) {
      AppStatusTone.live => semantic.success,
      AppStatusTone.degraded => semantic.warning,
      AppStatusTone.failed => context.colors.error,
      AppStatusTone.neutral => semantic.textSecondary,
    };

    final digits = Text(
      text,
      // A timer is a machine value: LTR in every locale.
      textDirection: TextDirection.ltr,
      style:
          (compact
                  ? AppTypography.monoValue.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    )
                  : AppTypography.monoTimer)
              .copyWith(color: color),
    );

    if (label == null) return digits;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: compact
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: AppTypography.monoLabel.copyWith(color: semantic.textTertiary),
        ),
        SizedBox(height: compact ? AppSpacing.xxs : AppSpacing.xs),
        digits,
      ],
    );
  }
}
