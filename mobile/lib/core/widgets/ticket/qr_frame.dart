import 'package:flutter/material.dart';

import '../../../app/theme/app_spacing.dart';
import '../../../app/theme/app_typography.dart';
import '../../extensions/build_context_x.dart';

/// What the gate pass is currently showing.
enum QrPassState {
  /// A valid rotating code is on screen.
  active,

  /// Withheld after a screenshot, or while the clock is out of sync. The
  /// payload is deliberately not rendered.
  suppressed,

  /// Expired or revoked.
  invalid,
}

/// The white QR card and the ring that counts down its rotation.
///
/// The card stays white in a dark app on purpose: a scanner needs dark modules
/// on a light field, so [AppSemanticColors.qrCanvas] is fixed rather than
/// themed.
///
/// This is presentation only. It renders whatever [qr] it is handed and knows
/// nothing about how a code is produced — generating one is the ticket
/// feature's job, and the payload must never be built inside a widget.
class QrFrame extends StatelessWidget {
  const QrFrame({
    super.key,
    required this.qr,
    this.state = QrPassState.active,
    this.progress,
    this.header,
    this.footer,
    this.suppressedLabel,
    this.suppressedHash,
    this.size = 236,
  });

  /// The rendered QR, supplied by the caller.
  final Widget qr;

  final QrPassState state;

  /// Rotation progress from 0 to 1, driving the ring. Null hides the ring.
  final double? progress;

  /// Small mono line inside the card's top edge: `TAZKERAH` / `ZONE 1`.
  final Widget? header;

  /// Small mono line inside the card's bottom edge: `DYNAMIC PASS` / hash.
  final Widget? footer;

  /// Shown in place of the code when [state] is not active.
  final String? suppressedLabel;

  /// Truncated payload hash shown under [suppressedLabel]. Must be a hash —
  /// never the payload itself.
  final String? suppressedHash;

  final double size;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    final Color accent = switch (state) {
      QrPassState.active => semantic.success,
      QrPassState.suppressed => semantic.warning,
      QrPassState.invalid => context.colors.error,
    };

    return SizedBox(
      width: size + AppSpacing.xxl,
      height: size + AppSpacing.xxl,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The ring sits behind the card and reads as a countdown.
          Positioned.fill(
            child: CustomPaint(
              painter: _RingPainter(
                color: accent,
                progress: progress,
                trackColor: accent.withValues(alpha: 0.18),
              ),
            ),
          ),
          _PassCard(
            size: size,
            accent: accent,
            state: state,
            qr: qr,
            header: header,
            footer: footer,
            suppressedLabel: suppressedLabel,
            suppressedHash: suppressedHash,
          ),
        ],
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({
    required this.size,
    required this.accent,
    required this.state,
    required this.qr,
    required this.header,
    required this.footer,
    required this.suppressedLabel,
    required this.suppressedHash,
  });

  final double size;
  final Color accent;
  final QrPassState state;
  final Widget qr;
  final Widget? header;
  final Widget? footer;
  final String? suppressedLabel;
  final String? suppressedHash;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;
    final isActive = state == QrPassState.active;

    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        // Suppressed passes drop the white field entirely — there is no code
        // to scan, and a white card would invite someone to try.
        color: isActive
            ? semantic.qrCanvas
            : context.colors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: isActive
            ? null
            : Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          if (header != null)
            DefaultTextStyle.merge(
              style: AppTypography.monoLabel.copyWith(
                color: isActive ? semantic.qrInk : semantic.textTertiary,
              ),
              child: header!,
            ),
          Expanded(
            child: Center(
              child: isActive
                  ? qr
                  : _SuppressedPayload(
                      accent: accent,
                      label: suppressedLabel,
                      hash: suppressedHash,
                    ),
            ),
          ),
          if (footer != null)
            DefaultTextStyle.merge(
              style: AppTypography.monoLabel.copyWith(
                color: isActive ? semantic.qrInk : semantic.textTertiary,
              ),
              child: footer!,
            ),
        ],
      ),
    );
  }
}

/// Stands in for the code when the pass is withheld.
class _SuppressedPayload extends StatelessWidget {
  const _SuppressedPayload({
    required this.accent,
    required this.label,
    required this.hash,
  });

  final Color accent;
  final String? label;
  final String? hash;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    final hash = this.hash;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.visibility_off_outlined, color: accent, size: 22),
        ),
        if (label != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.monoLabel.copyWith(color: accent),
          ),
        ],
        if (hash != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            hash,
            textAlign: TextAlign.center,
            // Always LTR: a hash is a machine value, and bidi reordering
            // would misrepresent it in an Arabic layout.
            textDirection: TextDirection.ltr,
            style: AppTypography.mono.copyWith(
              color: context.semantic.textTertiary,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

/// Draws the countdown ring around the pass.
class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.trackColor,
    this.progress,
  });

  final Color color;
  final Color trackColor;
  final double? progress;

  @override
  void paint(Canvas canvas, Size size) {
    final progress = this.progress;
    if (progress == null) return;

    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - 2,
    );

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = trackColor;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = color;

    canvas.drawCircle(rect.center, rect.width / 2, track);
    canvas.drawArc(
      rect,
      -1.5708, // start at twelve o'clock
      6.2832 * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
