import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/focus_utils.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/ads/presentation/feed_promos.dart';
import 'package:jperg_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/swipe_up_hint.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

// ── Virtual feed item types ───────────────────────────────────────────────────

sealed class _FeedItem {
  const _FeedItem();
}

final class _EventItem extends _FeedItem {
  const _EventItem(this.event, this.eventIndex);
  final EventDiscovery event;
  final int eventIndex;
}

// Each ad slot carries its own index so the builder can map it to _ads[index].
final class _AdItem extends _FeedItem {
  const _AdItem(this.adIndex);
  final int adIndex;
}

final class _RequestItem extends _FeedItem {
  const _RequestItem(this.requestIndex);
  final int requestIndex;
}

final class _LoadingItem extends _FeedItem {
  const _LoadingItem();
}

// ── Build the virtual list ────────────────────────────────────────────────────

List<_FeedItem> _buildVirtualList(
  List<EventDiscovery> events,
  bool isLoadingMore,
  FeedPromos promos,
) {
  final adsInterval = promos.adsInterval;
  final requestsInterval = promos.requestsInterval;

  final items = <_FeedItem>[];
  var requestSlot = 0;
  var adSlot = 0;

  for (var i = 0; i < events.length; i++) {
    items.add(_EventItem(events[i], i));
    final count = i + 1;
    // Requests take priority when both intervals coincide.
    if (count % requestsInterval == 0) {
      if (promos.requestsEnabled) items.add(_RequestItem(requestSlot++));
    } else if (count % adsInterval == 0) {
      if (promos.adsEnabled) items.add(_AdItem(adSlot++));
    }
  }

  // When the feed is shorter than both intervals, append one slot of each
  // so they always appear. The builder collapses them when data is absent.
  if (events.isNotEmpty) {
    if (adSlot == 0 && promos.adsEnabled) items.add(const _AdItem(0));
    if (requestSlot == 0 && promos.requestsEnabled) {
      items.add(const _RequestItem(0));
    }
  }

  if (isLoadingMore) items.add(const _LoadingItem());
  return items;
}

// ── Vertically-paged events feed (authenticated) ──────────────────────────────
//
// TikTok-style: each item (event, ad, or request) is one full-viewport page.
// Vertical swipe moves between pages; horizontal swipe within an event moves
// between that event's own photos/videos (FullBleedEventCard's nested
// PostPhotoCarousel — unchanged from before).

class EventsFeed extends StatefulWidget {
  const EventsFeed({
    super.key,
    required this.discoveryState,
    required this.onCardTap,
    required this.onCommentTap,
    required this.onLoadMore,
    this.topPadding = 0,
  });

  final DiscoveryState discoveryState;
  final ValueChanged<EventDiscovery> onCardTap;
  final ValueChanged<EventDiscovery> onCommentTap;
  final VoidCallback onLoadMore;
  final double topPadding;

  @override
  State<EventsFeed> createState() => _EventsFeedState();
}

class _EventsFeedState extends State<EventsFeed> {
  final _activeCardIndex = ValueNotifier<int>(0);
  final _pageCtrl = PageController();
  final _feedFocusNode = FocusNode();

  /// So the feed can tell your own request apart from everyone else's — you
  /// cannot answer your own.
  String _myUserId = '';

  /// The campaigns and requests dealt in between the events, and everything
  /// about how often they come round. Shared with the Following feed — see
  /// [FeedPromos].
  late final _promos = FeedPromos(
    onChanged: () {
      if (mounted) setState(() {});
    },
  );

  @override
  void initState() {
    super.initState();
    _resolveSwipeHint();
    _loadMyUserId();
    _fetchInitial();
    // NOTE: deliberately NOT auto-focusing the feed on web. Grabbing focus on
    // load captured the browser's keyboard/input focus, which then blocked the
    // sidebar search field (it lives above the Navigator in its own overlay)
    // from ever receiving keystrokes — typing there did nothing. The feed's
    // j/k/space shortcuts still work once the user clicks/scrolls the feed.
  }

  @override
  void didUpdateWidget(EventsFeed old) {
    super.didUpdateWidget(old);
    final newEvents = widget.discoveryState.events;
    final oldEvents = old.discoveryState.events;

    if (newEvents.length == oldEvents.length) return;
    // initState already called _fetchInitial for the very first population.
    if (oldEvents.isEmpty) return;

    final firstChanged =
        newEvents.isNotEmpty && newEvents.first.id != oldEvents.first.id;

    if (firstChanged) {
      // Full refresh: discard stale ad/request state and fetch fresh.
      setState(_promos.reset);
      _fetchInitial();
    } else if (newEvents.length > oldEvents.length) {
      // Load-more: events were appended, fetch next ad + request page.
      _fetchMore();
    }
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchInitial() => _promos.loadInitial(
        contextEventId: widget.discoveryState.events.isNotEmpty
            ? widget.discoveryState.events.first.id
            : null,
      );

  Future<void> _fetchMore() => _promos.loadMore(
        contextEventId: widget.discoveryState.events.isNotEmpty
            ? widget.discoveryState.events.last.id
            : null,
      );

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _activeCardIndex.dispose();
    _pageCtrl.dispose();
    _feedFocusNode.dispose();
    _promos.dispose();
    super.dispose();
  }

  // ── Page tracking ──────────────────────────────────────────────────────────

  /// Finds the page index (within [virtualItems]) of the event at
  /// [eventIndex] — used to translate keyboard nav / external requests
  /// (expressed in event-index terms) into a PageView page.
  int _pageIndexForEvent(List<_FeedItem> virtualItems, int eventIndex) {
    for (var i = 0; i < virtualItems.length; i++) {
      final item = virtualItems[i];
      if (item is _EventItem && item.eventIndex == eventIndex) return i;
    }
    return 0;
  }

  /// Swipe-up hint over the first card — same affordance as the guest feed,
  /// and the same device-level flag, so someone who learned the gesture as a
  /// guest is not taught it again after signing up.
  bool _showSwipeHint = false;

  Future<void> _resolveSwipeHint() async {
    if (await sl<AuthService>().getHasSeenSwipeHint()) return;
    if (mounted) setState(() => _showSwipeHint = true);
  }

  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    setState(() => _showSwipeHint = false);
    sl<AuthService>().setHasSeenSwipeHint();
  }

  void _onPageChanged(List<_FeedItem> virtualItems, int pageIndex) {
    _dismissSwipeHint();
    final item =
        pageIndex < virtualItems.length ? virtualItems[pageIndex] : null;
    _activeCardIndex.value = item is _EventItem ? item.eventIndex : -1;

    if (item is _AdItem) _promos.fireImpression(item.adIndex);

    if (pageIndex >= virtualItems.length - 2 &&
        !widget.discoveryState.isLoadingMore) {
      widget.onLoadMore();
    }
  }

  // ── Keyboard navigation (web desktop/laptop only) ─────────────────────────

  KeyEventResult _handleKeyEvent(
      List<_FeedItem> virtualItems, FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (isTextInputFocused()) return KeyEventResult.ignored;
    final events = widget.discoveryState.events;
    if (events.isEmpty) return KeyEventResult.ignored;
    final current = _activeCardIndex.value.clamp(0, events.length - 1);

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      final next = (current + 1).clamp(0, events.length - 1);
      if (next != current) {
        _pageCtrl.animateToPage(_pageIndexForEvent(virtualItems, next),
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      final prev = (current - 1).clamp(0, events.length - 1);
      if (prev != current) {
        _pageCtrl.animateToPage(_pageIndexForEvent(virtualItems, prev),
            duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (current < events.length) widget.onCardTap(events[current]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ── Event card hide ───────────────────────────────────────────────────────

  void _onHide(String eventId) {
    final bloc = context.read<DiscoveryBloc>();
    bloc.add(DiscoveryEventHideRequested(eventId));

    AppSnackBar.withAction(
      context,
      'Post hidden',
      actionLabel: 'Undo',
      onAction: () => bloc.add(const DiscoveryEventHideUndone()),
    ).then((reason) {
      if (reason != SnackBarClosedReason.action && !bloc.isClosed) {
        bloc.add(DiscoveryEventHideCommitted(eventId));
      }
    });
  }

  // ── Requests ──────────────────────────────────────────────────────────────

  Future<void> _loadMyUserId() async {
    final id = await sl<AuthService>().getUserId();
    if (mounted) setState(() => _myUserId = id);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = widget.discoveryState;
    // Drop ad/request slots with no confirmed content — _buildVirtualList
    // reserves a slot as soon as an interval is reached (or the batch is
    // shorter than the interval), before the async ad/request fetch for
    // that slot has resolved or is known to be empty. Rendering those as a
    // PageView page produces a swipeable blank screen; skipping them here
    // means the feed only ever shows a page once there's something on it.
    final virtualItems = _buildVirtualList(
      state.events,
      state.isLoadingMore,
      _promos,
    ).where((item) {
      if (item is _AdItem) return _promos.adForSlot(item.adIndex) != null;
      if (item is _RequestItem) {
        return _promos.requestForSlot(item.requestIndex) != null;
      }
      return true;
    }).toList();

    return Focus(
      focusNode: _feedFocusNode,
      onKeyEvent: kIsWeb
          ? (node, event) => _handleKeyEvent(virtualItems, node, event)
          : null,
      child: Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageCtrl,
              scrollDirection: Axis.vertical,
              itemCount: virtualItems.length,
              onPageChanged: (i) => _onPageChanged(virtualItems, i),
              itemBuilder: (context, index) {
                final item = virtualItems[index];

                // ── Loading spinner ───────────────────────────────────────────
                if (item is _LoadingItem) {
                  return const Center(child: CircularProgressIndicator());
                }

                // ── Injected ad ───────────────────────────────────────────────
                if (item is _AdItem) {
                  final adIdx = item.adIndex;
                  final ad = _promos.adForSlot(adIdx);
                  if (ad == null) return const SizedBox.shrink();

                  // Not scaled into a card any more: a campaign is a page of
                  // this feed like any other, and it fills one.
                  return FeedItemCard(
                    key: ValueKey('ad_$adIdx'),
                    data: FeedItemData.fromAd(
                      ad,
                      onCtaTap: () => _promos.trackClick(ad, adIdx),
                    ),
                    onHide: () => _promos.hideAd(adIdx),
                  );
                }

                // ── Injected request ──────────────────────────────────────────
                if (item is _RequestItem) {
                  final req = _promos.requestForSlot(item.requestIndex);
                  if (req == null) return const SizedBox.shrink();
                  return FeedItemCard(
                    // The slot is in the key as well as the request: a boosted
                    // one holds more than one slot, and two pages of the same
                    // pager cannot share a key.
                    key: ValueKey('req_${item.requestIndex}_${req.id}'),
                    data: FeedItemData.fromRequest(
                      req,
                      onAnswerTap: req.requesterId == _myUserId
                          ? null
                          : () => _promos.answer(context, req),
                    ),
                    onHide: () => _promos.hideRequest(req.id),
                  );
                }

                // ── Event card ────────────────────────────────────────────────
                final eventItem = item as _EventItem;
                final event = eventItem.event;

                return FullBleedEventCard(
                  key: ValueKey('event_${event.id}'),
                  event: event,
                  cardIndex: eventItem.eventIndex,
                  activeCardIndex: _activeCardIndex,
                  onTap: () => widget.onCardTap(event),
                  onHide: () => _onHide(event.id),
                );
              },
            ),
            // Swipe-up hint — first card, first time on this device. Below the
            // feed's own overlays and pointer-transparent, so it never
            // intercepts the gesture it is asking for.
            if (_showSwipeHint)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24.h,
                child: const Center(child: SwipeUpHint(label: '')),
              ),
          ],
        ),
      ),
    );
  }
}
