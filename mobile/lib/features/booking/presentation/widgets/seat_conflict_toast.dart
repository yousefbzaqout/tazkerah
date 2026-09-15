import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/seat_selection_state.dart';

/// The 409 notice: the seat was taken between rendering and submitting.
///
/// An inline panel rather than a `SnackBar`, for two reasons the design makes
/// clear: it carries four distinct pieces of information (status code, seat,
/// headline, explanation) that a snackbar cannot hold legibly, and it must sit
/// directly above the selection bar it has just emptied, so cause and effect
/// read together.
///
/// It does not auto-dismiss. Losing a seat is consequential, and a message
/// that vanishes on a timer is one the user may never have read.
class SeatConflictToast extends StatelessWidget {
  const SeatConflictToast({super.key, required this.conflict, this.onDismiss});

  final SeatConflict conflict;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final error = context.colors.error;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: semantic.dangerContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: error),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: error.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Icon(Icons.warning_amber_rounded, size: 18, color: error),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.seatConflictEyebrow,
                          style: AppTypography.monoLabel.copyWith(
                            fontSize: 10,
                            color: error,
                          ),
                        ),
                      ),
                      Text(
                        l10n.seatConflictSeat(conflict.displayLabel),
                        style: AppTypography.mono.copyWith(
                          fontSize: 10,
                          color: semantic.textTertiary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.seatConflictTitle,
                    style: context.textStyles.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.seatConflictMessage,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: semantic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onDismiss != null)
              Padding(
                padding: const EdgeInsetsDirectional.only(start: AppSpacing.sm),
                child: InkResponse(
                  onTap: onDismiss,
                  radius: 20,
                  child: Semantics(
                    button: true,
                    label: l10n.seatDismiss,
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: semantic.textTertiary,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
