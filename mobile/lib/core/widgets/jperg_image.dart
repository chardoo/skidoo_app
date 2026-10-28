import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blurhash/flutter_blurhash.dart';
import 'package:jperg_app/core/cache/jperg_image_cache.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/media_transform.dart';

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
    this.ladder = ImageLadder.none,
    this.blurhash,
  });

  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// What this photo knows about its own pre-sized copies — see [ImageLadder].
  ///
  /// Left at [ImageLadder.none] the original is fetched and bounded on the
  /// device, which is correct but means downloading a camera-sized file to
  /// paint a thumbnail. Pass it wherever the payload carries it.
  final ImageLadder ladder;

  /// The photo's BlurHash, painted by the default placeholder until the image
  /// lands — see [JpergImagePlaceholder]. Ignored when a [placeholder] of the
  /// caller's own is supplied, since that is then what fills the slot.
  final String? blurhash;

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
      JpergImagePlaceholder(spinner: true, blurhash: blurhash);

  /// How wide the decoded frame is kept in memory — and half of the key the
  /// global [ImageCache] files it under, which is why [precache] derives it
  /// from this same function rather than from a number of its own.
  static int _cacheWidthFor({
    required double logical,
    required double dpr,
    required bool isBlurBackground,
  }) {
    if (isBlurBackground) return 120;
    return (logical * dpr).ceil().clamp(1, 7680); // cap at 8K (future-proof)
  }

  int _cacheWidth(BuildContext context, double availableWidth) =>
      _cacheWidthFor(
        logical: logicalWidth ?? availableWidth,
        dpr: MediaQuery.devicePixelRatioOf(context),
        isBlurBackground: isBlurBackground,
      );

  /// The URL actually fetched: Cloudinary-optimised, sized to the slot, and
  /// for a video the still frame at t=0 rather than the clip.
  ///
  /// Null means a video this app cannot derive a poster for — there is nothing
  /// to load, and handing an mp4 to an image decoder can only fail.
  ///
  /// Shared with [precache] on purpose: the width is quantised (see
  /// [MediaTransform]), but two call sites computing it separately is
  /// still how a warmed URL and a requested one drift apart, and a precache
  /// that misses by one character is a wasted download rather than a fast
  /// first frame.
  static String? _deliveryUrl(
    String imageUrl, {
    required double logical,
    required double dpr,
    required bool isBlurBackground,
    required ImageLadder ladder,
  }) {
    // Blur backdrops request a tiny version since the blur destroys all
    // detail anyway; everything else is sized to what the slot displays.
    final requestWidth = isBlurBackground ? 80.0 : logical;
    final requestDpr = isBlurBackground ? 1.0 : dpr;

    if (MediaTransform.isVideoUrl(imageUrl)) {
      // The ladder belongs to the clip, and on R2 its rungs are the poster's —
      // which is what makes a stored still reachable at all. See
      // [MediaTransform.videoPoster].
      return MediaTransform.videoPoster(imageUrl,
          displayWidth: requestWidth,
          devicePixelRatio: requestDpr,
          ladder: ladder);
    }
    // Sized to the slot: the narrowest stored rung that covers it on R2, or an
    // edge render on Cloudinary.
    return MediaTransform.image(imageUrl,
        displayWidth: requestWidth,
        devicePixelRatio: requestDpr,
        ladder: ladder,
        sharpen: !isBlurBackground);
  }

  /// Downloads and decodes [imageUrl] now, so the [JpergImage] that asks for it
  /// later paints on its first frame instead of showing a placeholder.
  ///
  /// For images whose *first* appearance is worth paying for ahead of time:
  /// the top of the feed while the splash is still up, and the card or slide
  /// one swipe away — see `feed_prefetch.dart`, which is where the feed decides
  /// what is close enough to be worth it.
  ///
  /// Still not a general prefetcher. Warm what somebody is about to reach, not
  /// what they might: every warmed image is decoded bytes held in the global
  /// [ImageCache], and warming a whole list evicts the picture being looked at
  /// to make room for ones nobody asked for.
  ///
  /// **Never pass a video URL.** An image loader handed an `.mp4` downloads the
  /// clip in order to fail on it. Use `MediaTransform.videoPoster` for the
  /// still, which is what the feed warms for a video slide.
  ///
  /// The provider is assembled exactly as [CachedNetworkImage] assembles its
  /// own — `CachedNetworkImageProvider` wrapped by [ResizeImage] at
  /// `memCacheWidth`, which is what `octo_image` does with that argument — so
  /// the entry lands in the global [ImageCache] under the key the widget will
  /// look up. Build it any other way and the bytes are on disk but the frame
  /// still decodes on arrival, which is a spinner nobody expected.
  ///
  /// Never throws: a warm-up that fails is a slower first frame, not a fault,
  /// and every caller is on a path where that is the correct trade.
  static Future<void> precache(
    BuildContext context,
    String imageUrl, {
    required double logicalWidth,
    bool isBlurBackground = false,
    ImageLadder ladder = ImageLadder.none,
  }) async {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final url = _deliveryUrl(imageUrl,
        logical: logicalWidth,
        dpr: dpr,
        isBlurBackground: isBlurBackground,
        // Must be the same ladder the widget will pass, or the warmed URL and
        // the requested one are different objects and the warm-up is wasted.
        ladder: ladder);
    if (url == null) return;

    final provider = ResizeImage.resizeIfNeeded(
      _cacheWidthFor(
          logical: logicalWidth, dpr: dpr, isBlurBackground: isBlurBackground),
      null,
      CachedNetworkImageProvider(url, cacheManager: JpergImageCache.instance),
    );

    // `onError` rather than a try/catch: without it a failed load is handed to
    // `FlutterError.onError`, which in debug is a red screen for a photo that
    // was only ever being fetched early.
    await precacheImage(
      provider,
      context,
      onError: (e, _) =>
          debugPrint('[JpergImage] precache failed, going on anyway: $e'),
    );
  }

  Widget _image(BuildContext context, double availableWidth) {
    final optimisedUrl = _deliveryUrl(
      imageUrl,
      logical: logicalWidth ?? availableWidth,
      dpr: MediaQuery.devicePixelRatioOf(context),
      isBlurBackground: isBlurBackground,
      ladder: ladder,
    );
    // A video with no derivable poster has nothing to load — show the empty
    // slot rather than fetch an mp4 into an image decoder.
    if (optimisedUrl == null) return const JpergImagePlaceholder();

    final img = CachedNetworkImage(
      imageUrl: optimisedUrl,
      // One shared cache, sized for a photo app — see [JpergImageCache]. The
      // package default holds 200 files, which a single album scroll overruns,
      // so leaving it unset meant photos were re-downloaded on the way back to
      // a screen the user had just been on. Not on web: there is no filesystem
      // to cache into, and the browser's own HTTP cache does this job.
      cacheManager: JpergImageCache.instance,
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
      placeholder:
          placeholder ?? (isBlurBackground ? null : _defaultPlaceholder),
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
        builder: (context, constraints) => _image(context,
            constraints.maxWidth.isFinite ? constraints.maxWidth : 1080),
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
///
/// Given a [blurhash] it paints the photo's own colours instead of that
/// neutral — the ~28 characters the server stores per photo, decoded on the
/// device with no network at all. That is the difference between a slot that
/// reads as loading and one that reads as the photograph arriving, and it is
/// what makes a fast scroll never show a hole.
class JpergImagePlaceholder extends StatelessWidget {
  const JpergImagePlaceholder({
    super.key,
    this.spinner = false,
    this.alwaysDark = false,
    this.blurhash,
  });

  /// Adds the centred progress ring. Off by default: on a thumbnail-sized
  /// slot a 20 px spinner is noise, and a grid of them flickers.
  final bool spinner;

  /// The photo's BlurHash, when the payload carried one. Null falls back to
  /// the flat neutral, which is what every slot had before.
  final String? blurhash;

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
    final hash = blurhash;

    // The hash paints the photo's own colours, so the spinner is dropped with
    // it: a ring over a recognisable image reads as something being wrong
    // rather than as something arriving.
    if (hash != null && hash.isNotEmpty) {
      return ColoredBox(
        color: ext.searchFieldFill,
        child: BlurHash(
          hash: hash,
          // Already decoded by the time anything else is; a fade would make
          // the stand-in itself look like it was loading.
          duration: Duration.zero,
          // BlurHash's own image/child plumbing is deliberately unused — the
          // real photo is drawn by the JpergImage this is a placeholder for.
          imageFit: BoxFit.cover,
        ),
      );
    }

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

/// A bounded [ImageProvider] for the handful of slots that need a raw provider
/// rather than a widget — `CircleAvatar.backgroundImage` and
/// `DecorationImage`, neither of which accepts a child widget.
///
/// A bare `NetworkImage` decodes whatever the server sent at its full size: a
/// profile photo shot on a phone is 12–48 MP, which is 50–200 MB of RAM once
/// decoded, in a 40 px circle. A list of them is an out-of-memory kill, and
/// that is not hypothetical — it is what took the app down on the campaigns
/// list. This asks for a version sized to the slot and caps the decode with
/// [ResizeImage] so a URL that cannot be resized is bounded too.
///
/// On R2, with no [ladder] passed, it currently *is* only bounded rather than
/// resized: `User.profile_url` records no dimensions, and without the source
/// width there is no way to tell which rungs of its ladder were rendered — so
/// asking for one risks a 404 on every avatar in a list. The decode stays
/// capped either way; the download does not. Giving the avatar its own stored
/// dimensions is what would fix it.
///
/// Prefer [UserAvatar] where a widget will do; this is for the slots where one
/// won't.
ImageProvider boundedNetworkImage(
  BuildContext context,
  String url, {
  required double diameter,
  ImageLadder ladder = ImageLadder.none,
}) {
  final dpr = MediaQuery.devicePixelRatioOf(context);
  final optimised = MediaTransform.image(url,
      displayWidth: diameter, devicePixelRatio: dpr, ladder: ladder);
  return ResizeImage(
    NetworkImage(optimised),
    width: (diameter * dpr).ceil().clamp(1, 4096),
    policy: ResizeImagePolicy.fit,
  );
}
