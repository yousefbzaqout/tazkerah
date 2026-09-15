import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../app/router/routes.dart';
import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../../core/extensions/build_context_x.dart';
import '../../../core/providers/core_providers.dart';
import '../../../core/widgets/app_dialog.dart';
import '../../../core/widgets/app_error_view.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../../core/widgets/app_status_pill.dart';
import '../../../core/widgets/brand_emblem.dart';
import '../domain/checkout_order.dart';
import '../domain/checkout_state.dart';
import 'controllers/checkout_controller.dart';
import 'controllers/seat_selection_controller.dart';
import 'widgets/hold_expired_view.dart';
import 'widgets/order_summary.dart';
import 'widgets/payment_window_bar.dart';

/// Checkout: review the order and pay before the window closes.
///
/// Both designed frames live here. They are the two ends of one short-lived
/// state — a payment window that is either open or has closed — and the
/// transition between them happens on a timer rather than a navigation, so
/// they must share a screen.
class CheckoutScreen extends ConsumerWidget {
  const CheckoutScreen({super.key, required this.holdReference, this.eventId});

  /// The hold being paid for.
  final String holdReference;

  /// Where "select seats again" and "return to event" lead. Absent on a cold
  /// deep link, in which case those actions fall back to the feed.
  final String? eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = checkoutControllerProvider(holdReference);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(isExpired: state is CheckoutExpired),
            Expanded(
              child: switch (state) {
                CheckoutLoading() => const AppLoadingIndicator(),
                CheckoutReview() => _ReviewBody(
                  state: state,
                  onPay: () => _pay(context, ref, controller),
                  onCancel: () => _confirmCancel(context, ref, controller),
                ),
                CheckoutExpired(:final order, :final policyCode) =>
                  HoldExpiredView(
                    order: order,
                    policyCode: policyCode,
                    onSelectAgain: () => _selectAgain(context, ref),
                    onReturnToEvent: () => _returnToEvent(context),
                  ),
                // A hold that was already gone gets the released frame rather
                // than a retry button nobody can satisfy.
                CheckoutError(:final failure, :final isHoldGone) =>
                  isHoldGone
                      ? _HoldGoneView(
                          onSelectAgain: () => _selectAgain(context, ref),
                        )
                      : AppErrorView(
                          failure: failure,
                          onRetry: controller.load,
                        ),
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pay(
    BuildContext context,
    WidgetRef ref,
    CheckoutController controller,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final opener = ref.read(urlOpenerProvider);

    final url = await controller.pay();
    if (!context.mounted) return;

    if (url == null) {
      // Either the window closed — in which case the screen has already moved
      // to the expired frame — or the handoff failed and the window is still
      // running. Only the latter needs saying.
      final state = ProviderScope.containerOf(
        context,
      ).read(checkoutControllerProvider(holdReference));
      if (state is CheckoutReview) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.checkoutPaymentUnavailable)),
        );
      }
      return;
    }

    // Hand off to the hosted gateway. If the platform cannot open it — no
    // browser, a malformed URL — say so and stay put rather than advancing to
    // a confirmation screen for a payment that was never started.
    final opened = await opener.open(Uri.parse(url));
    if (!context.mounted) return;

    if (!opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.checkoutPaymentUnavailable)),
      );
      return;
    }

    messenger.showSnackBar(SnackBar(content: Text(l10n.checkoutGatewayOpens)));
    // Where the user lands on returning from a real gateway. It waits for a
    // ticket the backend actually issued rather than assuming the charge
    // succeeded.
    context.go(AppRoutes.orderConfirmationPath(holdReference));
  }

  Future<void> _confirmCancel(
    BuildContext context,
    WidgetRef ref,
    CheckoutController controller,
  ) async {
    final l10n = context.l10n;

    // Confirmed rather than immediate: releasing seats is irreversible in
    // practice — someone else may take them within seconds — and the button
    // sits directly under the one the user actually came here to press.
    final confirmed = await showAppDialog<bool>(
      context: context,
      builder: (dialogContext) => AppConfirmDialog(
        title: l10n.checkoutCancelTitle,
        message: l10n.checkoutCancelMessage,
        confirmLabel: l10n.checkoutCancelConfirm,
        cancelLabel: l10n.checkoutKeepHold,
        // The dialog's own docs name this case: failed tone for a destructive
        // choice such as cancelling a held reservation.
        tone: AppStatusTone.failed,
        icon: Icons.event_busy_outlined,
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await controller.cancelHold();
    if (!context.mounted) return;
    _selectAgain(context, ref);
  }

  /// Sends the user back to the seat map for a fresh attempt.
  ///
  /// Invalidates the seat selection controller first. Coming from a released
  /// hold, the controller for this event is usually still alive and sitting in
  /// [SeatSelectionPhase.expired] or holding seats the server has taken back;
  /// it is auto-disposed, but `go` can mount the seat screen before the old
  /// route lets go, in which case the new screen re-attaches to that stale
  /// state and shows an expired map the user cannot book from. Invalidating
  /// makes the reload unconditional instead of dependent on teardown order.
  void _selectAgain(BuildContext context, WidgetRef ref) {
    final id = eventId;
    if (id == null) {
      context.goNamed(AppRoutes.eventsName);
      return;
    }
    ref.invalidate(seatSelectionControllerProvider(id));
    context.go(AppRoutes.eventSeatsPath(id));
  }

  void _returnToEvent(BuildContext context) {
    final id = eventId;
    if (id == null) {
      context.goNamed(AppRoutes.eventsName);
      return;
    }
    context.go(AppRoutes.eventDetailPath(id));
  }
}

/// The top bar. Its right side reports the session state, which is the one
/// thing that differs between the two frames.
class _Header extends StatelessWidget {
  const _Header({required this.isExpired});

  final bool isExpired;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final semantic = context.semantic;

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
        children: [
          if (isExpired) ...[
            const BrandEmblem(size: 26),
            const SizedBox(width: AppSpacing.sm + 2),
            Expanded(
              child: Text(
                l10n.appTitleLatin.toUpperCase(),
                style: AppTypography.monoLabel.copyWith(
                  fontSize: 12,
                  color: context.colors.onSurface,
                ),
              ),
            ),
            AppStatusPill(
              label: l10n.checkoutSessionTimeout,
              tone: AppStatusTone.failed,
            ),
          ] else ...[
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back_ios_new, size: 16),
              tooltip: l10n.detailBack,
            ),
            Expanded(
              child: Text(
                l10n.checkoutTitle,
                style: context.textStyles.titleMedium,
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  l10n.appTitleLatin.toUpperCase(),
                  style: AppTypography.monoLabel.copyWith(
                    fontSize: 10,
                    color: semantic.textTertiary,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs + 2),
                Text(
                  l10n.authBrandNameArabic,
                  style: TextStyle(
                    fontFamily: AppTypography.arabicFamily,
                    fontSize: 11,
                    color: semantic.textTertiary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm - 2),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: semantic.success,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// The review frame: window bar, reservation, breakdown, and the pay action.
class _ReviewBody extends StatelessWidget {
  const _ReviewBody({
    required this.state,
    required this.onPay,
    required this.onCancel,
  });

  final CheckoutReview state;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final order = state.order;
    final gatewayNote = order.gatewayNote;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              PaymentWindowBar(remaining: state.remaining),
              const SizedBox(height: AppSpacing.lg),
              OrderReservationCard(order: order),
              const SizedBox(height: AppSpacing.lg),
              OrderPriceBreakdown(order: order),
              if (gatewayNote != null) ...[
                const SizedBox(height: AppSpacing.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: semantic.textDisabled,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        gatewayNote,
                        style: context.textStyles.bodySmall?.copyWith(
                          fontSize: 11,
                          color: semantic.textDisabled,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        _PayBar(
          order: order,
          isPaying: state.isPaying,
          onPay: onPay,
          onCancel: onCancel,
        ),
      ],
    );
  }
}

/// The pinned pay action and its cancel link.
class _PayBar extends StatelessWidget {
  const _PayBar({
    required this.order,
    required this.isPaying,
    required this.onPay,
    required this.onCancel,
  });

  final CheckoutOrder order;
  final bool isPaying;
  final VoidCallback onPay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toString();
    final amount = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 2,
    ).format(order.totalMinor / 100);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: context.semantic.border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton(
              // Disabled while the handoff runs: a second tap would be a
              // second charge, which is not a recoverable mistake.
              onPressed: isPaying ? null : onPay,
              child: isPaying
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.checkoutPayNow(amount, order.currency),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Transform.flip(
                          flipX:
                              Directionality.of(context) == TextDirection.rtl,
                          child: const Icon(Icons.arrow_forward, size: 16),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: isPaying ? null : onCancel,
              child: Text(l10n.checkoutCancelHold),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown when the hold was already gone before checkout could start.
class _HoldGoneView extends StatelessWidget {
  const _HoldGoneView({required this.onSelectAgain});

  final VoidCallback onSelectAgain;

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
              color: context.colors.error,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.checkoutExpiredTitleAccent,
              style: context.textStyles.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.checkoutExpiredMessage,
              textAlign: TextAlign.center,
              style: context.textStyles.bodyMedium?.copyWith(
                color: context.semantic.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              onPressed: onSelectAgain,
              child: Text(l10n.checkoutSelectSeatsAgain),
            ),
          ],
        ),
      ),
    );
  }
}
