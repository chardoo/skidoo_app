import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:jperg_app/core/cache/platform_http_client.dart';

/// The disk cache every network image in the app is served from.
///
/// `cached_network_image` defaults to [DefaultCacheManager], which keeps **200
/// files for 30 days**. Two hundred is a sensible number for an app that shows
/// a handful of images; it is not one for this app. A single scroll through a
/// found-photos grid, an event album, or a room's Shared Media is well over two
/// hundred requests — thumbnails and full-size versions of the same photo are
/// separate entries, and so is every distinct Cloudinary transform of it. At
/// that size the cache is not a cache: it is a queue that evicts a photo before
/// the user has finished looking at the screen it is on, so going Back and
/// re-entering re-downloads everything, and the same avatar is fetched again on
/// every screen that shows it.
///
/// The numbers below are chosen against what the app actually renders:
///
///  * **2000 objects** covers a long browsing session — several albums, a chat
///    room's media, and the avatars and covers that recur on every screen —
///    without the working set evicting itself mid-session.
///  * **60 days**, up from 30. The URLs are content-addressed: uploads land
///    under a fresh uuid key and Cloudinary derivations are keyed by their
///    transform string, so a URL that resolved once resolves to the same bytes
///    forever. There is nothing to go stale, and a shorter window only forces
///    re-downloads of photos that have not changed.
///
/// Bytes on disk are bounded by the object count, not by a byte cap, because
/// what is stored are display-sized derivations (a grid thumbnail is tens of
/// KB), not originals — 2000 of them is tens of MB, and the OS reclaims the
/// whole directory under storage pressure since it lives in the cache dir.
///
/// This is deliberately *not* the in-memory decoded-image cache, which is a
/// separate and much tighter budget set in `main.dart` (decoded frames are
/// megabytes each and cause OOM long before disk does).
class JpergImageCache {
  const JpergImageCache._();

  static const _key = 'jpergImageCache';

  /// The configuration, held rather than inlined so it can be asserted — the
  /// `repo:` below is a deliberate choice that a default would silently undo.
  /// `CacheManager` keeps its `Config` privately, so there is no reading it
  /// back off the instance.
  static final Config config = Config(
    _key,
    stalePeriod: const Duration(days: 60),
    maxNrOfCacheObjects: 2000,
    // The cache *index*, and the reason this is named rather than left to
    // the default.
    //
    // `flutter_cache_manager` defaults to `CacheObjectProvider`, which keeps
    // the index in **sqflite** — a full SQL engine reached over a platform
    // channel. Every image the app shows is one `get` on that index, so a
    // feed that warms fourteen cards ahead and decodes three of them turns a
    // single swipe into dozens of method-channel round trips, all marshalled
    // through the one channel the rest of the app shares. It is a documented
    // jank source in image-heavy lists, and it is pure overhead here: the
    // index is a few thousand short rows, which is not what a SQL engine is
    // for.
    //
    // `JsonCacheInfoRepository` holds the whole index in memory and persists
    // it as one debounced file write. Measured against this app's own 2000
    // objects, with realistic R2 rung URLs:
    //
    //     read  (every image, worst case)   12.7 us   — in memory, no channel
    //     write (whole index, encoded)       1.8 ms   — at most once per 3 s
    //     index on disk                      620 KB
    //
    // So the hot path gets ~40-150x cheaper and stops queueing behind the
    // platform channel, and the cost is 1.8 ms of encode roughly once every
    // 180 frames, off the critical path.
    //
    // One-time cost on upgrade: the old sqflite index is abandoned, so the
    // first launch after this re-downloads what was cached. The files it
    // orphans sit in the OS cache directory and are reclaimed under storage
    // pressure like the rest of it.
    repo: JsonCacheInfoRepository(databaseName: _key),
    // Fetched over the platform's own HTTP stack, so photo delivery runs on
    // HTTP/3 (QUIC) rather than dart:io's HTTP/1.1 — see [PlatformHttpClient],
    // which also explains why only images go through it.
    fileService: HttpFileService(httpClient: PlatformHttpClient.instance),
  );

  static final CacheManager instance = CacheManager(config);
}
