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

  /// Cloudinary serves videos under a `video` resource type. The segment is
  /// what tells a video delivery URL apart from an image one, and it's also
  /// what makes a poster frame derivable — see [videoPoster].
  static const _videoMarker = '/video/upload/';

  /// 4K ceiling — never request more pixels than this even on huge displays.
  static const _maxDimension = 3840;

  static const _videoExtensions = [
    '.mp4',
    '.mov',
    '.webm',
    '.m4v',
    '.avi',
    '.mkv',
    '.3gp',
  ];

  /// True when [url] points at a video rather than a still — a Cloudinary
  /// video delivery URL, or any URL whose path ends in a video extension.
  ///
  /// Callers that only have a URL (no `media_type` alongside it) use this to
  /// avoid handing a video to an image loader, which can only ever fail.
  static bool isVideoUrl(String url) {
    final lower = url.toLowerCase();
    if (lower.contains(_videoMarker)) return true;
    final path = lower.split('?').first;
    return _videoExtensions.any(path.endsWith);
  }

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

  /// Returns a still frame of a Cloudinary video, sized like [image] would
  /// size a photo — the poster a thumbnail slot shows in place of the video.
  ///
  /// Cloudinary renders one by asking for the video asset with a still
  /// extension: `…/video/upload/so_0/<public_id>.jpg` is the frame at second
  /// zero. Nothing has to be uploaded or stored for it.
  ///
  /// Null when no poster can be derived (a non-Cloudinary video, e.g. a bare
  /// `.mp4` on someone else's host). Callers should show a neutral slot rather
  /// than send the video URL to an image loader.
  static String? videoPoster(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
  }) {
    if (!_isCloudinary(url) || !url.contains(_videoMarker)) return null;

    final targetW = _targetWidth(displayWidth, devicePixelRatio);
    final dpr = _roundDpr(devicePixelRatio);

    final transforms = <String>[
      'so_0', // frame at t=0 — the video's own first frame
      'q_auto:good',
      'c_limit',
      'w_$targetW',
      'dpr_$dpr',
    ].join(',');

    // The extension picks the delivery format, so it has to become a still
    // one; `f_auto` is deliberately left off, since on a video resource it
    // would hand back a video container again.
    return _inject(_withJpgExtension(url), transforms);
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

  /// Swaps the URL's file extension for `.jpg`, leaving any query string in
  /// place. A URL with no extension gets one appended.
  static String _withJpgExtension(String url) {
    final queryAt = url.indexOf('?');
    final path = queryAt == -1 ? url : url.substring(0, queryAt);
    final query = queryAt == -1 ? '' : url.substring(queryAt);

    final lastSlash = path.lastIndexOf('/');
    final lastDot = path.lastIndexOf('.');
    final base = lastDot > lastSlash ? path.substring(0, lastDot) : path;

    return '$base.jpg$query';
  }

  static String _inject(String url, String transforms) {
    final idx = url.indexOf(_marker);
    if (idx == -1) return url;
    final head = url.substring(0, idx + _marker.length);
    final tail = url.substring(idx + _marker.length);

    // Guard against double-injection if this URL was already optimised by us
    // — `f_auto` leads an image chain, `so_0` a poster one.
    if (tail.startsWith('f_auto') || tail.startsWith('so_0')) return url;

    return '$head$transforms/$tail';
  }
}
