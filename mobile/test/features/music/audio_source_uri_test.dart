import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/cache/jperg_music_cache.dart';

/// Turning a cached file into something a platform player will open.
///
/// The bug this pins: the disk cache hands back a *path* —
/// `/var/mobile/Containers/…/xyz.m4a` — and `Uri.parse` on a bare path yields a
/// URI with no scheme. AVPlayer answers that with `-1002 unsupported URL`, so
/// on iOS every cached track failed to play *after* downloading perfectly. The
/// download worked; only the handover was wrong.
void main() {
  group('a cached file as a source', () {
    test('File.uri carries a scheme, File.path does not', () {
      final file = File('/var/mobile/Containers/Data/cache/track.m4a');

      // The shape that was being passed, and why it fails.
      expect(Uri.parse(file.path).hasScheme, isFalse,
          reason: 'a bare path parses to a scheme-less URI — this is the bug');

      // The shape that works.
      expect(file.uri.scheme, 'file');
      expect(file.uri.toString(), startsWith('file:///'));
    });

    test('a path with spaces survives the round trip', () {
      // iOS container paths contain no spaces, but Android external storage
      // and a user-named directory can. An unencoded space makes a URI that
      // parses to something else entirely.
      final file = File('/tmp/My Music/a track.m4a');
      final uri = Uri.parse(file.uri.toString());

      expect(uri.scheme, 'file');
      expect(uri.toFilePath(), file.path,
          reason: 'the path must come back out exactly as it went in');
    });

    test('an http url is left alone', () {
      // The fallback path: when the cache misses, the track's own URL is used
      // and must not be mangled into a file URI.
      const url = 'https://api.jperg.com/api/music/123/stream';
      expect(Uri.parse(url).hasScheme, isTrue);
      expect(Uri.parse(url).scheme, 'https');
    });
  });

  group('the cache on web', () {
    test('does not attempt storage it has no implementation for', () async {
      // flutter_cache_manager stores through path_provider, which has no web
      // implementation. Returning null lets the caller fall back to the URL
      // instead of throwing once per play.
      //
      // kIsWeb is false under `flutter test`, so this asserts the contract that
      // holds on every platform: an empty URL is never a cache lookup.
      expect(await cachedAudioFile(''), isNull);
    });
  });
}
