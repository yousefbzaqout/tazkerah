import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/gate_pass_state.dart';

/// The security notice shown when a screen capture is detected.
///
/// Amber rather than red: nothing has failed and nothing was lost. The pass is
/// intact, one rotation was invalidated, and a fresh code is one tap away —
/// treating that as an error would alarm someone standing at a gate for no
/// reason.
class PassInterceptBanner extends StatelessWidget {
  const PassInterceptBanner({super.key, required this.intercept});

  final PassIntercept intercept;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: semantic.warningContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          // A leading rule rather than a full outline, as drawn: it marks the
          // block without boxing it in beside the code.
          border: BorderDirectional(
            start: BorderSide(color: semantic.warning, width: 3),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: semantic.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppRadius.sm - 2),
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 17,
                color: semantic.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.passInterceptEyebrow,
                          style: AppTypography.monoLabel.copyWith(
                            fontSize: 10,
                            color: semantic.warning,
                          ),
                        ),
                      ),
                      Text(
                        l10n.passInterceptJustNow,
                        style: AppTypography.monoLabel.copyWith(
                          fontSize: 9,
                          color: semantic.textDisabled,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.passInterceptTitle,
                    style: context.textStyles.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.passInterceptMessage,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: semantic.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
