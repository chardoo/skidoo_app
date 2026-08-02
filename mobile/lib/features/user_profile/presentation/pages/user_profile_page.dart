import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/number_format.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/ads/presentation/pages/broadcasts_page.dart';
import 'package:skidoo_app/features/discovery/data/datasources/discovery_remote_data_source.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_pictures_page.dart'
    show EventPicturesPage, photosOfEvent;
import 'package:skidoo_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:skidoo_app/models/photos/Photo.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/create_bottom_sheet.dart';
import 'package:skidoo_app/features/user_profile/data/repositories/profile_overview_repository.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/features/user_profile/presentation/pages/account_page.dart';
import 'package:skidoo_app/services/auth_service.dart';

/// The profile screen.
///
/// The header is the account at a glance; the tabs are what the user has
/// gathered — photos they liked, photos they bookmarked, and the requests and
/// campaigns they have out. Everything that used to fill this screen (edit
/// profile, theme, privacy, face data, logout) now lives one tap away behind
/// the gear, in [AccountPage].
class UserProfilePage extends StatefulWidget {
  const UserProfilePage({super.key});

  @override
  State<UserProfilePage> createState() => UserProfilePageState();
}

/// Public so the nav can reach it through a [GlobalKey]: this page lives in an
/// IndexedStack and is built once at start-up, well before the user opens it —
/// often before there is even a token to load with. Without a nudge when the
/// tab is opened it would sit on whatever it fetched at launch, and a photo
/// liked elsewhere would not show up until the app restarted.
class UserProfilePageState extends State<UserProfilePage>
    with SingleTickerProviderStateMixin {
  final _repo = ProfileOverviewRepository();
  late final TabController _tabs;

  ProfileOverview _overview = ProfileOverview.empty;
  List<ProfilePhoto> _liked = const [];
  List<ProfilePhoto> _bookmarked = const [];

  /// An event tile has to fetch the event before it can open it; this keeps a
  /// second tap from starting a second fetch.
  bool _openingEvent = false;

  bool _loadingHeader = true;
  bool _loadingLiked = true;
  bool _loadingBookmarks = true;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  /// Called by the nav each time the Profile tab is opened, so likes and
  /// bookmarks made elsewhere in the app are there on arrival.
  Future<void> refresh() => _load();

  /// Each piece loads on its own so a slow or failing tab never holds up the
  /// header — the figures are the first thing on screen and the cheapest to
  /// fetch.
  Future<void> _load() async {
    await Future.wait([_loadHeader(), _loadLiked(), _loadBookmarks()]);
  }

  Future<void> _loadHeader() async {
    // A spinner only the first time. Every visit refetches — that is how a
    // like made elsewhere shows up here — but replacing loaded content with a
    // spinner on each visit is what made the screen look like it never settles.
    final first = _overview.id.isEmpty;
    if (first && mounted) setState(() => _loadingHeader = true);
    try {
      final overview = await _repo.getOverview();
      if (mounted) setState(() => _overview = overview);
    } catch (e) {
      debugPrint('[UserProfilePage] header ERROR: $e');
    } finally {
      if (mounted && _loadingHeader) setState(() => _loadingHeader = false);
    }
  }

  Future<void> _loadLiked() async {
    if (_liked.isEmpty && mounted) setState(() => _loadingLiked = true);
    try {
      final liked = await _repo.getLikedPhotos();
      if (mounted) setState(() => _liked = liked);
    } catch (e) {
      debugPrint('[UserProfilePage] liked ERROR: $e');
    } finally {
      if (mounted && _loadingLiked) setState(() => _loadingLiked = false);
    }
  }

  Future<void> _loadBookmarks() async {
    if (_bookmarked.isEmpty && mounted) setState(() => _loadingBookmarks = true);
    try {
      // The bookmarks endpoint is addressed by client id and only ever serves
      // the caller's own, so it takes the signed-in id rather than a param.
      final userId = await AuthService().getUserId();
      final saved = userId.isEmpty
          ? <ProfilePhoto>[]
          : await _repo.getBookmarkedPhotos(userId);
      if (mounted) setState(() => _bookmarked = saved);
    } catch (e) {
      debugPrint('[UserProfilePage] bookmarks ERROR: $e');
    } finally {
      if (mounted && _loadingBookmarks) setState(() => _loadingBookmarks = false);
    }
  }

  /// Unlike from the grid. The tile goes straight away — the row is written on
  /// the server as the tap lands, so there is nothing to wait for — and comes
  /// back if the call fails.
  Future<void> _unlike(ProfilePhoto photo) async {
    final previous = _liked;
    setState(() => _liked = [
          for (final p in _liked)
            if (p.id != photo.id) p,
        ]);
    try {
      // An event's like lives on a different endpoint to a photo's.
      if (photo.isEvent) {
        await _repo.unlikeEvent(photo.id);
      } else {
        await _repo.unlikePhoto(photo.id);
      }
      unawaited(_loadHeader());
    } catch (e) {
      debugPrint('[UserProfilePage] unlike ERROR: $e');
      if (mounted) setState(() => _liked = previous);
    }
  }

  Future<void> _removeBookmark(ProfilePhoto photo) async {
    final savedItemId = photo.savedItemId;
    if (savedItemId == null) return;
    final previous = _bookmarked;
    setState(() => _bookmarked = [
          for (final p in _bookmarked)
            if (p.savedItemId != savedItemId) p,
        ]);
    try {
      final userId = await AuthService().getUserId();
      await _repo.removeBookmark(userId, savedItemId);
      // The figures above the tabs move with what is in them.
      unawaited(_loadHeader());
    } catch (e) {
      debugPrint('[UserProfilePage] removeBookmark ERROR: $e');
      if (mounted) setState(() => _bookmarked = previous);
    }
  }

  /// Open what the tile stands for — always inside its own event's album.
  ///
  /// A tile is a photo out of an album, so tapping it opens that album's
  /// viewer positioned on it, with the rest of the event to swipe through and
  /// "View album" to step back to the grid. Swiping through the other things
  /// the user happened to bookmark would be a different album every photo.
  Future<void> _openTile(List<ProfilePhoto> tab, ProfilePhoto photo) async {
    final eventId = photo.isEvent ? (photo.eventId ?? photo.id) : photo.eventId;
    if (eventId == null || eventId.isEmpty || _openingEvent) {
      _openWithinTab(tab, photo);
      return;
    }

    setState(() => _openingEvent = true);
    try {
      // The tile carries a cover and a name, not the event — the album is
      // fetched the same way the Saved screen fetches it.
      final event = await sl<DiscoveryRemoteDataSource>().getEventById(eventId);
      final photos = photosOfEvent(event);
      if (!mounted) return;
      if (photos.isEmpty) {
        _openWithinTab(tab, photo);
        return;
      }
      // An event tile has no photo of its own to land on, so it starts at the
      // beginning of its album.
      final index = photo.isEvent
          ? 0
          : photos.indexWhere((p) => p.id == photo.id).clamp(0, photos.length - 1);

      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (viewerContext) => FoundPhotoViewerPage(
          photos: photos,
          initialIndex: index,
          onViewAlbum: () => Navigator.of(viewerContext).push(
            MaterialPageRoute<void>(
              builder: (_) => EventPicturesPage(event: event),
            ),
          ),
        ),
      ));
      // The viewer can like and unlike, so the tabs may be stale coming back.
      // Silent by now — the lists are already populated, so this swaps content
      // in rather than clearing the screen.
      if (mounted) unawaited(_load());
    } catch (e) {
      debugPrint('[UserProfilePage] openTile ERROR: $e');
      if (mounted) {
        // The album could not be loaded; the photo itself still opens.
        _openWithinTab(tab, photo);
      }
    } finally {
      if (mounted) setState(() => _openingEvent = false);
    }
  }

  /// Fallback for a photo whose event cannot be resolved — better than a tap
  /// that does nothing.
  void _openWithinTab(List<ProfilePhoto> tab, ProfilePhoto photo) {
    final photos = tab.where((p) => !p.isEvent).toList();
    final index = photos.indexWhere((p) => p.id == photo.id);
    if (index < 0) return;
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => FoundPhotoViewerPage(
        photos: [for (final p in photos) _asPhoto(p)],
        initialIndex: index,
      ),
    ));
  }

  /// The viewer speaks [Photo]; a tile is the little the grid needed.
  Photo _asPhoto(ProfilePhoto photo) => Photo(
        photo.id,
        photo.eventName ?? '',
        '',
        photo.url,
        '',
        0,
        '',
        null,
        true,
        eventId: photo.eventId ?? '',
        mediaType: photo.mediaType,
        width: photo.width,
        height: photo.height,
      );

  void _openSettings() {
    // Handed the bloc the host already keeps loaded, rather than letting the
    // page build its own and refetch: a route gets a new context, and without
    // this the settings screen reloads the account every single time it opens.
    UserProfileBloc? host;
    try {
      host = context.read<UserProfileBloc>();
    } catch (_) {
      // No host bloc — this page is only ever built inside one today, but a
      // settings screen that opens slowly beats one that cannot open at all.
      host = null;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => host == null
            ? const AccountPage()
            : BlocProvider<UserProfileBloc>.value(
                value: host,
                child: const AccountPage(reuseHostBloc: true),
              ),
      ),
    );
  }

  void _openBroadcasts() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const BroadcastsPage()))
        // Coming back from Broadcasts, the campaign figure may have moved.
        .then((_) => _loadHeader());
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        leading: IconButton(
          tooltip: 'Post a request or start a campaign',
          icon: Icon(Icons.add_rounded, color: ext.greetingColor, size: 26.r),
          onPressed: () => CreateBottomSheet.show(context),
        ),
        // The name, not the username: uiqueName doubles as the face-recognition
        // person id and is an email on most accounts.
        title: Text(
          _overview.name?.isNotEmpty == true
              ? _overview.name!
              : _overview.username,
          style: TextStyle(
            color: ext.greetingColor,
            fontWeight: FontWeight.w700,
            fontSize: 16.sp,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: Icon(Icons.settings_outlined,
                color: ext.greetingColor, size: 24.r),
            onPressed: _openSettings,
          ),
          SizedBox(width: AppSpacing.xs.w),
        ],
      ),
      // The indicator sits inside each tab rather than around the
      // NestedScrollView: the tab's own list owns the drag, so an outer one
      // never sees the gesture.
      body: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverToBoxAdapter(
              child: _Header(
                overview: _overview,
                loading: _loadingHeader,
                ext: ext,
                onCampaignsTap: _openBroadcasts,
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                background: ext.homeBackground,
                tabBar: TabBar(
                  controller: _tabs,
                  indicatorColor: ext.accentGold,
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: ext.accentGold,
                  unselectedLabelColor: ext.searchHintColor,
                  tabs: const [
                    Tab(icon: Icon(Icons.favorite_rounded), text: null),
                    Tab(icon: Icon(Icons.bookmark_rounded)),
                    Tab(icon: Icon(Icons.campaign_rounded)),
                  ],
                ),
              ),
            ),
          ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _Refreshable(
              onRefresh: _load,
              ext: ext,
              child: _PhotoGrid(
                photos: _liked,
                loading: _loadingLiked,
                ext: ext,
                emptyTitle: 'Nothing liked yet',
                emptyHint: 'Photos you like show up here.',
                removeIcon: Icons.favorite_rounded,
                removeTooltip: 'Unlike',
                onRemove: _unlike,
                onOpen: (photo) => _openTile(_liked, photo),
              ),
            ),
            _Refreshable(
              onRefresh: _load,
              ext: ext,
              child: _PhotoGrid(
                photos: _bookmarked,
                loading: _loadingBookmarks,
                ext: ext,
                emptyTitle: 'Nothing bookmarked yet',
                emptyHint: 'Bookmark a photo or an event to find it here.',
                removeIcon: Icons.bookmark_rounded,
                removeTooltip: 'Remove bookmark',
                onRemove: _removeBookmark,
                onOpen: (photo) => _openTile(_bookmarked, photo),
              ),
            ),
            _Refreshable(
              onRefresh: _load,
              ext: ext,
              child: _BroadcastsTab(
                requests: _overview.requests,
                campaigns: _overview.campaigns,
                ext: ext,
                onOpen: _openBroadcasts,
              ),
            ),
          ],
        ),
      ),
    );

    return webWrap(page, backgroundColor: ext.homeBackground);
  }
}

class _Refreshable extends StatelessWidget {
  const _Refreshable({
    required this.child,
    required this.onRefresh,
    required this.ext,
  });

  final Widget child;
  final Future<void> Function() onRefresh;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: ext.accentGold,
      child: child,
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────
class _Header extends StatelessWidget {
  const _Header({
    required this.overview,
    required this.loading,
    required this.ext,
    required this.onCampaignsTap,
  });

  final ProfileOverview overview;
  final bool loading;
  final AppThemeExtension ext;
  final VoidCallback onCampaignsTap;

  @override
  Widget build(BuildContext context) {
    final photo = overview.profileUrl;
    final initial = overview.username.trim().isNotEmpty
        ? overview.username.trim()[0].toUpperCase()
        : '?';

    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, AppSpacing.md.h, 20.w, AppSpacing.lg.h),
      child: Row(
        children: [
          CircleAvatar(
            radius: 36.r,
            backgroundColor: ext.avatarBackground,
            backgroundImage:
                photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
            child: photo != null && photo.isNotEmpty
                ? null
                : Text(
                    initial,
                    style: TextStyle(
                      color: ext.avatarForeground,
                      fontSize: 26.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
          SizedBox(width: AppSpacing.xl.w),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Stat(
                  value: overview.found,
                  label: 'Found',
                  loading: loading,
                  ext: ext,
                ),
                _Stat(
                  value: overview.following,
                  label: 'Following',
                  loading: loading,
                  ext: ext,
                ),
                _Stat(
                  value: overview.campaigns,
                  label: 'Campaigns',
                  loading: loading,
                  ext: ext,
                  onTap: onCampaignsTap,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    required this.loading,
    required this.ext,
    this.onTap,
  });

  final int value;
  final String label;
  final bool loading;
  final AppThemeExtension ext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A dash while loading, not a zero: "0 Found" reads as a fact, and
        // showing it before the number arrives is a small lie.
        Text(
          loading ? '—' : compactCount(value),
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        SizedBox(height: 2.h),
        Text(
          label,
          style: TextStyle(color: ext.searchHintColor, fontSize: 12.sp),
        ),
      ],
    );

    if (onTap == null) return column;
    return Semantics(
      button: true,
      label: '$label, ${loading ? 'loading' : value}',
      child: GestureDetector(onTap: onTap, child: column),
    );
  }
}

// ── Tabs ──────────────────────────────────────────────────────────────────────
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate({required this.tabBar, required this.background});

  final TabBar tabBar;
  final Color background;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      Container(color: background, child: tabBar);

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.background != background;
}

class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.loading,
    required this.ext,
    required this.emptyTitle,
    required this.emptyHint,
    required this.removeIcon,
    required this.removeTooltip,
    required this.onRemove,
    required this.onOpen,
  });

  final List<ProfilePhoto> photos;
  final bool loading;
  final AppThemeExtension ext;
  final String emptyTitle;
  final String emptyHint;

  /// The filled heart / bookmark on each tile — tapping it takes the photo out
  /// of the list it is in.
  final IconData removeIcon;
  final String removeTooltip;
  final Future<void> Function(ProfilePhoto) onRemove;

  /// Tapping the tile opens what it stands for.
  final void Function(ProfilePhoto) onOpen;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (photos.isEmpty) {
      return _Empty(title: emptyTitle, hint: emptyHint, ext: ext);
    }

    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.all(2.w),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: photos.length,
      itemBuilder: (_, i) {
        final photo = photos[i];
        return GestureDetector(
          onTap: () => onOpen(photo),
          child: ColoredBox(
          color: ext.avatarBackground,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                photo.url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.broken_image_outlined,
                  color: ext.searchHintColor,
                  size: 20.r,
                ),
              ),
              if (photo.isVideo)
                Positioned(
                  left: 6.w,
                  top: 6.h,
                  child: Icon(
                    Icons.play_circle_fill_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 18.r,
                  ),
                ),
              if (photo.isEvent)
                Positioned(
                  left: 6.w,
                  bottom: 6.h,
                  child: Icon(
                    Icons.event_rounded,
                    color: Colors.white.withValues(alpha: 0.9),
                    size: 16.r,
                  ),
                ),
              Positioned(
                right: 0,
                top: 0,
                child: Semantics(
                  button: true,
                  label: removeTooltip,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onRemove(photo),
                    child: Padding(
                      // Padded rather than sized: the icon is small, and the
                      // tap target around it needs to be a finger wide.
                      padding: EdgeInsets.all(6.r),
                      child: Icon(
                        removeIcon,
                        size: 18.r,
                        color: Colors.white.withValues(alpha: 0.95),
                        shadows: const [
                          Shadow(color: Colors.black54, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }
}

/// The third tab is a doorway rather than a list: Broadcasts is its own screen
/// with its own tabs, and nesting a second set of tabs inside this one would
/// leave two rows of them on the same screen.
class _BroadcastsTab extends StatelessWidget {
  const _BroadcastsTab({
    required this.requests,
    required this.campaigns,
    required this.ext,
    required this.onOpen,
  });

  final int requests;
  final int campaigns;
  final AppThemeExtension ext;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.all(AppSpacing.lg.w),
      children: [
        _BroadcastCard(
          icon: Icons.campaign_outlined,
          title: 'Requests',
          subtitle: requests == 0
              ? 'Ask photographers to shoot something'
              : '$requests posted',
          ext: ext,
          onTap: onOpen,
        ),
        SizedBox(height: AppSpacing.md.h),
        _BroadcastCard(
          icon: Icons.rocket_launch_outlined,
          title: 'Campaigns',
          subtitle:
              campaigns == 0 ? 'Nothing running yet' : '$campaigns running',
          ext: ext,
          onTap: onOpen,
        ),
      ],
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.ext,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ext.cardSurface,
      borderRadius: BorderRadius.circular(AppRadius.lg.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg.r),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg.w),
          child: Row(
            children: [
              Icon(icon, color: ext.accentGold, size: 22.r),
              SizedBox(width: AppSpacing.md.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: ext.searchHintColor, size: 20.r),
            ],
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.hint, required this.ext});

  final String title;
  final String hint;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      children: [
        SizedBox(height: 80.h),
        Icon(Icons.photo_library_outlined,
            color: ext.searchHintColor.withValues(alpha: 0.5), size: 40.r),
        SizedBox(height: AppSpacing.md.h),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 15.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: 6.h),
        Text(
          hint,
          textAlign: TextAlign.center,
          style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        ),
      ],
    );
  }
}
