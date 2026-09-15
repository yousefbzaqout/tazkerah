import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/ticket/seat_chip.dart';
import '../../domain/seat.dart';

/// The hall: a stage marker, a legend, and one panel per sector.
///
/// Scrolls as a whole rather than per sector, so the stage stays at the top of
/// the content and the spatial relationship between sectors survives — the map
/// is a picture of a room, and paging it sector by sector would lose that.
class SeatMap extends StatelessWidget {
  const SeatMap({
    super.key,
    required this.sectors,
    required this.selectedSeatId,
    required this.interactive,
    this.onSeatTap,
    this.stageLabel,
  });

  final List<Sector> sectors;
  final String? selectedSeatId;

  /// False during a hold, when the design locks the map.
  final bool interactive;

  final ValueChanged<String>? onSeatTap;

  /// Overrides the stage caption: `STAGE / MAIN PODIUM`.
  final String? stageLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StageMarker(label: stageLabel ?? context.l10n.seatStage),
        const SizedBox(height: AppSpacing.lg),
        for (final sector in sectors) ...[
          SectorPanel(
            sector: sector,
            selectedSeatId: selectedSeatId,
            interactive: interactive,
            onSeatTap: onSeatTap,
          ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ],
    );
  }
}

/// The emerald arc and caption standing in for the stage.
class _StageMarker extends StatelessWidget {
  const _StageMarker({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    return Column(
      children: [
        // A tapering line rather than a solid bar: it reads as the far edge of
        // a room instead of as a UI divider.
        Container(
          height: 3,
          width: 180,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: LinearGradient(
              colors: [
                semantic.success.withValues(alpha: 0),
                semantic.success,
                semantic.success.withValues(alpha: 0),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          label,
          textAlign: TextAlign.center,
          style: AppTypography.monoEyebrow.copyWith(
            color: semantic.textTertiary,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

/// One sector: its header, its grid, and any state tag it carries.
class SectorPanel extends StatelessWidget {
  const SectorPanel({
    super.key,
    required this.sector,
    required this.selectedSeatId,
    required this.interactive,
    this.onSeatTap,
  });

  final Sector sector;
  final String? selectedSeatId;
  final bool interactive;
  final ValueChanged<String>? onSeatTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;
    final holdsSelection = sector.seats.any((s) => s.status == SeatStatus.held);

    // A context-only sector is scenery: dimmed, inert, and labelled as such,
    // so the user can place the bookable seats in the room without being
    // invited to tap something that will never respond.
    final opacity = sector.isContextOnly ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md + 2),
        decoration: BoxDecoration(
          color: sector.isContextOnly
              ? Colors.transparent
              : context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: holdsSelection
                ? semantic.success.withValues(alpha: 0.5)
                : semantic.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectorHeader(sector: sector, holdsSelection: holdsSelection),
            const SizedBox(height: AppSpacing.md),
            // The grid scrolls as one block rather than row by row. A hall row
            // can hold more seats than a phone is wide, and scrolling each row
            // on its own offset would let the columns drift out of line —
            // which, on a picture of a room, is worse than not fitting.
            // Shrinking the chips instead would push seat numbers below
            // legibility and tap targets below what a finger can hit.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final row in sector.rows) ...[
                    _SeatRowStrip(
                      row: row,
                      selectedSeatId: selectedSeatId,
                      interactive: interactive && !sector.isContextOnly,
                      onSeatTap: onSeatTap,
                      // Row letters bracket the strip on both sides in the
                      // design, which helps the eye track across a wide row.
                      showTrailingLabel: !sector.isContextOnly,
                    ),
                    if (row != sector.rows.last)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            ),
            if (sector.isContextOnly) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.seatUnavailableInTier,
                style: AppTypography.monoLabel.copyWith(
                  fontSize: 9,
                  color: semantic.textDisabled,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A sector's name, tier, and status tag.
class _SectorHeader extends StatelessWidget {
  const _SectorHeader({required this.sector, required this.holdsSelection});

  final Sector sector;
  final bool holdsSelection;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final l10n = context.l10n;

    return Row(
      children: [
        if (!sector.isContextOnly) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: sector.isLocked ? semantic.warning : semantic.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
        ],
        Expanded(
          child: Text(
            '${sector.name} (${sector.tierLabel})',
            style: AppTypography.monoLabel.copyWith(
              fontSize: 11,
              color: sector.isContextOnly
                  ? semantic.textDisabled
                  : context.colors.onSurface,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (holdsSelection)
          _SectorTag(label: l10n.seatLockedToOrder, color: semantic.success),
      ],
    );
  }
}

/// The small tag on a sector header.
class _SectorTag extends StatelessWidget {
  const _SectorTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs + 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(AppRadius.sm - 2),
      ),
      child: Text(
        label,
        style: AppTypography.monoLabel.copyWith(fontSize: 9, color: color),
      ),
    );
  }
}

/// One row: its label, its seats, and its label again.
class _SeatRowStrip extends StatelessWidget {
  const _SeatRowStrip({
    required this.row,
    required this.selectedSeatId,
    required this.interactive,
    required this.showTrailingLabel,
    this.onSeatTap,
  });

  final SeatRow row;
  final String? selectedSeatId;
  final bool interactive;
  final bool showTrailingLabel;
  final ValueChanged<String>? onSeatTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    final label = SizedBox(
      width: 18,
      child: Text(
        row.label,
        textAlign: TextAlign.center,
        // Row letters are machine identifiers: LTR in every locale, so the
        // map reads the same way regardless of the interface language.
        textDirection: TextDirection.ltr,
        style: AppTypography.monoLabel.copyWith(
          fontSize: 10,
          color: semantic.textDisabled,
        ),
      ),
    );

    // Sized to its seats rather than filling the width: this sits inside a
    // horizontal scroll view, where the available width is unbounded and an
    // `Expanded` child would assert.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        label,
        for (final seat in row.seats)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _SeatCell(
              seat: seat,
              isSelected: seat.id == selectedSeatId,
              interactive: interactive,
              onTap: onSeatTap,
            ),
          ),
        if (showTrailingLabel) label,
      ],
    );
  }
}

/// One seat, plus the `TAKEN` tag the design pins over a lost one.
class _SeatCell extends StatelessWidget {
  const _SeatCell({
    required this.seat,
    required this.isSelected,
    required this.interactive,
    this.onTap,
  });

  final Seat seat;
  final bool isSelected;
  final bool interactive;
  final ValueChanged<String>? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    // Reuses the shared seat chip rather than restyling seats here, so the
    // seat map and any later ticket view cannot disagree about what "held"
    // looks like.
    final chip = SeatChip(
      label: seat.number,
      state: switch (seat.status) {
        SeatStatus.available => SeatState.available,
        SeatStatus.held => SeatState.held,
        SeatStatus.sold => SeatState.sold,
        SeatStatus.conflict => SeatState.conflict,
        SeatStatus.unavailableInTier => SeatState.unavailable,
      },
      onTap: interactive && seat.isSelectable && onTap != null
          ? () => onTap!(seat.id)
          : null,
    );

    final cell = isSelected
        ? Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              border: Border.all(color: semantic.success, width: 2),
            ),
            padding: const EdgeInsets.all(1),
            child: chip,
          )
        : chip;

    if (seat.status != SeatStatus.conflict) return cell;

    // The conflict tag sits above the seat and must not push the row taller,
    // so it is drawn outside the layout as an overflowing stack child.
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        cell,
        Positioned(
          top: -16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: context.colors.error,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              context.l10n.seatTakenTag,
              style: AppTypography.monoLabel.copyWith(
                fontSize: 8,
                color: context.colors.onError,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The legend above the map.
class SeatLegend extends StatelessWidget {
  const SeatLegend({super.key, required this.entries});

  final List<SeatLegendEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: [
        for (final entry in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: entry.filled ? entry.color : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: entry.color),
                ),
              ),
              const SizedBox(width: AppSpacing.sm - 2),
              Text(
                entry.label,
                style: AppTypography.mono.copyWith(
                  fontSize: 11,
                  color: entry.emphasised
                      ? entry.color
                      : context.semantic.textSecondary,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// One legend entry.
class SeatLegendEntry {
  const SeatLegendEntry({
    required this.label,
    required this.color,
    this.filled = false,
    this.emphasised = false,
  });

  final String label;
  final Color color;

  /// Whether the swatch is solid or outlined.
  final bool filled;

  /// Colours the text too, as the design does for the conflict entry.
  final bool emphasised;
}
