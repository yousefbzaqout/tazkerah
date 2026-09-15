import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/extensions/build_context_x.dart';
import '../../../../core/widgets/app_status_pill.dart';
import '../../../../core/widgets/ticket/ticket_card.dart';
import '../../domain/ticket.dart';

/// One ticket in the wallet list.
///
/// Uses the shared [TicketCard] shape — the notched outline with its
/// perforation — rather than a plain card. That shape exists for exactly this
/// screen, and it is what makes a row read as a ticket rather than as a list
/// item about a ticket.
class WalletTicketCard extends StatelessWidget {
  const WalletTicketCard({super.key, required this.ticket, this.onTap});

  final Ticket ticket;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final locale = Localizations.localeOf(context).toString();

    final (String statusLabel, AppStatusTone tone) = switch (ticket.status) {
      TicketStatus.valid => (l10n.walletStatusValid, AppStatusTone.live),
      TicketStatus.used => (l10n.walletStatusUsed, AppStatusTone.neutral),
      TicketStatus.refunded => (
        l10n.walletStatusRefunded,
        AppStatusTone.failed,
      ),
      TicketStatus.expired => (l10n.walletStatusExpired, AppStatusTone.neutral),
    };

    // Spent tickets are dimmed rather than hidden: they are the user's
    // receipts, but they must not compete with the ticket they need tonight.
    final isSpent = ticket.status != TicketStatus.valid;

    return Semantics(
      button: onTap != null,
      label:
          '${ticket.eventTitle}, ${ticket.seatLabel}, '
          '${DateFormat.yMMMEd(locale).format(ticket.localStartsAt)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Opacity(
          opacity: isSpent ? 0.55 : 1,
          child: TicketCard(
            accentColor: ticket.status == TicketStatus.valid
                ? semantic.success.withValues(alpha: 0.4)
                : null,
            stubHeight: 64,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        DateFormat.yMMMEd(
                          locale,
                        ).format(ticket.localStartsAt).toUpperCase(),
                        style: AppTypography.monoLabel.copyWith(
                          fontSize: 10,
                          color: semantic.textTertiary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AppStatusPill(
                      label: statusLabel,
                      tone: tone,
                      showDot: ticket.status == TicketStatus.valid,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  ticket.eventTitle,
                  style: context.textStyles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  ticket.venueName,
                  style: context.textStyles.bodySmall?.copyWith(
                    color: semantic.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            stub: Row(
              children: [
                _StubField(
                  label: l10n.ticketSeatLabel,
                  value: ticket.seatLabel,
                ),
                const SizedBox(width: AppSpacing.xl),
                _StubField(
                  label: l10n.ticketZoneLabel,
                  value: ticket.zoneLabel,
                ),
                const Spacer(),
                if (ticket.canPresent)
                  Icon(Icons.qr_code_2, size: 26, color: semantic.success),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One label/value pair on the ticket stub.
class _StubField extends StatelessWidget {
  const _StubField({required this.label, required this.value});

  final String label;
  final String value;

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
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          // Seat and zone references are machine values: LTR in any locale.
          textDirection: TextDirection.ltr,
          style: AppTypography.monoValue.copyWith(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
