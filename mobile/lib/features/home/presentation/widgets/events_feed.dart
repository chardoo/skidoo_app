import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
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
import 'package:skidoo_app/features/discovery/presentation/widgets/event_discovery_card.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
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

// ── Scrollable events feed (authenticated) ────────────────────────────────────

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
  final _cardKeys = <String, GlobalKey>{};
  final _feedFocusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  final _repo = AdsRepository();

  // One ad per slot — fetched fresh from the server for each slot.
  final List<AdModel?> _ads = [];
  // Per-slot impression IDs, saved after trackImpression responds.
  final List<String?> _impressionIds = [];
  // Context event IDs passed to serveAd, forwarded to trackImpression.
  final List<String?> _adContextEventIds = [];

  // GlobalKeys for ad cards — used to check viewport visibility.
  final _adCardGlobalKeys = <int, GlobalKey>{};
  // Ad slot indices that have already fired an impression (never re-fire).
  final _firedAdImpressions = <int>{};

  // All requests fetched so far (paginated on load-more).
  List<FeedRequestModel> _requests = [];
  int _requestPage = 1;
  final _hiddenRequestIds = <String>{};

  // Guards against overlapping fetch-more calls.
  bool _fetchingMore = false;

  GlobalKey _keyFor(String eventId) =>
      _cardKeys.putIfAbsent(eventId, GlobalKey.new);

  GlobalKey _adKeyFor(int adIdx) =>
      _adCardGlobalKeys.putIfAbsent(adIdx, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateActiveCard());
    _fetchInitial();
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _feedFocusNode.requestFocus();
      });
    }
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
        _adCardGlobalKeys.clear();
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
      // AppConfigRepository.current is already populated by the fire-and-forget
      // fetch in main.dart — no blocking network call needed here.
      final contextEventId = widget.discoveryState.events.isNotEmpty
          ? widget.discoveryState.events.first.id
          : null;

      // Respect config: skip API calls when the server has disabled a slot type.
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

      debugPrint(
        '[EventsFeed] _fetchInitial — '
        'adsEnabled=${cfg.adsEnabled} requestsEnabled=${cfg.requestsEnabled} | '
        'ad=${ad == null ? "none" : "adId=${ad.adId}"} | '
        'requests=${requests.length}',
      );
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
    debugPrint('[EventsFeed] _fetchMore — adSlot=${_ads.length} requestPage=${_requestPage + 1}');
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
        if (seenAdIds.contains(ad.adId)) {
          debugPrint('[EventsFeed] _fetchMore — duplicate adId=${ad.adId}, dropping');
          ad = null;
        }
      }

      if (!mounted) return;
      debugPrint(
        '[EventsFeed] _fetchMore — '
        'ad=${ad == null ? "none" : "adId=${ad.adId}"} | '
        'newRequests=${moreRequests.length}',
      );
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
    _feedFocusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Keyboard navigation (web desktop/laptop only) ─────────────────────────

  /// Scroll the card at [index] into view and update [_activeCardIndex].
  void _scrollToCard(String eventId, int index) {
    _activeCardIndex.value = index;
    final key = _cardKeys[eventId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0, // align top of card with top of viewport
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final events = widget.discoveryState.events;
    if (events.isEmpty) return KeyEventResult.ignored;
    final current = _activeCardIndex.value;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      final next = (current + 1).clamp(0, events.length - 1);
      if (next != current) _scrollToCard(events[next].id, next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      final prev = (current - 1).clamp(0, events.length - 1);
      if (prev != current) _scrollToCard(events[prev].id, prev);
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
    final idx =
        widget.discoveryState.events.indexWhere((e) => e.id == eventId);
    if (idx != -1 && _activeCardIndex.value == idx) {
      _activeCardIndex.value = -1;
    }

    final bloc = context.read<DiscoveryBloc>();
    bloc.add(DiscoveryEventHideRequested(eventId));

    AppSnackBar.withAction(
      context,
      AppLocalizations.of(context)!.discoveryContentHidden,
      actionLabel: AppLocalizations.of(context)!.discoveryUndo,
      onAction: () => bloc.add(const DiscoveryEventHideUndone()),
    ).then((reason) {
      if (reason != SnackBarClosedReason.action && !bloc.isClosed) {
        bloc.add(DiscoveryEventHideCommitted(eventId));
      }
    });
  }

  // ── Active card tracking ──────────────────────────────────────────────────

  void _updateActiveCard() {
    if (!mounted) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final viewportMid = screenH / 2;
    final events = widget.discoveryState.events;

    int? bestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < events.length; i++) {
      final key = _cardKeys[events[i].id];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      final cardCenter = pos.dy + box.size.height / 2;
      final dist = (cardCenter - viewportMid).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    if (bestIdx != null && bestIdx != _activeCardIndex.value) {
      _activeCardIndex.value = bestIdx;
    }

    _checkAdImpressions(screenH);
  }

  // Scans visible ad slots and fires impressions exactly once per slot.
  void _checkAdImpressions(double screenH) {
    for (final entry in _adCardGlobalKeys.entries) {
      final adIdx = entry.key;
      if (_firedAdImpressions.contains(adIdx)) continue;
      final ctx = entry.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      // Fire when any part of the card is within the screen.
      if (top + box.size.height > 0 && top < screenH) {
        _firedAdImpressions.add(adIdx);
        _fireAdImpression(adIdx);
      }
    }
  }

  Future<void> _fireAdImpression(int adIdx) async {
    final ad = adIdx < _ads.length ? _ads[adIdx] : null;
    if (ad == null) return;
    final contextEventId =
        adIdx < _adContextEventIds.length ? _adContextEventIds[adIdx] : null;
    debugPrint(
      '[EventsFeed] impression → adIdx=$adIdx adId=${ad.adId} token=${ad.impressionToken}',
    );
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

  // ── Chat ──────────────────────────────────────────────────────────────────

  Future<void> _openChat(
    BuildContext context,
    String userId,
    String userType,
    String displayName,
  ) async {
    debugPrint('[EventsFeed] _openChat → userId=$userId displayName="$displayName"');
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
        MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
      );
      if (context.mounted) roomsBloc?.add(const ChatRoomsLoadRequested());
    } catch (e) {
      debugPrint('[EventsFeed] _openChat ERROR: $e');
      if (!context.mounted) return;
      final blocked = e is ServerException && e.message.contains('400');
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
    final virtualItems = _buildVirtualList(
      state.events,
      state.isLoadingMore,
    );

    return Focus(
      focusNode: _feedFocusNode,
      onKeyEvent: kIsWeb ? _handleKeyEvent : null,
      child: NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollUpdateNotification) {
          final metrics = notification.metrics;
          if (metrics.pixels >= metrics.maxScrollExtent - 1000 &&
              !widget.discoveryState.isLoadingMore) {
            debugPrint(
              '[ForYouFeed] load-more threshold hit — '
              'offset=${metrics.pixels.toStringAsFixed(0)} '
              'maxExtent=${metrics.maxScrollExtent.toStringAsFixed(0)}',
            );
            widget.onLoadMore();
          }
          // Check ad visibility on every scroll frame.
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateActiveCard());
        } else if (notification is ScrollEndNotification) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateActiveCard());
        }
        return false;
      },
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          // On web the card manages its own 480px column + reactions panel via
          // LayoutBuilder — cap must not interfere. On mobile/tablet 720px
          // prevents cards from stretching too wide on large screens.
          constraints: kIsWeb
              ? const BoxConstraints()
              : const BoxConstraints(maxWidth: 720),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: widget.topPadding),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            builder: (context, pad, _) => ListView.builder(
            controller: _scrollCtrl,
            physics: kIsWeb
                ? const ClampingScrollPhysics()
                : const BouncingScrollPhysics(),
            // Keep fewer offscreen cards live on mobile — large cacheExtent
            // forces Flutter to decode images for items far off-screen, which
            // is the primary driver of OOM crashes on long feeds.
            cacheExtent: kIsWeb ? 2400 : 300,
            addAutomaticKeepAlives: false,
            padding: EdgeInsets.only(top: pad),
            itemCount: virtualItems.length,
            itemBuilder: (context, index) {
              final item = virtualItems[index];

              // ── Loading spinner ───────────────────────────────────────────
              if (item is _LoadingItem) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: const AppLoadingIndicator(),
                );
              }

              // ── Injected ad ───────────────────────────────────────────────
              if (item is _AdItem) {
                final adIdx = item.adIndex;
                final ad = adIdx < _ads.length ? _ads[adIdx] : null;

                // Primary path — real ad from the serve endpoint (with tracking).
                if (ad != null) {
                  debugPrint(
                    '[EventsFeed] _AdItem[$adIdx] — '
                    'adId=${ad.adId} '
                    'mediaCount=${ad.media.length} '
                    'mediaUrl=${ad.mediaUrl} '
                    'mediaType=${ad.mediaType} '
                    'media[0]url=${ad.media.isNotEmpty ? ad.media[0].url : "EMPTY"}',
                  );
                  return FeedItemCard(
                    key: _adKeyFor(adIdx),
                    data: FeedItemData.fromAd(
                      ad,
                      onCtaTap: () => _repo.trackClick(
                        adId: ad.adId,
                        campaignId: ad.campaignId,
                        impressionId: adIdx < _impressionIds.length
                            ? _impressionIds[adIdx]
                            : null,
                      ),
                      // Impression is fired by _checkAdImpressions() on
                      // first viewport entry — not on widget mount.
                    ),
                    onHide: () => setState(() {
                      if (adIdx < _ads.length) _ads[adIdx] = null;
                    }),
                  );
                }

                // /ads/serve returned null — no eligible ad, collapse the slot.
                return const SizedBox.shrink();
              }

              // ── Injected request ──────────────────────────────────────────
              if (item is _RequestItem) {
                final visible = _requests
                    .where((r) => !_hiddenRequestIds.contains(r.id))
                    .toList();
                if (item.requestIndex >= visible.length) {
                  return const SizedBox.shrink();
                }
                final req = visible[item.requestIndex];
                return FeedItemCard(
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
                  onHide: () =>
                      setState(() => _hiddenRequestIds.add(req.id)),
                );
              }

              // ── Event card ────────────────────────────────────────────────
              final eventItem = item as _EventItem;
              final event = eventItem.event;
              final isPending = state.pendingHideEventId == event.id;

              return ClipRect(
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  alignment: Alignment.topCenter,
                  heightFactor: isPending ? 0.0 : 1.0,
                  child: IgnorePointer(
                    ignoring: isPending,
                    child: EventDiscoveryCard(
                      key: _keyFor(event.id),
                      event: event,
                      cardIndex: eventItem.eventIndex,
                      activeCardIndex: _activeCardIndex,
                      isAuthenticated: true,
                      onTap: () => widget.onCardTap(event),
                      onCommentTap: () => widget.onCommentTap(event),
                      onHide: () => _onHide(event.id),
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ),
      ),
    ),
    );
  }
}
