import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/data/datasources/client_saved_data_source.dart';

void main() {
  group('SavedItem.fromJson resilience', () {
    test('camelCase top-level with nested event resolves title + ids', () {
      final item = SavedItem.fromJson({
        'id': 'rec1',
        'assetType': 'event',
        'assetId': 'evt-123',
        'asset': {
          'event': {
            'eventName': 'Beach Wedding',
            'pictures': [
              {'url': 'https://cdn/1.jpg'}
            ],
          }
        },
      });
      expect(item.savedItemId, 'rec1');
      expect(item.assetType, 'event');
      expect(item.assetId, 'evt-123');
      expect(item.title, 'Beach Wedding');
      expect(item.thumbnailUrl, 'https://cdn/1.jpg');
    });

    test('snake_case keys still resolve assetType/assetId/title', () {
      final item = SavedItem.fromJson({
        'id': 'rec2',
        'asset_type': 'event',
        'asset_id': 'evt-777',
        'asset': {
          'name': 'Street Festival',
        },
      });
      expect(item.assetType, 'event');
      expect(item.assetId, 'evt-777');
      expect(item.title, 'Street Festival');
    });

    test('id nested only on the asset is still extracted (no empty assetId)', () {
      final item = SavedItem.fromJson({
        'id': 'rec3',
        'assetType': 'event',
        'asset': {
          'id': 'evt-999',
          'eventName': 'Marathon',
          'images': [
            {'url': 'https://cdn/x.png'}
          ],
        },
      });
      // Regression: previously assetId was '' here → name unresolved AND the
      // detail page opened empty.
      expect(item.assetId, 'evt-999');
      expect(item.title, 'Marathon');
      expect(item.thumbnailUrl, 'https://cdn/x.png');
    });

    test('no asset details → title null (UI shows fallback, ids preserved)', () {
      final item = SavedItem.fromJson({
        'id': 'rec4',
        'assetType': 'event',
        'assetId': 'evt-1',
      });
      expect(item.assetId, 'evt-1');
      expect(item.title, isNull);
    });
  });

  /// A bookmarked photo has to be able to find the album it came from.
  ///
  /// Tapping one used to do nothing at all — the Saved screen returned on
  /// anything that was not an event — and the album is what lets it open *at
  /// that photo* rather than at the top of a grid. The server has always sent
  /// `eventId` on a hydrated picture; this is the field that was dropped.
  group('a saved picture carries its album', () {
    test('eventId is read off the hydrated asset', () {
      final item = SavedItem.fromJson({
        'id': 'rec-p1',
        'assetType': 'picture',
        'assetId': 'pic-9',
        'asset': {
          'id': 'pic-9',
          'url': 'https://cdn/9.jpg',
          'eventId': 'evt-42',
        },
      });
      expect(item.assetType, 'picture');
      expect(item.assetId, 'pic-9');
      expect(item.parentEventId, 'evt-42');
      expect(item.thumbnailUrl, 'https://cdn/9.jpg');
    });

    test('snake_case event_id too', () {
      final item = SavedItem.fromJson({
        'id': 'rec-p2',
        'asset_type': 'picture',
        'asset_id': 'pic-10',
        'asset': {'url': 'https://cdn/10.jpg', 'event_id': 'evt-43'},
      });
      expect(item.parentEventId, 'evt-43');
    });

    test('a picture the server could not hydrate has no album', () {
      // The row stays in the list with no asset attached when the photo is no
      // longer visible — see visible_picture_ids in saved_items.py. The screen
      // falls back to opening the photo alone, so null here is a real state
      // rather than a parse failure.
      final item = SavedItem.fromJson({
        'id': 'rec-p3',
        'assetType': 'picture',
        'assetId': 'pic-11',
        'asset': null,
      });
      expect(item.assetType, 'picture');
      expect(item.parentEventId, isNull);
    });

    test('an event is not given itself as a parent', () {
      // `firstOf(asset, ['eventId'...])` would happily read an event's own id
      // back out of it. An event is its own album, not a child of one.
      final item = SavedItem.fromJson({
        'id': 'rec-e1',
        'assetType': 'event',
        'assetId': 'evt-50',
        'asset': {
          'event': {'id': 'evt-50', 'eventName': 'Gala'}
        },
      });
      expect(item.parentEventId, isNull);
    });
  });
}
