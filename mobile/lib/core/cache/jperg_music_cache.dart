import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

/// The disk cache the feed's music is played from.
///
/// Audiomack bills per API request, and the feed is the one place that would
/// otherwise generate them without limit: every card that scrolls into view
/// asks for its soundtrack, and each ask is a signed-URL resolution upstream.
/// A viewer scrolling fifty scored events is fifty billed calls, every session,
/// for audio they may have heard four times already — the same handful of
/// popular tracks recur across events, because photographers pick from a
/// picker rather than the whole catalogue.
///
/// So the audio is kept on the device. A track heard once is played from disk
/// afterwards, and the upstream call happens only the first time a given phone
/// meets a given track. Audiomack have confirmed this is acceptable.
///
/// **Cached by our own URL, not theirs.** `Event.music` stores
/// `/api/music/{id}/stream`, which never changes; the signed link it redirects
/// to lasts about ten seconds. Keying on the stable URL is what makes a hit
/// possible at all — the URL actually carrying the bytes is different every
/// time and would never match twice.
///
/// The numbers, and why:
///
///  * **200 tracks.** A 30-second preview is roughly 300–500 KB, so this is
///    ~80 MB at worst. It lives in the OS cache directory, which the system
///    reclaims under storage pressure. LRU eviction means what survives is
///    what actually recurs, and the working set is likely far smaller than the
///    cap.
///  * **20 days.** Long enough that a returning viewer keeps their library
///    across a fortnight of use; short enough that a withdrawn track cannot
///    play on indefinitely.
class JpergMusicCache {
  const JpergMusicCache._();

  static const _key = 'jpergMusicCache';

  static final CacheManager instance = CacheManager(
    Config(
      _key,
      stalePeriod: const Duration(days: 20),
      maxNrOfCacheObjects: 200,
      fileService: _MusicFileService(),
    ),
  );
}

/// Downloads audio and tells the cache to keep it, whatever the origin said.
///
/// This override is the difference between the cache working and silently
/// doing nothing. `flutter_cache_manager`'s default service reads
/// `Cache-Control` off the response to decide how long a file is valid — and
/// what answers here is a signed link that expires in about ten seconds, so it
/// will very reasonably say `no-cache` or a max-age of seconds. Honouring that
/// would re-download the audio on every single play and we would have built an
/// elaborate no-op.
///
/// The distinction the headers cannot express is the one that matters: the
/// *URL* is short-lived, the *audio* is not. A track's bytes are the same
/// today as in a fortnight. So the response headers are ignored and the
/// lifetime from [JpergMusicCache]'s config is applied instead.
class _MusicFileService extends HttpFileService {
  _MusicFileService();

  @override
  Future<FileServiceResponse> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    final response = await super.get(url, headers: headers);
    return _KeepFor(response, const Duration(days: 20));
  }
}

/// Wraps a response and rewrites only its expiry.
class _KeepFor implements FileServiceResponse {
  _KeepFor(this._inner, this._keep);

  final FileServiceResponse _inner;
  final Duration _keep;

  @override
  DateTime get validTill => DateTime.now().add(_keep);

  // Everything else is the real response. `eTag` is passed through so a
  // revalidation after the file *does* expire can still come back 304 and cost
  // nothing but a round trip.
  @override
  int get statusCode => _inner.statusCode;

  @override
  Stream<List<int>> get content => _inner.content;

  @override
  int? get contentLength => _inner.contentLength;

  @override
  String? get eTag => _inner.eTag;

  @override
  String get fileExtension {
    // Their audio is served from signed URLs with query strings and often no
    // extension at all, which the default derives an empty one from — and an
    // extensionless file is one the platform players sniff rather than trust.
    final guess = _inner.fileExtension;
    return guess.isEmpty ? '.mp3' : guess;
  }
}

/// Resolves a track's stream URL to a local file, downloading it once.
///
/// Returns null when the audio cannot be had — no network on a cold cache, a
/// track the provider has withdrawn, a device with no room. Music is
/// decoration on a feed: the caller plays what it can and stays quiet about
/// the rest.
Future<File?> cachedAudioFile(String streamUrl) async {
  if (streamUrl.isEmpty) return null;
  try {
    return await JpergMusicCache.instance.getSingleFile(streamUrl);
  } catch (e) {
    debugPrint('[music] could not cache $streamUrl: $e');
    return null;
  }
}
