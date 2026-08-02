import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

/// Tapping a photo in an event now opens the same viewer the Found tab, the
/// album page and search open, instead of one only this screen had. That
/// viewer speaks [Photo], while an event carries [EventPicture] plus its own
/// metadata, so everything it credits the photo to has to survive the mapping.
///
/// Only the mapping is covered here. Mounting the page itself is impractical:
/// it fires a view-tracking POST on mount, and Dio leaves a timer pending that
/// the test binding fails on even with the adapter stubbed out.
EventDiscovery event({
  bool eventComments = true,
  bool pictureComments = true,
  List<Map<String, dynamic>>? pictures,
}) =>
    EventDiscovery.fromMap({
      'id': 'evt-1',
      'eventName': 'Fomula1',
      'comments_enabled': eventComments,
      'user': const {
        'id': 'ph-1',
        'name': 'mpiqw',
        'profile_url': 'https://cdn.example.com/avatar.jpg',
      },
      'pictures': pictures ??
          [
            {
              'id': 'pic-0',
              'url': 'https://cdn.example.com/pic-0.jpg',
              'imageId': 'img-0',
              'price': 40,
              'likeCount': 206,
              'comment_count': 10,
              'isLikedByUser': true,
              'comments_enabled': pictureComments,
              'width': 3000,
              'height': 2000,
            },
          ],
    });

void main() {
  test('a picture keeps its own identity and counts', () {
    final photo = photosOfEvent(event()).single;

    expect(photo.id, 'pic-0');
    expect(photo.imageId, 'img-0');
    expect(photo.url, 'https://cdn.example.com/pic-0.jpg');
    expect(photo.price, 40);
    expect(photo.likeCount, 206);
    expect(photo.commentCount, 10);
    expect(photo.isLikedByUser, isTrue);
  });

  test('the event supplies what the viewer credits the photo to', () {
    final photo = photosOfEvent(event()).single;

    expect(photo.eventId, 'evt-1');
    expect(photo.eventName, 'Fomula1');
    expect(photo.photographerName, 'mpiqw');
    expect(photo.photographerAvatarUrl, 'https://cdn.example.com/avatar.jpg');
  });

  test('dimensions carry over so the viewer boxes to the real shape', () {
    final photo = photosOfEvent(event()).single;

    expect(photo.width, 3000);
    expect(photo.height, 2000);
    expect(photo.aspectRatio, closeTo(1.5, 0.001));
  });

  test('feed photos are public, so the badge reads Public', () {
    expect(photosOfEvent(event()).single.isPublic, isTrue);
  });

  group('comments are off if either switch is off', () {
    test('both on', () {
      expect(photosOfEvent(event()).single.commentsEnabled, isTrue);
    });

    test('the event is silenced', () {
      expect(photosOfEvent(event(eventComments: false)).single.commentsEnabled,
          isFalse);
    });

    test('the single picture is silenced', () {
      expect(
          photosOfEvent(event(pictureComments: false)).single.commentsEnabled,
          isFalse);
    });
  });

  test('a clip maps to a video, so the viewer plays it instead of decoding it',
      () {
    final photos = photosOfEvent(event(pictures: [
      {
        'id': 'clip',
        'url': 'https://res.cloudinary.com/x/video/upload/v1/e/clip.mp4',
        'mediaType': 'video',
        'duration_seconds': 12.5,
      },
      {'id': 'still', 'url': 'https://cdn.example.com/still.jpg'},
    ]));

    expect(photos.first.isVideo, isTrue);
    expect(photos.first.durationSeconds, 12.5);
    expect(photos.last.isVideo, isFalse);
  });

  test('order is preserved, so a tapped index lands on the tapped photo', () {
    final photos = photosOfEvent(event(pictures: [
      for (var i = 0; i < 5; i++)
        {'id': 'pic-$i', 'url': 'https://cdn.example.com/pic-$i.jpg'},
    ]));

    expect([for (final p in photos) p.id],
        ['pic-0', 'pic-1', 'pic-2', 'pic-3', 'pic-4']);
  });

  test('an event with no pictures maps to nothing', () {
    expect(photosOfEvent(event(pictures: [])), isEmpty);
  });
}
