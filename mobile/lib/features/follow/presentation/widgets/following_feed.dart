import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/cache/disk_cache.dart';
import 'package:flutter/material.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/feed_suggestions_card.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_empty_state.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';

/// The "Following" feed: posts from the creators the user follows, backed by
/// `FollowRepository.getFollowFeed`, with a card of suggested creators dealt
/// in every [eventsPerSuggestionCard] posts — the next five each time.
/// Someone who already follows a couple of people never sees the empty tab, so
/// without those cards the app would never offer them anyone new.
///
/// Pages one post at a time, exactly as `events_feed.dart`'s Feed tab does —
/// a vertical [PageView] that snaps, so the two tabs feel the same under the
/// thumb rather than one gliding and the other catching.
///
/// This did scroll continuously for a while, because as a page the suggestions
/// card was stretched to the whole viewport for the sake of five rows and no
/// arrangement of them could fill the rest — top, centre and bottom each just
/// moved the empty half elsewhere. Stretching was the actual problem, though,
/// not paging: the Feed tab already deals non-post cards (ads, requests) into
/// its pager and keeps them their own size by wrapping them in a [FittedBox],
/// which centres the card in the page instead of pulling it apart. The same
/// wrapper is used here, so the card stays card-shaped and the feed still
/// snaps.
class FollowingFeed extends StatefulWidget {
  const FollowingFeed({
    super.key,
    this.chromeTopPadding = 0,
    this.onEventTap,
    this.loadSuggestions,
    this.loadFeed,
  });

  /// Opens a post's event. Tapping a card here did nothing at all until now —
  /// the Feed tab has always opened the event's grid on a tap and this one was
  /// built without the hookup, so a post in Following was the one post in the
  /// app you could not get into.
  ///
  /// Supplied by the host rather than pushed from here, which is where the
  /// Feed tab's own card taps are routed from too.
  final ValueChanged<EventDiscovery>? onEventTap;

  /// Posts between one suggestion card and the next.
  static const eventsPerSuggestionCard = 5;

  /// Creators per card — the "first five, then the next five" of the design.
  static const suggestionsPerCard = 5;

  /// How far the empty state has to start below the floating header to clear
  /// it.
  ///
  /// Only the empty state needs this. It is a static list pinned to the top of
  /// the tab, so without it the headline lands on the status bar. Everything
  /// else here scrolls, and scrolling under a floating header is what a
  /// floating header is for — the posts are full-bleed and meant to run
  /// beneath it.
  final double chromeTopPadding;

  /// Overrides where the interleaved suggestions come from. Tests only.
  final Future<List<SuggestedPhotographer>> Function(int limit)?
      loadSuggestions;

  /// Overrides where the posts come from. Tests only.
  final Future<({List<EventDiscovery> events, bool hasMore})> Function(
      int page, int limit)? loadFeed;

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> {
  final _repo = FollowRepository();
  final _activeCardIndex = ValueNotifier<int>(0);
  final _pageCtrl = PageController();

  /// The slots the last build laid out, so the page callback can reason about
  /// what it landed on without rebuilding them.
  List<FeedSlot> _slots = const [];

  List<EventDiscovery> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  List<SuggestedPhotographer> _suggestions = [];
  bool _loadingSuggestions = false;
  bool _hasMoreSuggestions = true;
  int _suggestionLimit = _suggestionPageSize;

  /// Whether the user followed anyone as far as this session knows. Compared
  /// against the live set to spot the moment the last follow is undone.
  bool _hadFollows = FollowRepository.followedIds.isNotEmpty;

  static const _initialLimit = 8;
  static const _pageLimit = 20;

  /// How many suggestions to ask for at a time. Four cards' worth, so the
  /// user has to scroll a long way before another fetch is needed.
  static const _suggestionPageSize = 20;

  @override
  void initState() {
    super.initState();
    FollowRepository.followedRevision.addListener(_onFollowedChanged);
    _restoreFromDisk();
    _load();
    _loadSuggestions();
  }

  /// Paint the last-seen posts before the request goes out.
  ///
  /// Synchronous, so this lands in the first frame — the tab opens to content
  /// rather than to a spinner, and with no connection it opens to content
  /// rather than to an error. The photos come with it: their bytes are already
  /// in the image cache, and what was missing was only the list saying which
  /// ones to draw.
  ///
  /// `_loading` stays false afterwards so the refresh runs underneath. If it
  /// succeeds the list is replaced; if it fails the cached posts stay up,
  /// which for somebody with no signal is the whole point.
  void _restoreFromDisk() {
    // Not when a loader has been injected: that is a test or a preview
    // driving this widget with its own data, and the real account's cache
    // has nothing to do with it.
    if (widget.loadFeed != null) return;
    try {
      final rows = sl<DiskCache>(instanceName: kFollowingFeedCache).restore();
      if (rows.isEmpty) return;
      final events = <EventDiscovery>[];
      for (final row in rows) {
        try {
          events.add(EventDiscovery.fromMap(row));
        } catch (_) {
          // One unreadable row is not worth losing the rest of the screen.
        }
      }
      if (events.isEmpty) return;
      _events = events;
      _loading = false;
    } catch (_) {
      // No cache is simply a cold start.
    }
  }

  @override
  void dispose() {
    FollowRepository.followedRevision.removeListener(_onFollowedChanged);
    _pageCtrl.dispose();
    _activeCardIndex.dispose();
    super.dispose();
  }

  /// Unfollowing the last creator empties this feed by definition — every
  /// post in it came from someone the user has just stopped following. So the
  /// posts go immediately, which puts the empty state (and its suggestions)
  /// on screen without waiting for a request to come back and confirm it.
  ///
  /// Only the transition *to* empty acts. Following someone must not swap the
  /// view out from under a user working down a list of suggestions, and an
  /// empty set at startup means "nothing seeded yet", not "follows nobody".
  void _onFollowedChanged() {
    final hasFollows = FollowRepository.followedIds.isNotEmpty;
    if (_hadFollows && !hasFollows && mounted) {
      setState(() {
        _events = [];
        _hasMore = false;
        _loading = false;
        _error = null;
      });
    }
    _hadFollows = hasFollows;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = widget.loadFeed != null
          ? await widget.loadFeed!(1, _initialLimit)
          : await _repo.getFollowFeed(page: 1, limit: _initialLimit);
      if (!mounted) return;
      setState(() {
        _events = result.events;
        _loading = false;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    final next = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final result = widget.loadFeed != null
          ? await widget.loadFeed!(next, _pageLimit)
          : await _repo.getFollowFeed(page: next, limit: _pageLimit);
      if (!mounted) return;
      setState(() {
        _page = next;
        _events = [..._events, ...result.events];
        _loadingMore = false;
        _hasMore = result.hasMore;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  /// Fetches the pool the interleaved cards are sliced from.
  ///
  /// [grow] asks for a bigger page than last time. The endpoint has no cursor
  /// — it returns the best matches, minus anyone already followed — so more
  /// suggestions means asking for a longer list and keeping what's new.
  Future<void> _loadSuggestions({bool grow = false}) async {
    if (_loadingSuggestions || (grow && !_hasMoreSuggestions)) return;
    _loadingSuggestions = true;
    final limit = grow ? _suggestionLimit + _suggestionPageSize : _suggestionLimit;

    try {
      final results = widget.loadSuggestions != null
          ? await widget.loadSuggestions!(limit)
          : await _repo.getSuggestedPhotographers(limit: limit);
      if (!mounted) return;
      setState(() {
        _suggestionLimit = limit;
        // The endpoint answers from the top each time, so a grown fetch
        // repeats what we already have; only the tail is new.
        _hasMoreSuggestions = results.length > _suggestions.length;
        _suggestions = results;
      });
    } catch (_) {
      // Suggestions are an extra on this screen, never the point of it — a
      // failed fetch just means no card this time.
      if (mounted) setState(() => _hasMoreSuggestions = false);
    } finally {
      _loadingSuggestions = false;
    }
  }

  void _onHide(String eventId) {
    AppSnackBar.withAction(
      context,
      AppLocalizations.of(context)!.discoveryContentHidden,
      actionLabel: AppLocalizations.of(context)!.discoveryUndo,
      onAction: () {},
    ).then((reason) {
      if (reason != SnackBarClosedReason.action && mounted) {
        setState(() => _events.removeWhere((e) => e.id == eventId));
      }
    });
  }

  /// Which slot owns the screen: with a pager, simply the page landed on.
  ///
  /// While this feed scrolled freely there was no such thing — two slots were
  /// on screen for most of a swipe — so it measured which covered the most,
  /// keyed off a [GlobalKey] per slot. Snapping removes the question and the
  /// bookkeeping with it.
  ///
  /// A suggestions page winning is meaningful, not a miss: its index matches
  /// no post card, which is what stops a video or a soundtrack playing under a
  /// card the reader is looking at.
  void _onPageChanged(int pageIndex) {
    if (pageIndex == _activeCardIndex.value) return;
    _activeCardIndex.value = pageIndex;
    _onActiveSlotChanged(pageIndex);
  }

  void _onActiveSlotChanged(int slotIndex) {
    if (slotIndex >= _slots.length - 2 && !_loadingMore) _loadMore();

    // Top the pool up before the last slice is reached, so the next card is
    // ready rather than silently skipped.
    final slicesUsed =
        _slots.take(slotIndex + 1).where((s) => s.isSuggestions).length;
    final slicesAvailable =
        (_suggestions.length / FollowingFeed.suggestionsPerCard).ceil();
    if (slicesUsed >= slicesAvailable - 1) _loadSuggestions(grow: true);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    if (_loading) return const AppLoadingIndicator();

    // Only when there is nothing to read. A refresh that failed over posts
    // restored from disk is a failed refresh, not an empty screen — and with
    // no connection those posts are the only thing this tab has, so replacing
    // them with "wifi off" would undo the caching that just supplied them.
    if (_error != null && _events.isEmpty) {
      return AppErrorView(
        message: _error!,
        icon: Icons.wifi_off_outlined,
        onRetry: _load,
      );
    }

    // Nothing to page through yet. Rather than a dead-end message, the empty
    // state is the way out of it: suggested creators, each with its own
    // Follow button.
    if (_events.isEmpty) {
      return FollowingEmptyState(
        topPadding: widget.chromeTopPadding,
        onRefresh: _load,
      );
    }

    _slots = buildFollowingSlots(
      events: _events,
      suggestions: _suggestions,
    );

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.accentGold,
      // The Feed tab's pager, to the letter: vertical, one slot per page,
      // snapping. See the note on [FollowingFeed] for why the suggestions card
      // no longer needs this to be a free-scrolling list.
      child: PageView.builder(
        controller: _pageCtrl,
        scrollDirection: Axis.vertical,
        onPageChanged: _onPageChanged,
        itemCount: _slots.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, i) {
          if (i == _slots.length) {
            return const Center(child: CircularProgressIndicator());
          }

          final slot = _slots[i];
          final suggestions = slot.suggestions;
          if (suggestions != null) {
            // Scaled to fit rather than stretched to fill — the same wrapper
            // the Feed tab puts round its ads and requests. Without it the
            // card is pulled to the height of the viewport and five rows of
            // creators float in a screen of empty space.
            return FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: MediaQuery.sizeOf(context).width,
                child: FeedSuggestionsCard(suggestions: suggestions),
              ),
            );
          }

          final event = slot.event!;
          return FullBleedEventCard(
            key: ValueKey('following_event_${event.id}'),
            event: event,
            // The slot index, not the event index: it is matched against
            // [_activeCardIndex] to decide which card's video and music may
            // play, and a suggestions card matching nothing is the point —
            // nothing plays while one is on screen.
            cardIndex: i,
            activeCardIndex: _activeCardIndex,
            onTap: () => widget.onEventTap?.call(event),
            onHide: () => _onHide(event.id),
          );
        },
      ),
    );
  }
}

/// The pages of the Following feed, in order: every [eventsPerCard] posts is
/// followed by the next slice of [suggestionsPerCard] creators, for as long as
/// slices last.
///
/// A pure function of the two lists — no cursor to drift — so the page at a
/// given index is the same on every rebuild, and appending posts or
/// suggestions never reshuffles what came before.
List<FeedSlot> buildFollowingSlots({
  required List<EventDiscovery> events,
  required List<SuggestedPhotographer> suggestions,
  int eventsPerCard = FollowingFeed.eventsPerSuggestionCard,
  int suggestionsPerCard = FollowingFeed.suggestionsPerCard,
}) {
  final slots = <FeedSlot>[];
  var slice = 0;

  for (var i = 0; i < events.length; i++) {
    slots.add(FeedSlot.event(events[i]));

    if ((i + 1) % eventsPerCard != 0) continue;

    final start = slice * suggestionsPerCard;
    if (start >= suggestions.length) continue;
    final end = (start + suggestionsPerCard).clamp(0, suggestions.length);
    slots.add(FeedSlot.suggestions(suggestions.sublist(start, end)));
    slice++;
  }
  return slots;
}

/// One page of the feed: either a post or a slice of suggested creators.
class FeedSlot {
  const FeedSlot.event(EventDiscovery this.event) : suggestions = null;
  const FeedSlot.suggestions(List<SuggestedPhotographer> this.suggestions)
      : event = null;

  final EventDiscovery? event;
  final List<SuggestedPhotographer>? suggestions;

  bool get isSuggestions => suggestions != null;
}
