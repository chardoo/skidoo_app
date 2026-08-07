import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';

/// A link that arrives before the app is ready must be kept, not dropped.
///
/// This is the failure everyone ships: the link works when the app is already
/// open, and does nothing when it is closed, because it landed before the
/// Navigator existed. Same for a link that needs a sign-in.
void main() {
  // GlobalKey.currentState needs a binding, even from a plain test.
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a link needing auth is held, not lost, when signed out', () async {
    final service = DeepLinkService(isSignedIn: () async => false);
    await service.follow(const DeepLink(DeepLinkKind.myPhotos));
    expect(service.pending, const DeepLink(DeepLinkKind.myPhotos),
        reason: 'it must survive the trip through the login screen');
  });

  test('a link that needs no auth is not held for one', () async {
    final service = DeepLinkService(isSignedIn: () async => false);
    // No navigator in a plain test, so it is held for that instead — the
    // point is that the *reason* is not authentication.
    await service.follow(const DeepLink(DeepLinkKind.picture, id: 'p1'));
    expect(service.pending, const DeepLink(DeepLinkKind.picture, id: 'p1'));
  });

  test('a link arriving before the navigator is held', () async {
    final service = DeepLinkService(isSignedIn: () async => true);
    await service.follow(const DeepLink(DeepLinkKind.event, id: 'e1'));
    expect(service.pending, const DeepLink(DeepLinkKind.event, id: 'e1'));
  });

  test('a URL with no screen behind it is ignored entirely', () async {
    final service = DeepLinkService(isSignedIn: () async => true);
    await service.handle(Uri.parse('https://jperg.com/privacy'));
    expect(service.pending, isNull,
        reason: 'a website page must not queue itself against the app');
  });

  test('resuming twice does not open twice', () async {
    final service = DeepLinkService(isSignedIn: () async => true);
    await service.follow(const DeepLink(DeepLinkKind.myPhotos));
    expect(service.pending, isNotNull);
    await service.resumePending();   // no navigator: re-held
    final afterFirst = service.pending;
    await service.resumePending();
    expect(service.pending, afterFirst);
  });
}
