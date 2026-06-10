import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/discovery/data/datasources/client_saved_data_source.dart';

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
}
