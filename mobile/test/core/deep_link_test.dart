import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';

/// What a link means, decided away from any Navigator.
///
/// A deep link is the one entry point into the app that nobody tests by using
/// the app: it arrives from an email, on a cold start, on a device that may not
/// be signed in. Getting the meaning wrong opens the wrong screen, and getting
/// `null` wrong opens the app on a link that belongs in a browser.
void main() {
  DeepLink? parse(String url) => parseDeepLink(Uri.tryParse(url));

  group('the links we send', () {
    test('the face-found email lands on my photos', () {
      expect(parse('https://jperg.com/my-photos'),
          const DeepLink(DeepLinkKind.myPhotos));
    });

    test('a shared photo, event, request and profile each carry their id', () {
      expect(parse('https://jperg.com/p/abc123'),
          const DeepLink(DeepLinkKind.picture, id: 'abc123'));
      expect(parse('https://jperg.com/e/ev_88'),
          const DeepLink(DeepLinkKind.event, id: 'ev_88'));
      expect(parse('https://jperg.com/r/req_12'),
          const DeepLink(DeepLinkKind.request, id: 'req_12'));
      expect(parse('https://jperg.com/photographer/ph_7'),
          const DeepLink(DeepLinkKind.photographer, id: 'ph_7'));
    });

    test('a link survives the query string a mail client staples on', () {
      // SendGrid click-tracking and utm_* parameters ride along on every link
      // in an email. They must not change what opens.
      expect(
        parse('https://jperg.com/p/abc123?utm_source=email&utm_campaign=faces'),
        const DeepLink(DeepLinkKind.picture, id: 'abc123'),
      );
    });

    test('a trailing slash is the same link', () {
      expect(parse('https://jperg.com/e/ev_88/'),
          const DeepLink(DeepLinkKind.event, id: 'ev_88'));
    });

    test('the domain is not what decides — the OS already checked it', () {
      // Only a verified domain reaches the app at all, so re-checking the host
      // here would only break staging and local builds.
      expect(parse('https://staging.jperg.com/e/ev_88'),
          const DeepLink(DeepLinkKind.event, id: 'ev_88'));
    });
  });

  group('the custom scheme', () {
    test('puts its first segment in the host, and still resolves', () {
      expect(parse('jperg://photo/abc123'),
          const DeepLink(DeepLinkKind.picture, id: 'abc123'));
      expect(parse('jperg://my-photos'), const DeepLink(DeepLinkKind.myPhotos));
    });
  });

  group('links that are not ours to open', () {
    test('the site\'s own pages stay in the browser', () {
      for (final url in [
        'https://jperg.com/',
        'https://jperg.com/terms',
        'https://jperg.com/privacy',
        'https://jperg.com/about',
      ]) {
        expect(parse(url), isNull, reason: '$url should not open the app');
      }
    });

    test('a known prefix with nothing after it is not a link to anything', () {
      expect(parse('https://jperg.com/p'), isNull);
      expect(parse('https://jperg.com/p/'), isNull);
      expect(parse('https://jperg.com/e//'), isNull);
    });

    test('garbage does not throw', () {
      expect(parseDeepLink(null), isNull);
      expect(parse(''), isNull);
      expect(parse('not a url at all'), isNull);
    });
  });

  group('what a link needs before it can be followed', () {
    test('my photos needs a signed-in person; the rest do not', () {
      expect(const DeepLink(DeepLinkKind.myPhotos).requiresAuth, isTrue);
      // A shared photo has to work for someone who has just installed the app
      // and has no account — that is the whole point of sharing it.
      expect(const DeepLink(DeepLinkKind.picture, id: 'x').requiresAuth, isFalse);
      expect(const DeepLink(DeepLinkKind.event, id: 'x').requiresAuth, isFalse);
      expect(const DeepLink(DeepLinkKind.request, id: 'x').requiresAuth, isFalse);
    });
  });

  group('round trip', () {
    test('a link the app builds is a link the app can read', () {
      for (final link in [
        const DeepLink(DeepLinkKind.myPhotos),
        const DeepLink(DeepLinkKind.picture, id: 'abc123'),
        const DeepLink(DeepLinkKind.event, id: 'ev_88'),
        const DeepLink(DeepLinkKind.request, id: 'req_12'),
        const DeepLink(DeepLinkKind.photographer, id: 'ph_7'),
      ]) {
        expect(parse('https://jperg.com${link.path()}'), link,
            reason: 'sharing then following ${link.path()} must round trip');
      }
    });
  });

  group('push notifications resolve the same way', () {
    test('the screen key already in the payloads maps to a link', () {
      // notifications.py stores {"screen": "my_photos"} on every face match.
      expect(parsePushScreen('my_photos'), const DeepLink(DeepLinkKind.myPhotos));
      expect(parsePushScreen('event', id: 'ev_88'),
          const DeepLink(DeepLinkKind.event, id: 'ev_88'));
    });

    test('an unknown or id-less screen resolves to nothing', () {
      expect(parsePushScreen('some_new_screen'), isNull);
      expect(parsePushScreen('event'), isNull, reason: 'no id to open');
      expect(parsePushScreen(null), isNull);
      expect(parsePushScreen('  '), isNull);
    });
  });


  // The app claims all of /photographer/*, and the creator portal puts its own
  // screens directly under that prefix. Both live on jperg.com.
  group('the /photographer/ prefix is shared with the web portal', () {
    test('a portal screen is not read as a profile', () {
      for (final screen in const [
        'dashboard', 'payouts', 'events', 'messages',
        'analytics', 'upload', 'requests', 'broadcasts', 'profile', 'samples',
      ]) {
        expect(
          parseDeepLink(Uri.parse('https://jperg.com/photographer/$screen')),
          isNull,
          reason: '/photographer/$screen is a portal page, not a photographer',
        );
      }
    });

    test('a real profile still opens', () {
      expect(
        parseDeepLink(Uri.parse(
            'https://jperg.com/photographer/6adb7476-73b5-4249-9388-e11a09328410')),
        const DeepLink(DeepLinkKind.photographer,
            id: '6adb7476-73b5-4249-9388-e11a09328410'),
      );
    });

    test('the plural form the website uses opens too', () {
      expect(
        parseDeepLink(Uri.parse('https://jperg.com/photographers/abc123')),
        const DeepLink(DeepLinkKind.photographer, id: 'abc123'),
      );
    });
  });
}
