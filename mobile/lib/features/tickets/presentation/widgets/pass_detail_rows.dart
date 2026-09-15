import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/gate_pass.dart';

/// The pass details block.
///
/// Two arrangements of the same facts, because the two frames need different
/// things: the active pass lists them as label/value rows a steward can read
/// aloud, while the intercepted frame uses a compact three-column strip that
/// leaves room for the security banner above it.
class PassDetailRows extends StatelessWidget {
  const PassDetailRows({
    super.key,
    required this.pass,
    this.isIntercepted = false,
  });

  final GatePass pass;
  final bool isIntercepted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    if (isIntercepted) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: semantic.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _Column(
                label: l10n.passVenueEntry,
                value: pass.entranceLabel,
              ),
            ),
            Expanded(
              child: _Column(
                label: l10n.passValidation,
                value: l10n.passSynced,
                valueColor: semantic.success,
                leading: Icon(Icons.check, size: 12, color: semantic.success),
              ),
            ),
            Expanded(
              child: _Column(
                label: l10n.passDeviceId,
                // A device id is a machine value: LTR in every locale.
                value: pass.deviceId ?? '—',
                valueDirection: TextDirection.ltr,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Column(
        children: [
          _Row(label: l10n.passHolder, value: pass.holderName),
          const SizedBox(height: AppSpacing.md),
          _Row(
            label: l10n.passEntrance,
            value: pass.isFastTrack
                ? l10n.passFastTrack(pass.entranceLabel)
                : pass.entranceLabel,
            valueColor: semantic.success,
          ),
          const SizedBox(height: AppSpacing.md),
          _Row(
            label: l10n.passStatusRow,
            value: l10n.passOnlineValidated,
            valueColor: semantic.success,
            leadingDot: true,
          ),
        ],
      ),
    );
  }
}

/// One label/value row of the active pass.
class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.valueColor,
    this.leadingDot = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool leadingDot;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: AppTypography.mono.copyWith(
              fontSize: 12,
              color: semantic.textSecondary,
            ),
          ),
        ),
        if (leadingDot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: valueColor ?? semantic.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm - 2),
        ],
        Flexible(
          child: Text(
            value,
            style: AppTypography.mono.copyWith(
              fontSize: 12,
              color: valueColor ?? context.colors.onSurface,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// One column of the intercepted frame's compact strip.
class _Column extends StatelessWidget {
  const _Column({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueDirection,
    this.leading,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextDirection? valueDirection;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.monoLabel.copyWith(
            fontSize: 8,
            color: semantic.textTertiary,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: AppSpacing.xs),
            ],
            Flexible(
              child: Text(
                value,
                textDirection: valueDirection,
                style: AppTypography.monoValue.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: valueColor ?? context.colors.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
