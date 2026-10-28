/// Getting the next thing ready before somebody asks for it.
///
/// The feed is a pager: one card fills the screen, the next is a swipe away,
/// and until this file existed neither the card below nor the slide to either
/// side was touched until it arrived. On a fast connection that reads as
/// instant. On a slow one it is the whole experience — swipe, wait, swipe,
/// wait — and the wait is entirely avoidable, because the app knew what was
/// coming next several seconds earlier.
///
/// Two separate things are prepared, and they are not prepared the same way:
///
///   **Images** are warmed through [JpergImage.precache], which assembles the
///   very provider the widget will later look up. Cheap, bounded by the global
///   [ImageCache]'s own byte budget, and invisible if it fails.
///
///   **Videos are never warmed.** [JpergVideoPlayer] initialises its controller
///   from `initState`, unconditionally — so merely *building* one allocates a
///   platform decoder, and devices have few of those. A video slide gets its
///   poster still warmed instead: the frame paints immediately on arrival and
///   the decoder starts only once the slide is actually being watched.
///
/// Nothing here builds a widget. Warming is strictly "have the bytes decoded
/// and in the cache"; the card below is still constructed when it is scrolled
/// to, it just has nothing left to wait for.
///
/// The decisions are pure functions — [urlsToWarm], [neighbourIndices] and
/// [shouldLoadMore] — because the effects are untestable (precacheImage wants a
/// real HTTP stack) and the arithmetic is where the mistakes are.
import 'package:flutter/widgets.dart';

import 'package:jperg_app/core/utils/media_transform.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// How many cards past the one on screen the pager asks for more.
///
/// Was two, which is two swipes of runway — on a slow connection a page takes
/// longer to arrive than two swipes take to perform, so the reader caught up
/// with the loader and watched a spinner. Five is roughly a second and a half
/// of fast scrolling, which is enough for a request to land, and it costs
/// nothing when the connection is quick: the page would have been fetched
/// anyway, just later.
const int kFeedLoadMoreLookahead = 5;

/// How many cards *below* the active one have their first image warmed.
///
/// Three. It was one, and one was right at the time: every photo was fetched
/// at full resolution — a camera-sized file, often several megabytes — so each
/// extra warm-up was competing for bandwidth with the card actually on screen.
/// Warming further ahead would have made scrolling *worse*.
///
/// The ladder changed the arithmetic. A feed-sized rung is on the order of a
/// hundred kilobytes (see `main/app/services/derivatives.py`), so three of them
/// cost less than one old original, and three cards is roughly what a fast
/// flick covers before the finger lifts — which is the gesture one-ahead could
/// never keep up with.
///
/// Still not a general prefetcher: every warmed image is decoded bytes held in
/// the global `ImageCache`, which evicts the photo being looked at to make room.
const int kFeedWarmAhead = 3;

/// How far either side of the active slide a carousel warms. One in each
/// direction: a horizontal swipe reaches exactly one slide.
const int kCarouselWarmRadius = 1;

/// Which slide indices to warm around [current], clamped to the list.
///
/// Both directions, because a carousel is swiped back as often as forward —
/// and the slide behind has usually been evicted by the time somebody returns
/// to it.
List<int> neighbourIndices(
  int current,
  int length, {
  int radius = kCarouselWarmRadius,
}) {
  if (length <= 0 || radius <= 0) return const [];
  final out = <int>[];
  for (var offset = 1; offset <= radius; offset++) {
    for (final index in [current - offset, current + offset]) {
      if (index >= 0 && index < length && index != current) out.add(index);
    }
  }
  return out;
}

/// The URL to warm for one picture, or null if there is nothing worth warming.
///
/// A photo warms itself. A video warms its poster — the still Cloudinary
/// renders from frame zero — and never its own URL: handing an `.mp4` to an
/// image loader downloads the clip to fail on it, which is the opposite of
/// what this is for. A video that is not on Cloudinary has no derivable
/// poster, so it warms nothing and shows its backdrop on arrival as before.
String? warmableUrl(
  EventPicture picture, {
  required double logicalWidth,
  required double devicePixelRatio,
}) {
  if (!picture.isVideo) return picture.url;
  return MediaTransform.videoPoster(
    picture.url,
    displayWidth: logicalWidth,
    devicePixelRatio: devicePixelRatio,
    ladder: picture.ladder,
  );
}

/// One thing worth warming: the URL, and the ladder the widget will later ask
/// with.
///
/// The pair travels together because [JpergImage.precache] has to be handed the
/// same ladder the widget will pass. Warming the original and then requesting a
/// rung — or the reverse — are two different objects, so the warm-up is a
/// wasted download rather than a fast first frame.
typedef WarmTarget = ({String url, ImageLadder ladder});

/// Every target worth warming for a carousel sitting on [current].
///
/// Deduplicated by URL: the same photo can legitimately appear twice in one
/// event, and warming it twice is a wasted decode rather than a second copy.
List<WarmTarget> urlsToWarm(
  List<EventPicture> pictures,
  int current, {
  required double logicalWidth,
  required double devicePixelRatio,
  int radius = kCarouselWarmRadius,
}) {
  final seen = <String>{};
  final out = <WarmTarget>[];
  for (final index in neighbourIndices(current, pictures.length, radius: radius)) {
    final picture = pictures[index];
    final url = warmableUrl(
      picture,
      logicalWidth: logicalWidth,
      devicePixelRatio: devicePixelRatio,
    );
    if (url == null || !seen.add(url)) continue;
    // A photo's URL still has to be turned into a rung, so it carries its
    // ladder. A video's poster URL came back from `warmableUrl` already
    // resolved to one — handing the ladder on would try to pick a rung of a
    // rung, so the pair is deliberately empty.
    out.add((url: url, ladder: picture.isVideo ? ImageLadder.none : picture.ladder));
  }
  return out;
}

/// Whether a pager sitting at [leadingEdge] should be asking for another page.
///
/// [leadingEdge] is a *fractional* page — `PageController.page` mid-drag — not
/// the settled index, and it is **rounded up**. That rounding is the whole
/// mechanism, not a detail: a reader 30% of the way off card 13 is going to
/// card 14, and counting them as already there fires the request a full card
/// before `onPageChanged` would. Comparing the raw fraction instead buys
/// almost nothing, because a drag only reaches 14.0 at the moment it lands,
/// which is when the settled callback fires anyway.
///
/// Rounding up is also why a settled caller can share this function: it passes
/// a whole number, where the ceiling changes nothing, so the backstop keeps
/// exactly the behaviour it had.
///
/// [itemCount] counts what the pager can actually scroll to. Callers that pad
/// their list with a trailing spinner must not include it, or the feed asks
/// for more because of a widget that only exists because it asked.
bool shouldLoadMore({
  required double leadingEdge,
  required int itemCount,
  required bool hasMore,
  required bool isLoading,
  int lookahead = kFeedLoadMoreLookahead,
}) {
  // An empty pager is the initial load's job. Without this guard every
  // position satisfies the comparison below and the feed asks forever.
  if (!hasMore || isLoading || itemCount <= 0) return false;
  final heading = leadingEdge.ceil();
  return heading + lookahead >= itemCount - 1;
}

/// Warm the first frame of each of the next [ahead] cards.
///
/// The first picture only. It is the one the card opens on, and the rest of
/// that event's carousel is warmed by the carousel itself once the card is
/// in front of somebody.
///
/// Fire-and-forget by design: a warm-up that loses a race with the swipe it
/// was meant to beat has simply not helped, and must not make anything wait.
void warmNextCards(
  BuildContext context,
  List<EventDiscovery> events,
  int current, {
  int ahead = kFeedWarmAhead,
}) {
  final end = (current + ahead + 1).clamp(0, events.length);
  final start = (current + 1).clamp(0, end);
  warmEventFirstFrames(context, events.sublist(start, end));
}

/// Warm the opening frame of each of [events].
///
/// Takes the events rather than an index, because the three feeds do not agree
/// on what an index means: Home interleaves ads and requests into its pager,
/// Following interleaves creator-suggestion cards, and only Discovery's page
/// number is an event number. Each of them knows how to find the next *event*
/// in its own list; none of them should have to explain that here.
void warmEventFirstFrames(
  BuildContext context,
  Iterable<EventDiscovery> events,
) {
  if (!context.mounted) return;
  final width = MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);

  for (final event in events) {
    if (event.pictures.isEmpty) continue;
    final picture = event.pictures.first;
    final url = warmableUrl(
      picture,
      logicalWidth: width,
      devicePixelRatio: dpr,
    );
    if (url == null) continue;
    JpergImage.precache(
      context,
      url,
      logicalWidth: width,
      // The same ladder the card will pass, or the warmed object and the
      // requested one are different URLs and nothing was gained. A video's
      // poster URL is already a rung — see `urlsToWarm`.
      ladder: picture.isVideo ? ImageLadder.none : picture.ladder,
    );
  }
}

/// Warm the slides either side of [current] in one event's carousel.
void warmCarouselNeighbours(
  BuildContext context,
  List<EventPicture> pictures,
  int current, {
  int radius = kCarouselWarmRadius,
}) {
  if (!context.mounted || pictures.length < 2) return;
  final width = MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);

  for (final target in urlsToWarm(
    pictures,
    current,
    logicalWidth: width,
    devicePixelRatio: dpr,
    radius: radius,
  )) {
    JpergImage.precache(context, target.url,
        logicalWidth: width, ladder: target.ladder);
  }
}
