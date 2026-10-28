import 'dart:math' as math;

/// Asking the server for a photo at the size this screen will actually draw it,
/// rather than downloading whatever the photographer's camera produced.
///
/// There are two storage providers behind the app's URLs and they are optimised
/// in completely different ways. Both are permanent: a Cloudinary-stored asset
/// keeps its URL forever, so neither branch can ever be deleted.
///
///   **R2** is plain object storage — it serves back exactly the bytes it was
///   given and has no transformation engine. So the server pre-renders a ladder
///   of WebP copies at upload (see `main/app/services/derivatives.py`) and this
///   file rewrites the URL to the narrowest rung that still covers the slot.
///
///   **Cloudinary** renders on demand at its own edge, so the size is asked for
///   in the URL's transformation segment.
///
/// For anything else — a bare URL on somebody else's host — the original string
/// is returned untouched, so this is always safe to call.
class MediaTransform {
  const MediaTransform._();

  /// The rung widths the server renders.
  ///
  /// **Must match `RUNGS` in `main/app/services/derivatives.py`.** The keys are
  /// derived arithmetically on both sides rather than listed in the payload, so
  /// the two lists disagreeing means asking for an object that was never
  /// written. Ascending, and relied on to be.
  static const List<int> rungs = [320, 640, 1080, 1600, 2560];

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

  /// The URL to fetch for a still, sized for [displayWidth] logical pixels at
  /// [devicePixelRatio].
  ///
  /// [ladder] is what the photo knows about its own stored copies. Without it
  /// — an asset with no ladder, or one whose source width was never recorded —
  /// an R2 URL comes back unchanged, which is the behaviour every row had
  /// before the ladder existed.
  /// [maxPhysicalWidth] caps how many device pixels are asked for, whatever
  /// the slot and the screen density work out to.
  ///
  /// For a full-bleed feed card the honest arithmetic is: a 393 pt card on a
  /// 3x screen is 1179 device pixels, so rung selection reaches past 1080 and
  /// takes 1600 — **549 KB where 1080 is 204 KB**, measured. What that buys is
  /// the difference between painting 1080 px into a 1179 px slot (a 1.09x
  /// upscale, invisible at that density) and painting 1179 of 1600 available.
  /// Not worth 2.7x the bytes and a larger frame to decode on the way past.
  ///
  /// Null means no cap, which is what a viewer somebody has deliberately
  /// opened and can pinch into should have.
  static String image(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
    ImageLadder ladder = ImageLadder.none,
    bool sharpen = true,
    int? maxPhysicalWidth,
  }) {
    if (_isCloudinary(url)) {
      return _cloudinaryImage(
        url,
        displayWidth: displayWidth,
        devicePixelRatio: devicePixelRatio,
        sharpen: sharpen,
        maxPhysicalWidth: maxPhysicalWidth,
      );
    }
    return _rungUrl(
          url,
          target: _cappedWidth(displayWidth, devicePixelRatio, maxPhysicalWidth),
          ladder: ladder,
        ) ??
        url;
  }

  /// Returns an optimised video URL: automatic container/codec, best quality,
  /// and a width cap so 4K sources stream at the display's real resolution.
  ///
  /// Cloudinary only. R2 stores one encode of a clip and has nothing to
  /// transcode with, so its URLs come back untouched.
  static String video(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
  }) {
    if (!_isCloudinary(url)) return url;

    final transforms = <String>[
      'f_auto', // best container for the platform
      'q_auto:good', // see the quality note on _cloudinaryImage
      'vc_auto', // modern codec (h265/vp9/av1) when supported
      'c_limit',
      'w_${_steppedWidth(displayWidth, devicePixelRatio)}',
    ].join(',');

    return _inject(url, transforms);
  }

  /// A still frame of a video, sized like [image] would size a photo — the
  /// poster a thumbnail slot shows in place of the clip.
  ///
  /// Cloudinary renders one on demand by asking for the video asset with a
  /// still extension: `…/video/upload/so_0/<public_id>.jpg` is the frame at
  /// second zero, and nothing has to be stored for it.
  ///
  /// On R2 nothing can be rendered on demand, so the server pulls frame zero
  /// out with ffmpeg at upload and stores *its* rungs under a parallel key —
  /// `…/clip_poster_1080.webp`. Picking one works exactly like picking a
  /// photo's rung, because the frame is the width the clip is.
  ///
  /// Null when no poster can be derived — a video on somebody else's host, or
  /// an R2 clip uploaded before posters existed (no [ladder]). Callers should
  /// show a neutral slot rather than send the video URL to an image loader.
  static String? videoPoster(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
    ImageLadder ladder = ImageLadder.none,
  }) {
    if (!_isCloudinary(url)) {
      return _rungUrl(
        _posterBaseUrl(url),
        target: _physicalWidth(displayWidth, devicePixelRatio),
        ladder: ladder,
      );
    }
    if (!url.contains(_videoMarker)) return null;

    final transforms = <String>[
      'so_0', // frame at t=0 — the video's own first frame
      'q_auto:good',
      'c_limit',
      'w_${_steppedWidth(displayWidth, devicePixelRatio)}',
    ].join(',');

    // The extension picks the delivery format, so it has to become a still
    // one; `f_auto` is deliberately left off, since on a video resource it
    // would hand back a video container again.
    return _inject(_withJpgExtension(url), transforms);
  }

  // ── R2: pick a rung ────────────────────────────────────────────────────────

  /// The rung URL for a [target] physical width, or null to use the original.
  ///
  /// Two separate reasons to decline, and both have to be honoured or the app
  /// requests an object that is not there and draws a broken slot:
  ///
  ///   *Rungs at or above the source width were never rendered*, because they
  ///   would be upscales carrying no extra detail. So a 1500 px photo has rungs
  ///   up to 1080 and nothing above, and the source width is the only way to
  ///   know that.
  ///
  ///   *No rung is wide enough.* A full-screen viewer at 4x zoom wants more
  ///   pixels than the top rung holds, and the original is the right answer.
  static String? _rungUrl(
    String url, {
    required int target,
    required ImageLadder ladder,
  }) {
    final sourceWidth = ladder.sourceWidth;
    if (ladder.version == null || sourceWidth == null) return null;

    for (final rung in rungs) {
      if (rung >= sourceWidth) break;
      if (rung >= target) return _withRungSuffix(url, rung);
    }
    return null;
  }

  /// `…/events/clip.mp4` → `…/events/clip_poster.jpg`, the notional base the
  /// poster's rungs hang off. Mirrors `derivatives.poster_base_key`; the key
  /// itself is never stored, only its rungs.
  static String _posterBaseUrl(String url) {
    final queryAt = url.indexOf('?');
    final path = queryAt == -1 ? url : url.substring(0, queryAt);
    final query = queryAt == -1 ? '' : url.substring(queryAt);

    final lastSlash = path.lastIndexOf('/');
    final lastDot = path.lastIndexOf('.');
    final stem = lastDot > lastSlash ? path.substring(0, lastDot) : path;

    return '${stem}_poster.jpg$query';
  }

  /// `…/events/9f3c.jpg` → `…/events/9f3c_1080.webp`, leaving any query string
  /// alone. Mirrors `derivatives.rung_key` on the server.
  static String _withRungSuffix(String url, int width) {
    final queryAt = url.indexOf('?');
    final path = queryAt == -1 ? url : url.substring(0, queryAt);
    final query = queryAt == -1 ? '' : url.substring(queryAt);

    final lastSlash = path.lastIndexOf('/');
    final lastDot = path.lastIndexOf('.');
    final stem = lastDot > lastSlash ? path.substring(0, lastDot) : path;

    return '${stem}_$width.webp$query';
  }

  // ── Cloudinary: ask the edge ───────────────────────────────────────────────

  static String _cloudinaryImage(
    String url, {
    required double displayWidth,
    required double devicePixelRatio,
    required bool sharpen,
    int? maxPhysicalWidth,
  }) {
    final transforms = <String>[
      'f_auto', // AVIF/WebP when the device supports it
      // `q_auto:good`, not `:best`. Best targets near-visually-lossless and
      // lands 1.5-2.5x the bytes for a difference nobody can see in a
      // phone-width card, because the downscale has already discarded the
      // detail the extra quality would have protected.
      'q_auto:good',
      'c_limit', // never upscale beyond the source
      // Physical pixels, and deliberately *without* a `dpr_` alongside it.
      // Cloudinary treats `dpr_` as a multiplier on `w_`, so passing both —
      // which this did — asked a 3x phone for ~3840 px where 1179 was wanted,
      // roughly ten times the pixel area. One axis also keeps the CDN cache
      // key space half the size.
      'w_${_steppedWidth(displayWidth, devicePixelRatio, maxPhysicalWidth)}',
      if (sharpen) 'e_sharpen:40', // gentle crispness
    ].join(',');

    return _inject(url, transforms);
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  static bool _isCloudinary(String url) =>
      url.contains('res.cloudinary.com') && url.contains(_marker);

  static int _physicalWidth(double displayWidth, double dpr) =>
      (displayWidth * math.max(dpr, 1.0)).ceil();

  /// The physical width to ask for, never more than [cap].
  static int _cappedWidth(double displayWidth, double dpr, int? cap) {
    final want = _physicalWidth(displayWidth, dpr);
    return cap == null ? want : math.min(want, cap);
  }

  /// Physical width rounded up to the nearest 160 px.
  ///
  /// The rounding is for Cloudinary's cache, not for the picture: a unique
  /// width per device size means a separate render and a separate cached object
  /// for every viewport in the wild. Rungs need no equivalent — their widths
  /// are the quantisation.
  static int _steppedWidth(double displayWidth, double dpr, [int? cap]) {
    final raw = _cappedWidth(displayWidth, dpr, cap);
    final stepped = ((raw / 160).ceil()) * 160;
    return stepped.clamp(160, _maxDimension);
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

/// What one stored image knows about the pre-sized copies of itself.
///
/// Carried as a pair because picking a rung needs both halves and neither is
/// useful alone: [version] says a ladder was rendered at all, [sourceWidth]
/// says which rungs of it exist — anything at or above the source was skipped
/// as an upscale. A missing half means "use the original", which is always
/// correct and never broken, just bigger.
class ImageLadder {
  const ImageLadder({this.version, this.sourceWidth});

  /// Which rendering produced the rungs, or null when there are none —
  /// a Cloudinary-stored asset, a video, or a row the backfill has not reached.
  final int? version;

  /// The stored original's width in pixels, oriented as it is displayed.
  final int? sourceWidth;

  /// No ladder: the original is what gets fetched.
  static const none = ImageLadder();

  /// Reads the pair out of an API payload. Tolerates either naming, since the
  /// event cover spells them `coverDerivativesVersion` / `coverWidth`.
  factory ImageLadder.fromJson(
    Map<String, dynamic> json, {
    String versionKey = 'derivativesVersion',
    String widthKey = 'width',
  }) =>
      ImageLadder(
        version: _asInt(json[versionKey]),
        sourceWidth: _asInt(json[widthKey]),
      );

  bool get exists => version != null && sourceWidth != null;

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is ImageLadder &&
      other.version == version &&
      other.sourceWidth == sourceWidth;

  @override
  int get hashCode => Object.hash(version, sourceWidth);
}
