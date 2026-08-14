import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/cache/session_cache.dart';
import 'package:jperg_app/core/common/widgets/app_empty_state.dart';
import 'package:jperg_app/core/deep_links/deep_link_service.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/time_formatter.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
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

/// One chip. `category` is what the endpoint takes; null is every category,
/// which is the tab that has no filter rather than a filter named "all".
typedef _Filter = ({String? category, String label});

class _NotificationsPageState extends State<NotificationsPage> {
  final _api = NotificationApi();
  final _scroll = ScrollController();
  final _inbox = NotificationInbox.instance;

  /// The tabs, in the order they read. Money rather than "Purchases" because
  /// the tab holds both ends of it — what you paid and what you were paid.
  static const _filters = <_Filter>[
    (category: null, label: 'All'),
    (category: 'photos', label: 'Photos'),
    (category: 'bookings', label: 'Bookings'),
    (category: 'money', label: 'Money'),
    (category: 'social', label: 'Social'),
  ];

  String? _filter;

  /// Whether the spinner is up. Only true when there is nothing behind it — a
  /// refetch over rows already on screen is silent.
  bool _loading = false;

  /// The tabs with a first-page request in the air, spinner or not. Two pushes
  /// landing together would otherwise start two of them — and switching tab
  /// while one is in flight has to be able to start the other.
  final _inFlight = <String>{};

  bool _loadingMore = false;
  String? _error;

  static const _pageSize = 20;

  String get _key => _filter ?? '';
  List<AppNotification> get _items => _inbox.items(filter: _filter);
  bool get _exhausted => _inbox.exhausted(filter: _filter);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    // While this page is up, a push should land in the list rather than wait
    // for the next visit.
    AppCacheSignals.notifications.addListener(_onInboxStale);
    if (!_inbox.isFresh(filter: _filter)) _load();
  }

  @override
  void dispose() {
    AppCacheSignals.notifications.removeListener(_onInboxStale);
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    super.dispose();
  }

  void _onInboxStale() {
    // Only the tab being looked at. The others are stale too — freshness is
    // measured against the one signal — so each refetches when it is next
    // selected, rather than five requests going out for four lists nobody is
    // reading.
    if (mounted) _load();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loadingMore || _exhausted) return;
    final remaining =
        _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _loadMore();
  }

  void _selectFilter(String? category) {
    if (_filter == category) return;
    setState(() {
      _filter = category;
      // Both belong to the tab being left. A failed load on Photos is not a
      // reason to show Bookings an error screen.
      _error = null;
      _loadingMore = false;
    });
    if (!_inbox.isFresh(filter: category)) _load();
  }

  Future<void> _load() async {
    // Captured, not read again later: the tab can change while this is in the
    // air, and the rows that come back belong to the tab that asked for them.
    final filter = _filter;
    final key = filter ?? '';
    if (_inFlight.contains(key)) return;
    _inFlight.add(key);

    final at = AppCacheSignals.notifications.value;
    setState(() {
      // A spinner only when there is nothing to show. A refetch behind rows
      // that are already up replaces them when it lands; blanking the list
      // first is what made the tab look like it reloaded on every visit.
      _loading = _inbox.items(filter: filter).isEmpty;
      if (filter == _filter) _error = null;
    });
    var loaded = false;
    try {
      final rows = await _api.list(page: 1, limit: _pageSize, category: filter);
      if (!mounted) return;
      loaded = true;
      setState(() {
        _inbox.reset(
          rows,
          exhausted: rows.length < _pageSize,
          at: at,
          filter: filter,
        );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        // Rows already held are still worth showing — the error screen is for
        // when there is nothing behind it.
        if (_inbox.items(filter: filter).isEmpty && filter == _filter) {
          _error = 'Could not load your notifications.';
        }
      });
    } finally {
      _inFlight.remove(key);
    }

    // A push that landed while the request was in the air had its listener
    // turned away by the guard above, and nothing else will come back for it.
    // Only after a success: going again on a failure would spin.
    if (loaded &&
        mounted &&
        filter == _filter &&
        AppCacheSignals.notifications.value != at) {
      unawaited(_load());
    }
  }

  Future<void> _loadMore() async {
    final filter = _filter;
    setState(() => _loadingMore = true);
    try {
      final rows = await _api.list(
        page: _inbox.page(filter: filter) + 1,
        limit: _pageSize,
        category: filter,
      );
      if (!mounted) return;
      setState(() {
        _inbox.append(
          rows,
          exhausted: rows.length < _pageSize,
          filter: filter,
        );
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

  void _markRead(AppNotification item) {
    if (item.isRead) return;
    if (_inbox.markRead(item.id)) setState(() {});
    _api.markRead(item.id);
  }

  Future<void> _delete(AppNotification item) async {
    // Gone from the list first, request second. A delete that fails leaves the
    // row on the server, and the next load brings it back — which is a far
    // smaller surprise than a tap that appears to do nothing.
    setState(() => _inbox.remove(item.id));
    try {
      await _api.delete(item.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete that notification.')),
      );
    }
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
            bottom: PreferredSize(
              preferredSize: Size.fromHeight(52.h),
              child: _FilterBar(
                filters: _filters,
                selected: _filter,
                onSelected: _selectFilter,
              ),
            ),
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
          AppEmptyState(
            icon: Icons.notifications_none_rounded,
            message: _filter == null
                ? 'No notifications yet.'
                : 'Nothing under this filter yet.',
          ),
        ],
      );
    }

    return ListView.separated(
      // Per tab, so switching back to one lands where it was left rather than
      // at the top of a list somebody had scrolled through.
      key: PageStorageKey<String>('notifications-$_key'),
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
        final item = _items[index];
        return _NotificationTile(
          item: item,
          onTap: () => _open(item),
          onMarkRead: () => _markRead(item),
          onDelete: () => _delete(item),
        );
      },
    );
  }
}

/// The row of chips under the title.
///
/// Server-side filters, not a client-side sieve over the page in hand: the list
/// is paged, so a tab that filtered what it had been sent would show whatever
/// happened to be in the first twenty rows and call it the whole category.
class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filters,
    required this.selected,
    required this.onSelected,
  });

  final List<_Filter> filters;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final primary = Theme.of(context).colorScheme.primary;

    return SizedBox(
      height: 52.h,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
        itemCount: filters.length,
        separatorBuilder: (_, __) => SizedBox(width: 8.w),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = filter.category == selected;
          return Semantics(
            selected: isSelected,
            button: true,
            child: InkWell(
              onTap: () => onSelected(filter.category),
              borderRadius: BorderRadius.circular(999.r),
              child: Container(
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: 16.w),
                decoration: BoxDecoration(
                  color: isSelected ? primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999.r),
                  border: Border.all(
                    color: isSelected
                        ? primary
                        : ext.searchHintColor.withValues(alpha: 0.35),
                  ),
                ),
                child: Text(
                  filter.label,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : ext.greetingColor,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.onTap,
    required this.onMarkRead,
    required this.onDelete,
  });

  final AppNotification item;
  final VoidCallback onTap;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final unread = !item.isRead;
    final look = _lookFor(item.type);

    return Semantics(
      button: true,
      // The row reads as one sentence to a screen reader, ending in the moment
      // it happened — spelled out, because "2w" is not something to listen to.
      label: '${item.title}. ${item.body}. '
          '${TimeFormatter.absolute(item.createdAt)}'
          '${unread ? '. Unread' : ''}',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          child: Container(
            // Unread carries a tint as well as the dot: the dot alone is easy to
            // miss on a long list, and the tint is what makes "what's new"
            // legible at a glance.
            color: unread
                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.06)
                : Colors.transparent,
            padding: EdgeInsets.fromLTRB(8.w, 12.h, 4.w, 12.h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8.w,
                  height: 8.w,
                  margin: EdgeInsets.only(top: 20.h, right: 8.w),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unread
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                  ),
                ),
                _Thumbnail(imageUrl: item.imageUrl, look: look),
                SizedBox(width: 12.w),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 2.h),
                    child: RichText(
                      // One paragraph rather than a heading and a subtitle: the
                      // title is the first few words of the sentence the body
                      // finishes ("Campaign Approved — your campaign is live"),
                      // and stacking them made every row two lines of the same
                      // thing at two different weights.
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 14.sp,
                          height: 1.35,
                          color: ext.searchHintColor,
                        ),
                        children: [
                          TextSpan(
                            text: item.title,
                            style: TextStyle(
                              color: ext.greetingColor,
                              fontWeight:
                                  unread ? FontWeight.w700 : FontWeight.w600,
                            ),
                          ),
                          if (item.body.isNotEmpty)
                            TextSpan(text: '  ${item.body}'),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Fixed width, so the stamp and the menu line up down the list
                // and a long label cannot take space off the sentence. Without
                // it every row's text ended in a different place.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        _stamp(item.createdAt),
                        maxLines: 1,
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          color: ext.searchHintColor.withValues(alpha: 0.8),
                          fontSize: 11.sp,
                          fontWeight:
                              unread ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ),
                    SizedBox(height: 2.h),
                    _RowMenu(
                      unread: unread,
                      onMarkRead: onMarkRead,
                      onDelete: onDelete,
                      color: ext.searchHintColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The corner stamp: "now", "5m", "3h", "2d", "15/4".
///
/// [TimeFormatter.relative] everywhere else, but "Just now" is eight characters
/// in a corner sized for three. The exact moment is still spoken by the row's
/// semantics label.
String _stamp(DateTime when) {
  final label = TimeFormatter.relative(when);
  return label == 'Just now' ? 'now' : label;
}

/// The picture on the left: whatever the notification is about, or the icon for
/// its kind when it is about nothing you can photograph.
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl, required this.look});

  final String? imageUrl;
  final _Look look;

  static const _size = 44.0;

  @override
  Widget build(BuildContext context) {
    final fallback = Container(
      width: _size.w,
      height: _size.w,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: look.color.withValues(alpha: 0.15),
      ),
      child: Icon(look.icon, size: 22.sp, color: look.color),
    );

    if (imageUrl == null || imageUrl!.isEmpty) return fallback;

    return ClipOval(
      child: JpergImage(
        imageUrl: imageUrl!,
        width: _size.w,
        height: _size.w,
        logicalWidth: _size.w,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.unread,
    required this.onMarkRead,
    required this.onDelete,
    required this.color,
  });

  final bool unread;
  final VoidCallback onMarkRead;
  final VoidCallback onDelete;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 32.w,
      height: 28.h,
      child: PopupMenuButton<String>(
        tooltip: 'Notification options',
        padding: EdgeInsets.zero,
        iconSize: 18.sp,
        icon: Icon(Icons.more_horiz_rounded, color: color),
        onSelected: (value) {
          if (value == 'read') onMarkRead();
          if (value == 'delete') onDelete();
        },
        itemBuilder: (context) => [
          if (unread)
            const PopupMenuItem(
              value: 'read',
              child: Text('Mark as read'),
            ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// What a kind of notification looks like when it has no picture of its own.
typedef _Look = ({IconData icon, Color color});

/// Keyed on the type the backend sends — the same strings POLICY in
/// main/app/services/notify.py is written in. A kind this build has never heard
/// of gets the bell, which is the honest answer rather than a wrong icon.
_Look _lookFor(String type) {
  const photos = Color(0xFF2E9E7B);
  const money = Color(0xFF2F8F4E);
  const bookings = Color(0xFF3D6DF0);
  const campaigns = Color(0xFFE08A2B);
  const social = Color(0xFF8B5CF6);
  const account = Color(0xFF6B7280);
  const alert = Color(0xFFD84343);

  return switch (type) {
    'image_recognised' => (icon: Icons.photo_camera_rounded, color: photos),
    'new_event' => (icon: Icons.photo_library_rounded, color: photos),
    'likes_digest' => (icon: Icons.favorite_rounded, color: social),

    'payment_success' => (icon: Icons.receipt_long_rounded, color: money),
    'payment_failed' => (icon: Icons.error_outline_rounded, color: alert),
    'photographer_sale' => (icon: Icons.sell_rounded, color: money),
    'cashout_requested' ||
    'cashout_approved' ||
    'cashout_paid' =>
      (icon: Icons.account_balance_wallet_rounded, color: money),
    'cashout_failed' => (icon: Icons.account_balance_wallet_rounded, color: alert),

    'request_interest' => (icon: Icons.waving_hand_rounded, color: bookings),
    'request_updated' => (icon: Icons.edit_calendar_rounded, color: bookings),
    'request_selected' => (icon: Icons.how_to_reg_rounded, color: bookings),
    'request_cancelled' => (icon: Icons.event_busy_rounded, color: alert),
    'request_expiring' => (icon: Icons.hourglass_bottom_rounded, color: bookings),
    'ad_request_approved' => (icon: Icons.task_alt_rounded, color: bookings),
    'ad_request_rejected' => (icon: Icons.cancel_outlined, color: alert),

    'campaign_approved' => (icon: Icons.campaign_rounded, color: campaigns),
    'campaign_awaiting_payment' => (icon: Icons.payments_rounded, color: campaigns),
    'campaign_paused' => (icon: Icons.pause_circle_outline_rounded, color: campaigns),
    'campaign_rejected' ||
    'campaign_payment_expired' =>
      (icon: Icons.campaign_rounded, color: alert),
    'budget_low' => (icon: Icons.trending_down_rounded, color: alert),

    'new_follower' => (icon: Icons.person_add_alt_1_rounded, color: social),
    'new_review' => (icon: Icons.star_rounded, color: social),
    'new_comment' ||
    'comment_reply' ||
    'new_event_comment' ||
    'event_comment_reply' =>
      (icon: Icons.chat_bubble_rounded, color: social),

    'welcome' => (icon: Icons.celebration_rounded, color: photos),
    'password_reset_success' => (icon: Icons.lock_reset_rounded, color: account),
    'verification_approved' => (icon: Icons.verified_rounded, color: photos),
    'verification_rejected' => (icon: Icons.gpp_maybe_rounded, color: alert),
    'content_removed' || 'account_suspended' => (
      icon: Icons.report_gmailerrorred_rounded,
      color: alert,
    ),
    'broadcast' => (icon: Icons.campaign_rounded, color: account),

    _ => (icon: Icons.notifications_rounded, color: account),
  };
}
