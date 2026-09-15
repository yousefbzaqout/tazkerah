import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../domain/gate_pass.dart';
import '../../domain/gate_pass_state.dart';

/// The offline fallback shown when the device clock has drifted too far for a
/// generated code to be accepted.
///
/// The QR is not merely hidden here — it is never requested, because a code
/// produced against an untrusted clock would be rejected at the gate without
/// explanation. What replaces it is a server-issued number a steward can type,
/// which is the one credential that does not depend on this device being right
/// about the time.
class ClockSkewFallback extends StatelessWidget {
  const ClockSkewFallback({
    super.key,
    required this.pass,
    required this.state,
    this.onResync,
  });

  final GatePass pass;
  final GatePassViewState state;
  final VoidCallback? onResync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final manual = state.manualCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SkewBanner(policy: pass.reference),
        const SizedBox(height: AppSpacing.lg),
        Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: semantic.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _Labelled(
                      label: l10n.passHolderLabel,
                      value: pass.eventTitle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  _Labelled(
                    label: l10n.passAssignedSeat,
                    value: pass.seatLabel,
                    valueColor: semantic.success,
                    alignEnd: true,
                    // A seat reference is a machine value: LTR in any locale.
                    valueDirection: TextDirection.ltr,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              _SuppressedChip(policy: pass.reference),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: Text(
                  l10n.passManualCodeLabel,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 11,
                    color: semantic.warning,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (manual == null)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: CircularProgressIndicator(),
                  ),
                )
              else
                _ManualCodePanel(code: manual),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.passManualCodeHelp,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
              if (manual != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Divider(color: semantic.border, height: 1),
                const SizedBox(height: AppSpacing.md),
                _DiagnosticsRow(offset: state.clockOffset, code: manual),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small uppercase label over its value.
class _Labelled extends StatelessWidget {
  const _Labelled({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueDirection,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final TextDirection? valueDirection;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: AppTypography.monoLabel.copyWith(
            fontSize: 9,
            color: semantic.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          textDirection: valueDirection,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: valueColor == null
              ? context.textStyles.titleSmall
              : AppTypography.monoValue.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The amber notice explaining the suppression.
class _SkewBanner extends StatelessWidget {
  const _SkewBanner({required this.policy});

  final String policy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final seconds = AppConstants.clockSkewSuppressionThreshold.inSeconds;

    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: semantic.warningContainer,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(color: semantic.warning.withValues(alpha: 0.6)),
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
                  Text(
                    l10n.passSkewTitle,
                    style: AppTypography.monoLabel.copyWith(
                      fontSize: 11,
                      color: semantic.warning,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    l10n.passSkewMessage(seconds, policy),
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

/// The chip standing where the QR would be.
class _SuppressedChip extends StatelessWidget {
  const _SuppressedChip({required this.policy});

  final String policy;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: semantic.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.visibility_off_outlined,
            size: 14,
            color: semantic.textTertiary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              context.l10n.passQrSuppressed(policy),
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
    );
  }
}

/// The eight digits themselves.
class _ManualCodePanel extends StatelessWidget {
  const _ManualCodePanel({required this.code});

  final ManualEntryCode code;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Semantics(
        // Read digit by digit: a screen reader announcing "forty-eight million
        // two hundred ninety-one thousand…" is useless to someone reading a
        // code aloud at a gate.
        label: code.digits.split('').join(' '),
        excludeSemantics: true,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              code.spaced,
              // Digits are a machine value: always LTR, so the code a steward
              // types matches the order it is printed in.
              textDirection: TextDirection.ltr,
              style: AppTypography.monoOtp.copyWith(
                fontSize: 28,
                letterSpacing: 2,
                color: context.colors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The offset and hash readouts under the code.
class _DiagnosticsRow extends StatelessWidget {
  const _DiagnosticsRow({required this.offset, required this.code});

  final Duration offset;
  final ManualEntryCode code;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    // Signed, because the direction of the drift is what a support engineer
    // needs: ahead of the server and behind it fail differently.
    final seconds = offset.inSeconds;
    final formatted = '${seconds >= 0 ? '+' : ''}${seconds}s';

    return Row(
      children: [
        Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: semantic.warning,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: AppSpacing.sm - 2),
        Expanded(
          child: Text(
            l10n.passOffsetReadout(formatted),
            style: AppTypography.mono.copyWith(
              fontSize: 10,
              color: semantic.textTertiary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        Text(
          l10n.passHashReadout(code.displayHash),
          textDirection: TextDirection.ltr,
          style: AppTypography.mono.copyWith(
            fontSize: 10,
            color: semantic.textTertiary,
          ),
        ),
      ],
    );
  }
}
