import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';

/// Read-only display of the identifier being verified, with an Edit link.
///
/// Shows what the code was sent to, so a mistyped address is obvious before
/// the user waits for a message that will never arrive. Edit returns to the
/// previous step rather than making the field editable in place — the server
/// has already issued a code against this identifier, so changing it means
/// starting over.
class IdentifierPreview extends StatelessWidget {
  const IdentifierPreview({super.key, required this.identifier, this.onEdit});

  final String identifier;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.authIdentifierLabel,
                style: AppTypography.monoEyebrow.copyWith(
                  color: semantic.textSecondary,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.55,
                ),
              ),
            ),
            if (onEdit != null)
              InkWell(
                onTap: onEdit,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  child: Text(
                    l10n.otpEdit,
                    style: context.textStyles.bodySmall?.copyWith(
                      color: context.colors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg + 1,
            vertical: AppSpacing.md + 3,
          ),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: semantic.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  identifier,
                  // Mono and LTR: an address or phone number is a machine
                  // value, and bidi reordering would scramble it in Arabic.
                  textDirection: TextDirection.ltr,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.monoValue.copyWith(
                    fontSize: 14,
                    color: context.colors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
