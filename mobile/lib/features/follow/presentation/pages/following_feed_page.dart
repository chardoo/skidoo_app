import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/features/ads/presentation/feed_promos.dart';
import 'package:jperg_app/features/ads/presentation/widgets/feed_item_card.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_discovery_card.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/core/utils/web_wrap.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/services/auth_service.dart';

// ── What a row of this feed can be ────────────────────────────────────────────

sealed class _Row {
  const _Row();
}

final class _EventRow extends _Row {
  const _EventRow(this.event, this.index);
  final EventDiscovery event;

  /// The event's own position, which is what the active-card tracking counts —
  /// promos are not cards anyone is "on".
  final int index;
}

final class _AdRow extends _Row {
  const _AdRow(this.slot);
  final int slot;
}

final class _RequestRow extends _Row {
  const _RequestRow(this.slot);
  final int slot;
}

class FollowingFeedPage extends StatefulWidget {
  const FollowingFeedPage({super.key});

  @override
  State<FollowingFeedPage> createState() => _FollowingFeedPageState();
}

class _FollowingFeedPageState extends State<FollowingFeedPage> {
  final _repo = FollowRepository();
  final _activeCardIndex = ValueNotifier<int>(0);
  final _cardKeys = <String, GlobalKey>{};
  bool _activeCardUpdateScheduled = false;

  List<EventDiscovery> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;
  String? _pendingHideEventId;
  static const _limit = 20;

  /// So a request you posted yourself shows its count without an answer button.
  String _myUserId = '';

  /// Campaigns and requests, dealt in at half the rate Explore uses.
  ///
  /// This feed is the people you chose, so the bar for interrupting it is
  /// higher — but a request board nobody browses and a campaign nobody is
  /// shown are worth nothing to the people paying for them, and this is where
  /// the readers are. See [FeedPromos] for the boost rota.
  late final _promos = FeedPromos(
    onChanged: () {
      if (mounted) setState(() {});
    },
    intervalScale: 2,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleActiveCardUpdate());
    _load();
    _loadMyUserId();
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    _promos.dispose();
    super.dispose();
  }

  Future<void> _loadMyUserId() async {
    final id = await sl<AuthService>().getUserId();
    if (mounted) setState(() => _myUserId = id);
  }

  /// Events with the promo slots folded in, in the order they are scrolled
  /// through. Same arithmetic as Explore, at [FeedPromos.intervalScale] twice
  /// the interval — and a slot with nothing in it is left out rather than
  /// rendered as a gap.
  List<_Row> get _rows {
    final adsInterval = _promos.adsInterval;
    final requestsInterval = _promos.requestsInterval;

    final rows = <_Row>[];
    var adSlot = 0;
    var requestSlot = 0;

    for (var i = 0; i < _events.length; i++) {
      rows.add(_EventRow(_events[i], i));
      final count = i + 1;
      // Requests take priority when both intervals coincide — the same rule
      // the Explore feed follows.
      if (_promos.requestsEnabled && count % requestsInterval == 0) {
        final slot = requestSlot++;
        if (_promos.requestForSlot(slot) != null) rows.add(_RequestRow(slot));
      } else if (_promos.adsEnabled && count % adsInterval == 0) {
        final slot = adSlot++;
        if (_promos.adForSlot(slot) != null) rows.add(_AdRow(slot));
      }
    }
    return rows;
  }

  GlobalKey _keyFor(String eventId) =>
      _cardKeys.putIfAbsent(eventId, GlobalKey.new);

  // ── Active card tracking ──────────────────────────────────────────────────

  void _scheduleActiveCardUpdate() {
    if (_activeCardUpdateScheduled) return;
    _activeCardUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeCardUpdateScheduled = false;
      _updateActiveCard();
    });
  }

  void _updateActiveCard() {
    if (!mounted) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final viewportMid = screenH / 2;

    int? bestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < _events.length; i++) {
      final key = _cardKeys[_events[i].id];
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

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await _repo.getFollowFeed(page: 1, limit: _limit);
      if (!mounted) return;
      setState(() {
        _events = result.events;
        _loading = false;
        _hasMore = result.hasMore;
      });
      _promos.reset();
      _promos.loadInitial(
        contextEventId: result.events.isNotEmpty ? result.events.first.id : null,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) {
      debugPrint('[FollowingFeed] load-more skipped — already loading');
      return;
    }
    if (!_hasMore) {
      debugPrint('[FollowingFeed] load-more skipped — no more events');
      return;
    }
    final next = _page + 1;
    debugPrint(
      '[FollowingFeed] load-more START — currentCount=${_events.length} nextPage=$next',
    );
    setState(() => _loadingMore = true);
    try {
      final result = await _repo.getFollowFeed(page: next, limit: _limit);
      if (!mounted) return;
      debugPrint(
        '[FollowingFeed] load-more DONE — fetched=${result.events.length} '
        'totalNow=${_events.length + result.events.length} hasMore=${result.hasMore}',
      );
      setState(() {
        _page = next;
        _events = [..._events, ...result.events];
        _loadingMore = false;
        _hasMore = result.hasMore;
      });
      // A page more of events is a page more of slots to fill.
      _promos.loadMore(
        contextEventId: _events.isNotEmpty ? _events.last.id : null,
      );
    } catch (e) {
      debugPrint('[FollowingFeed] load-more ERROR: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  // ── Hide ──────────────────────────────────────────────────────────────────

  void _onHide(String eventId) {
    setState(() => _pendingHideEventId = eventId);

    AppSnackBar.withAction(
      context,
      AppLocalizations.of(context)!.discoveryContentHidden,
      actionLabel: AppLocalizations.of(context)!.discoveryUndo,
      onAction: () {
        if (mounted) setState(() => _pendingHideEventId = null);
      },
    ).then((reason) {
      if (reason != SnackBarClosedReason.action && mounted) {
        setState(() {
          _events.removeWhere((e) => e.id == eventId);
          if (_pendingHideEventId == eventId) _pendingHideEventId = null;
        });
      }
    });
  }

  // ── Promo rows ────────────────────────────────────────────────────────────

  /// A campaign or a request as a tile in this list, not a page of a pager:
  /// this feed scrolls, and a full-viewport poster in the middle of it would
  /// read as the end of the list. Boxed to the height the request board gives
  /// the same card. See [FeedItemCard.fullBleed].
  Widget _promoTile(Widget? card) {
    if (card == null) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md.w,
        AppSpacing.sm.h,
        AppSpacing.md.w,
        AppSpacing.sm.h,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        child: SizedBox(height: 520.h, child: card),
      ),
    );
  }

  Widget? _adCard(int slot) {
    final ad = _promos.adForSlot(slot);
    if (ad == null) return null;
    // Counted as seen when it is built, which in a scrolling list is the
    // nearest thing to "it came round": the pager can wait for a page change
    // because a page is the whole screen, and a tile is not.
    _promos.fireImpression(slot);
    return FeedItemCard(
      key: ValueKey('following_ad_${ad.adId}'),
      fullBleed: false,
      data: FeedItemData.fromAd(
        ad,
        onCtaTap: () => _promos.trackClick(ad, slot),
      ),
      onHide: () => _promos.hideAd(slot),
    );
  }

  Widget? _requestCard(int slot) {
    final req = _promos.requestForSlot(slot);
    if (req == null) return null;
    return FeedItemCard(
      // Slotted as well as identified: a boosted request comes round more than
      // once, and two rows of one list cannot share a key.
      key: ValueKey('following_req_${slot}_${req.id}'),
      fullBleed: false,
      data: FeedItemData.fromRequest(
        req,
        onAnswerTap: req.requesterId == _myUserId
            ? null
            : () => _promos.answer(context, req),
      ),
      onHide: () => _promos.hideRequest(req.id),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    String? currentUserId;
    try {
      currentUserId = context.read<DiscoveryBloc>().state.currentUserId;
    } catch (_) {}

    final page = Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: kIsWeb ? null : const AppBackButton(),
        title: Text(
          'Following',
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: false,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Divider(
            height: 0.5,
            thickness: 0.5,
            color: ext.searchHintColor.withValues(alpha: 0.12),
          ),
        ),
      ),
      body: _loading
          ? const AppLoadingIndicator()
          : _error != null
              ? AppErrorView(
                  message: _error!,
                  icon: Icons.wifi_off_outlined,
                  onRetry: _load,
                )
              : _events.isEmpty
                  ? const AppEmptyState(
                      icon: Icons.photo_camera_outlined,
                      message:
                          'No events yet — follow creators to see their work here.',
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n is ScrollUpdateNotification) {
                          if (n.metrics.pixels >=
                              n.metrics.maxScrollExtent - 1000) {
                            _loadMore();
                          }
                          _scheduleActiveCardUpdate();
                        } else if (n is ScrollEndNotification) {
                          _scheduleActiveCardUpdate();
                        }
                        return false;
                      },
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: ext.accentGold,
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 720),
                            child: Builder(builder: (context) {
                              final rows = _rows;
                              return ListView.builder(
                                physics: const BouncingScrollPhysics(
                                  decelerationRate: ScrollDecelerationRate.fast,
                                ),
                                cacheExtent: 1500,
                                padding: EdgeInsets.zero,
                                itemCount: rows.length + (_loadingMore ? 1 : 0),
                                itemBuilder: (_, i) {
                                  if (i == rows.length) {
                                    return Padding(
                                      padding: EdgeInsets.symmetric(
                                          vertical: AppSpacing.xl.h),
                                      child: const AppLoadingIndicator(),
                                    );
                                  }

                                  switch (rows[i]) {
                                    case _AdRow(:final slot):
                                      return _promoTile(_adCard(slot));
                                    case _RequestRow(:final slot):
                                      return _promoTile(_requestCard(slot));
                                    case _EventRow(:final event, :final index):
                                      final isPending =
                                          _pendingHideEventId == event.id;
                                      return ClipRect(
                                        child: AnimatedAlign(
                                          duration:
                                              const Duration(milliseconds: 380),
                                          curve: Curves.easeInOut,
                                          alignment: Alignment.topCenter,
                                          heightFactor: isPending ? 0.0 : 1.0,
                                          child: IgnorePointer(
                                            ignoring: isPending,
                                            child: EventDiscoveryCard(
                                              key: _keyFor(event.id),
                                              event: event,
                                              cardIndex: index,
                                              activeCardIndex: _activeCardIndex,
                                              isAuthenticated: true,
                                              isOwner: currentUserId != null &&
                                                  currentUserId ==
                                                      event.photographerId,
                                              onTap: () {},
                                              onCommentTap: () =>
                                                  EventCommentPage.show(
                                                      context, event),
                                              onHide: () => _onHide(event.id),
                                            ),
                                          ),
                                        ),
                                      );
                                  }
                                },
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground);
  }

}
