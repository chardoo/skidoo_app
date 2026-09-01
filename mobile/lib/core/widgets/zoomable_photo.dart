import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// Pinch-, wheel- and double-tap zoom around [child], for a photo being looked
/// at in full.
///
/// Every full-screen viewer in the app pages through photos, so this reports
/// its zoom state up rather than keeping it private: a [PageView] and a zoomed
/// [InteractiveViewer] both want the horizontal drag, and the page wins — a
/// magnified photo could be pulled off the screen sideways but never panned
/// across. The host takes [onZoomChanged] and freezes its pager while it is
/// true, which is what makes the zoom usable rather than merely present.
///
/// Zoom is reset when [resetToken] changes (a recycled page now showing a
/// different photo) and when [isActive] goes false (a page swiped away from),
/// so a photo is never opened already magnified and off-centre.
class ZoomableArea extends StatefulWidget {
  const ZoomableArea({
    super.key,
    required this.child,
    this.maxScale = 4.0,
    this.doubleTapScale = 2.5,
    this.onTap,
    this.onZoomChanged,
    this.isActive = true,
    this.resetToken,
  });

  final Widget child;

  final double maxScale;

  /// Where a double-tap lands, when there is one. See [onTap].
  final double doubleTapScale;

  /// Usually the viewer's "toggle the overlays" handler.
  ///
  /// Giving one costs the double-tap: registering both recognizers makes every
  /// single tap wait out the double-tap timeout before firing, and that tap is
  /// how those viewers show and hide their chrome. Pinch and wheel still zoom.
  final VoidCallback? onTap;

  /// Fires with true as the photo leaves 1×, and false as it returns.
  final ValueChanged<bool>? onZoomChanged;

  /// False for the off-screen neighbours in a viewer's pager.
  final bool isActive;

  /// Identifies the photo on show — the id or the URL. A change means this
  /// slot has been recycled onto a different one.
  final Object? resetToken;

  @override
  State<ZoomableArea> createState() => _ZoomableAreaState();
}

class _ZoomableAreaState extends State<ZoomableArea>
    with SingleTickerProviderStateMixin {
  final TransformationController _transform = TransformationController();
  late final AnimationController _anim;
  Animation<Matrix4>? _zoomAnim;
  Offset _doubleTapPos = Offset.zero;

  /// The last state handed to [ZoomableArea.onZoomChanged] — the host hears
  /// about crossings, not about every frame of a pinch.
  bool _zoomed = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final anim = _zoomAnim;
        if (anim != null) _transform.value = anim.value;
      });
    _transform.addListener(_reportZoom);
  }

  @override
  void didUpdateWidget(ZoomableArea old) {
    super.didUpdateWidget(old);
    if (old.resetToken != widget.resetToken ||
        (old.isActive && !widget.isActive)) {
      _resetZoom();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    _transform.dispose();
    super.dispose();
  }

  /// Slightly above 1 so the float left behind by a pinch that ended almost
  /// back at rest doesn't read as still zoomed and keep the pager frozen.
  bool get _isZoomed => _transform.value.getMaxScaleOnAxis() > 1.05;

  void _resetZoom() {
    if (_transform.value.isIdentity()) return;
    _anim.stop();
    _transform.value = Matrix4.identity();
  }

  void _reportZoom() {
    final zoomed = _isZoomed;
    if (zoomed == _zoomed) return;
    _zoomed = zoomed;

    final onZoomChanged = widget.onZoomChanged;
    if (onZoomChanged == null) return;

    // A reset runs from didUpdateWidget — mid-build — and the host's handler
    // is a setState on the pager above us. Hand it to the end of the frame
    // there rather than marking an ancestor that is already building.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) onZoomChanged(zoomed);
      });
    } else {
      onZoomChanged(zoomed);
    }
  }

  void _animateZoomTo(Matrix4 target) {
    _zoomAnim = Matrix4Tween(begin: _transform.value, end: target)
        .animate(CurvedAnimation(parent: _anim, curve: Curves.easeOut));
    _anim.forward(from: 0);
  }

  /// Zoom in on the point that was tapped, or back out to the whole frame.
  ///
  /// The tap position is in the content's coordinates rather than the
  /// viewport's, which are the same thing at rest — and rest is the only state
  /// this zooms in from, since a zoomed photo goes back to the whole frame.
  void _handleDoubleTap() {
    if (_isZoomed) {
      _animateZoomTo(Matrix4.identity());
      return;
    }
    final scale = widget.doubleTapScale;
    _animateZoomTo(Matrix4.identity()
      ..translateByDouble(-_doubleTapPos.dx * (scale - 1),
          -_doubleTapPos.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, scale, 1));
  }

  @override
  Widget build(BuildContext context) {
    final doubleTap = widget.onTap == null;

    return InteractiveViewer(
      transformationController: _transform,
      minScale: 1.0,
      maxScale: widget.maxScale,
      // Inside the viewer, not around it. The viewer's own scale recognizer
      // beats an ancestor's double-tap in the gesture arena — the taps simply
      // never arrive — while a descendant's wins, because the arena sweep
      // favours the deepest entry in the hit-test.
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTapDown:
            doubleTap ? (d) => _doubleTapPos = d.localPosition : null,
        onDoubleTap: doubleTap ? _handleDoubleTap : null,
        child: widget.child,
      ),
    );
  }
}

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
class ZoomablePhoto extends StatelessWidget {
  const ZoomablePhoto({
    super.key,
    required this.imageUrl,
    this.knownAspect,
    this.semanticLabel,
    this.onTap,
    this.onZoomChanged,
    this.isActive = true,
    this.maxScale = 4.0,
    this.errorWidget,
  });

  final String imageUrl;

  /// The server's `width`/`height` as a ratio. Null for legacy records.
  final double? knownAspect;

  final String? semanticLabel;

  /// Usually the viewer's "toggle the overlays" handler — see
  /// [ZoomableArea.onTap] for what it costs.
  final VoidCallback? onTap;

  /// Freeze the pager on true, or a zoomed photo pages away instead of
  /// panning. See [ZoomableArea].
  final ValueChanged<bool>? onZoomChanged;

  /// False for the off-screen neighbours in a viewer's pager.
  final bool isActive;

  final double maxScale;

  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  @override
  Widget build(BuildContext context) {
    return ResolvedAspect(
      imageUrl: imageUrl,
      knownAspect: knownAspect,
      builder: (context, aspect) => ZoomableArea(
        onTap: onTap,
        onZoomChanged: onZoomChanged,
        isActive: isActive,
        maxScale: maxScale,
        resetToken: imageUrl,
        child: Center(
          child: AspectRatio(
            aspectRatio: aspect,
            child: JpergImage(
              imageUrl: imageUrl,
              // Identical to `cover` once the box is the photo's own shape,
              // which is the steady state. It differs only in the moment
              // before an unmeasured photo resolves, and there `contain`
              // shows the whole frame rather than cropping into it.
              fit: BoxFit.contain,
              semanticLabel: semanticLabel,
              placeholder: (_, __) =>
                  const JpergImagePlaceholder(spinner: true, alwaysDark: true),
              errorWidget: errorWidget ??
                  (_, __, ___) => const JpergImagePlaceholder(
                      spinner: false, alwaysDark: true),
            ),
          ),
        ),
      ),
    );
  }
}
