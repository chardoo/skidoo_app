import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:jperg_app/core/cache/jperg_image_cache.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/cloudinary_transform.dart';

/// High-quality drop-in for [CachedNetworkImage].
///
/// Computes `memCacheWidth` from the actual layout width × device pixel
/// ratio so images are cached at physical-pixel resolution and never
/// blurry-downsampled on retina / high-DPI screens.
///
/// Pass [isBlurBackground] = true for heavily-blurred backdrop layers — they
/// intentionally decode at 120 px to save RAM, since blur hides all detail.
///
/// If [logicalWidth] is supplied the cache is sized to that value × DPR.
/// Otherwise a [LayoutBuilder] measures the actual available width at build
/// time, which is the safest default.
///
/// Shows a centred spinner over a subtle tint while loading unless the
/// caller passes its own [placeholder] — every [JpergImage] gets a real
/// loading state without having to remember to wire one up each time. Blur
/// backdrops ([isBlurBackground]) skip the spinner: they're tiny (120px),
/// load near-instantly, and a spinner flashing behind a blur layer is just
/// visual noise.
///
/// Handed a **video** URL — which happens all over the app, since a grid,
/// carousel or list tile gets one `url` per item and only sometimes knows
/// whether it's a clip — it renders the video's poster frame instead of
/// failing. Without this every video in a thumbnail grid was a broken-image
/// icon, because the image loader was being asked to decode an mp4. Videos we
/// can't derive a poster for (non-Cloudinary hosts) get the neutral
/// placeholder slot, never the error icon: nothing is broken, there's just no
/// still to show.
///
/// When [imageUrl] changes on a widget that stays mounted the old image holds
/// its place and the new one cross-fades in over it, rather than the slot
/// blanking to a placeholder and cutting to the replacement — see
/// [swapDuration].
class JpergImage extends StatelessWidget {
  const JpergImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.logicalWidth,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 250),
    this.swapDuration = const Duration(milliseconds: 300),
    this.isBlurBackground = false,
    this.colorFilter,
    this.semanticLabel,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Logical display width used to derive the physical-pixel cache width.
  /// When null the widget measures its own layout constraints.
  final double? logicalWidth;

  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;

  /// How long the arriving image takes to fade up over whatever it replaces —
  /// the placeholder on a first load, the previous photo on a swap.
  final Duration fadeInDuration;

  /// How long the *outgoing* half of a swap takes to dissolve away, and the
  /// switch that enables swapping at all.
  ///
  /// While non-zero, an [imageUrl] change under a mounted widget keeps the old
  /// image on screen as the new one's placeholder: the slot never blanks to a
  /// spinner mid-swap and never holds an empty frame waiting on the network,
  /// so the two photos cross-dissolve. That is what makes a carousel, a
  /// filmstrip, or a grid tile recycled onto another photo read as one surface
  /// changing contents rather than as unrelated images being cut between.
  ///
  /// Slightly longer than [fadeInDuration] so the outgoing image is still
  /// faintly there as the incoming one lands, which is what reads as a
  /// dissolve rather than as a cut with a soft edge. [Duration.zero] opts out
  /// and restores the hard cut.
  final Duration swapDuration;

  /// True for heavily-blurred background copies — caches at 120 px to save
  /// RAM. The blur masks all detail so high resolution adds no visual value.
  final bool isBlurBackground;

  /// Optional color filter applied to the rendered image.
  final ColorFilter? colorFilter;

  /// Screen-reader description. When null the image is treated as decorative
  /// (no semantics node). Set for content images (photos, samples, covers).
  final String? semanticLabel;

  Widget _defaultPlaceholder(BuildContext context, String url) =>
      const JpergImagePlaceholder(spinner: true);

  int _cacheWidth(BuildContext context, double availableWidth) {
    if (isBlurBackground) return 120;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = logicalWidth ?? availableWidth;
    return (logical * dpr).ceil().clamp(1, 7680); // cap at 8K (future-proof)
  }

  Widget _image(BuildContext context, double availableWidth) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = logicalWidth ?? availableWidth;

    // Blur backdrops request a tiny version since the blur destroys all
    // detail anyway; everything else is sized to what the slot displays.
    final requestWidth = isBlurBackground ? 80.0 : logical;
    final requestDpr = isBlurBackground ? 1.0 : dpr;

    final String optimisedUrl;
    if (CloudinaryTransform.isVideoUrl(imageUrl)) {
      final poster = CloudinaryTransform.videoPoster(imageUrl,
          displayWidth: requestWidth, devicePixelRatio: requestDpr);
      // A video with no derivable poster has nothing to load — show the empty
      // slot rather than fetch an mp4 into an image decoder.
      if (poster == null) return const JpergImagePlaceholder();
      optimisedUrl = poster;
    } else {
      // Cloudinary-optimise the delivery URL: AVIF/WebP, best quality, retina
      // DPR, sized to the display, and gently sharpened.
      optimisedUrl = CloudinaryTransform.image(imageUrl,
          displayWidth: requestWidth,
          devicePixelRatio: requestDpr,
          sharpen: !isBlurBackground);
    }

    final img = CachedNetworkImage(
      imageUrl: optimisedUrl,
      // One shared cache, sized for a photo app — see [JpergImageCache]. The
      // package default holds 200 files, which a single album scroll overruns,
      // so leaving it unset meant photos were re-downloaded on the way back to
      // a screen the user had just been on. Not on web: there is no filesystem
      // to cache into, and the browser's own HTTP cache does this job.
      cacheManager: kIsWeb ? null : JpergImageCache.instance,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: _cacheWidth(context, availableWidth),
      filterQuality: FilterQuality.high,
      fadeInDuration: fadeInDuration,
      // The swap: on a url change the outgoing image is installed as the new
      // one's placeholder, so it stays visible until its replacement has
      // decoded and then dissolves into it. Without this the widget falls back
      // to `placeholder` — a blank slot or a spinner between two photos.
      useOldImageOnUrlChange: swapDuration > Duration.zero,
      fadeOutDuration: swapDuration,
      fadeOutCurve: Curves.easeOut,
      fadeInCurve: Curves.easeIn,
      placeholder: placeholder ?? (isBlurBackground ? null : _defaultPlaceholder),
      errorWidget: errorWidget,
    );
    if (colorFilter != null) {
      return ColorFiltered(colorFilter: colorFilter!, child: img);
    }
    return img;
  }

  @override
  Widget build(BuildContext context) {
    final Widget result;
    if (logicalWidth != null) {
      result = _image(context, logicalWidth!);
    } else {
      result = LayoutBuilder(
        builder: (context, constraints) =>
            _image(context, constraints.maxWidth.isFinite ? constraints.maxWidth : 1080),
      );
    }
    if (semanticLabel == null) return result;
    return Semantics(image: true, label: semanticLabel, child: result);
  }
}

/// The fill shown in an image slot before the image arrives — and the one
/// every [JpergImage] should use, whether or not it wants the spinner.
///
/// Call sites used to hardcode a near-black each (#111111, #141414, #1A1A1A,
/// `Colors.black`, and a literal #2C2C2A that was really the dark theme's
/// surface token copied by hand). Two things were wrong with that. In light
/// mode a loading grid punched black holes in an otherwise light page. In dark
/// mode the fills were *darker* than the surfaces around them, so a screen
/// mid-load read as a checkerboard of black squares rather than as a page
/// waiting for content — the surround is #111110, so a #111111 tile is
/// invisible and a `Colors.black` one is a hole.
///
/// [searchFieldFill] is the same neutral the search field and filter chips
/// use: clearly a slot, in both themes, without competing with real content.
class JpergImagePlaceholder extends StatelessWidget {
  const JpergImagePlaceholder({
    super.key,
    this.spinner = false,
    this.alwaysDark = false,
  });

  /// Adds the centred progress ring. Off by default: on a thumbnail-sized
  /// slot a 20 px spinner is noise, and a grid of them flickers.
  final bool spinner;

  /// Pins to the dark palette for surfaces that stay dark in either app theme
  /// — the full-screen photo viewers. Without it those flash a light tile in
  /// light mode, which is the same bug in the other direction.
  final bool alwaysDark;

  /// The same fill as a bare colour, for slots that must stay a [Container]
  /// because they carry a fixed height or an error icon.
  static Color colorOf(BuildContext context, {bool alwaysDark = false}) =>
      _paletteOf(context, alwaysDark).searchFieldFill;

  static AppThemeExtension _paletteOf(BuildContext context, bool alwaysDark) =>
      alwaysDark
          ? AppThemeExtension.dark
          : (Theme.of(context).extension<AppThemeExtension>() ??
              AppThemeExtension.dark);

  @override
  Widget build(BuildContext context) {
    final ext = _paletteOf(context, alwaysDark);

    return ColoredBox(
      color: ext.searchFieldFill,
      child: spinner
          ? Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: ext.accentGold.withValues(alpha: 0.8),
                ),
              ),
            )
          : null,
    );
  }
}
