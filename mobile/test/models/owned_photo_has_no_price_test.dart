import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// A photo you already own does not quote you a price.
///
/// The amount only means anything as a thing to pay. On something already paid
/// for it reads as a second charge, so every surface hides it — and every
/// surface can only do that if the flag survives the parse. It did not: one of
/// the three parsers dropped it, and the screens fed by that one went on
/// selling photos back to the people who had bought them.
void main() {
  group('the flag survives parsing', () {
    test('Photo.fromMap reads it — the Found payload', () {
      final photo = Photo.fromMap({
        'id': 'p1',
        'url': 'https://x/p1.jpg',
        'price': 20,
        'isPurchased': true,
      });

      expect(photo.isPurchased, isTrue);
    });

    test('Photo.fromMap2 reads it — the search-images stream', () {
      // The regression this file exists for. fromMap2 never read the field, so
      // every photo off that stream claimed to be unowned however many times
      // it had been bought.
      final photo = Photo.fromMap2(_streamRow(purchased: true));

      expect(photo.isPurchased, isTrue);
    });

    test('EventPicture reads it — the discovery feed', () {
      final picture = EventPicture.fromMap({
        'id': 'p1',
        'url': 'https://x/p1.jpg',
        'price': 20,
        'isPurchased': true,
      });

      expect(picture.isPurchased, isTrue);
    });

    test('snake_case is accepted too', () {
      // The endpoints are not consistent about it, and a field read under one
      // spelling only is a field that is silently false under the other.
      expect(Photo.fromMap({'is_purchased': true}).isPurchased, isTrue);
      expect(
        Photo.fromMap2(_streamRow(snakeCase: true)).isPurchased,
        isTrue,
      );
      expect(EventPicture.fromMap({'is_purchased': true}).isPurchased, isTrue);
    });

    test('absent means not owned, not owned-by-default', () {
      expect(Photo.fromMap({'price': 20}).isPurchased, isFalse);
      expect(Photo.fromMap2(_streamRow()).isPurchased, isFalse);
      expect(EventPicture.fromMap({'price': 20}).isPurchased, isFalse);
    });
  });

  group('the discovery feed hands ownership to the viewer', () {
    test('photosOfEvent carries it', () {
      // The feed's grid shows no price, but the viewer it opens into does —
      // so dropping the flag here would offer to sell a photo already owned.
      final event = EventDiscovery.fromMap({
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'pictures': [
          {
            'id': 'p1',
            'url': 'https://x/p1.jpg',
            'price': 20,
            'isPurchased': true
          },
          {'id': 'p2', 'url': 'https://x/p2.jpg', 'price': 20},
        ],
      });

      final photos = photosOfEvent(event);

      expect(photos.firstWhere((p) => p.id == 'p1').isPurchased, isTrue);
      expect(photos.firstWhere((p) => p.id == 'p2').isPurchased, isFalse);
    });
  });
}

/// One row as the search-images stream sends it.
///
/// [Photo.fromMap2] reaches into `event` without guarding, so a fixture has to
/// carry one — which is itself worth knowing about that parser.
Map<String, dynamic> _streamRow({
  bool purchased = false,
  bool snakeCase = false,
}) =>
    {
      'id': 'p1',
      'imageId': 'img-p1',
      'url': 'https://x/p1.jpg',
      'price': 20,
      'public': true,
      'event': {
        'id': 'evt-1',
        'eventName': 'Praise Reloaded 2026',
        'eventDate': '',
        'userId': 'photographer-1',
      },
      if (purchased && !snakeCase) 'isPurchased': true,
      if (snakeCase) 'is_purchased': true,
    };
