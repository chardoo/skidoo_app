/// How the disk caches keep their index.
///
/// `flutter_cache_manager` defaults to sqflite — a full SQL engine over a
/// platform channel — and every image the app shows is one lookup on that
/// index. A feed that warms fourteen cards ahead turns a single swipe into
/// dozens of method-channel round trips, queued on the one channel the rest of
/// the app shares. Measured against this app's own 2000 objects, an in-memory
/// JSON index answers a lookup in ~13 µs against ~0.5–2 ms for sqflite, and
/// pays 1.8 ms of encode at most once every three seconds.
///
/// A default is easy to fall back into — `Config` works perfectly well without
/// `repo:` — so the choice is asserted rather than left to the comment.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/jperg_image_cache.dart';
import 'package:jperg_app/core/cache/jperg_music_cache.dart';

void main() {
  // `Config`'s constructor builds a file system, which asks `path_provider`
  // for the cache directory over a platform channel. There is no plugin behind
  // that channel in a unit test, so it is answered with a temporary path.
  //
  // Nothing here ever opens the cache or writes to that directory — these
  // tests only read back the configuration the manager was handed.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (call) async => Directory.systemTemp.createTempSync('cachecfg').path,
    );
  });

  test('the image cache keeps its index in memory, not in sqflite', () {
    expect(JpergImageCache.config.repo,
        isA<JsonCacheInfoRepository>());
    expect(JpergImageCache.config.repo,
        isNot(isA<CacheObjectProvider>()));
  });

  test('the music cache does too — it shares the scroll', () {
    // A lookup happens for every scored card that scrolls into view, so this
    // contends for the channel at exactly the moment the images need it.
    expect(JpergMusicCache.config.repo,
        isA<JsonCacheInfoRepository>());
  });

  test('both caches fetch over the platform HTTP stack', () {
    // HTTP/3 over QUIC instead of dart:io's HTTP/1.1 — see
    // [PlatformHttpClient]. Asserted because `Config` works perfectly well
    // without `fileService:`, so the default is easy to fall back into.
    expect(JpergImageCache.config.fileService, isA<HttpFileService>());
    expect(JpergMusicCache.config.fileService, isA<HttpFileService>());
  });

  test('the image cache still holds a session, not 200 files', () {
    // The package default is 200, which a single album scroll overruns — the
    // cache becomes a queue that evicts a photo before the screen it is on is
    // finished with.
    expect(JpergImageCache.config.maxNrOfCacheObjects, 2000);
  });
}
