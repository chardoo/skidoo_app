import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:skidoo_app/core/utils/cloudinary_transform.dart';

/// Aspect ratios recovered from the images themselves, for records the server
/// never sent `width`/`height` for.
///
/// The alternative is a hard-coded fallback shape, which is wrong for every
/// photo that isn't that shape — a panorama gets a 4:3 box and is cropped or
/// stranded in one. Resolving goes through [CachedNetworkImageProvider], the
/// same provider the widgets render with, so a photo already on screen costs
/// nothing extra: the decoded frame is served straight from Flutter's image
/// cache.
class ImageAspectCache {
  const ImageAspectCache._();

  static final Map<String, double> _resolved = {};
  static final Map<String, Future<double?>> _inFlight = {};

  /// The ratio if it is already known, without starting any work. Lets a build
  /// use the real shape on its very first frame once anything has resolved it.
  static double? peek(String url) => _resolved[url];

  /// Width ÷ height, or null when the image can't be loaded or measured.
  /// Concurrent callers for the same url share one decode.
  static Future<double?> resolve(String url) {
    if (url.isEmpty) return Future.value();
    final hit = _resolved[url];
    if (hit != null) return Future.value(hit);
    return _inFlight.putIfAbsent(url, () => _load(url));
  }

  /// What to actually decode to measure [url]. A video can't be decoded as an
  /// image, so its poster frame stands in — same asset, same proportions.
  /// Null when there's nothing measurable (a video on a non-Cloudinary host).
  static String? _measurableUrl(String url) {
    if (!CloudinaryTransform.isVideoUrl(url)) return url;
    // A small render is enough: c_limit keeps the source's proportions, and
    // this is the only thing being read off the frame.
    return CloudinaryTransform.videoPoster(url,
        displayWidth: 320, devicePixelRatio: 1.0);
  }

  static Future<double?> _load(String url) async {
    // The in-flight entry is deliberately left in place here: it resolves to
    // null, so an unmeasurable url is answered from the map instead of being
    // retried on every rebuild.
    final measurable = _measurableUrl(url);
    if (measurable == null) return null;

    final completer = Completer<double?>();
    final stream = CachedNetworkImageProvider(measurable)
        .resolve(ImageConfiguration.empty);

    late final ImageStreamListener listener;
    void finish(double? ratio) {
      if (ratio != null) _resolved[url] = ratio;
      if (!completer.isCompleted) completer.complete(ratio);
      stream.removeListener(listener);
    }

    listener = ImageStreamListener(
      (info, _) {
        final height = info.image.height;
        finish(height == 0 ? null : info.image.width / height);
      },
      onError: (_, __) => finish(null),
    );
    stream.addListener(listener);

    try {
      return await completer.future;
    } finally {
      _inFlight.remove(url);
    }
  }

  @visibleForTesting
  static void clear() {
    _resolved.clear();
    _inFlight.clear();
  }
}

/// Hands [builder] the truest aspect ratio available for [imageUrl].
///
/// [knownAspect] — the server's `width`/`height` — is used as-is when present,
/// which is the normal path and costs no work. Only when it is missing does
/// this fall back to measuring the image, rebuilding once with the real shape.
/// [fallback] is what the first frame uses while that is in flight.
class ResolvedAspect extends StatefulWidget {
  const ResolvedAspect({
    super.key,
    required this.imageUrl,
    required this.knownAspect,
    required this.builder,
    this.fallback = 4 / 3,
  });

  final String imageUrl;

  /// Null for legacy records the server has no dimensions for.
  final double? knownAspect;

  final double fallback;
  final Widget Function(BuildContext context, double aspectRatio) builder;

  @override
  State<ResolvedAspect> createState() => _ResolvedAspectState();
}

class _ResolvedAspectState extends State<ResolvedAspect> {
  double? _measured;

  @override
  void initState() {
    super.initState();
    _measure();
  }

  @override
  void didUpdateWidget(ResolvedAspect old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl ||
        old.knownAspect != widget.knownAspect) {
      _measured = null;
      _measure();
    }
  }

  void _measure() {
    if (widget.knownAspect != null) return;
    // Anything already measured is applied synchronously, so a photo revisited
    // in the same session never flashes the fallback shape again.
    final cached = ImageAspectCache.peek(widget.imageUrl);
    if (cached != null) {
      _measured = cached;
      return;
    }
    ImageAspectCache.resolve(widget.imageUrl).then((ratio) {
      if (!mounted || ratio == null || ratio == _measured) return;
      setState(() => _measured = ratio);
    });
  }

  @override
  Widget build(BuildContext context) {
    final aspect = widget.knownAspect ?? _measured ?? widget.fallback;
    return widget.builder(context, aspect > 0 ? aspect : widget.fallback);
  }
}
