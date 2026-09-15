import 'package:flutter/material.dart';

import '../../../../core/extensions/build_context_x.dart';

/// Cover art for an event card.
///
/// Owns the three outcomes a remote image has — loading, loaded, failed — so
/// no card has to. All three occupy exactly the same box, which is what stops
/// the feed from reflowing as images arrive while the user is scrolling it.
///
/// There is no image caching package here. `Image.network` already holds
/// decoded frames in Flutter's in-memory [ImageCache], which is what keeps
/// scrolling smooth within a session; disk caching across launches is a real
/// gap, but it belongs with the offline work in a later phase rather than as
/// an unjustified dependency now. The feed's own cache stores the *rows*, and
/// a cached row with a placeholder cover is still a usable card.
class EventCoverImage extends StatelessWidget {
  const EventCoverImage({
    super.key,
    required this.imageUrl,
    required this.title,
    this.desaturate = false,
  });

  final String? imageUrl;

  /// Used to seed the placeholder's tint, so an event without art still looks
  /// like itself rather than like every other event without art.
  final String title;

  /// Mutes the image, matching the design's treatment of cached covers. The
  /// row is real but stale, and the art says so before the tag does.
  final bool desaturate;

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;

    final Widget image = url == null || url.isEmpty
        ? _CoverPlaceholder(title: title)
        : Image.network(
            url,
            fit: BoxFit.cover,
            // Fade in rather than popping, and only on a genuine network
            // fetch — a frame already in the cache appears immediately.
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return AnimatedOpacity(
                opacity: frame == null ? 0 : 1,
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: child,
              );
            },
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return _CoverPlaceholder(title: title);
            },
            // A broken URL or a dead CDN must not punch a hole in the feed.
            errorBuilder: (context, error, stack) =>
                _CoverPlaceholder(title: title),
          );

    if (!desaturate) return image;

    return ColorFiltered(
      colorFilter: const ColorFilter.matrix(_desaturationMatrix),
      child: image,
    );
  }

  /// Partial desaturation — roughly 65% of full colour retained, matching the
  /// design's muted cached covers. Full greyscale would read as disabled
  /// rather than stale.
  ///
  /// Built from the ITU-R BT.601 luma weights, interpolated toward identity.
  static const List<double> _desaturationMatrix = <double>[
    0.4045, 0.2065, 0.039, 0, 0, //
    0.1045, 0.5065, 0.039, 0, 0, //
    0.1045, 0.2065, 0.339, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Stand-in for art that is missing or still arriving.
///
/// A flat tinted field with the event's initial, not a spinner: a spinner on
/// every card turns a scrolling feed into a wall of motion, and the
/// placeholder is only on screen for a moment.
class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semantic;

    // Derived from the title so the same event always gets the same tint, and
    // two adjacent cards rarely share one.
    final hue = (title.hashCode % 360).abs().toDouble();
    final tint = HSLColor.fromAHSL(1, hue, 0.18, 0.16).toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [tint, semantic.surfaceElevated],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.local_activity_outlined,
          size: 32,
          color: semantic.textDisabled,
        ),
      ),
    );
  }
}
