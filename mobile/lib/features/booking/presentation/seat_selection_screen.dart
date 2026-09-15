import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../../../core/widgets/ticket/countdown_display.dart';
import '../domain/seat.dart';
import '../domain/seat_selection_state.dart';
import 'controllers/seat_selection_controller.dart';
import 'widgets/locked_sector_sheet.dart';
import 'widgets/seat_bottom_bars.dart';
import 'widgets/seat_conflict_toast.dart';
import 'widgets/seat_map.dart';

/// Seat selection: choose a seat, hold it, and watch the clock.
///
/// One screen for all three designed frames. They are phases of a single flow
/// — the map stays on screen through a conflict and under a hold — so
/// splitting them into separate routes would throw away scroll position and
/// make the transitions feel like navigations rather than answers.
class SeatSelectionScreen extends ConsumerStatefulWidget {
  const SeatSelectionScreen({
    super.key,
    required this.eventId,
    this.eventTitle,
    this.venueLabel,
  });

  final String eventId;

  /// Shown in the header. Passed from the detail screen, which already has it,
  /// so this screen does not refetch an event to print its name.
  final String? eventTitle;

  /// The hall line: `BANBAN ARENA · HALL 01`.
  final String? venueLabel;

  @override
  ConsumerState<SeatSelectionScreen> createState() =>
      _SeatSelectionScreenState();
}

class _SeatSelectionScreenState extends ConsumerState<SeatSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = seatSelectionControllerProvider(widget.eventId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    // The locked-sector sheet is presented as a route, so it is raised from a
    // listener rather than built into the tree — a sheet returned from `build`
    // would be re-presented on every rebuild the countdown triggers.
    ref.listen(provider, (previous, next) {
      final sector = next.lockedSector;
      if (sector != null && previous?.lockedSector != sector) {
        _showLocked(context, controller, next, sector);
      }
    });

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              state: state,
              title: widget.eventTitle,
              venue: widget.venueLabel,
            ),
            Expanded(child: _buildBody(context, state, controller)),
            ..._buildFooter(context, state, controller),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SeatSelectionState state,
    SeatSelectionController controller,
  ) {
    switch (state.phase) {
      case SeatSelectionPhase.loading:
        return const AppLoadingIndicator();

      case SeatSelectionPhase.error:
        final failure = state.failure;
        return failure == null
            ? const SizedBox.shrink()
            : AppErrorView(failure: failure, onRetry: controller.load);

      case SeatSelectionPhase.expired:
        return _HoldExpiredView(onRestart: controller.restartSelection);

      case SeatSelectionPhase.selecting:
      case SeatSelectionPhase.held:
        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xl,
          ),
          children: [
            _Legend(state: state),
            const SizedBox(height: AppSpacing.xl),
            SeatMap(
              sectors: state.sectors,
              selectedSeatId: state.selectedSeatId,
              interactive: state.isMapInteractive,
              onSeatTap: controller.selectSeat,
              stageLabel: state.phase == SeatSelectionPhase.held
                  ? context.l10n.seatStagePodium
                  : null,
            ),
            if (state.phase == SeatSelectionPhase.held) ...[
              const SizedBox(height: AppSpacing.md),
              _LockedSelectionNote(),
            ],
          ],
        );
    }
  }

  /// The conflict toast and whichever bottom bar the phase calls for.
  List<Widget> _buildFooter(
    BuildContext context,
    SeatSelectionState state,
    SeatSelectionController controller,
  ) {
    final conflict = state.conflict;
    final hold = state.hold;
    final locale = Localizations.localeOf(context).toString();
    final formatter = NumberFormat.decimalPattern(locale);

    return [
      if (conflict != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: SeatConflictToast(
            conflict: conflict,
            onDismiss: controller.dismissConflict,
          ),
        ),
      if (state.phase == SeatSelectionPhase.held && hold != null)
        SeatHeldBar(
          hold: hold,
          seat: _heldSeat(state, hold.seatIds),
          sectorName: _shortSector(state, hold.seatIds.firstOrNull),
          totalLabel: formatter.format(hold.totalMinor / 100),
          onCheckout: () => _onCheckout(context, hold.reference),
        )
      else if (state.phase == SeatSelectionPhase.selecting)
        SeatSelectionBar(
          seat: state.selectedSeat,
          priceLabel: state.selectedSector == null
              ? null
              : formatter.format(state.selectedSector!.priceMinor / 100),
          currency: state.selectedSector?.currency ?? '',
          isSubmitting: state.isSubmitting,
          onHold: controller.holdSelectedSeat,
        ),
    ];
  }

  void _showLocked(
    BuildContext context,
    SeatSelectionController controller,
    SeatSelectionState state,
    Sector sector,
  ) {
    showLockedSectorSheet(
      context,
      sector: sector,
      alternatives: state.sectors.where((s) => s.hasAvailability).toList(),
    ).whenComplete(controller.dismissLockedSector);
  }

  Seat? _heldSeat(SeatSelectionState state, List<String> seatIds) {
    final id = seatIds.firstOrNull;
    if (id == null) return null;
    return state.allSeats.where((s) => s.id == id).firstOrNull;
  }

  String _shortSector(SeatSelectionState state, String? seatId) {
    if (seatId == null) return '';
    for (final sector in state.sectors) {
      if (sector.seats.any((s) => s.id == seatId)) {
        return sector.name
            .replaceFirst(RegExp(r'^SECTOR\s+', caseSensitive: false), '')
            .split(' ')
            .first;
      }
    }
    return '';
  }

  /// Opens checkout for the granted hold, passing the event id along so the
  /// recovery actions there can come back to the right seat map.
  void _onCheckout(BuildContext context, String holdReference) {
    context.push(AppRoutes.checkoutPath(holdReference), extra: widget.eventId);
  }
}

/// The top bar: back, event identity, and either live-sync status or the hold
/// countdown.
class _Header extends StatelessWidget {
  const _Header({required this.state, this.title, this.venue});

  final SeatSelectionState state;
  final String? title;
  final String? venue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final hold = state.hold;
    final isHeld = state.phase == SeatSelectionPhase.held && hold != null;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: semantic.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: const Icon(Icons.arrow_back_ios_new, size: 16),
            tooltip: l10n.detailBack,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (venue != null)
                  Text(
                    venue!,
                    style: AppTypography.monoLabel.copyWith(
                      fontSize: 9,
                      color: semantic.textTertiary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  title ?? l10n.navEvents,
                  style: context.textStyles.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (isHeld)
            _HoldTimer(reference: hold.reference, remaining: state.remaining)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.seatStatusLabel,
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 9,
                    color: semantic.textTertiary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                AppStatusPill(
                  label: l10n.seatStatusLive,
                  tone: AppStatusTone.live,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// The `SEATS HELD 09:41` readout, with its booking reference.
class _HoldTimer extends StatelessWidget {
  const _HoldTimer({required this.reference, required this.remaining});

  final String reference;
  final Duration remaining;

  /// Below this the readout turns amber, as a last call.
  static const Duration _urgentThreshold = Duration(minutes: 2);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final minutes = remaining.inMinutes.toString().padLeft(2, '0');
    final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppStatusPill(
          label: l10n.seatHeldBadge(reference),
          tone: AppStatusTone.live,
        ),
        const SizedBox(height: AppSpacing.xs),
        CountdownDisplay(
          text: '$minutes:$seconds',
          label: l10n.seatSeatsHeld,
          compact: true,
          tone: remaining <= _urgentThreshold
              ? AppStatusTone.degraded
              : AppStatusTone.live,
        ),
      ],
    );
  }
}

/// The legend, which differs by phase: a held order names what is held, while
/// an active selection names what can still go wrong.
class _Legend extends StatelessWidget {
  const _Legend({required this.state});

  final SeatSelectionState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    if (state.phase == SeatSelectionPhase.held) {
      return SeatLegend(
        entries: [
          SeatLegendEntry(
            label: l10n.seatLegendHeld,
            color: semantic.success,
            filled: true,
          ),
          SeatLegendEntry(
            label: l10n.seatLegendSold,
            color: semantic.textDisabled,
            filled: true,
          ),
          SeatLegendEntry(
            label: l10n.seatLegendAvailable,
            color: semantic.borderStrong,
          ),
        ],
      );
    }

    return SeatLegend(
      entries: [
        SeatLegendEntry(
          label: l10n.seatLegendAvailable,
          color: semantic.borderStrong,
        ),
        SeatLegendEntry(
          label: l10n.seatLegendTaken,
          color: semantic.textDisabled,
          filled: true,
        ),
        // Only offered once a conflict has actually happened: a legend entry
        // for a state nothing on screen is in teaches nothing.
        if (state.conflict != null ||
            state.allSeats.any((s) => s.status == SeatStatus.conflict))
          SeatLegendEntry(
            label: l10n.seatLegendConflict,
            color: context.colors.error,
            emphasised: true,
          ),
      ],
    );
  }
}

/// The note explaining why the map stops responding during a hold.
class _LockedSelectionNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline, size: 12, color: semantic.textDisabled),
        const SizedBox(width: AppSpacing.sm - 2),
        Flexible(
          child: Text(
            context.l10n.seatSelectionLockedNote,
            style: AppTypography.mono.copyWith(
              fontSize: 11,
              color: semantic.textDisabled,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}

/// Shown when the countdown reaches zero and the server released the seats.
class _HoldExpiredView extends StatelessWidget {
  const _HoldExpiredView({required this.onRestart});

  final Future<void> Function() onRestart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.timer_off_outlined,
              size: 48,
              color: context.semantic.warning,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.seatHoldExpiredTitle,
              style: context.textStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.seatHoldExpiredMessage,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onRestart,
              child: Text(l10n.seatChooseAgain),
            ),
          ],
        ),
      ),
    );
  }
}
