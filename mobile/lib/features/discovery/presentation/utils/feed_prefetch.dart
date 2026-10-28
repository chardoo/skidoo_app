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
import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:jperg_app/core/cache/jperg_image_cache.dart';
import 'package:jperg_app/core/utils/media_transform.dart';
import 'package:jperg_app/core/utils/network_quality.dart';
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

/// The most device pixels a feed card ever asks for.
///
/// 1080, which pins a full-bleed card to the 1080 rung. Measured on the live
/// CDN, same photograph:
///
///     rung 1080   204 KB
///     rung 1600   549 KB
///
/// A 393 pt card on a 3x screen is 1179 device pixels, so uncapped selection
/// reaches past 1080 and takes 1600 — 2.7x the bytes, and a larger frame to
/// decode, to avoid a 1.09x upscale that cannot be seen at that density.
///
/// Only the feed is capped. A viewer somebody has deliberately opened and can
/// pinch into passes nothing and gets the rung its slot actually wants.
///
/// This is the **ceiling**, not the answer: [feedMaxPhysicalWidth] lowers it
/// further on a slow connection.
const int kFeedMaxPhysicalWidth = 1080;

/// The cap a feed card should ask with right now.
///
/// [kFeedMaxPhysicalWidth] is as wide as the feed ever goes; this is as wide as
/// *this connection* can afford, measured from the images already fetched — see
/// [NetworkQuality]. On a 3 Mbps mobile link the 1080 rung takes over half a
/// second and the 640 rung takes under a fifth of one, and in a phone-width
/// card the difference in the picture is hard to find.
///
/// One function so warming and rendering cannot disagree: both ask here, and a
/// card warmed at one size must be requested at the same size or the warm-up
/// is a wasted download. (The estimate is deliberately slow to change for the
/// same reason — see `NetworkQuality._hysteresis`.)
int feedMaxPhysicalWidth() {
  final measured = NetworkQuality.instance.feedMaxPhysicalWidth;
  return measured < kFeedMaxPhysicalWidth ? measured : kFeedMaxPhysicalWidth;
}

/// How many cards *below* the active one are warmed at all.
///
/// Fourteen. It was one, then three, then ten, and each was right for what a
/// warm cost at the time: originally every photo was fetched at full
/// resolution — a camera file, 2 MB on average and up to 8 — so each extra
/// warm-up competed with the card on screen and warming deeper made scrolling
/// *worse*.
///
/// Three things have since changed what a warm costs, all measured rather than
/// assumed. A capped feed rung is **204 KB** (see [kFeedMaxPhysicalWidth]). It
/// arrives off a warm Cloudflare edge in **~0.15 s** — `cf-cache-status: HIT`,
/// TTFB ~0.10 s. And no more than [kWarmConcurrency] are ever in flight, so a
/// runway cannot outbid the visible card however deep it goes.
///
/// Fourteen × 204 KB is under 3 MB of speculative traffic, and at three at a
/// time it fills in roughly `14 / 3 × 0.15 s` ≈ 0.7 s — comfortably inside the
/// second and a half a hard flick takes. Past that is waste: it fetches cards
/// a flick does not reach.
///
/// Affordable only because of the split below. Warming is two different
/// operations and only the first [kFeedDecodeAhead] cards pay the expensive
/// one — and only photographs that have a rung are warmed at all, since an
/// un-laddered one is still a multi-megabyte original.
const int kFeedWarmAhead = 14;

/// How many of those cards are decoded into memory, ready to paint.
///
/// Three. This tier is bounded by **memory, not bandwidth**, which is why it
/// did not move with [kFeedWarmAhead]: a decoded 1080-wide frame is roughly
/// `1080 × 1620 × 4` ≈ **7 MB** of RAM, so fourteen would be 98 MB against a
/// 100 MB budget and the `ImageCache` would evict the photo being looked at to
/// hold photos nobody has reached. That is the jank this is meant to remove.
///
/// Three rather than two because the cap above shrank the frame — 7 MB where
/// an uncapped 1179-wide frame was 8.3 MB — and because three is where a flick
/// that lands early stops finding an undecoded card.
///
/// Everything from here to [kFeedWarmAhead] is warmed to **disk** instead, by
/// [warmToDisk]: the bytes are fetched and stored, nothing is decoded, and the
/// cost is a few hundred kilobytes of file rather than megabytes of heap. When
/// the reader arrives, the image loads from local disk — tens of milliseconds,
/// no network — instead of starting a request at the moment it is needed.
const int kFeedDecodeAhead = 3;

/// How far either side of the active slide a carousel decodes into memory.
///
/// One in each direction: a horizontal swipe reaches exactly one slide, and
/// these are full-width frames under the same memory budget as the cards.
const int kCarouselWarmRadius = 1;

/// How far *ahead* in a carousel is warmed to disk.
///
/// Forward only, and further than [kCarouselWarmRadius] reaches. Somebody
/// flicking through an event's photos goes one way, fast, and the slide behind
/// has usually been decoded already on the way past. Disk-warmed, so the depth
/// costs files rather than heap — see [kFeedDecodeAhead].
const int kCarouselDiskAhead = 6;

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

/// Fetch [url] into the disk cache without decoding it.
///
/// The cheap half of warming. `JpergImage.precache` decodes into the global
/// `ImageCache` — megabytes of heap per frame — which is right for a card
/// about to be painted and ruinous for one ten swipes away. This stores the
/// bytes and stops, so a deep runway costs files rather than memory.
///
/// Fire-and-forget, and deliberately silent: a warm-up is an optimisation, and
/// one that fails — offline, a 404, a cancelled scroll — must behave exactly
/// as though it had never been attempted. The error is swallowed rather than
/// logged because a reader flicking past twenty cards would otherwise fill the
/// log with failures that changed nothing.
///
/// The URL must be the *delivery* URL — the rung the widget will later ask
/// for, not the stored original. See [deliveryUrlFor].
void warmToDisk(String url) {
  if (url.isEmpty) return;
  if (!_inFlight.add(url)) return;
  _queue.add(url);
  _pump();
}

/// How many warm-ups may be on the wire at once.
///
/// Three. Not a tuning detail — the whole reason a deep runway is safe.
///
/// These were fired the instant they were decided, one `unawaited` per URL, so
/// a single swipe could put the ten cards ahead *plus* six carousel slides on
/// the wire together: sixteen parallel requests racing the one image the reader
/// is actually waiting for. The visible photo lost that race, and because the
/// carousel will not advance off a slide that has not settled (see
/// `media_readiness.dart`) the reader was then held on it — so a feature meant
/// to remove the wait produced a longer one.
///
/// A queue fixes the ordering rather than the depth: the runway still fills,
/// it just stops competing. Three is enough to keep the connection busy on a
/// phone and few enough to leave room for the fetch that matters.
const int kWarmConcurrency = 3;

final _queue = <String>[];
final _inFlight = <String>{};
var _active = 0;

void _pump() {
  while (_active < kWarmConcurrency && _queue.isNotEmpty) {
    final url = _queue.removeAt(0);
    _active++;
    unawaited(_download(url));
  }
}

Future<void> _download(String url) async {
  final started = DateTime.now();
  try {
    final info = await JpergImageCache.instance.downloadFile(url);
    // What that cost, so the next card can be sized for this connection —
    // see [NetworkQuality]. A cache hit is excluded by the size floor only by
    // luck, so it is excluded explicitly: it measures the disk, not the link.
    final bytes = await info.file.length();
    NetworkQuality.instance.record(
      bytes: bytes,
      elapsed: DateTime.now().difference(started),
    );
  } catch (_) {
    // See warmToDisk: a warm-up that fails must look like one that never ran.
  } finally {
    _active--;
    _inFlight.remove(url);
    _pump();
  }
}

/// Forget what is queued, for tests — the queue is process-wide state.
@visibleForTesting
void resetWarmQueue() {
  _queue.clear();
  _inFlight.clear();
  _active = 0;
}

/// The URL a widget will actually request for [picture] at [logicalWidth].
///
/// The rung, not the stored original — warming one and requesting the other
/// are two different objects, and the warm-up would be a wasted download.
/// Mirrors what `JpergImage` resolves internally.
String? deliveryUrlFor(
  EventPicture picture, {
  required double logicalWidth,
  required double devicePixelRatio,
  int? maxPhysicalWidth,
}) {
  final base = warmableUrl(
    picture,
    logicalWidth: logicalWidth,
    devicePixelRatio: devicePixelRatio,
  );
  if (base == null || base.isEmpty) return null;
  final cap = maxPhysicalWidth ?? feedMaxPhysicalWidth();
  // A video's poster URL came back already resolved to a rung; picking a rung
  // of a rung would produce an object that was never written.
  if (picture.isVideo) return base;
  return MediaTransform.image(
    base,
    displayWidth: logicalWidth,
    devicePixelRatio: devicePixelRatio,
    ladder: picture.ladder,
    maxPhysicalWidth: cap,
  );
}

/// Warm the first frame of each of the next [ahead] cards.
///
/// The first picture only. It is the one the card opens on, and the rest of
/// that event's carousel is warmed by the carousel itself once the card is
/// in front of somebody.
///
/// Two tiers, and the split is the point. The next [decodeAhead] cards are
/// decoded into memory so they paint the instant they arrive; everything
/// behind them to [ahead] is fetched to disk only. The reader who flicks hard
/// past six cards still finds every one of them local — they just spend a
/// decode on arrival instead of a network round trip.
///
/// Fire-and-forget by design: a warm-up that loses a race with the swipe it
/// was meant to beat has simply not helped, and must not make anything wait.
void warmNextCards(
  BuildContext context,
  List<EventDiscovery> events,
  int current, {
  int ahead = kFeedWarmAhead,
  int decodeAhead = kFeedDecodeAhead,
}) {
  final end = (current + ahead + 1).clamp(0, events.length);
  final start = (current + 1).clamp(0, end);
  if (start >= end) return;

  final decodeEnd = (current + decodeAhead + 1).clamp(start, end);
  warmEventFirstFrames(context, events.sublist(start, decodeEnd));

  if (decodeEnd >= end || !context.mounted) return;
  final width = MediaQuery.sizeOf(context).width;
  final dpr = MediaQuery.devicePixelRatioOf(context);
  for (final event in events.sublist(decodeEnd, end)) {
    if (event.pictures.isEmpty) continue;
    final picture = event.pictures.first;
    // A photo with no ladder is fetched at full size — a camera original,
    // ~2 MB and often far more. The depth above is priced for a ~180 KB rung,
    // so warming eight of those is tens of megabytes of speculative traffic
    // for cards the reader may never reach, and it is taken from the card
    // they are looking at right now.
    //
    // This is not a transitional guard. Coverage is whatever the backfill has
    // reached — it was 7% of photographs when this was written — and a feed
    // mixes laddered and un-laddered albums freely, so the depth has to be
    // decided per photograph rather than assumed for all of them. An
    // un-laddered card simply loads when it arrives, exactly as it did before
    // any of this existed.
    if (!picture.ladder.exists) continue;
    final url = deliveryUrlFor(
      picture,
      logicalWidth: width,
      devicePixelRatio: dpr,
    );
    if (url != null) warmToDisk(url);
  }
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
      maxPhysicalWidth: feedMaxPhysicalWidth(),
    );
  }
}

/// Warm the slides either side of [current] in one event's carousel.
///
/// Two tiers, as with the cards. [radius] slides either side are decoded and
/// ready to paint; the next [diskAhead] *forward* are fetched to disk. Forward
/// only for the deep tier, because that is the direction somebody flicking
/// through an event's photos is going — the slide behind was decoded on the
/// way past it.
void warmCarouselNeighbours(
  BuildContext context,
  List<EventPicture> pictures,
  int current, {
  int radius = kCarouselWarmRadius,
  int diskAhead = kCarouselDiskAhead,
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
        logicalWidth: width,
        ladder: target.ladder,
        maxPhysicalWidth: feedMaxPhysicalWidth());
  }

  // Past what the decoded tier reaches, to the end of the run.
  final from = current + radius + 1;
  final to = (current + diskAhead + 1).clamp(0, pictures.length);
  for (var i = from; i < to; i++) {
    // Only where a rung exists — the depth is priced for one. See the same
    // guard in [warmNextCards] for why this is a standing rule and not a
    // temporary one.
    if (!pictures[i].ladder.exists) continue;
    final url = deliveryUrlFor(
      pictures[i],
      logicalWidth: width,
      devicePixelRatio: dpr,
    );
    if (url != null) warmToDisk(url);
  }
}
