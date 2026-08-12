import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/notifications/data/notification_service.dart';

/// The notification inbox.
///
/// Every notification the backend sends writes a row here, whether or not it
/// also pushed — so this is where someone finds what they swiped away, and the
/// only place a muted category still shows up. Tapping one goes to the same
/// destination the push would have.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = NotificationApi();
  final _scroll = ScrollController();

  final List<AppNotification> _items = [];
  bool _loading = true;
  bool _loadingMore = false;
  bool _exhausted = false;
  String? _error;
  int _page = 1;

  static const _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _load();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _exhausted) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _loadMore();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rows = await _api.list(page: 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(rows);
        _page = 1;
        _exhausted = rows.length < _pageSize;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Could not load your notifications.';
      });
    }
  }

  Future<void> _loadMore() async {
    setState(() => _loadingMore = true);
    try {
      final rows = await _api.list(page: _page + 1, limit: _pageSize);
      if (!mounted) return;
      setState(() {
        _items.addAll(rows);
        _page += 1;
        _exhausted = rows.length < _pageSize;
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
      final index = _items.indexWhere((n) => n.id == item.id);
      if (index != -1) {
        setState(() => _items[index] = item.copyWith(isRead: true));
      }
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
    setState(() {
      for (var i = 0; i < _items.length; i++) {
        _items[i] = _items[i].copyWith(isRead: true);
      }
    });
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
