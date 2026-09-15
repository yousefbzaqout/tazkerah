import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_banner.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../../../core/widgets/brand_emblem.dart';
import '../../../core/widgets/ticket/qr_frame.dart';
import '../domain/gate_pass.dart';
import '../domain/gate_pass_state.dart';
import 'controllers/gate_pass_controller.dart';
import 'widgets/clock_skew_fallback.dart';
import 'widgets/pass_detail_rows.dart';
import 'widgets/pass_intercept_banner.dart';

/// The gate pass: a rotating QR code to be held over a scanner.
///
/// Both designed frames live here — an active code and a capture-intercepted
/// one — because the intercept happens while the user is standing at the gate
/// with the phone raised. A navigation at that moment would be slow and
/// disorienting; a state change in place is neither.
class GatePassScreen extends ConsumerWidget {
  const GatePassScreen({super.key, required this.ticketId});

  final String ticketId;

  /// Re-syncs the clock and reports what changed.
  ///
  /// The outcome matters to someone standing at a gate: a re-sync that did not
  /// fix the drift must not look like one that did, or they will put away a
  /// fallback code they still need.
  Future<void> _resync(
    BuildContext context,
    WidgetRef ref,
    GatePassController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;

    await controller.attemptTimeResync();
    if (!context.mounted) return;

    final state = ref.read(gatePassControllerProvider(ticketId));
    if (state.status == GatePassViewStatus.active) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          state.failure != null
              ? l10n.passResyncFailed
              : l10n.passResyncStillSkewed,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = gatePassControllerProvider(ticketId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      // Deliberately black rather than the themed background: the pass is held
      // under a scanner, and every stray pixel of light is contrast the reader
      // has to fight.
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: switch (state.status) {
          GatePassViewStatus.loading => const AppLoadingIndicator(),
          GatePassViewStatus.error => AppErrorView(
            failure: state.failure!,
            onRetry: controller.load,
          ),
          GatePassViewStatus.unavailable => _UnavailableView(pass: state.pass),
          // Clock drift is a different problem from a screenshot: nothing
          // leaked, and no fresh code would help. It gets the fallback frame.
          GatePassViewStatus.active || GatePassViewStatus.intercepted =>
            state.intercept?.reason == InterceptReason.clockDrift
                ? _SkewBody(
                    state: state,
                    onResync: () => _resync(context, ref, controller),
                  )
                : _PassBody(state: state, onReveal: controller.revealFreshCode),
        },
      ),
    );
  }
}

/// The pass itself, in whichever of the two states it is in.
class _PassBody extends StatelessWidget {
  const _PassBody({required this.state, required this.onReveal});

  final GatePassViewState state;
  final Future<void> Function() onReveal;

  @override
  Widget build(BuildContext context) {
    final pass = state.pass!;
    final isIntercepted = state.status == GatePassViewStatus.intercepted;

    return Column(
      children: [
        _PassHeader(pass: pass, isIntercepted: isIntercepted),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            children: [
              if (state.isClockStale) ...[
                const SizedBox(height: AppSpacing.md),
                AppBanner(
                  title: context.l10n.passClockStale,
                  tone: AppStatusTone.degraded,
                  icon: Icons.schedule,
                ),
              ],
              if (isIntercepted) ...[
                const SizedBox(height: AppSpacing.md),
                PassInterceptBanner(intercept: state.intercept!),
              ] else ...[
                const SizedBox(height: AppSpacing.lg),
                const _LuminosityNotice(),
              ],
              const SizedBox(height: AppSpacing.lg),
              Center(child: _PassCode(state: state)),
              const SizedBox(height: AppSpacing.lg),
              _RotationStatus(state: state),
              const SizedBox(height: AppSpacing.xl),
              PassDetailRows(pass: pass, isIntercepted: isIntercepted),
              const SizedBox(height: AppSpacing.lg),
              if (!isIntercepted) _ScannerHint(),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
        if (isIntercepted) _RevealBar(onReveal: onReveal),
      ],
    );
  }
}

/// The clock-skew frame: header, fallback code, and the re-sync action.
class _SkewBody extends StatelessWidget {
  const _SkewBody({required this.state, required this.onResync});

  final GatePassViewState state;
  final Future<void> Function() onResync;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final pass = state.pass!;

    return Column(
      children: [
        _SkewHeader(pass: pass),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xl,
            ),
            children: [
              ClockSkewFallback(pass: pass, state: state),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton(
                onPressed: state.isRefreshing ? null : onResync,
                child: state.isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.sync, size: 15, color: semantic.warning),
                          const SizedBox(width: AppSpacing.sm),
                          Flexible(
                            child: Text(
                              l10n.passResyncAction,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.passStaffOverride,
                textAlign: TextAlign.center,
                style: AppTypography.mono.copyWith(
                  fontSize: 11,
                  color: semantic.textDisabled,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The skew frame's header, which reports the drift rather than the seat.
class _SkewHeader extends StatelessWidget {
  const _SkewHeader({required this.pass});

  final GatePass pass;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final seconds = AppConstants.clockSkewSuppressionThreshold.inSeconds;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: semantic.border)),
      ),
      child: Row(
        children: [
          const BrandEmblem(size: 26),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.appTitleLatin.toUpperCase(),
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 11,
                    color: context.colors.onSurface,
                  ),
                ),
                Text(
                  l10n.passAuthProtocol(pass.reference),
                  style: AppTypography.mono.copyWith(
                    fontSize: 10,
                    color: semantic.textTertiary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppStatusPill(
            label: l10n.passSkewBadge(seconds),
            tone: AppStatusTone.degraded,
            showDot: false,
          ),
        ],
      ),
    );
  }
}

/// The QR card, or the redacted placeholder in its place.
class _PassCode extends StatelessWidget {
  const _PassCode({required this.state});

  final GatePassViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final pass = state.pass!;
    final code = state.code;

    // No code means nothing to draw. The payload is absent from state rather
    // than hidden behind a flag, so there is nothing here to leak.
    if (code == null) {
      return QrFrame(
        qr: const SizedBox.shrink(),
        state: QrPassState.suppressed,
        suppressedLabel: l10n.passRedacted,
        suppressedHash: state.intercept?.withheldHash,
      );
    }

    return QrFrame(
      qr: QrImageView(
        data: code.payload,
        version: QrVersions.auto,
        // Fixed dark-on-white: a scanner needs that contrast, and theming it
        // would make the pass unreadable in the app's own dark palette.
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: AppColors.qrInk,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: AppColors.qrInk,
        ),
        backgroundColor: AppColors.qrCanvas,
        gapless: true,
      ),
      progress: state.progress,
      header: _CardEdge(leading: l10n.passCardBrand, trailing: pass.zoneLabel),
      footer: _CardEdge(
        leading: l10n.passDynamicPass,
        trailing: code.displayHash,
      ),
    );
  }
}

/// One of the two mono lines printed inside the QR card.
class _CardEdge extends StatelessWidget {
  const _CardEdge({required this.leading, required this.trailing});

  final String leading;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    // Printed on the white card, so these take the QR ink colour rather than
    // the theme's text colours.
    final style = AppTypography.monoLabel.copyWith(
      fontSize: 8,
      color: AppColors.qrInk.withValues(alpha: 0.75),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(leading, style: style),
        Text(trailing, style: style, textDirection: TextDirection.ltr),
      ],
    );
  }
}

/// The countdown pill and the rotation policy beneath the code.
class _RotationStatus extends StatelessWidget {
  const _RotationStatus({required this.state});

  final GatePassViewState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final pass = state.pass!;
    final seconds = pass.rotationInterval.inSeconds;

    if (state.status == GatePassViewStatus.intercepted) {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: semantic.warning,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.passRekeying,
                style: AppTypography.monoLabel.copyWith(
                  fontSize: 11,
                  color: semantic.textTertiary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Text(
                l10n.passNewTokenReady,
                style: AppTypography.monoLabel.copyWith(
                  fontSize: 11,
                  color: context.colors.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.passRollingNote(seconds),
            textAlign: TextAlign.center,
            style: AppTypography.mono.copyWith(
              fontSize: 11,
              color: semantic.textTertiary,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md + 2,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: semantic.success.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: semantic.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                // Rounded up: a code with 0.4s left still has time on it, and
                // showing "0s" beside a working code reads as broken.
                l10n.passSecondsRemaining(state.remaining.inSeconds + 1),
                textDirection: TextDirection.ltr,
                style: AppTypography.monoValue.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: semantic.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(width: 1, height: 14, color: semantic.border),
              const SizedBox(width: AppSpacing.sm),
              Text(
                l10n.passRemainingSuffix,
                style: AppTypography.mono.copyWith(
                  fontSize: 12,
                  color: semantic.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.passRefreshNote(seconds),
          style: AppTypography.mono.copyWith(
            fontSize: 12,
            color: semantic.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l10n.passSecurityNote,
          textAlign: TextAlign.center,
          style: AppTypography.monoLabel.copyWith(
            fontSize: 9,
            color: semantic.textDisabled,
          ),
        ),
      ],
    );
  }
}

/// The top bar: back, brand, seat, and the pass reference.
class _PassHeader extends StatelessWidget {
  const _PassHeader({required this.pass, required this.isIntercepted});

  final GatePass pass;
  final bool isIntercepted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isIntercepted ? semantic.warning : semantic.success,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  isIntercepted
                      ? l10n.passConfirmedAccess
                      : l10n.passActiveBadge,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 10,
                    color: isIntercepted ? semantic.success : semantic.success,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                l10n.passReferenceLine(pass.reference),
                style: AppTypography.monoLabel.copyWith(
                  fontSize: 10,
                  color: semantic.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back_ios_new, size: 16),
                tooltip: l10n.detailBack,
                style: IconButton.styleFrom(
                  backgroundColor: context.colors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isIntercepted ? pass.eventTitle : l10n.appTitleLatin,
                      style: context.textStyles.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      isIntercepted
                          ? l10n.passZoneSeat(pass.zoneLabel, pass.seatLabel)
                          : pass.venueName,
                      style: AppTypography.mono.copyWith(
                        fontSize: 11,
                        color: semantic.textTertiary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (!isIntercepted) ...[
                const SizedBox(width: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm - 2,
                  ),
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: semantic.border),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.passSeatLabel,
                        style: AppTypography.monoLabel.copyWith(
                          fontSize: 8,
                          color: semantic.success,
                        ),
                      ),
                      Text(
                        pass.seatLabel,
                        textDirection: TextDirection.ltr,
                        style: AppTypography.monoValue.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// The "screen set to high luminosity" notice.
class _LuminosityNotice extends StatelessWidget {
  const _LuminosityNotice();

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm - 2,
        ),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.light_mode_outlined, size: 13, color: semantic.success),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                context.l10n.passHighLuminosity,
                style: AppTypography.mono.copyWith(
                  fontSize: 11,
                  color: semantic.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The instruction under the pass details.
class _ScannerHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.touch_app_outlined, size: 13, color: semantic.textDisabled),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            context.l10n.passScannerHint,
            textAlign: TextAlign.center,
            style: AppTypography.mono.copyWith(
              fontSize: 11,
              color: semantic.textDisabled,
            ),
          ),
        ),
      ],
    );
  }
}

/// The pinned action that reveals a fresh code after an intercept.
class _RevealBar extends StatefulWidget {
  const _RevealBar({required this.onReveal});

  final Future<void> Function() onReveal;

  @override
  State<_RevealBar> createState() => _RevealBarState();
}

class _RevealBarState extends State<_RevealBar> {
  bool _busy = false;

  Future<void> _reveal() async {
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onReveal();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              onPressed: _busy ? null : _reveal,
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh, size: 16),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            l10n.passRevealFresh,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.passSecuredBy,
              textAlign: TextAlign.center,
              style: AppTypography.mono.copyWith(
                fontSize: 9,
                color: context.semantic.textDisabled,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown for a pass that cannot be presented at all.
class _UnavailableView extends StatelessWidget {
  const _UnavailableView({required this.pass});

  final GatePass? pass;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppEmptyView(
      title: l10n.passUnavailableTitle,
      message: pass?.status == GatePassStatus.consumed
          ? l10n.passUnavailableConsumed
          : l10n.passUnavailableInvalid,
      icon: Icons.confirmation_number_outlined,
    );
  }
}
