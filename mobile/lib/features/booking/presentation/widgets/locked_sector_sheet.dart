import 'package:flutter/material.dart';

import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/app_sheet.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../domain/seat.dart';

/// The 423 overlay: this sector is withheld by the organizer.
///
/// Built on [AppSheetContent], which exists for exactly this frame — status
/// pill, title, message, a recessed detail table, and stacked actions. Using
/// it rather than a bespoke layout means the next error sheet in the flow
/// looks the same without anyone re-deciding how.
///
/// It offers alternatives rather than just reporting the lock. A user who
/// wanted seats has not stopped wanting seats because one sector is
/// unavailable, and an overlay that only says "no" makes them find their own
/// way back.
Future<void> showLockedSectorSheet(
  BuildContext context, {
  required Sector sector,
  required List<Sector> alternatives,
  VoidCallback? onChooseAnother,
  VoidCallback? onViewAvailableOnly,
}) {
  return showAppSheet<void>(
    context: context,
    builder: (sheetContext) {
      final l10n = sheetContext.l10n;
      final semantic = sheetContext.semantic;

      return AppSheetContent(
        statusLabel: l10n.seatLockedStatus,
        statusTone: AppStatusTone.degraded,
        icon: Icons.lock_outline,
        title: l10n.seatLockedTitle,
        message: l10n.seatLockedMessage('${sector.name} ${sector.tierLabel}'),
        details: [
          AppSheetDetail(label: l10n.seatLockedTargetLabel, value: sector.name),
          AppSheetDetail(
            label: l10n.seatLockedReasonLabel,
            // The reason code is a backend identifier, printed as given.
            value: sector.lockReason == null
                ? '—'
                : 'Organizer Hold (${sector.lockReason})',
            valueColor: semantic.warning,
          ),
          AppSheetDetail(
            label: l10n.seatLockedAlternativesLabel,
            value: alternatives.isEmpty
                ? '—'
                : alternatives.map((s) => s.name).join(' · '),
            valueColor: alternatives.isEmpty ? null : semantic.success,
          ),
        ],
        primaryAction: FilledButton(
          onPressed: alternatives.isEmpty
              ? null
              : () {
                  Navigator.of(sheetContext).pop();
                  onChooseAnother?.call();
                },
          style: FilledButton.styleFrom(
            backgroundColor: semantic.warning,
            foregroundColor: sheetContext.colors.onPrimary,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.seatChooseAnotherSector),
              const SizedBox(width: 8),
              Transform.flip(
                flipX: Directionality.of(sheetContext) == TextDirection.rtl,
                child: const Icon(Icons.arrow_forward, size: 16),
              ),
            ],
          ),
        ),
        secondaryAction: OutlinedButton(
          onPressed: () {
            Navigator.of(sheetContext).pop();
            onViewAvailableOnly?.call();
          },
          child: Text(l10n.seatViewAvailableOnly),
        ),
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}
