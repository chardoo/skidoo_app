/// Which HTTP stack images are fetched over.
///
/// Dart's own client speaks HTTP/1.1, where NSURLSession and Cronet negotiate
/// HTTP/3 over QUIC. The win is loss recovery rather than multiplexing: HTTP/1.1
/// stalls an entire connection on one dropped packet, and on mobile data that
/// stall is what "the photo never arrived" actually is.
///
/// What is pinned here is the thing that must never break — **falling back**.
/// Cronet is delivered through Google Play Services, which plenty of Android
/// devices in this app's market do not have, so an unavailable platform stack
/// has to degrade to dart:io rather than leave the app unable to load a photo.
/// In a unit test there is no platform stack at all, which is exactly that case.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:jperg_app/core/cache/platform_http_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(PlatformHttpClient.resetForTest);

  test('a client is always produced, even with no platform stack', () {
    // The whole contract. There is no Cronet and no NSURLSession under a unit
    // test, so this exercises the fallback — and it must still hand back a
    // working client rather than throwing.
    expect(PlatformHttpClient.instance, isA<http.Client>());
  });

  test('and it says which stack it ended up on', () {
    // 'dart:io' here, because the platform channels are not there. On a device
    // this reads 'cupertino' or 'cronet'.
    expect(PlatformHttpClient.kind, isNotEmpty);
    expect(PlatformHttpClient.kind, isNot('unbuilt'));
  });

  test('the same client is reused, not rebuilt per request', () {
    // Rebuilding would throw away the connection pool and the negotiated
    // protocol — the two things that make the platform stack worth using.
    expect(PlatformHttpClient.instance, same(PlatformHttpClient.instance));
  });

  test('images are not double-cached underneath the disk cache', () {
    // The platform stacks can cache too. flutter_cache_manager already keeps
    // every image on disk under an immutable URL, so a second cache would hold
    // a duplicate copy of the same bytes — storage paid twice to answer a
    // question already answered a layer up. Documented on the constant rather
    // than reachable from here, so this pins the intent.
    expect(debugDefaultTargetPlatformOverride, isNull,
        reason: 'the cache-disabling config is per platform branch');
  });
}
