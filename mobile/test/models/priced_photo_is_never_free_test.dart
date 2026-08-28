import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// A price the photographer set is a price, whatever the photo's visibility.
///
/// Being recognised in a photo is what lets somebody *see* it — `public: false`
/// says who may look, not who may have it for nothing. The split that decides
/// bought-vs-saved reads the price and only the price, so anything that loses
/// the price gives the photo away.
void main() {
  EventPicture picture(num price) => EventPicture.fromMap({
        'id': 'p1',
        'url': 'https://x/p1.jpg',
        'imageId': 'i1',
        'price': price,
      });

  group('EventPicture keeps the pesewas', () {
    test('a price under one unit does not truncate to free', () {
      // The bug: `price` was an int, so 0.50 became 0 — and 0 means free, so
      // the photo was saved for nothing instead of being sold.
      expect(picture(0.50).price, 0.50);
      expect(picture(0.50).price > 0, isTrue,
          reason: 'a photo priced 0.50 must still be a photo that costs money');
    });

    test('a price with pesewas keeps them', () {
      expect(picture(6.27).price, 6.27);
    });

    test('a whole price is unchanged', () {
      expect(picture(10).price, 10.0);
    });

    test('no price at all is free', () {
      expect(EventPicture.fromMap({'id': 'p', 'url': 'u', 'imageId': 'i'}).price, 0.0);
    });
  });

  group('the paid/free split follows the price, not the visibility', () {
    Photo photo(String id, double price, {required bool isPublic}) =>
        Photo(id, 'Event', 'img-$id', 'https://x/$id.jpg', 'owner', price, '',
            null, isPublic);

    test('a private priced photo is charged for, not saved free', () {
      final selection = PhotoSelection(reviewMode: true)
        ..updatePhotos([photo('a', 1.0, isPublic: false)]);

      expect(selection.free, isEmpty,
          reason: 'private is a visibility rule, not a discount');
      expect(selection.paidCount, 1);
      expect(selection.total, 1.0);
    });

    test('a private photo priced under one unit is still charged for', () {
      final selection = PhotoSelection(reviewMode: true)
        ..updatePhotos([photo('a', 0.50, isPublic: false)]);

      expect(selection.free, isEmpty);
      expect(selection.total, 0.50);
    });

    test('an unpriced private photo is the one that is free', () {
      final selection = PhotoSelection(reviewMode: true)
        ..updatePhotos([photo('a', 0, isPublic: false)]);

      expect(selection.paidCount, 0);
      expect(selection.freeCount, 1);
    });

    test('a mixed album splits on price alone', () {
      final selection = PhotoSelection(reviewMode: true)
        ..updatePhotos([
          photo('free-public', 0, isPublic: true),
          photo('free-private', 0, isPublic: false),
          photo('paid-public', 2.5, isPublic: true),
          photo('paid-private', 1.0, isPublic: false),
        ]);

      expect(selection.freeCount, 2);
      expect(selection.paidCount, 2);
      expect(selection.total, 3.5);
    });
  });
}
