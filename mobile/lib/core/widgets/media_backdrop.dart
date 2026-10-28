import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/media_transform.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';

/// Fills a full-bleed slot with the media's own colours, so a photo that does
/// not match the screen's shape never sits in empty bands.
///
/// The media is drawn twice: once blown up to cover the whole slot and blurred
/// past recognition, and once — by the caller, as [child] — at its true size
/// and aspect ratio on top. Nothing about the real image changes; only what is
/// behind it.
///
/// ## The blur waits for the photo
///
/// The backdrop is only ever scenery *around* a photo, so until there is a
/// photo there is nothing for it to surround — and it is held back until the
/// one in [child] has actually arrived.
///
/// It did not used to be, and the cost was the whole screen. The backdrop is a
/// copy at 80 px; the photo is a rung, or, for a row the ladder backfill has
/// not reached, a camera original of several megabytes. The small one always
/// won, so opening an album showed a full screen of blur that resolved seconds
/// later. Worse, it only did so the *first* time: tap the same photo again and
/// the cached image painted on the first frame, so nobody could reproduce it
/// on the device they were holding.
///
/// Waiting means watching the very provider [child] draws from — see
/// [JpergImage.providerFor]. Resolving a URL of this widget's own would be a
/// second object with its own load arriving at its own time, which is the
/// failure restated rather than fixed. So a caller whose child passes a
/// [ladder] or a [maxPhysicalWidth] must pass the same ones here; anything
/// else is a different rung, and waiting on the wrong file.
///
/// Until then the slot is [AppThemeExtension.mediaBackdropVeil] alone — the
/// same ground the backdrop is knocked back to, so the reveal is the blur
/// fading up rather than the screen changing colour underneath it.
///
/// A video [url] works without any extra handling: [JpergImage] derives a
/// poster frame from it, so the backdrop is a still and there is never a
/// second decoder running for something nobody can make out anyway. There is
/// nothing to wait for in that case — a clip's first frame is its own
/// placeholder — so the backdrop is shown straight away, as before.
class MediaBackdrop extends StatefulWidget {
  const MediaBackdrop({
    super.key,
    required this.url,
    required this.child,
    this.ladder = ImageLadder.none,
    this.maxPhysicalWidth,
  });

  /// The image or video the backdrop is made from — the same one [child] draws.
  final String url;

  /// The real media, at its own size. Painted over the backdrop.
  final Widget child;

  /// What [child] passes, so the wait is on the file it will actually fetch.
  final ImageLadder ladder;

  /// Likewise — the feed caps itself, and an uncapped guess here would watch a
  /// wider rung than the card ever asks for.
  final int? maxPhysicalWidth;

  /// Enough to leave shape and colour with no legible detail.
  ///
  /// A backdrop that can still be read as a photo competes with the real one
  /// in front of it, which is the failure this is meant to avoid: the bands
  /// should register as the picture's own light, not as a second picture.
  static const double blurSigma = 40;

  /// How long the blur takes to arrive once the photo has.
  ///
  /// Not instant: the bands appearing in the same frame as the photo reads as
  /// the photo having been drawn wrong. Fading them in reads as the picture
  /// settling into its slot.
  static const Duration revealDuration = Duration(milliseconds: 220);

  @override
  State<MediaBackdrop> createState() => _MediaBackdropState();
}

class _MediaBackdropState extends State<MediaBackdrop> {
  /// Sticky once set. A carousel builds one of these per page, so this is the
  /// readiness of *this* slide — and a slide that has shown its photo must not
  /// blank its bands again while the next image cross-dissolves over it.
  bool _revealed = false;

  ImageStream? _stream;
  ImageStreamListener? _listener;

  /// What [_watch] last resolved against, so a rebuild at the same size does
  /// not tear down a listener and start the wait again.
  String? _watchedUrl;
  double? _watchedWidth;

  /// True while [build] is running, so a provider that is already in the cache
  /// — which calls its listener *synchronously* on `addListener` — reveals by
  /// setting the field this build is about to read, rather than by calling
  /// `setState` during a build, which throws.
  bool _building = false;

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    final stream = _stream, listener = _listener;
    if (stream != null && listener != null) stream.removeListener(listener);
    _stream = null;
    _listener = null;
  }

  void _reveal() {
    if (_revealed) return;
    _revealed = true;
    _detach();
    // Mid-build the assignment above is enough; this build has not read it yet.
    if (_building || !mounted) return;
    setState(() {});
  }

  void _watch(BuildContext context, double logicalWidth) {
    if (_revealed) return;

    // A clip has no still to wait for, and handing an mp4 to an image loader
    // downloads the whole thing in order to fail on it.
    if (MediaTransform.isVideoUrl(widget.url)) {
      _reveal();
      return;
    }

    if (_watchedUrl == widget.url && _watchedWidth == logicalWidth) return;
    _watchedUrl = widget.url;
    _watchedWidth = logicalWidth;
    _detach();

    final provider = JpergImage.providerFor(
      context,
      widget.url,
      logicalWidth: logicalWidth,
      ladder: widget.ladder,
      maxPhysicalWidth: widget.maxPhysicalWidth,
    );
    // Nothing loadable. Showing the bands beats leaving the slot flat forever.
    if (provider == null) {
      _reveal();
      return;
    }

    final listener = ImageStreamListener(
      (_, __) => _reveal(),
      // A photo that failed is a slot with nothing in it, and its own colours
      // are better than a flat ground. The child draws its own error state on
      // top either way.
      onError: (_, __) => _reveal(),
    );
    _stream = provider.resolve(createLocalImageConfiguration(context))
      ..addListener(listener);
    _listener = listener;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>() ??
        AppThemeExtension.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        // The child measures its own constraints to size its request, and they
        // are these: both fill the same box. Watching at any other width asks
        // the cache for a different entry than the one being waited on.
        _building = true;
        _watch(context, constraints.maxWidth);
        _building = false;

        return Stack(
          fit: StackFit.expand,
          children: [
            // The blurred copy — and the one thing here that waits. Hidden
            // rather than absent so the veil below keeps painting the same
            // ground either way: revealing the bands is a blur fading up, not
            // the slot changing colour underneath the photo.
            AnimatedOpacity(
              opacity: _revealed ? 1 : 0,
              duration: MediaBackdrop.revealDuration,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(
                  sigmaX: MediaBackdrop.blurSigma,
                  sigmaY: MediaBackdrop.blurSigma,
                ),
                child: JpergImage(
                  imageUrl: widget.url,
                  fit: BoxFit.cover,
                  isBlurBackground: true,
                  // No spinner on either state: the backdrop is scenery, and a
                  // spinner behind the real media's own spinner reads as a
                  // fault.
                  placeholder: (_, __) => const JpergImagePlaceholder(),
                  errorWidget: (_, __, ___) => const JpergImagePlaceholder(),
                ),
              ),
            ),
            // Knocks the backdrop back so it cannot compete with the media in
            // front. Themed, because this fills most of the screen on a card
            // that does not match its shape — a fixed black veil made the
            // whole feed read as dark in light mode.
            ColoredBox(color: ext.mediaBackdropVeil),
            widget.child,
          ],
        );
      },
    );
  }
}
