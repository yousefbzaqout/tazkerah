import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/extensions/build_context_x.dart';
import 'event_detail_hero.dart';

/// Placeholder shown while one event loads.
///
/// Mirrors the loaded screen's geometry — same hero height, same gutters, same
/// stacked blocks — so the page does not jump when content replaces it.
///
/// Hidden from assistive technology: these bars carry no information, and
/// reading a screenful of empty boxes aloud is worse than silence.
class EventDetailSkeleton extends StatefulWidget {
  const EventDetailSkeleton({super.key});

  @override
  State<EventDetailSkeleton> createState() => _EventDetailSkeletonState();
}

class _EventDetailSkeletonState extends State<EventDetailSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final heroHeight =
        MediaQuery.sizeOf(context).height * EventDetailHero.heightFactor;

    return ExcludeSemantics(
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Bar(animation: _controller, height: heroHeight, radius: 0),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bar(
                    animation: _controller,
                    width: 150,
                    height: 22,
                    radius: AppRadius.sm,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _Bar(animation: _controller, height: 28, radius: 6),
                  const SizedBox(height: AppSpacing.sm),
                  FractionallySizedBox(
                    widthFactor: 0.6,
                    child: _Bar(animation: _controller, height: 28, radius: 6),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Row(
                    children: [
                      Expanded(
                        child: _Bar(
                          animation: _controller,
                          height: 92,
                          radius: AppRadius.md,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _Bar(
                          animation: _controller,
                          height: 92,
                          radius: AppRadius.md,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  for (final width in [1.0, 0.95, 0.98, 0.7]) ...[
                    FractionallySizedBox(
                      widthFactor: width,
                      alignment: AlignmentDirectional.centerStart,
                      child: _Bar(
                        animation: _controller,
                        height: 14,
                        radius: AppSpacing.xs,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One grey placeholder bar.
class _Bar extends StatelessWidget {
  const _Bar({
    required this.animation,
    this.width,
    required this.height,
    required this.radius,
  });

  final Animation<double> animation;
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.semantic.surfaceElevated,
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    // Respects the OS "reduce motion" setting — a looping pulse is exactly
    // what that setting exists to stop.
    if (MediaQuery.disableAnimationsOf(context)) {
      return Opacity(opacity: 0.6, child: child);
    }

    return FadeTransition(
      opacity: animation.drive(
        Tween<double>(
          begin: 0.4,
          end: 0.85,
        ).chain(CurveTween(curve: Curves.easeInOut)),
      ),
      child: child,
    );
  }
}
