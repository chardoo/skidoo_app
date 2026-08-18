import 'package:flutter_cache_manager/flutter_cache_manager.dart';

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

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 2000,
    ),
  );
}
