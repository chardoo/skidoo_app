import 'package:flutter/material.dart';
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
import 'package:skidoo_app/features/ads/models/ad_campaign.dart';
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
  });

  final DiscoveryState discoveryState;
  final ValueChanged<EventDiscovery> onCardTap;
  final ValueChanged<EventDiscovery> onCommentTap;
  final VoidCallback onLoadMore;

  @override
  State<EventsFeed> createState() => _EventsFeedState();
}

class _EventsFeedState extends State<EventsFeed> {
  final _activeCardIndex = ValueNotifier<int>(0);
  final _cardKeys = <String, GlobalKey>{};
  final _repo = AdsRepository();

  // One ad per slot — fetched fresh from the server for each slot.
  final List<AdModel?> _ads = [];
  // Per-slot impression IDs, populated when onInit fires.
  final List<String?> _impressionIds = [];

  // Fallback: campaigns fetched directly when serveAd returns null.
  // Mirrors how requests are fetched — shown in ad slots until real ads exist.
  List<AdCampaign> _fallbackCampaigns = [];

  // All requests fetched so far (paginated on load-more).
  List<FeedRequestModel> _requests = [];
  int _requestPage = 1;
  final _hiddenRequestIds = <String>{};

  // Guards against overlapping fetch-more calls.
  bool _fetchingMore = false;

  GlobalKey _keyFor(String eventId) =>
      _cardKeys.putIfAbsent(eventId, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateActiveCard());
    _fetchInitial();
  }

  @override
  void didUpdateWidget(EventsFeed old) {
    super.didUpdateWidget(old);
    // When the discovery feed grows (load-more fired), fetch a new ad and the
    // next page of requests so the newly created slots have fresh content.
    final grew = widget.discoveryState.events.length >
        old.discoveryState.events.length;
    if (grew) _fetchMore();
  }

  // ── Data fetching ─────────────────────────────────────────────────────────

  Future<void> _fetchInitial() async {
    debugPrint('[EventsFeed] _fetchInitial');
    try {
      // Await config first so _buildVirtualList reads the correct adsEnabled /
      // requestsEnabled flags rather than racing with the ad+request fetch.
      try {
        await sl<AppConfigRepository>().fetch();
      } catch (_) {}

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

      // When the ad-serve pipeline returns nothing (campaigns not yet active),
      // fall back to fetching campaigns directly — same pattern as requests.
      List<AdCampaign> fallbackCampaigns = _fallbackCampaigns;
      if (ad == null && cfg.adsEnabled && fallbackCampaigns.isEmpty) {
        try {
          fallbackCampaigns = await _repo.getCampaignFeed(page: 1);
          debugPrint('[EventsFeed] _fetchInitial — fallback campaigns=${fallbackCampaigns.length}');
        } catch (e) {
          debugPrint('[EventsFeed] _fetchInitial getCampaignFeed ERROR: $e');
        }
      }

      if (!mounted) return;
      debugPrint(
        '[EventsFeed] _fetchInitial — '
        'adsEnabled=${cfg.adsEnabled} requestsEnabled=${cfg.requestsEnabled} | '
        'ad=${ad == null ? "none" : "adId=${ad.adId}"} | '
        'fallbackCampaigns=${fallbackCampaigns.length} | '
        'requests=${requests.length}',
      );
      setState(() {
        _ads
          ..clear()
          ..add(ad);
        _impressionIds
          ..clear()
          ..add(null);
        if (fallbackCampaigns.isNotEmpty) _fallbackCampaigns = fallbackCampaigns;
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
      final ad = results[0] as AdModel?;
      final moreRequests = results[1] as List<FeedRequestModel>;

      // Fetch fallback campaigns once if we haven't already.
      if (ad == null && cfg.adsEnabled && _fallbackCampaigns.isEmpty) {
        try {
          final fallback = await _repo.getCampaignFeed(page: 1);
          if (!mounted) return;
          if (fallback.isNotEmpty) {
            setState(() => _fallbackCampaigns = fallback);
          }
          debugPrint('[EventsFeed] _fetchMore — fallback campaigns=${fallback.length}');
        } catch (e) {
          debugPrint('[EventsFeed] _fetchMore getCampaignFeed ERROR: $e');
        }
      }

      if (!mounted) return;
      debugPrint(
        '[EventsFeed] _fetchMore — '
        'ad=${ad == null ? "none" : "adId=${ad.adId}"} | '
        'fallbackCampaigns=${_fallbackCampaigns.length} | '
        'newRequests=${moreRequests.length}',
      );
      setState(() {
        _ads.add(ad);
        _impressionIds.add(null);
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
    super.dispose();
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

    return NotificationListener<ScrollNotification>(
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
        } else if (notification is ScrollEndNotification) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateActiveCard());
        }
        return false;
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView.builder(
            physics: const BouncingScrollPhysics(),
            cacheExtent: 1500,
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
                      onInit: () async {
                        final id = await _repo.trackImpression(
                          adId: ad.adId,
                          adsetId: ad.adsetId,
                          campaignId: ad.campaignId,
                          placement: ad.placement,
                          impressionToken: ad.impressionToken,
                        );
                        if (mounted && adIdx < _impressionIds.length) {
                          _impressionIds[adIdx] = id;
                        }
                      },
                    ),
                    onHide: () => setState(() {
                      if (adIdx < _ads.length) _ads[adIdx] = null;
                    }),
                  );
                }

                // Fallback path — direct campaign list (mirrors how requests work).
                // Used when the serve endpoint returns null because campaigns are
                // not yet fully configured in the ad pipeline.
                if (_fallbackCampaigns.isNotEmpty) {
                  final campaign =
                      _fallbackCampaigns[adIdx % _fallbackCampaigns.length];
                  return FeedItemCard(
                    key: ValueKey('campaign_${campaign.id}_$adIdx'),
                    data: FeedItemData.fromCampaign(campaign),
                    onHide: () => setState(() {
                      _fallbackCampaigns = _fallbackCampaigns
                          .where((c) => c.id != campaign.id)
                          .toList();
                    }),
                  );
                }

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
    );
  }
}
