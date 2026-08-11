import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Choosing what to buy, in both of the screens that do it.
///
/// The two are mirror images and the difference is the whole point:
/// **browsing** an album from the Found tab starts with nothing selected, and
/// **reviewing** what a scan turned up starts with everything selected. Get
/// the default backwards and the browsing screen quietly proposes to charge
/// someone for every photo they scrolled past.
///
/// The other rule worth pinning: an already-owned photo is never in the total,
/// in either mode. Re-charging for a photo someone has bought is the failure
/// that costs real money and real trust.
Photo _photo(
  String id, {
  double price = 0,
  bool purchased = false,
}) {
  return Photo(
    id,
    'Praise Reloaded 2026',
    'img_$id',
    'https://example.com/$id.jpg',
    'photographer-1',
    price,
    '',
    null,
    false,
    eventId: 'event-1',
    isPurchased: purchased,
  );
}

void main() {
  group('PhotoSelection — review screen (after a scan)', () {
    test('everything starts selected', () {
      final s = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
        _photo('c'),
      ]);

      expect(s.isSelected('a'), isTrue);
      expect(s.isSelected('b'), isTrue);
      expect(s.isSelected('c'), isTrue);
      expect(s.paidCount, 2);
      expect(s.freeCount, 1);
      expect(s.total, 40);
    });

    test('toggling removes a photo and its price from the total', () {
      final s = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      s.toggle('a');

      expect(s.isSelected('a'), isFalse);
      expect(s.paidCount, 1);
      expect(s.total, 20);
    });

    test('toggling twice puts it back', () {
      final s = PhotoSelection(reviewMode: true, photos: [_photo('a', price: 20)]);

      s.toggle('a');
      s.toggle('a');

      expect(s.isSelected('a'), isTrue);
      expect(s.total, 20);
    });

    test('already-purchased photos are never charged for again', () {
      final s = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('owned', price: 20, purchased: true),
      ]);

      expect(s.paidCount, 1);
      expect(s.total, 20, reason: 'the owned photo must not be re-charged');
      expect(s.paid.map((p) => p.id), ['a']);
    });

    test('free photos are counted apart from paid ones', () {
      final s = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('f1'),
        _photo('f2'),
      ]);

      expect(s.paidCount, 1);
      expect(s.freeCount, 2);
      expect(s.free.map((p) => p.id), ['f1', 'f2']);
      // The free ones cost nothing, so they must not move the amount charged.
      expect(s.total, 20);
    });

    test('deselecting a free photo drops it from the free save', () {
      final s = PhotoSelection(reviewMode: true, photos: [_photo('f1'), _photo('f2')]);

      s.toggle('f1');

      expect(s.freeCount, 1);
      expect(s.free.map((p) => p.id), ['f2']);
    });

    test('clear puts everything back rather than emptying it', () {
      // "Clear" on a preselected screen means "undo my exclusions" — the
      // opposite of what it means on an opt-in basket, and getting this
      // backwards would silently drop someone's whole purchase.
      final s = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      s.toggle('a');
      expect(s.paidCount, 1);

      s.clear();
      expect(s.paidCount, 2);
      expect(s.total, 40);
    });

    test('deselections survive more photos paging in', () {
      final s = PhotoSelection(reviewMode: true, photos: [_photo('a', price: 20)]);
      s.toggle('a');

      s.updatePhotos([
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      expect(s.isSelected('a'), isFalse,
          reason: 'scrolling must not undo a "not me"');
      expect(s.paidCount, 1);
      expect(s.total, 20);
    });

    test('hasPurchase is false when only free photos remain', () {
      final s = PhotoSelection(reviewMode: true, photos: [_photo('a', price: 20), _photo('f')]);

      s.toggle('a');

      expect(s.hasPurchase, isFalse);
      expect(s.hasAnything, isTrue, reason: 'there is still a free save to do');
    });

    test('nothing left when every match is marked not me', () {
      final s = PhotoSelection(reviewMode: true, photos: [_photo('a', price: 20), _photo('f')]);

      s.toggle('a');
      s.toggle('f');

      expect(s.hasAnything, isFalse);
      expect(s.total, 0);
    });

    test('notifies listeners when the selection changes', () {
      final s = PhotoSelection(reviewMode: true, photos: [_photo('a', price: 20)]);
      var notifications = 0;
      s.addListener(() => notifications++);

      s.toggle('a');
      expect(notifications, 1);

      // Nothing to undo — no notification, so the bar does not repaint for a
      // no-op.
      s.clear();
      expect(notifications, 2);
      s.clear();
      expect(notifications, 2);
    });
  });

  group('PhotoSelection — browsing an album from the Found tab', () {
    test('nothing is selected until it is chosen', () {
      final s = PhotoSelection(photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
        _photo('c'),
      ]);

      expect(s.isSelected('a'), isFalse);
      expect(s.paidCount, 0);
      expect(s.freeCount, 0);
      expect(s.total, 0);
      expect(s.hasAnything, isFalse,
          reason: 'no bar should appear on an untouched album');
    });

    test('tapping a photo adds it and its price', () {
      final s = PhotoSelection(photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      s.toggle('a');

      expect(s.isSelected('a'), isTrue);
      expect(s.isSelected('b'), isFalse);
      expect(s.paidCount, 1);
      expect(s.total, 20);
    });

    test('tapping twice takes it back out', () {
      final s = PhotoSelection(photos: [_photo('a', price: 20)]);

      s.toggle('a');
      s.toggle('a');

      expect(s.isSelected('a'), isFalse);
      expect(s.total, 0);
    });

    test('clear empties rather than fills', () {
      // The same word, the opposite operation — because in both modes it means
      // "undo what I did on this screen".
      final s = PhotoSelection(photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      s.toggle('a');
      s.toggle('b');
      expect(s.paidCount, 2);

      s.clear();
      expect(s.paidCount, 0);
      expect(s.total, 0);
    });

    test('choices survive more photos paging in', () {
      final s = PhotoSelection(photos: [_photo('a', price: 20)]);
      s.toggle('a');

      s.updatePhotos([_photo('a', price: 20), _photo('b', price: 20)]);

      expect(s.isSelected('a'), isTrue);
      expect(s.isSelected('b'), isFalse,
          reason: 'a photo that just arrived was never chosen');
      expect(s.total, 20);
    });

    test('an owned photo cannot be added even by tapping it', () {
      final s = PhotoSelection(photos: [_photo('owned', price: 20, purchased: true)]);

      s.toggle('owned');

      expect(s.paidCount, 0);
      expect(s.total, 0);
    });

    test('a chosen free photo is saved but never charged for', () {
      final s = PhotoSelection(photos: [_photo('f')]);

      s.toggle('f');

      expect(s.freeCount, 1);
      expect(s.total, 0);
      expect(s.hasPurchase, isFalse);
      expect(s.hasAnything, isTrue);
    });
  });
}
