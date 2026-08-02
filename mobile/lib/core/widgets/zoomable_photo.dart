import 'package:flutter/material.dart';
import 'package:skidoo_app/core/widgets/image_aspect.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';

/// One page of a full-screen photo viewer: the photo at its own shape, pinch
/// to zoom.
///
/// The point of boxing it to [knownAspect] rather than handing a screen-sized
/// slot to `BoxFit.contain` is that the box is then the *photo*, not the
/// screen, before a single byte has arrived:
///
///  * the loading state sits in the photo's footprint instead of as a spinner
///    marooned in the middle of a black screen, so nothing jumps when the
///    image lands — it fades in exactly where its placeholder was;
///  * panning a zoomed photo is bounded by the image, so a landscape shot
///    can't be dragged off into the letterbox bars;
///  * the surround is a deliberate letterbox rather than whatever the image
///    failed to cover.
///
/// Records with no dimensions still work: [ResolvedAspect] measures the
/// decoded image and rebuilds once with its real shape.
class ZoomablePhoto extends StatefulWidget {
  const ZoomablePhoto({
    super.key,
    required this.imageUrl,
    this.knownAspect,
    this.semanticLabel,
    this.onTap,
    this.maxScale = 4.0,
    this.errorWidget,
  });

  final String imageUrl;

  /// The server's `width`/`height` as a ratio. Null for legacy records.
  final double? knownAspect;

  final String? semanticLabel;

  /// Usually the viewer's "toggle the overlays" handler.
  final VoidCallback? onTap;

  final double maxScale;

  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  @override
  State<ZoomablePhoto> createState() => _ZoomablePhotoState();
}

class _ZoomablePhotoState extends State<ZoomablePhoto> {
  final TransformationController _transform = TransformationController();

  @override
  void didUpdateWidget(ZoomablePhoto old) {
    super.didUpdateWidget(old);
    // A recycled page showing a different photo must not inherit the last
    // one's zoom, or the new image opens already magnified and off-centre.
    if (old.imageUrl != widget.imageUrl) _transform.value = Matrix4.identity();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResolvedAspect(
      imageUrl: widget.imageUrl,
      knownAspect: widget.knownAspect,
      // Deliberately tap-only: adding a double-tap recognizer here would make
      // every single tap wait out the double-tap timeout before firing, and
      // that tap is how the viewers show and hide their overlays.
      builder: (context, aspect) => GestureDetector(
        onTap: widget.onTap,
        child: InteractiveViewer(
          transformationController: _transform,
          minScale: 1.0,
          maxScale: widget.maxScale,
          child: Center(
            child: AspectRatio(
              aspectRatio: aspect,
              child: SkidooImage(
                imageUrl: widget.imageUrl,
                // Identical to `cover` once the box is the photo's own shape,
                // which is the steady state. It differs only in the moment
                // before an unmeasured photo resolves, and there `contain`
                // shows the whole frame rather than cropping into it.
                fit: BoxFit.contain,
                semanticLabel: widget.semanticLabel,
                placeholder: (_, __) =>
                    const SkidooImagePlaceholder(spinner: true, alwaysDark: true),
                errorWidget: widget.errorWidget ??
                    (_, __, ___) => const SkidooImagePlaceholder(
                        spinner: false, alwaysDark: true),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
