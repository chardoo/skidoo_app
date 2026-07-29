import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/cloudinary_transform.dart';

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
/// caller passes its own [placeholder] — every [SkidooImage] gets a real
/// loading state without having to remember to wire one up each time. Blur
/// backdrops ([isBlurBackground]) skip the spinner: they're tiny (120px),
/// load near-instantly, and a spinner flashing behind a blur layer is just
/// visual noise.
class SkidooImage extends StatelessWidget {
  const SkidooImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.logicalWidth,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 250),
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
  final Duration fadeInDuration;

  /// True for heavily-blurred background copies — caches at 120 px to save
  /// RAM. The blur masks all detail so high resolution adds no visual value.
  final bool isBlurBackground;

  /// Optional color filter applied to the rendered image.
  final ColorFilter? colorFilter;

  /// Screen-reader description. When null the image is treated as decorative
  /// (no semantics node). Set for content images (photos, samples, covers).
  final String? semanticLabel;

  Widget _defaultPlaceholder(BuildContext context, String url) =>
      const SkidooImagePlaceholder(spinner: true);

  int _cacheWidth(BuildContext context, double availableWidth) {
    if (isBlurBackground) return 120;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = logicalWidth ?? availableWidth;
    return (logical * dpr).ceil().clamp(1, 7680); // cap at 8K (future-proof)
  }

  Widget _image(BuildContext context, double availableWidth) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final logical = logicalWidth ?? availableWidth;

    // Cloudinary-optimise the delivery URL: AVIF/WebP, best quality, retina
    // DPR, sized to the display, and gently sharpened. Blur backdrops request
    // a tiny version since the blur destroys all detail anyway.
    final optimisedUrl = isBlurBackground
        ? CloudinaryTransform.image(imageUrl,
            displayWidth: 80, devicePixelRatio: 1.0, sharpen: false)
        : CloudinaryTransform.image(imageUrl,
            displayWidth: logical, devicePixelRatio: dpr);

    final img = CachedNetworkImage(
      imageUrl: optimisedUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: _cacheWidth(context, availableWidth),
      filterQuality: FilterQuality.high,
      fadeInDuration: fadeInDuration,
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
/// every [SkidooImage] should use, whether or not it wants the spinner.
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
class SkidooImagePlaceholder extends StatelessWidget {
  const SkidooImagePlaceholder({
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

  @override
  Widget build(BuildContext context) {
    final ext = alwaysDark
        ? AppThemeExtension.dark
        : (Theme.of(context).extension<AppThemeExtension>() ??
            AppThemeExtension.dark);

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
