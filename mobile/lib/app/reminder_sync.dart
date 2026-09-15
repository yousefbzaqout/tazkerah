import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/core_providers.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/notifications/presentation/reminder_providers.dart';
import '../features/tickets/domain/wallet_state.dart';
import '../features/tickets/presentation/controllers/wallet_controller.dart';

/// Keeps scheduled reminders in step with the wallet and the session.
///
/// Mounted once, high in the tree, rather than on the wallet screen: the OS
/// drops pending notifications on reboot and reinstall, so a reconcile has to
/// happen when the app runs — not only when the user visits a particular tab.
///
/// It watches wallet state rather than polling. Every path that changes
/// tickets already flows through [walletControllerProvider] — a purchase, a
/// refund, a scan at the gate — so there is nothing extra to hook.
///
/// **It lives in `app/`, not in `features/notifications/`, because it is the
/// wiring between three features.** `features/*` may never import another
/// feature; the composition root is the one place allowed to know that
/// reminders, the wallet and auth exist together.
class ReminderSync extends ConsumerStatefulWidget {
  const ReminderSync({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<ReminderSync> createState() => _ReminderSyncState();
}

class _ReminderSyncState extends ConsumerState<ReminderSync> {
  /// The ticket set last synced, so an unrelated wallet rebuild — a refresh
  /// spinner, a reordering — does not re-run the reconcile.
  String? _lastSignature;

  /// Whether permission has been asked for this session.
  ///
  /// The request happens when the wallet first holds a ticket, not at launch:
  /// a prompt shown before the user has anything to be reminded about is the
  /// reliable way to earn a permanent refusal.
  bool _asked = false;

  /// The auth controller being listened to, so the listener can be detached.
  AuthController? _auth;

  @override
  void initState() {
    super.initState();
    final auth = ref.read(authControllerProvider);
    auth.addListener(_onAuthChanged);
    _auth = auth;
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// Clears reminders when the session ends.
  ///
  /// Reminders name events the signed-out user was attending, so leaving them
  /// on a handed-over or sold device would leak that after the credentials
  /// themselves are gone.
  void _onAuthChanged() {
    if (_auth?.isAuthenticated ?? false) return;

    _lastSignature = null;
    _asked = false;
    unawaited(_cancelAll());
  }

  Future<void> _cancelAll() async {
    try {
      await ref.read(reminderServiceProvider).cancelAll();
    } catch (e, stack) {
      developer.log(
        'Clearing reminders on sign-out failed',
        name: 'notifications',
        error: e,
        stackTrace: stack,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<WalletState>(walletControllerProvider, (previous, next) {
      if (next is! WalletReady) return;
      unawaited(_sync(next));
    });

    return widget.child;
  }

  Future<void> _sync(WalletReady wallet) async {
    // Past tickets are passed too: the planner ignores anything not valid, and
    // the service needs to see them to cancel reminders for a ticket that has
    // just been used or refunded.
    final tickets = [...wallet.upcoming, ...wallet.past];

    final signature = tickets
        .map((t) => '${t.id}:${t.status.name}:${t.startsAt.toIso8601String()}')
        .join('|');
    if (signature == _lastSignature) return;

    final service = ref.read(reminderServiceProvider);
    final scheduler = ref.read(reminderSchedulerProvider);

    try {
      if (!_asked && tickets.isNotEmpty) {
        _asked = true;
        if (!await scheduler.hasPermission()) {
          await scheduler.requestPermission();
        }
      }

      await service.sync(
        tickets: tickets,
        // The corrected clock, not the device's: a handset set a day fast
        // would otherwise decide every reminder had already passed and
        // schedule none of them.
        now: ref.read(clockProvider).now,
      );

      _lastSignature = signature;
    } catch (e, stack) {
      // Reminders are a convenience layered on the wallet. A scheduler that
      // fails must not take a screen full of working tickets down with it, so
      // this is logged and swallowed; the next wallet change retries.
      developer.log(
        'Reminder sync failed',
        name: 'notifications',
        error: e,
        stackTrace: stack,
      );
    }
  }
}
