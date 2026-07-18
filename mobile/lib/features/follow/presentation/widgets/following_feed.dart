import 'package:flutter/material.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

/// TikTok-style vertically-paged "Following" feed — same paging mechanism
/// and [FullBleedEventCard] as `events_feed.dart`'s "For You" feed, just
/// backed by `FollowRepository.getFollowFeed` instead of `DiscoveryBloc`.
class FollowingFeed extends StatefulWidget {
  const FollowingFeed({super.key, this.topPadding = 0});

  final double topPadding;

  @override
  State<FollowingFeed> createState() => _FollowingFeedState();
}

class _FollowingFeedState extends State<FollowingFeed> {
  final _repo = FollowRepository();
  final _activeCardIndex = ValueNotifier<int>(0);
  final _pageCtrl = PageController();

  List<EventDiscovery> _events = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  static const _initialLimit = 8;
  static const _pageLimit = 20;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _activeCardIndex.dispose();
    _pageCtrl.dispose();
    super.dispose();
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
    if (_loadingMore || !_hasMore) return;
    final next = _page + 1;
    setState(() => _loadingMore = true);
    try {
      final result = await _repo.getFollowFeed(page: next, limit: _pageLimit);
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

  void _onPageChanged(int pageIndex) {
    _activeCardIndex.value = pageIndex;
    if (pageIndex >= _events.length - 2 && !_loadingMore) _loadMore();
  }

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

    if (_events.isEmpty) {
      return const AppEmptyState(
        icon: Icons.photo_camera_outlined,
        message: 'No events yet — follow creators to see their work here.',
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: ext.accentGold,
      child: Padding(
        padding: EdgeInsets.only(top: widget.topPadding),
        child: PageView.builder(
          controller: _pageCtrl,
          scrollDirection: Axis.vertical,
          itemCount: _events.length + (_loadingMore ? 1 : 0),
          onPageChanged: _onPageChanged,
          itemBuilder: (_, i) {
            if (i == _events.length) {
              return const Center(child: CircularProgressIndicator());
            }
            final event = _events[i];
            return FullBleedEventCard(
              key: ValueKey('following_event_${event.id}'),
              event: event,
              cardIndex: i,
              activeCardIndex: _activeCardIndex,
              onTap: () {},
              onHide: () => _onHide(event.id),
            );
          },
        ),
      ),
    );
  }
}
