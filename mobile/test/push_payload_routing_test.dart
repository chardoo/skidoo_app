import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/deep_links/deep_link.dart';

/// What a push tap resolves to.
///
/// The legacy-key cases are the ones worth pinning: rows written before the
/// payload was standardised are still in the Notification table, and tasks
/// queued under the old shape are still on the broker. If those stop parsing,
/// every notification from before the change taps through to nothing — and it
/// fails silently, which is exactly the sort of regression a test has to catch.
void main() {
  group('parsePushPayload', () {
    test('reads the standard {screen, id} shape', () {
      expect(
        parsePushPayload({'screen': 'event', 'id': 'evt-1'}),
        const DeepLink(DeepLinkKind.event, id: 'evt-1'),
      );
    });

    test('falls back to each legacy id key', () {
      final cases = <String, Map<String, dynamic>>{
        'event_id': {'screen': 'event', 'event_id': 'evt-2'},
        'room_id': {'screen': 'chat', 'room_id': 'room-1'},
        'requestId': {'screen': 'request', 'requestId': 'req-1'},
        'pictureId': {'screen': 'picture', 'pictureId': 'pic-1'},
        'campaignId': {'screen': 'ads_dashboard', 'campaignId': 'camp-1'},
        'followerId': {'screen': 'photographer', 'followerId': 'usr-1'},
      };

      for (final entry in cases.entries) {
        final link = parsePushPayload(entry.value);
        expect(link, isNotNull, reason: 'legacy key ${entry.key} did not parse');
      }

      expect(
        parsePushPayload(cases['room_id']),
        const DeepLink(DeepLinkKind.chat, id: 'room-1'),
      );
      expect(
        parsePushPayload(cases['requestId']),
        const DeepLink(DeepLinkKind.request, id: 'req-1'),
      );
      expect(
        parsePushPayload(cases['campaignId']),
        const DeepLink(DeepLinkKind.campaign, id: 'camp-1'),
      );
    });

    test('a campaign notification opens that campaign, not the list', () {
      // "Your campaign was rejected" landing on a list of nine campaigns is
      // the report this fixes. Every campaign notification carries its id.
      expect(
        parsePushPayload({'screen': 'ads_dashboard', 'id': 'camp-9'}),
        const DeepLink(DeepLinkKind.campaign, id: 'camp-9'),
      );
      expect(
        parsePushPayload({'screen': 'campaign', 'id': 'camp-9'}),
        const DeepLink(DeepLinkKind.campaign, id: 'camp-9'),
      );
    });

    test('ads_dashboard with no id is still the list', () {
      // Nothing names a campaign, so there is none to open — and a row written
      // before the ids were sent must not stop routing.
      expect(
        parsePushPayload({'screen': 'ads_dashboard'}),
        const DeepLink(DeepLinkKind.adsDashboard),
      );
    });

    test('prefers "id" when both it and a legacy key are present', () {
      // The backend emits both during the transition, and they always agree —
      // but if they ever did not, the new key is the authoritative one.
      expect(
        parsePushPayload({
          'screen': 'event',
          'id': 'new-id',
          'event_id': 'old-id',
        }),
        const DeepLink(DeepLinkKind.event, id: 'new-id'),
      );
    });

    test('chat without a room id is the messages list, not a dead link', () {
      expect(
        parsePushPayload({'screen': 'chat'}),
        const DeepLink(DeepLinkKind.chat),
      );
    });

    test('a screen this build does not know returns null', () {
      // An older app meeting a newer backend. Null means "open the app
      // normally", which is the whole point — not a crash and not a dead tap.
      expect(parsePushPayload({'screen': 'some_future_screen'}), isNull);
    });

    test('missing, empty and malformed payloads return null', () {
      expect(parsePushPayload(null), isNull);
      expect(parsePushPayload({}), isNull);
      expect(parsePushPayload({'screen': ''}), isNull);
      expect(parsePushPayload({'screen': '   '}), isNull);
    });

    test('an id-requiring screen with no id returns null', () {
      // Better to open the app than to push a screen with nothing to show.
      expect(parsePushPayload({'screen': 'picture'}), isNull);
      expect(parsePushPayload({'screen': 'event', 'id': ''}), isNull);
    });

    test('non-string ids are coerced rather than dropped', () {
      // JSONB round-trips can hand back a number for an id that was stored
      // as one.
      expect(
        parsePushPayload({'screen': 'event', 'id': 12345}),
        const DeepLink(DeepLinkKind.event, id: '12345'),
      );
    });
  });

  group('destinations', () {
    test('push-only destinations are not offered as shareable links', () {
      const pushOnly = [
        DeepLinkKind.home,
        DeepLinkKind.notifications,
        DeepLinkKind.chat,
        DeepLinkKind.adsDashboard,
        DeepLinkKind.requestBoard,
        DeepLinkKind.earnings,
        DeepLinkKind.cart,
      ];
      for (final kind in pushOnly) {
        expect(
          DeepLink(kind).isShareable,
          isFalse,
          reason: '$kind is not claimed by the domain — sharing it would open '
              'a browser',
        );
      }
    });

    test('web-grammar links stay shareable', () {
      expect(const DeepLink(DeepLinkKind.myPhotos).isShareable, isTrue);
      expect(const DeepLink(DeepLinkKind.picture, id: 'p').isShareable, isTrue);
      expect(const DeepLink(DeepLinkKind.event, id: 'e').isShareable, isTrue);
    });

    test('destinations about the viewer require a session', () {
      expect(const DeepLink(DeepLinkKind.myPhotos).requiresAuth, isTrue);
      expect(const DeepLink(DeepLinkKind.chat).requiresAuth, isTrue);
      expect(const DeepLink(DeepLinkKind.earnings).requiresAuth, isTrue);
      // A public object does not — someone arriving from a shared link may
      // not have an account at all.
      expect(const DeepLink(DeepLinkKind.event, id: 'e').requiresAuth, isFalse);
    });
  });
}
