/// My Events: the albums somebody owns, and saving them.
///
/// Ownership is not purchase. An owner has bought nothing — `PaidImage` is
/// empty for them — and still gets every frame at full resolution with no
/// watermark. The two rights are decided server-side; what is pinned here is
/// that the client asks the right endpoints and saves the right URL.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/user_profile/data/album_download.dart';
import 'package:jperg_app/features/user_profile/data/owned_events.dart';

OwnedPhoto _photo({
  String id = 'p1',
  String url = 'https://cdn/wm/p1.jpg',
  String original = 'https://cdn/orig/p1.jpg',
  String type = 'image',
}) =>
    OwnedPhoto(id: id, url: url, originalUrl: original, mediaType: type);

void main() {
  group('what a download writes', () {
    test('saves the original, not the watermarked render', () {
      // The whole point of the feature. `url` is the badged copy the grid
      // draws; saving it would hand an owner a watermark on their own
      // wedding photos.
      expect(_photo().downloadUrl, 'https://cdn/orig/p1.jpg');
    });

    test('falls back to the display copy when there is no original', () {
      // A row whose originalUrl came back empty. A watermarked photo beats a
      // silent failure in the middle of a batch of sixty.
      expect(_photo(original: '').downloadUrl, 'https://cdn/wm/p1.jpg');
    });

    test('knows a video from a photo', () {
      // They take different save calls — an image record for one, a file
      // record for the other — and a video saved as an image lands in the
      // gallery as something the photo app will not play.
      expect(_photo(type: 'video').isVideo, isTrue);
      expect(_photo().isVideo, isFalse);
    });
  });

  group('parsing what the server sends', () {
    test('reads an album', () {
      final event = OwnedEvent.fromJson({
        'id': 'e1',
        'eventName': 'Richard Wedding',
        'url': 'https://cdn/cover.jpg',
        'photoCount': 24,
        'eventDate': '2026-05-02T00:00:00+00:00',
      });

      expect(event, isNotNull);
      expect(event!.name, 'Richard Wedding');
      expect(event.photoCount, 24);
      expect(event.eventDate?.year, 2026);
    });

    test('an album with no cover is still an album', () {
      // The cover is optional at creation, so this is a real state and not a
      // malformed row — it draws a placeholder tile rather than vanishing.
      final event = OwnedEvent.fromJson({'id': 'e1', 'eventName': 'Shoot'});

      expect(event, isNotNull);
      expect(event!.coverUrl, '');
      expect(event.photoCount, 0);
    });

    test('a row with no id is dropped', () {
      expect(OwnedEvent.fromJson({'eventName': 'Nameless'}), isNull);
      expect(OwnedEvent.fromJson('not a map'), isNull);
    });

    test('a photo with neither url is dropped', () {
      // Nothing to draw and nothing to save.
      expect(
        OwnedPhoto.fromJson({'id': 'p1', 'url': '', 'originalUrl': ''}),
        isNull,
      );
    });

    test('a photo with only an original survives', () {
      final photo =
          OwnedPhoto.fromJson({'id': 'p1', 'originalUrl': 'https://cdn/o.jpg'});

      expect(photo, isNotNull);
      expect(photo!.downloadUrl, 'https://cdn/o.jpg');
    });
  });

  group('progress', () {
    test('is indeterminate before there is anything to measure', () {
      // Null, not zero: a bar sitting at 0% looks stuck, where an
      // indeterminate one reads as starting.
      const p = AlbumDownloadProgress(running: true);
      expect(p.fraction, isNull);
    });

    test('counts failures towards done, so the bar still reaches the end', () {
      // One unreachable photo in sixty must not leave the bar stalled at 59
      // for ever — the run finished, and the failure is reported separately.
      const p = AlbumDownloadProgress(total: 10, saved: 7, failed: 3);
      expect(p.done, 10);
      expect(p.fraction, 1.0);
    });

    test('idle until a run starts, finished once one has', () {
      const idle = AlbumDownloadProgress();
      expect(idle.isIdle, isTrue);
      expect(idle.finished, isFalse);

      const done = AlbumDownloadProgress(total: 3, saved: 3);
      expect(done.isIdle, isFalse);
      expect(done.finished, isTrue);
    });

    test('a run in flight is neither idle nor finished', () {
      const running = AlbumDownloadProgress(total: 5, saved: 1, running: true);
      expect(running.isIdle, isFalse);
      expect(running.finished, isFalse);
      expect(running.fraction, 0.2);
    });
  });

  group('the downloader is shared, not owned by a screen', () {
    tearDown(AlbumDownloader.instance.reset);

    test('progress is readable without any widget alive', () {
      // This is what lets the album screen be left mid-run: the state lives
      // on the singleton, so the profile tab underneath can draw the same
      // bar and coming back finds the run still going.
      expect(AlbumDownloader.progress.value.isIdle, isTrue);
    });

    test('an empty album finishes rather than hanging', () async {
      final result = await AlbumDownloader.instance.downloadAll(
        const [],
        eventId: 'e1',
        eventName: 'Empty',
      );

      expect(result.running, isFalse);
      expect(result.total, 0);
    });

    test('cancelling an idle downloader does nothing', () {
      AlbumDownloader.instance.cancel();
      expect(AlbumDownloader.progress.value.cancelled, isFalse);
    });
  });
}
