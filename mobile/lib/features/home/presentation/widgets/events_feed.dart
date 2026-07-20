import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageRoute;
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/utils/focus_utils.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/features/ads/data/models/ad_model.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/data/repositories/ads_repository.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

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
) {
  final cfg = AppConfigRepository.current;
  final adsInterval = cfg.adsEveryNEvents.clamp(1, 9999);
  final requestsInterval = cfg.requestsEveryNEvents.clamp(1, 9999);

  final items = <_FeedItem>[];
  var requestSlot = 0;
  var adSlot = 0;

  for (var i = 0; i < events.length; i++) {
    items.add(_EventItem(events[i], i));
    final count = i + 1;
    // Requests take priority when both intervals coincide.
    if (count % requestsInterval == 0) {
      if (cfg.requestsEnabled) items.add(_RequestItem(requestSlot++));
    } else if (count % adsInterval == 0) {
      if (cfg.adsEnabled) items.add(_AdItem(adSlot++));
    }
  }

  // When the feed is shorter than both intervals, append one slot of each
  // so they always appear. The builder collapses them when data is absent.
  if (events.isNotEmpty) {
    if (adSlot == 0 && cfg.adsEnabled) items.add(const _AdItem(0));
    if (requestSlot == 0 && cfg.requestsEnabled) {
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
  final _repo = AdsRepository();

  // One ad per slot — fetched fresh from the server for each slot.
  final List<AdModel?> _ads = [];
  // Per-slot impression IDs, saved after trackImpression responds.
  final List<String?> _impressionIds = [];
  // Context event IDs passed to serveAd, forwarded to trackImpression.
  final List<String?> _adContextEventIds = [];
  // Ad slot indices that have already fired an impression (never re-fire).
  final _firedAdImpressions = <int>{};

  // All requests fetched so far (paginated on load-more).
  List<FeedRequestModel> _requests = [];
  int _requestPage = 1;
  final _hiddenRequestIds = <String>{};

  // Guards against overlapping fetch-more calls.
  bool _fetchingMore = false;

  @override
  void initState() {
    super.initState();
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
      setState(() {
        _ads.clear();
        _impressionIds.clear();
        _adContextEventIds.clear();
        _requests = [];
        _requestPage = 1;
        _firedAdImpressions.clear();
      });
      _fetchInitial();
    } else if (newEvents.length > oldEvents.length) {
      // Load-more: events were appended, fetch next ad + request page.
      _fetchMore();
    }
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchInitial() async {
    debugPrint('[EventsFeed] _fetchInitial');
    try {
      final contextEventId = widget.discoveryState.events.isNotEmpty
          ? widget.discoveryState.events.first.id
          : null;

      final cfg = AppConfigRepository.current;
      final results = await Future.wait([
        if (cfg.adsEnabled)
          _repo.serveAd(placement: 'event_feed', contextEventId: contextEventId)
        else
          Future<AdModel?>.value(null),
        if (cfg.requestsEnabled)
          _repo.getRequests(page: 1)
        else
          Future<List<FeedRequestModel>>.value([]),
      ]);

      if (!mounted) return;
      final ad = results[0] as AdModel?;
      final requests = results[1] as List<FeedRequestModel>;

      setState(() {
        _ads
          ..clear()
          ..add(ad);
        _impressionIds
          ..clear()
          ..add(null);
        _adContextEventIds
          ..clear()
          ..add(contextEventId);
        _requests = requests;
        _requestPage = 1;
      });
    } catch (e, st) {
      debugPrint('[EventsFeed] _fetchInitial ERROR: $e\n$st');
    }
  }

  Future<void> _fetchMore() async {
    if (_fetchingMore) return;
    _fetchingMore = true;
    try {
      final cfg = AppConfigRepository.current;
      final nextRequestPage = _requestPage + 1;
      final contextEventId = widget.discoveryState.events.isNotEmpty
          ? widget.discoveryState.events.last.id
          : null;
      final results = await Future.wait([
        if (cfg.adsEnabled)
          _repo.serveAd(placement: 'event_feed', contextEventId: contextEventId)
        else
          Future<AdModel?>.value(null),
        if (cfg.requestsEnabled)
          _repo.getRequests(page: nextRequestPage)
        else
          Future<List<FeedRequestModel>>.value([]),
      ]);
      if (!mounted) return;
      AdModel? ad = results[0] as AdModel?;
      final moreRequests = results[1] as List<FeedRequestModel>;

      // Drop the ad if its ID was already shown in a previous slot.
      if (ad != null) {
        final seenAdIds = _ads.whereType<AdModel>().map((a) => a.adId).toSet();
        if (seenAdIds.contains(ad.adId)) ad = null;
      }

      if (!mounted) return;
      setState(() {
        _ads.add(ad);
        _impressionIds.add(null);
        _adContextEventIds.add(contextEventId);
        if (moreRequests.isNotEmpty) {
          _requests = [..._requests, ...moreRequests];
          _requestPage = nextRequestPage;
        }
      });
    } catch (e, st) {
      debugPrint('[EventsFeed] _fetchMore ERROR: $e\n$st');
    } finally {
      _fetchingMore = false;
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _activeCardIndex.dispose();
    _pageCtrl.dispose();
    _feedFocusNode.dispose();
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

  void _onPageChanged(List<_FeedItem> virtualItems, int pageIndex) {
    final item = pageIndex < virtualItems.length ? virtualItems[pageIndex] : null;
    _activeCardIndex.value = item is _EventItem ? item.eventIndex : -1;

    if (item is _AdItem && !_firedAdImpressions.contains(item.adIndex)) {
      _firedAdImpressions.add(item.adIndex);
      _fireAdImpression(item.adIndex);
    }

    if (pageIndex >= virtualItems.length - 2 && !widget.discoveryState.isLoadingMore) {
      widget.onLoadMore();
    }
  }

  Future<void> _fireAdImpression(int adIdx) async {
    final ad = adIdx < _ads.length ? _ads[adIdx] : null;
    if (ad == null) return;
    final contextEventId =
        adIdx < _adContextEventIds.length ? _adContextEventIds[adIdx] : null;
    final id = await _repo.trackImpression(
      adId: ad.adId,
      adsetId: ad.adsetId,
      campaignId: ad.campaignId,
      placement: ad.placement,
      impressionToken: ad.impressionToken,
      contextEventId: contextEventId,
    );
    if (mounted && adIdx < _impressionIds.length) {
      _impressionIds[adIdx] = id;
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

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> _openChat(
    BuildContext context,
    String userId,
    String userType,
    String displayName,
  ) async {
    final role = userType == 'photographer'
        ? ChatConfig.rolePhotographer
        : ChatConfig.roleClient;

    ChatRoomsBloc? roomsBloc;
    try {
      roomsBloc = context.read<ChatRoomsBloc>();
    } catch (_) {}

    try {
      final room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: userId,
        recipientRole: role,
        localDisplayName: displayName,
      );
      if (!context.mounted) return;
      roomsBloc?.add(const ChatRoomsLoadRequested());
      await Navigator.of(context).push(
        CupertinoPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
      if (context.mounted) roomsBloc?.add(const ChatRoomsLoadRequested());
    } catch (e) {
      if (!context.mounted) return;
      final blocked = e is ServerException &&
          (e.message.contains('400') ||
              e.message.contains('RECIPIENT_NOT_ACCEPTING_DMS') ||
              e.message.contains('USER_BLOCKED'));
      AppSnackBar.error(
        context,
        blocked ? 'This user is not accepting messages.' : 'Could not open chat.',
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = widget.discoveryState;
    final visibleRequests =
        _requests.where((r) => !_hiddenRequestIds.contains(r.id)).toList();
    // Drop ad/request slots with no confirmed content — _buildVirtualList
    // reserves a slot as soon as an interval is reached (or the batch is
    // shorter than the interval), before the async ad/request fetch for
    // that slot has resolved or is known to be empty. Rendering those as a
    // PageView page produces a swipeable blank screen; skipping them here
    // means the feed only ever shows a page once there's something on it.
    final virtualItems = _buildVirtualList(state.events, state.isLoadingMore)
        .where((item) {
      if (item is _AdItem) {
        return item.adIndex < _ads.length && _ads[item.adIndex] != null;
      }
      if (item is _RequestItem) {
        return item.requestIndex < visibleRequests.length;
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
        child: PageView.builder(
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
              final ad = adIdx < _ads.length ? _ads[adIdx] : null;
              if (ad == null) return const SizedBox.shrink();

              return FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: FeedItemCard(
                    key: ValueKey('ad_$adIdx'),
                    data: FeedItemData.fromAd(
                      ad,
                      onCtaTap: () => _repo.trackClick(
                        adId: ad.adId,
                        campaignId: ad.campaignId,
                        impressionId: adIdx < _impressionIds.length
                            ? _impressionIds[adIdx]
                            : null,
                      ),
                    ),
                    onHide: () => setState(() {
                      if (adIdx < _ads.length) _ads[adIdx] = null;
                    }),
                  ),
                ),
              );
            }

            // ── Injected request ──────────────────────────────────────────
            if (item is _RequestItem) {
              if (item.requestIndex >= visibleRequests.length) {
                return const SizedBox.shrink();
              }
              final req = visibleRequests[item.requestIndex];
              return FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: FeedItemCard(
                    key: ValueKey('req_${req.id}'),
                    data: FeedItemData.fromRequest(
                      req,
                      onMessageTap: () => _openChat(
                        context,
                        req.requesterId,
                        req.requesterType,
                        req.requesterName,
                      ),
                    ),
                    onHide: () => setState(() => _hiddenRequestIds.add(req.id)),
                  ),
                ),
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
      ),
    );
  }
}
