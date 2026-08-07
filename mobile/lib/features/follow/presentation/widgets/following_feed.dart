import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
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
/// This scrolls continuously rather than paging, which is the one way it
/// differs from `events_feed.dart`'s Feed tab. The suggestions card is the
/// reason: as a page in a [PageView] it was stretched to the whole viewport
/// for the sake of five rows, and no arrangement of those rows could fill the
/// rest — top, centre and bottom each just moved the empty half elsewhere.
/// Scrolling lets it be as tall as its contents, with the next post directly
/// beneath it. Posts still take a screen each; they are simply not snapped to.
class FollowingFeed extends StatefulWidget {
  const FollowingFeed({
    super.key,
    this.chromeTopPadding = 0,
    this.loadSuggestions,
    this.loadFeed,
  });

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
  final _scrollCtrl = ScrollController();

  /// The slots the last build laid out, so the scroll callback can reason
  /// about what it is looking at without rebuilding them.
  List<FeedSlot> _slots = const [];
  final _slotKeys = <int, GlobalKey>{};

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
    _scrollCtrl.addListener(_onScroll);
    _load();
    _loadSuggestions();
  }

  @override
  void dispose() {
    FollowRepository.followedRevision.removeListener(_onFollowedChanged);
    _scrollCtrl.removeListener(_onScroll);
    _scrollCtrl.dispose();
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

  /// Which slot currently owns the screen, by how much of it each one covers.
  ///
  /// The feed used to page, so this was simply the page index. Scrolling
  /// continuously there is no such thing — two slots are on screen for most of
  /// a swipe — so "active" is the one showing the most. A suggestions card
  /// winning is meaningful, not a miss: its index matches no post, which is
  /// what stops a video playing under a card the reader is looking at.
  void _onScroll() {
    final self = context.findRenderObject() as RenderBox?;
    if (self == null || !self.hasSize) return;
    final viewport = self.size.height;

    int? best;
    var bestVisible = 0.0;
    for (final entry in _slotKeys.entries) {
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: self).dy;
      final visible = math.min(top + box.size.height, viewport) - math.max(top, 0);
      if (visible > bestVisible) {
        bestVisible = visible;
        best = entry.key;
      }
    }

    if (best == null || best == _activeCardIndex.value) return;
    _activeCardIndex.value = best;
    _onActiveSlotChanged(best);
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

  /// One key per slot so [_onScroll] can measure what is on screen. Only the
  /// handful the list has built resolve to a context; the rest are inert.
  GlobalKey _keyFor(int slotIndex) =>
      _slotKeys.putIfAbsent(slotIndex, GlobalKey.new);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    if (_loading) return const AppLoadingIndicator();

    if (_error != null) {
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
      // Scrolls rather than pages, so a suggestions card can be an item the
      // reader passes on the way to the next post instead of a screen of its
      // own. Posts keep a full screen each; only the card is as tall as it is.
      child: LayoutBuilder(
        builder: (context, constraints) => ListView.builder(
          controller: _scrollCtrl,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _slots.length + (_loadingMore ? 1 : 0),
          itemBuilder: (_, i) {
            if (i == _slots.length) {
              return Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xl.h),
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            final slot = _slots[i];
            final suggestions = slot.suggestions;
            if (suggestions != null) {
              return Padding(
                key: _keyFor(i),
                // A card at the very end has nothing after it to push it clear
                // of the floating nav bar.
                padding: EdgeInsets.only(
                    bottom: i == _slots.length - 1 ? 88.h : 0),
                child: FeedSuggestionsCard(suggestions: suggestions),
              );
            }

            final event = slot.event!;
            return SizedBox(
              key: _keyFor(i),
              // A post still owns the screen; it just isn't snapped to.
              height: constraints.maxHeight,
              child: FullBleedEventCard(
                key: ValueKey('following_event_${event.id}'),
                event: event,
                // The slot index, not the event index: it is matched against
                // [_activeCardIndex] to decide which card's video may play,
                // and a suggestions card matching nothing is the point — no
                // video plays while one is on screen.
                cardIndex: i,
                activeCardIndex: _activeCardIndex,
                onTap: () {},
                onHide: () => _onHide(event.id),
              ),
            );
          },
        ),
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
