import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../domain/ticket.dart';
import 'controllers/order_confirmation_controller.dart';
import 'widgets/wallet_ticket_card.dart';

/// What the user sees after returning from the payment gateway.
///
/// It waits for a ticket the backend has actually issued rather than declaring
/// success on arrival. The app has no authority over whether a charge settled
/// — it was handed off to a hosted gateway — so the only honest confirmation
/// is the ticket itself.
class OrderConfirmationScreen extends ConsumerWidget {
  const OrderConfirmationScreen({super.key, required this.orderReference});

  final String orderReference;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(
      orderConfirmationControllerProvider(orderReference),
    );

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: switch (state) {
            OrderSettling() => const _SettlingView(),
            OrderConfirmed(:final ticket) => _ConfirmedView(ticket: ticket),
            OrderConfirmationFailed() => const _PendingView(),
          },
        ),
      ),
    );
  }
}

/// Shown while the gateway settles.
class _SettlingView extends StatelessWidget {
  const _SettlingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: AppSpacing.xl),
          Text(
            l10n.confirmationSettlingTitle,
            style: context.textStyles.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.confirmationSettlingMessage,
            textAlign: TextAlign.center,
            style: context.textStyles.bodyMedium?.copyWith(
              color: context.semantic.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ticket was issued.
class _ConfirmedView extends StatelessWidget {
  const _ConfirmedView({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: semantic.successContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: semantic.success.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 36,
                    color: semantic.success,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Center(
                child: AppStatusPill(
                  label: l10n.walletStatusValid,
                  tone: AppStatusTone.live,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                l10n.confirmationTitle,
                textAlign: TextAlign.center,
                style: context.textStyles.headlineSmall,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.confirmationMessage,
                textAlign: TextAlign.center,
                style: context.textStyles.bodyMedium?.copyWith(
                  color: semantic.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              // The ticket itself, in the same shape the wallet uses — so what
              // was just bought is recognisable when it is found again later.
              WalletTicketCard(ticket: ticket),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
        FilledButton(
          onPressed: () => context.go(AppRoutes.ticketDetailPath(ticket.id)),
          child: Text(l10n.confirmationViewTicket),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          onPressed: () => context.goNamed(AppRoutes.ticketsName),
          child: Text(l10n.confirmationGoToWallet),
        ),
      ],
    );
  }
}

/// Settlement took longer than the polling window.
///
/// Deliberately not an error: the payment may well have succeeded, and telling
/// someone it failed when their card was charged is the worst thing this
/// screen could do. It says what is known, and points at the wallet.
class _PendingView extends StatelessWidget {
  const _PendingView();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 48, color: semantic.warning),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.confirmationPendingTitle,
                  textAlign: TextAlign.center,
                  style: context.textStyles.titleLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  l10n.confirmationPendingMessage,
                  textAlign: TextAlign.center,
                  style: context.textStyles.bodyMedium?.copyWith(
                    color: semantic.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
        FilledButton(
          onPressed: () => context.goNamed(AppRoutes.ticketsName),
          child: Text(l10n.confirmationGoToWallet),
        ),
      ],
    );
  }
}
