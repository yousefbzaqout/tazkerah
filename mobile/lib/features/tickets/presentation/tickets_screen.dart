import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/widgets/app_empty_view.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../domain/wallet_state.dart';
import 'controllers/wallet_controller.dart';
import 'widgets/wallet_ticket_card.dart';

/// The ticket wallet: everything the user has bought.
///
/// Split into upcoming and past rather than one list, because the two are read
/// for different reasons — one is "what do I need tonight", the other "what did
/// I pay for". A single chronological list buries the first under the second.
class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(walletControllerProvider);
    final controller = ref.read(walletControllerProvider.notifier);
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.walletTitle)),
      body: switch (state) {
        WalletLoading() => const AppLoadingIndicator(),
        WalletError(:final failure) => AppErrorView(
          failure: failure,
          onRetry: controller.load,
        ),
        WalletReady() when state.isEmpty => AppEmptyView(
          title: l10n.walletEmptyTitle,
          message: l10n.walletEmptyMessage,
          icon: Icons.confirmation_number_outlined,
          action: FilledButton(
            onPressed: () => context.goNamed(AppRoutes.eventsName),
            child: Text(l10n.walletBrowseEvents),
          ),
        ),
        WalletReady() => RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (state.upcoming.isNotEmpty) ...[
                _SectionHeading(label: l10n.walletUpcoming),
                for (final ticket in state.upcoming) ...[
                  WalletTicketCard(
                    ticket: ticket,
                    onTap: () =>
                        context.go(AppRoutes.ticketDetailPath(ticket.id)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
              if (state.past.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                _SectionHeading(label: l10n.walletPast),
                for (final ticket in state.past) ...[
                  WalletTicketCard(
                    ticket: ticket,
                    onTap: () =>
                        context.go(AppRoutes.ticketDetailPath(ticket.id)),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            ],
          ),
        ),
      },
    );
  }
}

/// One uppercase mono section label.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Text(
        label,
        style: AppTypography.monoEyebrow.copyWith(
          color: context.semantic.textTertiary,
        ),
      ),
    );
  }
}
