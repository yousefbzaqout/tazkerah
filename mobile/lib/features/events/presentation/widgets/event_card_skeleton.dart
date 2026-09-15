import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/extensions/build_context_x.dart';
import 'event_card.dart';

/// The placeholder card from the design's skeleton frame.
///
/// Mirrors [EventCard]'s geometry exactly — same aspect ratio, same padding,
/// same row structure — so the feed does not jump when real cards replace
/// these. A skeleton of the wrong height is worse than no skeleton: it
/// promises a layout the content then contradicts.
///
/// The shimmer is driven by one [AnimationController] per card. That is
/// acceptable because at most a screenful exists at once and they are
/// discarded the moment data arrives; a shared ticker would be the right call
/// only if these outlived the load.
class EventCardSkeleton extends StatefulWidget {
  const EventCardSkeleton({super.key, this.titleWidthFactor = 0.55});

  /// Varies the title bar's width between cards, as the design does. A column
  /// of identically-sized grey bars reads as a rendering fault rather than as
  /// loading content.
  final double titleWidthFactor;

  @override
  State<EventCardSkeleton> createState() => _EventCardSkeletonState();
}

class _EventCardSkeletonState extends State<EventCardSkeleton>
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
    final semantic = context.semantic;

    // Hidden from assistive technology entirely. These carry no information —
    // announcing a screenful of empty placeholders would bury the one thing
    // worth saying, which the screen itself announces once via its loading
    // status pill.
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: semantic.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
              child: AspectRatio(
                aspectRatio: EventCard.coverAspectRatio,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: _Shimmer(
                        animation: _controller,
                        child: ColoredBox(
                          color: semantic.surfaceElevated,
                          child: const SizedBox.expand(),
                        ),
                      ),
                    ),
                    // The date chip's ghost, in its designed position.
                    PositionedDirectional(
                      top: AppSpacing.md + 2,
                      start: AppSpacing.md + 2,
                      child: _Bar(
                        animation: _controller,
                        width: 90,
                        height: 22,
                        radius: AppRadius.sm - 2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FractionallySizedBox(
                          widthFactor: widget.titleWidthFactor,
                          child: _Bar(
                            animation: _controller,
                            height: 20,
                            radius: AppSpacing.xs,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md - 2),
                        Row(
                          children: [
                            _Bar(
                              animation: _controller,
                              width: 14,
                              height: 14,
                              radius: 7,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: FractionallySizedBox(
                                widthFactor: 0.45,
                                alignment: AlignmentDirectional.centerStart,
                                child: _Bar(
                                  animation: _controller,
                                  height: 12,
                                  radius: AppSpacing.xs,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _Bar(
                        animation: _controller,
                        width: 32,
                        height: 10,
                        radius: AppSpacing.xs,
                      ),
                      const SizedBox(height: AppSpacing.sm - 2),
                      _Bar(
                        animation: _controller,
                        width: 64,
                        height: 20,
                        radius: AppSpacing.xs,
                      ),
                    ],
                  ),
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

  /// Null stretches to the parent's width — used where a
  /// [FractionallySizedBox] above sets the proportion instead.
  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return _Shimmer(
      animation: animation,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: context.semantic.surfaceElevated,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Pulses its child's opacity.
///
/// A pulse rather than a travelling gradient sweep: the sweep needs a shader
/// repainted every frame per element, and at a screenful of bars that is
/// measurable work for an effect the user sees for under a second.
class _Shimmer extends StatelessWidget {
  const _Shimmer({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Respects the OS "reduce motion" setting: a looping pulse is exactly the
    // kind of animation that setting exists to stop.
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
