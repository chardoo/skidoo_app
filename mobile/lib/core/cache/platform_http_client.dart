import 'dart:io' show Platform;

import 'package:cronet_http/cronet_http.dart';
import 'package:cupertino_http/cupertino_http.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The HTTP client images are fetched with: the platform's own stack, so photo
/// delivery runs over **HTTP/3 (QUIC)** rather than HTTP/1.1.
///
/// Why this exists
/// ───────────────
/// Dart's `HttpClient` (dart:io, BoringSSL) speaks HTTP/1.1 and nothing else.
/// `NSURLSession` on iOS and Cronet on Android both negotiate h2 and h3.
///
/// **The win is loss recovery, not multiplexing.** It would be easy to assume
/// h2's parallel streams are the point, and at this app's concurrency they are
/// nearly worthless: warming is capped at three in flight and keep-alive
/// already amortises connection setup across them. What matters is what happens
/// when a packet goes missing. HTTP/1.1 rides one TCP stream per connection, so
/// a single dropped packet stalls everything behind it — head-of-line blocking,
/// and a stall is exactly what "the photo never arrived" looks like. QUIC
/// recovers per stream and survives a changing network path, which is the
/// normal condition on mobile data rather than the exception. Most of this
/// app's readers are on Ghanaian mobile networks.
///
/// Scoped to the image cache
/// ─────────────────────────
/// Only images go through here. Two reasons, and the second is the real one:
///
///   `HttpFileService` takes a `package:http` Client directly, so the image
///   path needs no adapter — where Dio, which every API call uses, would need
///   a bridge to accept one.
///
///   Images are where throughput and loss actually matter. An API response is
///   a few kilobytes on one request; a feed card is 204 KB and a scroll is
///   dozens of them. Swapping the transport under every API call to chase the
///   smaller half of the benefit is a much larger change with a much larger
///   blast radius, and it can be done separately if it ever looks worth it.
///
/// Degrading, never failing
/// ────────────────────────
/// Cronet is delivered through Google Play Services by default, and plenty of
/// Android devices — notably many sold in this app's own market — do not have
/// it. So construction is wrapped: anything that goes wrong falls back to
/// `http.Client()`, which is the dart:io client the app used before any of
/// this. The cost of the fallback is HTTP/1.1, which is where it started;
/// the cost of *not* having it would be an app that cannot load a photo.
///
/// Built once, lazily, and never closed — it lives as long as the process, the
/// same as the cache it serves.
class PlatformHttpClient {
  const PlatformHttpClient._();

  /// How much the platform stack may cache on our behalf.
  ///
  /// Zero. `flutter_cache_manager` already keeps every fetched image on disk
  /// and indexes it (see [JpergImageCache]), so a second cache underneath that
  /// one would hold a duplicate copy of the same bytes under the same
  /// immutable URL — paying storage twice to answer a question that has
  /// already been answered a layer up.
  static const _noCacheBytes = 0;

  /// True inside `flutter test`, where there is no platform HTTP stack to find
  /// and the fallback below is the only possible outcome.
  static bool get _underTest =>
      Platform.environment.containsKey('FLUTTER_TEST');

  static http.Client? _instance;

  /// The shared client. Falls back to `dart:io` if the platform stack is
  /// unavailable.
  static http.Client get instance => _instance ??= _build();

  /// Which stack is actually in use, for diagnostics and for the log line
  /// below — 'cupertino', 'cronet', or 'dart:io' after a fallback.
  static String _kind = 'unbuilt';
  static String get kind {
    instance; // force construction, so this never reports 'unbuilt'
    return _kind;
  }

  @visibleForTesting
  static void resetForTest() {
    _instance = null;
    _kind = 'unbuilt';
  }

  static http.Client _build() {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS) {
        _kind = 'cupertino';
        // A *default* session configuration, not an ephemeral one: ephemeral
        // keeps nothing between launches, and while the cache is disabled here
        // anyway, the default is also what carries the system's own HTTP/3
        // negotiation state and connection reuse across a session.
        final config = URLSessionConfiguration.defaultSessionConfiguration()
          ..cache = URLCache.withCapacity(memoryCapacity: _noCacheBytes);
        return CupertinoClient.fromSessionConfiguration(config);
      }

      if (defaultTargetPlatform == TargetPlatform.android) {
        _kind = 'cronet';
        final engine = CronetEngine.build(
          // QUIC is the entire reason for this file — see the class comment.
          enableQuic: true,
          // Not HTTP/2 server push: `enableHttp2` is Cronet's h2 support, and
          // h3 negotiation falls back to it when QUIC cannot be established.
          enableHttp2: true,
          // Brotli costs nothing to offer and never applies to the images this
          // fetches — WebP and JPEG are already compressed — but this client
          // may serve other media later.
          enableBrotli: true,
          cacheMode: CacheMode.disabled,
        );
        return CronetClient.fromCronetEngine(engine, closeEngine: true);
      }
    } catch (error) {
      // The expected path on an Android device with no Play Services, and the
      // catch-all for anything else. HTTP/1.1 is where this started, so the
      // fallback is a lost optimisation rather than a broken feature.
      //
      // Not logged under `flutter test`: the host VM reports as Android, so
      // every suite takes this branch when it cannot find Cronet's JNI
      // library, and the warning appeared 138 times in one run — noise that
      // buries whatever a test was actually trying to say. On a device it is
      // worth knowing, because it is the difference between HTTP/3 and
      // HTTP/1.1 for every photo.
      if (!_underTest) {
        debugPrint(
          '[http] platform HTTP stack unavailable, using dart:io: $error',
        );
      }
    }

    _kind = 'dart:io';
    return http.Client();
  }
}
