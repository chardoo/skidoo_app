import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
      placeholder: placeholder,
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
