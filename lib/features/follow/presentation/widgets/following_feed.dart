import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_discovery_card.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/l10n/app_localizations.dart'; // for discoveryContentHidden / discoveryUndo
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class FollowingFeed extends StatefulWidget {
  const FollowingFeed({super.key});

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> {
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

  static const _initialLimit = 8;
  static const _pageLimit = 20;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _scheduleActiveCardUpdate());
    _load();
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    super.dispose();
  }

  GlobalKey _keyFor(String eventId) =>
      _cardKeys.putIfAbsent(eventId, GlobalKey.new);

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

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _page = 1;
    });
    try {
      final result = await _repo.getFollowFeed(page: 1, limit: _initialLimit);
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
      final result = await _repo.getFollowFeed(page: next, limit: _pageLimit);
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
    } catch (e) {
      debugPrint('[FollowingFeed] load-more ERROR: $e');
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

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

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    String? currentUserId;
    try {
      currentUserId = context.read<DiscoveryBloc>().state.currentUserId;
    } catch (_) {}

    if (_loading) return const AppLoadingIndicator();

    if (_error != null) {
      return AppErrorView(
        message: _error!,
        icon: Icons.wifi_off_outlined,
        onRetry: _load,
      );
    }

    if (_events.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_camera_outlined,
        message: 'No events yet — follow creators to see their work here.',
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        if (n is ScrollUpdateNotification) {
          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 1000 &&
              !_loadingMore) {
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
            child: ListView.builder(
              physics: const BouncingScrollPhysics(
                decelerationRate: ScrollDecelerationRate.fast,
              ),
              cacheExtent: 1500,
              padding: EdgeInsets.zero,
              itemCount: _events.length + (_loadingMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _events.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.h),
                    child: const AppLoadingIndicator(),
                  );
                }
                final event = _events[i];
                final isPending = _pendingHideEventId == event.id;
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
                        cardIndex: i,
                        activeCardIndex: _activeCardIndex,
                        isAuthenticated: true,
                        isOwner: currentUserId != null &&
                            currentUserId == event.photographerId,
                        onTap: () {},
                        onCommentTap: () =>
                            EventCommentPage.show(context, event),
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
    );
  }
}
