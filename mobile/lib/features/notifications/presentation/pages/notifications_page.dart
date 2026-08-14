import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/notifications/data/notification_inbox.dart';
import 'package:jperg_app/features/notifications/data/notification_service.dart';

/// The notification inbox.
///
/// Every notification the backend sends writes a row here, whether or not it
/// also pushed — so this is where someone finds what they swiped away, and the
/// only place a muted category still shows up. Tapping one goes to the same
/// destination the push would have.
///
/// The rows live in [NotificationInbox] rather than in this state, so leaving
/// the tab and coming back shows what was there — read marks, paged-in rows and
/// all — instead of refetching the same list. A push arriving is what makes it
/// fetch again; pull-to-refresh asks regardless.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = NotificationApi();
  final _scroll = ScrollController();
  final _inbox = NotificationInbox.instance;

  /// Whether the spinner is up. Only true when there is nothing behind it — a
  /// refetch over rows already on screen is silent.
  bool _loading = false;

  /// Whether a first-page request is in the air, spinner or not. Two pushes
  /// landing together would otherwise start two of them.
  bool _fetching = false;

  bool _loadingMore = false;
  String? _error;

  static const _pageSize = 20;

  List<AppNotification> get _items => _inbox.items;
  bool get _exhausted => _inbox.exhausted;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // While this page is up, a push should land in the list rather than wait
    // for the next visit.
    AppCacheSignals.notifications.addListener(_onInboxStale);
    if (!_inbox.isFresh) _load();
  }

  @override
  void dispose() {
    AppCacheSignals.notifications.removeListener(_onInboxStale);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onInboxStale() {
    if (mounted) _load();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _exhausted) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _loadMore();
  }

  Future<void> _load() async {
    if (_fetching) return;
    _fetching = true;
    final at = AppCacheSignals.notifications.value;
    setState(() {
      // A spinner only when there is nothing to show. A refetch behind rows
      // that are already up replaces them when it lands; blanking the list
      // first is what made the tab look like it reloaded on every visit.
      _loading = _items.isEmpty;
      _error = null;
    });
    var loaded = false;
    try {
      final rows = await _api.list(page: 1, limit: _pageSize);
      if (!mounted) return;
      loaded = true;
      setState(() {
        _inbox.reset(rows, exhausted: rows.length < _pageSize, at: at);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Rows already held are still worth showing — the error screen is for
        // when there is nothing behind it.
        if (_items.isEmpty) _error = 'Could not load your notifications.';
      });
    } finally {
      _fetching = false;
    }

    // A push that landed while the request was in the air had its listener
    // turned away by the guard above, and nothing else will come back for it.
    // Only after a success: going again on a failure would spin.
    if (loaded && mounted && AppCacheSignals.notifications.value != at) {
      unawaited(_load());
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final rows = await _api.list(page: _inbox.page + 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _inbox.append(rows, exhausted: rows.length < _pageSize);
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      // A failed page is not worth an error screen — the rows already on
      // screen are still good, and scrolling will try again.
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _open(AppNotification item) async {
    // Marked read straight away and optimistically: waiting on the request
    // before navigating puts a network round trip between the tap and the
    // screen, and the badge correcting itself later is invisible.
    if (!item.isRead) {
      if (_inbox.markRead(item.id)) setState(() {});
      _api.markRead(item.id);
    }

    final link = item.destination;
    if (link == null) {
      // A row written by a newer backend than this build knows about. Nothing
      // to open, and nothing worth interrupting anyone over.
      return;
    }
    await DeepLinkService.instance?.follow(link);
  }

  Future<void> _markAllRead() async {
    setState(_inbox.markAllRead);
    await _api.markAllRead();
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final hasUnread = _items.any((n) => !n.isRead);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: NestedScrollView(
        headerSliverBuilder: (context, _) => [
          SliverAppBar(
            automaticallyImplyLeading: false,
            backgroundColor: Colors.transparent,
            surfaceTintColor: Colors.transparent,
            floating: true,
            snap: true,
            elevation: 0,
            titleSpacing: 16.w,
            title: Text(
              'Notifications',
              style: TextStyle(
                color: ext.greetingColor,
                fontWeight: FontWeight.bold,
                fontSize: 20.sp,
              ),
            ),
            actions: [
              if (hasUnread)
                TextButton(
                  onPressed: _markAllRead,
                  child: Text(
                    'Mark all read',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                ),
            ],
          ),
        ],
        body: RefreshIndicator(
          onRefresh: _load,
          child: _buildBody(ext),
        ),
      ),
    );
  }

  Widget _buildBody(AppThemeExtension ext) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      // Scrollable so pull-to-refresh still works from the error state —
      // otherwise the only way to retry is to leave the tab and come back.
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120.h),
          AppEmptyState(
            icon: Icons.cloud_off_rounded,
            message: _error!,
            action:
                TextButton(onPressed: _load, child: const Text('Try again')),
          ),
        ],
      );
    }

    if (_items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: 120.h),
          const AppEmptyState(
            icon: Icons.notifications_none_rounded,
            message: 'No notifications yet.',
          ),
        ],
      );
    }

    return ListView.separated(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(bottom: 96.h),
      itemCount: _items.length + (_exhausted ? 0 : 1),
      separatorBuilder: (_, __) => Divider(
        height: 1,
        thickness: 0.5,
        color: ext.searchHintColor.withValues(alpha: 0.15),
      ),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        return _NotificationTile(
          item: _items[index],
          onTap: () => _open(_items[index]),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.item, required this.onTap});

  final AppNotification item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final unread = !item.isRead;

    return InkWell(
      onTap: onTap,
      child: Container(
        // Unread carries a tint as well as the dot: the dot alone is easy to
        // miss on a long list, and the tint is what makes "what's new" legible
        // at a glance.
        color: unread
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)
            : Colors.transparent,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8.w,
              height: 8.w,
              margin: EdgeInsets.only(top: 6.h, right: 12.w),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: unread
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontSize: 15.sp,
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    item.body,
                    style: TextStyle(
                      color: ext.searchHintColor,
                      fontSize: 13.sp,
                      height: 1.35,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    _relativeTime(item.createdAt),
                    style: TextStyle(
                      color: ext.searchHintColor.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                    ),
                  ),
                ],
              ),
            ),
            if (item.destination != null)
              Icon(
                Icons.chevron_right_rounded,
                size: 20.sp,
                color: ext.searchHintColor,
              ),
          ],
        ),
      ),
    );
  }
}

String _relativeTime(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${when.day}/${when.month}/${when.year}';
}
