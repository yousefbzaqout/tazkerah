import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/build_context_x.dart';
import '../domain/sign_in_flow_state.dart';
import 'auth_screen.dart';
import 'controllers/sign_in_controller.dart';
import 'otp_screen.dart';

/// Hosts the two sign-in steps behind a single route.
///
/// The steps share one controller and one identifier, and step two is
/// meaningless without step one — making them separate routes would let a
/// deep link land on code entry with nothing to verify against. Keeping them
/// under `/login` means the back gesture returns to the identifier field
/// rather than leaving the flow.
class SignInFlow extends ConsumerWidget {
  const SignInFlow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(signInControllerProvider);
    final controller = ref.read(signInControllerProvider.notifier);

    return PopScope(
      // Intercept back on step two so it returns to the identifier rather
      // than popping the whole flow.
      canPop: state.step == SignInStep.identifier,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) controller.editIdentifier();
      },
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        child: switch (state.step) {
          SignInStep.identifier => AuthScreen(
            key: const ValueKey('identifier'),
            isSubmitting: state.isSubmitting,
            errorText: _message(context, state.failure),
            onSubmit: controller.submitIdentifier,
          ),
          SignInStep.code => OtpScreen(
            key: const ValueKey('code'),
            identifier: state.identifier ?? '',
            isSubmitting: state.isSubmitting,
            errorText: _message(context, state.failure),
            onVerify: controller.submitCode,
            onResend: controller.resendCode,
            onEditIdentifier: controller.editIdentifier,
          ),
        },
      ),
    );
  }

  /// Maps a failure reason to its localized message.
  ///
  /// Lives in presentation because wording is a UI concern; the controller
  /// only decides which reason applies.
  String? _message(BuildContext context, SignInFailure? failure) {
    if (failure == null) return null;
    final l10n = context.l10n;

    return switch (failure) {
      SignInFailure.invalidCode => l10n.otpInvalid,
      SignInFailure.expiredCode => l10n.otpExpired,
      SignInFailure.tooManyAttempts => l10n.otpTooManyAttempts,
      SignInFailure.invalidIdentifier => l10n.authIdentifierInvalid,
      SignInFailure.network => l10n.errorNetwork,
      SignInFailure.unknown => l10n.errorUnexpected,
    };
  }
}
