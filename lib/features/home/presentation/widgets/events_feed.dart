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
import 'package:skidoo_app/features/ads/presentation/widgets/ad_feed_card.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/request_feed_card.dart';
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

final class _AdItem extends _FeedItem {
  const _AdItem();
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
  var adSlotCount = 0;

  for (var i = 0; i < events.length; i++) {
    items.add(_EventItem(events[i], i));
    final count = i + 1;
    // Requests take priority when both intervals coincide.
    if (count % requestsInterval == 0) {
      if (cfg.requestsEnabled) items.add(_RequestItem(requestSlot++));
    } else if (count % adsInterval == 0) {
      if (cfg.adsEnabled) {
        items.add(const _AdItem());
        adSlotCount++;
      }
    }
  }

  // When the feed is shorter than both intervals, append one slot of each
  // so they always appear. The builder collapses them when data is absent.
  if (events.isNotEmpty) {
    if (adSlotCount == 0 && cfg.adsEnabled) items.add(const _AdItem());
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

  AdModel? _servedAd;
  List<FeedRequestModel> _requests = [];

  GlobalKey _keyFor(String eventId) =>
      _cardKeys.putIfAbsent(eventId, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _updateActiveCard());
    _fetchAdsData();
  }

  Future<void> _fetchAdsData() async {
    debugPrint('[EventsFeed] _fetchAdsData start');
    try {
      // Fetch config in parallel — failure is non-fatal, defaults remain.
      sl<AppConfigRepository>().fetch().catchError((_) => AppConfigRepository.current);
      final results = await Future.wait([
        _repo.serveAd(placement: 'event_feed'),
        _repo.getRequests(),
      ]);
      if (!mounted) return;
      final ad = results[0] as AdModel?;
      final requests = results[1] as List<FeedRequestModel>;
      debugPrint(
        '[EventsFeed] _fetchAdsData done ─── '
        'ad=${ad == null ? "NULL (no active campaign)" : "✓ adId=${ad.adId} headline=${ad.headline}"} | '
        'requests=${requests.length} items',
      );
      if (ad == null) {
        debugPrint('[EventsFeed] ad slot will be hidden — serveAd returned null');
      }
      if (requests.isEmpty) {
        debugPrint('[EventsFeed] request slot will be hidden — getRequests returned empty list');
      }
      setState(() {
        _servedAd = ad;
        _requests = requests;
      });
    } catch (e, st) {
      debugPrint('[EventsFeed] _fetchAdsData ERROR: $e\n$st');
    }
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    super.dispose();
  }

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

  Future<void> _openChat(
    BuildContext context,
    String userId,
    String userType,
    String displayName,
  ) async {
    debugPrint('[EventsFeed] _openChat → userId=$userId userType=$userType displayName="$displayName"');
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
      debugPrint('[EventsFeed] _openChat — room created/found roomId=${room.id}');
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
          if (metrics.pixels >= metrics.maxScrollExtent - 300) {
            widget.onLoadMore();
          }
          WidgetsBinding.instance
              .addPostFrameCallback((_) => _updateActiveCard());
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
            itemCount: virtualItems.length,
            itemBuilder: (context, index) {
              final item = virtualItems[index];

              // ── Loading spinner ─────────────────────────────────────────
              if (item is _LoadingItem) {
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: 20.h),
                  child: const AppLoadingIndicator(),
                );
              }

              // ── Injected ad ─────────────────────────────────────────────
              if (item is _AdItem) {
                final ad = _servedAd;
                if (ad == null) {
                  return const SizedBox.shrink();
                }
                return AdFeedCard(
                  key: ValueKey('ad_${item.hashCode}'),
                  ad: ad,
                );
              }

              // ── Injected request ────────────────────────────────────────
              if (item is _RequestItem) {
                if (item.requestIndex >= _requests.length) {
                  return const SizedBox.shrink();
                }
                final req = _requests[item.requestIndex];
                return RequestFeedCard(
                  key: ValueKey('req_${req.id}'),
                  request: req,
                  onMessageTap: () => _openChat(
                    context,
                    req.requesterId,
                    req.requesterType,
                    req.requesterName,
                  ),
                );
              }

              // ── Event card ──────────────────────────────────────────────
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
