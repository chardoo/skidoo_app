import 'dart:math' as math;

/// Rewrites Cloudinary delivery URLs to request format-optimised, retina-sharp
/// media — the same technique Instagram / TikTok use to make photos and videos
/// look crisp without shipping the raw multi-MB original to every device.
///
/// For non-Cloudinary URLs the original string is returned unchanged, so this
/// is always safe to call.
///
/// Cloudinary URL anatomy:
/// ```
/// https://res.cloudinary.com/<cloud>/<image|video>/upload/<transforms?>/<version?>/<public_id>.<ext>
/// ```
/// We inject our transform chain immediately after `/upload/`. Any pre-existing
/// transforms become a second (chained) step applied after ours, which is
/// harmless for format/quality/dpr/sizing.
class CloudinaryTransform {
  const CloudinaryTransform._();

  static const _marker = '/upload/';

  /// 4K ceiling — never request more pixels than this even on huge displays.
  static const _maxDimension = 3840;

  /// Returns an optimised image URL sized for [displayWidth] logical pixels at
  /// [devicePixelRatio]. Adds automatic format (AVIF/WebP), best perceptual
  /// quality, explicit DPR, a width cap, and a subtle sharpen for "pop".
  static String image(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
    bool sharpen = true,
  }) {
    if (!_isCloudinary(url)) return url;

    final targetW = _targetWidth(displayWidth, devicePixelRatio);
    final dpr = _roundDpr(devicePixelRatio);

    final transforms = <String>[
      'f_auto', // AVIF/WebP when the browser/device supports it
      'q_auto:best', // best perceptual quality
      'c_limit', // never upscale beyond the source
      'w_$targetW', // cap width to what the screen actually shows
      'dpr_$dpr', // retina-correct pixel density
      if (sharpen) 'e_sharpen:40', // gentle crispness, Instagram-like
    ].join(',');

    return _inject(url, transforms);
  }

  /// Returns an optimised video URL: automatic container/codec, best quality,
  /// and a width cap so 4K sources stream at the display's real resolution.
  static String video(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
  }) {
    if (!_isCloudinary(url)) return url;

    final targetW = _targetWidth(displayWidth, devicePixelRatio);

    final transforms = <String>[
      'f_auto', // best container for the platform
      'q_auto:best', // best perceptual quality
      'vc_auto', // modern codec (h265/vp9/av1) when supported
      'c_limit',
      'w_$targetW',
    ].join(',');

    return _inject(url, transforms);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static bool _isCloudinary(String url) =>
      url.contains('res.cloudinary.com') && url.contains(_marker);

  static int _targetWidth(double displayWidth, double dpr) {
    final raw = (displayWidth * dpr).ceil();
    // Round up to the nearest 160 px so Cloudinary's CDN cache is shared across
    // similar viewport sizes instead of generating a unique render per pixel.
    final stepped = ((raw / 160).ceil()) * 160;
    return stepped.clamp(160, _maxDimension);
  }

  /// Cloudinary accepts dpr values like 1.0, 2.0, 3.0. Clamp to the supported
  /// range and round to one decimal so the CDN cache key stays stable.
  static String _roundDpr(double dpr) {
    final clamped = dpr.clamp(1.0, 3.0);
    return (math.min(clamped, 3.0)).toStringAsFixed(1);
  }

  static String _inject(String url, String transforms) {
    final idx = url.indexOf(_marker);
    if (idx == -1) return url;
    final head = url.substring(0, idx + _marker.length);
    final tail = url.substring(idx + _marker.length);

    // Guard against double-injection if this URL was already optimised by us.
    if (tail.startsWith('f_auto')) return url;

    return '$head$transforms/$tail';
  }
}
