import 'package:flutter/material.dart';

/// Reserves the space a photo or video will occupy *before* it loads, from the
/// `width`/`height` the API sends with every media record.
///
/// Without it a masonry tile has no height until the image decodes, so it is
/// laid out at whatever its placeholder happens to be and then snaps to its
/// real size — re-flowing the column, and every column after it, while the
/// user is scrolling. The dimensions are already on the wire; this is just
/// spending them.
///
/// Falls back to intrinsic sizing (or [fallbackHeight] when given) for legacy
/// records the server has no dimensions for, which is exactly the old
/// behaviour rather than a guess.
class PhotoAspectBox extends StatelessWidget {
  const PhotoAspectBox({
    super.key,
    required this.aspectRatio,
    required this.child,
    this.fallbackHeight,
  });

  /// Width ÷ height. Null when the record carries no dimensions.
  final double? aspectRatio;

  /// Used only when [aspectRatio] is unavailable. Null lets the child size
  /// itself.
  final double? fallbackHeight;

  final Widget child;

  /// A grid tile has to stay a grid tile: a 1:4 panorama or a 4:1 tower would
  /// otherwise take a whole screen on its own. Beyond these the media is
  /// cropped to fit (every call site uses `BoxFit.cover`), which is the right
  /// trade for a thumbnail.
  static const _minAspect = 0.5; // tallest — 1:2
  static const _maxAspect = 2.0; // widest — 2:1

  @override
  Widget build(BuildContext context) {
    final ar = aspectRatio;
    if (ar != null && ar > 0) {
      return AspectRatio(
        aspectRatio: ar.clamp(_minAspect, _maxAspect),
        child: child,
      );
    }
    if (fallbackHeight != null) {
      return SizedBox(height: fallbackHeight, child: child);
    }
    return child;
  }
}
