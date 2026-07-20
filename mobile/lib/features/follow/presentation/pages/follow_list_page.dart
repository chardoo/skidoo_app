import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/time_formatter.dart';
import 'package:skidoo_app/core/widgets/animations/app_animations.dart';
import 'package:skidoo_app/core/utils/web_panel_route.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographer_profile_page.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';

/// Viewport width at/above which web shows the sidebar + content layout, so the
/// follow list opens as the right-side floating panel (matches app.dart).
const double _kDesktopWebMinWidth = 720.0;

/// Which list to show first when the page opens.
enum FollowListTab { followers, following }

/// Paginated lists of the current user's followers and the accounts they
/// follow. Two tabs, infinite scroll, pull-to-refresh.
///
/// Backed by GET /follow/followers and GET /follow/following — both return the
/// *current user's* relationships, so this page is only meaningful for the
/// signed-in user's own profile.
class FollowListPage extends StatefulWidget {
  const FollowListPage({
    super.key,
    this.initialTab = FollowListTab.followers,
    this.followersCount,
    this.followingCount,
  });

  final FollowListTab initialTab;
  // Optional counts shown in the tab labels until the first page loads.
  final int? followersCount;
  final int? followingCount;

  /// Opens the list. On desktop/laptop web it slides in as the right-side
  /// floating panel (the shared web "panel" util); on mobile (native or narrow
  /// web) it pushes full-screen.
  static Future<void> open(
    BuildContext context, {
    FollowListTab initialTab = FollowListTab.followers,
    int? followersCount,
    int? followingCount,
  }) {
    final page = FollowListPage(
      initialTab: initialTab,
      followersCount: followersCount,
      followingCount: followingCount,
    );
    final isDesktopWeb =
        kIsWeb && MediaQuery.of(context).size.width >= _kDesktopWebMinWidth;
    if (isDesktopWeb) {
      return showWebPanelPage<void>(context, page);
    }
    return Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
  }

  @override
  State<FollowListPage> createState() => _FollowListPageState();
}

class _FollowListPageState extends State<FollowListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;

  @override
  void initState() {
    super.initState();
    _tab = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab == FollowListTab.following ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  String _label(String base, int? count) =>
      count == null ? base : '$base · $count';

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        backgroundColor: ext.homeBackground,
        elevation: 0,
        foregroundColor: ext.greetingColor,
        title: Text(
          'Connections',
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: TabBar(
          controller: _tab,
          labelColor: ext.accentGold,
          unselectedLabelColor: ext.searchHintColor,
          indicatorColor: ext.accentGold,
          indicatorWeight: 2.5,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: [
            Tab(text: _label('Followers', widget.followersCount)),
            Tab(text: _label('Following', widget.followingCount)),
          ],
        ),
      ),
      body: webWrap(
        TabBarView(
          controller: _tab,
          children: const [
            _FollowListView(kind: FollowListTab.followers),
            _FollowListView(kind: FollowListTab.following),
          ],
        ),
        backgroundColor: ext.homeBackground,
        width: kWebColumnWidth,
      ),
    );
  }
}

class _FollowListView extends StatefulWidget {
  const _FollowListView({required this.kind});
  final FollowListTab kind;

  @override
  State<_FollowListView> createState() => _FollowListViewState();
}

class _FollowListViewState extends State<_FollowListView>
    with AutomaticKeepAliveClientMixin {
  final _repo = FollowRepository();
  final _scroll = ScrollController();
  final List<FollowEntry> _items = [];

  int _page = 0; // last loaded page (0 = none yet)
  int _totalPages = 1;
  bool _loading = false;
  bool _initialLoaded = false;
  Object? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadNext();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  bool get _hasMore => _page < _totalPages;

  void _onScroll() {
    if (_scroll.position.pixels >=
            _scroll.position.maxScrollExtent - 320 &&
        !_loading &&
        _hasMore) {
      _loadNext();
    }
  }

  Future<void> _loadNext() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final next = _page + 1;
      final result = widget.kind == FollowListTab.followers
          ? await _repo.getFollowers(page: next, limit: 20)
          : await _repo.getFollowing(page: next, limit: 20);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.data);
        _page = result.page;
        _totalPages = result.totalPages == 0 ? 1 : result.totalPages;
        _initialLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _items.clear();
      _page = 0;
      _totalPages = 1;
      _initialLoaded = false;
    });
    await _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    // Initial load spinner.
    if (!_initialLoaded && _loading) {
      return Center(
        child: CircularProgressIndicator(color: ext.accentGold),
      );
    }

    // Initial load failed with nothing to show.
    if (!_initialLoaded && _error != null) {
      return _ErrorState(ext: ext, onRetry: _loadNext);
    }

    if (_initialLoaded && _items.isEmpty) {
      return _EmptyState(ext: ext, kind: widget.kind);
    }

    return RefreshIndicator(
      color: ext.accentGold,
      onRefresh: _refresh,
      child: ListView.separated(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: _items.length + (_hasMore || _loading ? 1 : 0),
        separatorBuilder: (_, __) => Divider(
          height: 1,
          indent: 76,
          color: ext.searchHintColor.withValues(alpha: 0.10),
        ),
        itemBuilder: (context, i) {
          if (i >= _items.length) {
            // Footer: loading spinner or a small retry on pagination error.
            if (_error != null) {
              return _PaginationError(ext: ext, onRetry: _loadNext);
            }
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final entry = _items[i];
          // Stagger the first screenful in; later (paged) rows just fade in.
          return Reveal(
            delay: AppMotion.stagger * (i < 8 ? i : 0),
            offset: const Offset(0, 16),
            child: _FollowTile(
              entry: entry,
              ext: ext,
              showNotify: widget.kind == FollowListTab.following,
              onNotifyChanged: (value) => _setNotify(i, value),
              // Only photographers have a public profile page to open.
              onTap: entry.isPhotographer ? () => _openProfile(entry) : null,
            ),
          );
        },
      ),
    );
  }

  void _openProfile(FollowEntry entry) {
    final model = PhotographerModel(
      entry.id,
      '',
      entry.name,
      '',
      imageUrl: entry.profileUrl,
    );
    final page = PhotographerProfilePage(photographer: model);
    final isDesktopWeb =
        kIsWeb && MediaQuery.of(context).size.width >= _kDesktopWebMinWidth;
    if (isDesktopWeb) {
      showWebPanelPage<void>(context, page);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => page),
      );
    }
  }

  Future<void> _setNotify(int index, bool value) async {
    final entry = _items[index];
    setState(() => _items[index] = entry.copyWith(notify: value));
    try {
      await _repo.setNotifyFor(entry.type, entry.id, notify: value);
    } catch (_) {
      if (!mounted) return;
      setState(() => _items[index] = entry.copyWith(notify: !value));
    }
  }
}

class _FollowTile extends StatelessWidget {
  const _FollowTile({
    required this.entry,
    required this.ext,
    required this.showNotify,
    required this.onNotifyChanged,
    this.onTap,
  });

  final FollowEntry entry;
  final AppThemeExtension ext;
  final bool showNotify;
  final ValueChanged<bool> onNotifyChanged;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      entry.isPhotographer ? 'Photographer' : 'Client',
      if (entry.followedAt != null) TimeFormatter.relative(entry.followedAt!),
    ].join(' · ');

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          _Avatar(entry: entry, ext: ext),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.name.isEmpty ? 'Unknown' : entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          if (showNotify && entry.notify != null)
            Semantics(
              button: true,
              label: entry.notify!
                  ? 'Turn off notifications for ${entry.name}'
                  : 'Turn on notifications for ${entry.name}',
              child: IconButton(
                tooltip:
                    entry.notify! ? 'Notifications on' : 'Notifications off',
                icon: Icon(
                  entry.notify!
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_off_outlined,
                  color: entry.notify! ? ext.accentGold : ext.searchHintColor,
                  size: 22,
                ),
                onPressed: () => onNotifyChanged(!entry.notify!),
              ),
            )
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: ext.searchHintColor, size: 20),
        ],
      ),
    );

    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: 'Open ${entry.name}’s profile',
      child: InkWell(onTap: onTap, child: row),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.entry, required this.ext});
  final FollowEntry entry;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    final initial =
        entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?';
    final fallback = Container(
      width: 48,
      height: 48,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [ext.accentGold, ext.accentGoldDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          fontSize: 18,
        ),
      ),
    );

    if (entry.profileUrl == null) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: entry.profileUrl!,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.ext, required this.kind});
  final AppThemeExtension ext;
  final FollowListTab kind;

  @override
  Widget build(BuildContext context) {
    final isFollowers = kind == FollowListTab.followers;
    return ListView(
      // Scrollable so RefreshIndicator and pull-to-refresh still work.
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(
          isFollowers
              ? Icons.group_outlined
              : Icons.person_search_outlined,
          size: 56,
          color: ext.searchHintColor.withValues(alpha: 0.5),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(
            isFollowers ? 'No followers yet' : 'Not following anyone yet',
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            isFollowers
                ? 'People who follow you will appear here.'
                : 'Accounts you follow will appear here.',
            style: TextStyle(color: ext.searchHintColor, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.ext, required this.onRetry});
  final AppThemeExtension ext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 48, color: ext.searchHintColor),
          const SizedBox(height: 12),
          Text(
            'Couldn’t load this list',
            style: TextStyle(
              color: ext.greetingColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: onRetry,
            style: OutlinedButton.styleFrom(
              foregroundColor: ext.accentGold,
              side: BorderSide(color: ext.accentGold),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _PaginationError extends StatelessWidget {
  const _PaginationError({required this.ext, required this.onRetry});
  final AppThemeExtension ext;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: TextButton.icon(
          onPressed: onRetry,
          icon: Icon(Icons.refresh_rounded, color: ext.accentGold, size: 18),
          label: Text(
            'Tap to load more',
            style: TextStyle(color: ext.accentGold),
          ),
        ),
      ),
    );
  }
}
