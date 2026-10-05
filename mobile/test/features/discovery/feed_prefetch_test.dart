/// What the feed decides to get ready, and when it asks for more.
///
/// The effects are untestable here — `precacheImage` wants a real HTTP stack —
/// so what is pinned is the arithmetic, which is where this kind of code goes
/// wrong: an off-by-one that warms the card already on screen, a trigger that
/// counts its own loading spinner and so never stops asking, a video URL handed
/// to an image loader.
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/presentation/utils/feed_prefetch.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// A Cloudinary image, which is what a photo slide warms.
const _photoUrl =
    'https://res.cloudinary.com/demo/image/upload/v1/sample.jpg';

/// A Cloudinary video, whose *poster* is what a video slide warms.
const _videoUrl =
    'https://res.cloudinary.com/demo/video/upload/v1/clip.mp4';

/// A video somewhere else, which has no derivable still.
const _foreignVideoUrl = 'https://example.com/clip.mp4';

EventPicture _pic(String url, {MediaType type = MediaType.photo}) =>
    EventPicture(
      id: url,
      url: url,
      imageId: url,
      price: 0,
      mediaType: type,
      owner: false,
      likeCount: 0,
      commentCount: 0,
      isLikedByUser: false,
      commentsEnabled: true,
      isPurchased: false,
    );

String? _warm(EventPicture picture) => warmableUrl(
      picture,
      logicalWidth: 400,
      devicePixelRatio: 2,
    );

void main() {
  group('which slides are neighbours', () {
    test('both sides of the active one', () {
      // Backwards too: a carousel is swiped back as often as forward, and the
      // slide behind has usually been evicted by the time somebody returns.
      expect(neighbourIndices(2, 5), unorderedEquals([1, 3]));
    });

    test('the active slide is never one of them', () {
      expect(neighbourIndices(2, 5), isNot(contains(2)));
    });

    test('the first slide has only a slide after it', () {
      expect(neighbourIndices(0, 5), [1]);
    });

    test('the last slide has only a slide before it', () {
      expect(neighbourIndices(4, 5), [3]);
    });

    test('a lone slide has no neighbours', () {
      expect(neighbourIndices(0, 1), isEmpty);
    });

    test('an empty carousel asks for nothing', () {
      expect(neighbourIndices(0, 0), isEmpty);
    });

    test('a wider radius reaches further, still clamped', () {
      expect(neighbourIndices(2, 5, radius: 2), unorderedEquals([0, 1, 3, 4]));
      expect(neighbourIndices(0, 3, radius: 2), unorderedEquals([1, 2]));
    });
  });

  group('what a slide warms', () {
    test('a photo warms itself', () {
      expect(_warm(_pic(_photoUrl)), _photoUrl);
    });

    test('a video warms a still, never the clip', () {
      // Handing an .mp4 to an image loader downloads the whole clip in order
      // to fail on it — the exact opposite of getting ahead.
      final warmed = _warm(_pic(_videoUrl, type: MediaType.video));

      expect(warmed, isNotNull);
      expect(warmed, isNot(contains('.mp4')));
      expect(warmed, contains('so_0'), reason: 'the frame at second zero');
    });

    test('a video recognised only by its url still warms a still', () {
      // mediaType is absent on older records; EventPicture.isVideo falls back
      // to the url, and this has to follow it or those slides fetch an mp4.
      final warmed = _warm(_pic(_videoUrl));

      expect(warmed, isNot(contains('.mp4')));
    });

    test('a video we cannot derive a still for warms nothing', () {
      expect(_warm(_pic(_foreignVideoUrl, type: MediaType.video)), isNull);
    });
  });

  group('the urls a carousel warms', () {
    List<String> warmFor(List<EventPicture> pics, int current) => urlsToWarm(
          pics,
          current,
          logicalWidth: 400,
          devicePixelRatio: 2,
        );

    test('the slide either side, and not the one on screen', () {
      final pics = [
        _pic('https://res.cloudinary.com/demo/image/upload/a.jpg'),
        _pic('https://res.cloudinary.com/demo/image/upload/b.jpg'),
        _pic('https://res.cloudinary.com/demo/image/upload/c.jpg'),
      ];

      final warmed = warmFor(pics, 1);

      expect(warmed, hasLength(2));
      expect(warmed, isNot(contains(pics[1].url)));
    });

    test('the same photo twice is warmed once', () {
      // One event can legitimately carry the same picture twice; warming it
      // twice is a wasted decode, not a second copy.
      final pics = [_pic(_photoUrl), _pic('other'), _pic(_photoUrl)];

      // Both neighbours are the same photo, so one warm, not two.
      expect(warmFor(pics, 1), [_photoUrl]);
    });

    test('a video neighbour contributes its still', () {
      final pics = [
        _pic(_photoUrl),
        _pic(_videoUrl, type: MediaType.video),
      ];

      final warmed = warmFor(pics, 0);

      expect(warmed, hasLength(1));
      expect(warmed.single, isNot(contains('.mp4')));
    });

    test('a neighbour with no derivable still contributes nothing', () {
      final pics = [
        _pic(_photoUrl),
        _pic(_foreignVideoUrl, type: MediaType.video),
      ];

      expect(warmFor(pics, 0), isEmpty);
    });

    test('a single-slide carousel warms nothing', () {
      expect(warmFor([_pic(_photoUrl)], 0), isEmpty);
    });
  });

  group('when another page is asked for', () {
    bool ask({
      required double edge,
      int itemCount = 20,
      bool hasMore = true,
      bool isLoading = false,
    }) =>
        shouldLoadMore(
          leadingEdge: edge,
          itemCount: itemCount,
          hasMore: hasMore,
          isLoading: isLoading,
        );

    test('not at the top of a full feed', () {
      expect(ask(edge: 0), isFalse);
    });

    test('once the runway runs short', () {
      // 20 cards, 5 of lookahead: card 14 is the last index, so the ask starts
      // there and not at the end of the list.
      expect(ask(edge: 13), isFalse);
      expect(ask(edge: 14), isTrue);
    });

    test('a part-finished drag counts as having arrived', () {
      // The whole point of taking a fractional page rather than the settled
      // index. A reader 30% off card 13 is going to card 14, and card 14 is
      // where the ask begins — so it goes out now rather than when the swipe
      // lands. Comparing the raw fraction would not: 13.3 is still short, and
      // a drag only reaches 14.0 as it settles, which is too late to help.
      expect(ask(edge: 13.0), isFalse, reason: 'settled on 13, not yet');
      expect(ask(edge: 13.3), isTrue, reason: 'heading for 14');
    });

    test('never while a page is already in flight', () {
      // Scroll updates fire many times a second; without this the feed would
      // queue a dozen requests for the same page.
      expect(ask(edge: 18, isLoading: true), isFalse);
    });

    test('never when the feed has run out', () {
      expect(ask(edge: 18, hasMore: false), isFalse);
    });

    test('an empty feed asks for nothing', () {
      // It is the initial load's job to fill an empty feed. Asking from here
      // would race it, and `leadingEdge + lookahead >= -1` is true of every
      // position — so without the guard an empty feed asks forever.
      expect(ask(edge: 0, itemCount: 0), isFalse);
    });

    test('a feed shorter than the lookahead asks straight away', () {
      // Three cards and five of runway: there is nothing to wait for.
      expect(ask(edge: 0, itemCount: 3), isTrue);
    });

    test('a deeper lookahead asks earlier', () {
      bool askWith(int lookahead) => shouldLoadMore(
            leadingEdge: 10,
            itemCount: 20,
            hasMore: true,
            isLoading: false,
            lookahead: lookahead,
          );

      expect(askWith(5), isFalse);
      expect(askWith(9), isTrue);
    });
  });
}
