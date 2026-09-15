import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';

/// One of the paired cards under the title: an icon tile, an uppercase label,
/// and one or two lines of value.
///
/// The design sets these side by side at equal width. They are built to be
/// laid out by the caller in a [Row] of [Expanded]s rather than owning that
/// themselves, so a third card — an age rating, a sector — can be added
/// without this widget changing.
class EventInfoCard extends StatelessWidget {
  const EventInfoCard({
    super.key,
    required this.icon,
    required this.label,
    required this.primary,
    this.secondary,
    this.secondaryTone = InfoCardTone.muted,
  });

  final IconData icon;

  /// Uppercase mono label: `DATE & TIME`. Passed already localized and already
  /// uppercased — `toUpperCase` is wrong in some locales and meaningless in
  /// Arabic.
  final String label;

  /// The bold first line: `Fri, 28 Nov 2025`.
  final String primary;

  /// The second line: the time, or the city under the venue.
  final String? secondary;

  /// Whether the second line reads as ordinary detail or as a live value. The
  /// design prints the event time in emerald and the city in grey.
  final InfoCardTone secondaryTone;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final secondary = this.secondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md + 2),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: semantic.successContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 15, color: semantic.success),
              ),
              const SizedBox(width: AppSpacing.sm + 2),
              Expanded(
                child: Text(
                  label,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 10,
                    color: semantic.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            primary,
            style: context.textStyles.titleSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (secondary != null) ...[
            const SizedBox(height: AppSpacing.xxs),
            Text(
              secondary,
              style: switch (secondaryTone) {
                // The time is a machine value, so it takes mono — which also
                // stops the clock from reflowing the card as digits change.
                InfoCardTone.live => AppTypography.mono.copyWith(
                  fontSize: 12,
                  color: semantic.success,
                ),
                InfoCardTone.muted => context.textStyles.bodySmall?.copyWith(
                  color: semantic.textTertiary,
                ),
              },
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

enum InfoCardTone {
  /// Emerald, for the event's own time.
  live,

  /// Grey, for supporting geography.
  muted,
}

/// The assurance row under the overview: a shield, the ticket type, and the
/// anti-passback note.
///
/// Renders only what it is given. The security claim is supplied by the
/// backend rather than hard-coded here, because a screen that promises
/// encryption the server is not performing is the one lie this product cannot
/// afford.
class TicketSecurityRow extends StatelessWidget {
  const TicketSecurityRow({
    super.key,
    required this.note,
    this.antiPassbackEnabled = true,
  });

  final String note;
  final bool antiPassbackEnabled;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 2,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Row(
        children: [
          Icon(Icons.verified_user_outlined, size: 16, color: semantic.success),
          const SizedBox(width: AppSpacing.sm + 2),
          Expanded(
            child: Text(
              note,
              style: context.textStyles.titleSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (antiPassbackEnabled) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                context.l10n.detailAntiPassback,
                style: AppTypography.mono.copyWith(
                  fontSize: 10,
                  color: semantic.textDisabled,
                ),
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
