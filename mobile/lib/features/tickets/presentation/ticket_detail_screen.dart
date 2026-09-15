import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../domain/ticket.dart';
import 'controllers/ticket_detail_controller.dart';

/// A single ticket, and the entry point to its rotating gate pass.
///
/// The pass itself is a separate screen because it is a different mode: full
/// brightness, no tab bar, a rotating credential. This screen is the calm
/// record of what was bought; that one is the thing held under a scanner.
class TicketDetailScreen extends ConsumerWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = ticketDetailControllerProvider(ticketId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTitle)),
      body: switch (state) {
        TicketDetailLoading() => const AppLoadingIndicator(),
        TicketDetailFailed(:final failure, :final isMissing) =>
          isMissing
              ? AppEmptyView(
                  title: l10n.ticketMissingTitle,
                  message: l10n.ticketMissingMessage,
                  icon: Icons.confirmation_number_outlined,
                  action: FilledButton(
                    onPressed: () => context.goNamed(AppRoutes.ticketsName),
                    child: Text(l10n.walletTitle),
                  ),
                )
              : AppErrorView(failure: failure, onRetry: controller.load),
        TicketDetailReady(:final ticket) => _TicketBody(ticket: ticket),
      },
    );
  }
}

/// The loaded ticket.
class _TicketBody extends StatelessWidget {
  const _TicketBody({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final locale = Localizations.localeOf(context).toString();
    final purchasedAt = ticket.purchasedAt;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.ticketOrderReference(ticket.orderReference),
                      style: AppTypography.monoLabel.copyWith(
                        fontSize: 10,
                        color: semantic.textTertiary,
                      ),
                    ),
                  ),
                  AppStatusPill(
                    label: switch (ticket.status) {
                      TicketStatus.valid => l10n.walletStatusValid,
                      TicketStatus.used => l10n.walletStatusUsed,
                      TicketStatus.refunded => l10n.walletStatusRefunded,
                      TicketStatus.expired => l10n.walletStatusExpired,
                    },
                    tone: ticket.canPresent
                        ? AppStatusTone.live
                        : AppStatusTone.neutral,
                    showDot: ticket.canPresent,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(ticket.eventTitle, style: context.textStyles.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(
                ticket.venueName,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _DetailPanel(ticket: ticket, locale: locale),
              if (purchasedAt != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.ticketPurchasedOn(
                    DateFormat.yMMMd(locale).format(purchasedAt),
                  ),
                  style: context.textStyles.bodySmall?.copyWith(
                    color: semantic.textDisabled,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextButton(
                onPressed: () =>
                    context.go(AppRoutes.eventDetailPath(ticket.eventId)),
                child: Text(l10n.ticketViewEvent),
              ),
            ],
          ),
        ),
        _PresentBar(ticket: ticket),
      ],
    );
  }
}

/// The date, seat, zone, gate and price block.
class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.ticket, required this.locale});

  final Ticket ticket;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;
    final money = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    );
    final entrance = ticket.entranceLabel;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: semantic.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Field(
            label: l10n.detailDateTimeLabel,
            value: DateFormat.yMMMEd(
              locale,
            ).add_Hm().format(ticket.localStartsAt),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _Field(
                  label: l10n.ticketSeatLabel,
                  value: ticket.seatLabel,
                  mono: true,
                  valueColor: semantic.success,
                ),
              ),
              Expanded(
                child: _Field(
                  label: l10n.ticketZoneLabel,
                  value: ticket.zoneLabel,
                  mono: true,
                ),
              ),
              if (entrance != null)
                Expanded(
                  child: _Field(
                    label: l10n.ticketGateLabel,
                    value: entrance,
                    mono: true,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: l10n.ticketPaidLabel,
            value:
                '${money.format(ticket.totalMinor / 100)} ${ticket.currency}',
            mono: true,
          ),
        ],
      ),
    );
  }
}

/// One label/value pair.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.value,
    this.mono = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool mono;
  final Color? valueColor;

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
            fontSize: 9,
            color: semantic.textTertiary,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          // Machine values keep their own direction in any locale.
          textDirection: mono ? TextDirection.ltr : null,
          style: mono
              ? AppTypography.monoValue.copyWith(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                )
              : context.textStyles.titleSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// The action that opens the gate pass — or explains why it cannot.
class _PresentBar extends StatelessWidget {
  const _PresentBar({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: semantic.border)),
      ),
      child: SafeArea(
        top: false,
        child: ticket.canPresent
            ? FilledButton(
                onPressed: () =>
                    context.push(AppRoutes.ticketPassPath(ticket.id)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.qr_code_2, size: 18),
                    const SizedBox(width: AppSpacing.sm),
                    Text(l10n.ticketPresentAction),
                  ],
                ),
              )
            // A used or refunded ticket says why rather than offering a
            // disabled button with no explanation.
            : Text(
                l10n.ticketCannotPresent,
                textAlign: TextAlign.center,
                style: context.textStyles.bodySmall?.copyWith(
                  color: semantic.textTertiary,
                ),
              ),
      ),
    );
  }
}
