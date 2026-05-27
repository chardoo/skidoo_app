import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/config/chat_config.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/error/exceptions.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_room_page.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/search_results_page.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographer_events_usecase.dart';
import 'package:image_picker/image_picker.dart';
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/samples_fullscreen_page.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/profile_header.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/profile_info_row.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/profile_rating_row.dart';
import 'package:skidoo_app/features/photographers/presentation/widgets/profile_sample_tile.dart';
import 'package:skidoo_app/core/utils/auth_guard.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/models/chat/chat_room.dart';
import 'package:skidoo_app/models/photographer/photographer_event.dart';
import 'package:skidoo_app/models/photographer/photographer_sample.dart';
import 'package:skidoo_app/models/photographer/photographerModel.dart';
import 'package:skidoo_app/features/follow/data/follow_repository.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';

class PhotographerProfilePage extends StatefulWidget {
  const PhotographerProfilePage({super.key, required this.photographer});

  final PhotographerModel photographer;

  @override
  State<PhotographerProfilePage> createState() =>
      _PhotographerProfilePageState();
}

class _PhotographerProfilePageState extends State<PhotographerProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _followRepo = FollowRepository();
  bool _isOwner = false;
  FollowStats _stats = const FollowStats(followers: 0, following: 0);
  bool _statsLoaded = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _checkOwner();
    _loadStats();
  }

  Future<void> _checkOwner() async {
    try {
      final myId = await sl<AuthService>().getUserId();
      if (mounted) setState(() => _isOwner = myId == widget.photographer.id);
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    final stats = await _followRepo.getStats(widget.photographer.id);
    if (mounted) setState(() {
      _stats = stats;
      _statsLoaded = true;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _openDirectChat(BuildContext context) async {
    final p = widget.photographer;
    ChatRoomsBloc? roomsBloc;
    try {
      roomsBloc = context.read<ChatRoomsBloc>();
    } catch (_) {}

    ChatRoom room;
    try {
      room = await sl<GetOrCreateDirectRoomUseCase>().call(
        recipientId: p.id,
        recipientRole: ChatConfig.rolePhotographer,
        localDisplayName: p.name,
      );
    } catch (e) {
      if (context.mounted) {
        final isBlocked = e is ServerException && e.message.contains('400');
        AppSnackBar.error(
          context,
          isBlocked
              ? AppLocalizations.of(context)!.photographerProfileNotAcceptingConversations
              : AppLocalizations.of(context)!.photographerProfileCouldNotOpenChat(e.toString()),
        );
      }
      return;
    }

    if (!context.mounted) return;
    roomsBloc?.add(const ChatRoomsLoadRequested());

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ChatRoomPage(room: room)),
    );

    if (context.mounted) roomsBloc?.add(const ChatRoomsLoadRequested());
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final p = widget.photographer;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // ── Collapsing header with avatar ──────────────────────────────
          SliverAppBar(
            expandedHeight: 240.h,
            pinned: true,
            forceElevated: innerBoxIsScrolled,
            backgroundColor: ext.homeBackground,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_rounded,
                  color: ext.greetingColor, size: 20.sp),
              onPressed: () => Navigator.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: PhotographerProfileHeader(photographer: p, ext: ext),
            ),
          ),

          // ── Profile info ───────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.name,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 22.sp,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  PhotographerRatingRow(rating: p.rating, ext: ext),
                  SizedBox(height: 12.h),

                  // ── Follow stats ────────────────────────────────────────
                  if (_statsLoaded)
                    _FollowStatsRow(stats: _stats, ext: ext),
                  if (!_statsLoaded)
                    SizedBox(
                      height: 18.h,
                      child: Row(
                        children: [
                          SizedBox(
                            width: 12.w,
                            height: 12.w,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: ext.accentGold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  SizedBox(height: 16.h),

                  PhotographerInfoRow(
                      icon: Icons.mail_outline_rounded,
                      text: p.email,
                      ext: ext),
                  SizedBox(height: 8.h),
                  if (p.contact.isNotEmpty)
                    PhotographerInfoRow(
                        icon: Icons.phone_outlined,
                        text: p.contact,
                        ext: ext),
                  SizedBox(height: 20.h),

                  // ── Action row: Follow + Chat ───────────────────────────
                  if (!_isOwner)
                    Row(
                      children: [
                        Expanded(
                          child: _ProfileFollowButton(
                            photographerId: p.id,
                            ext: ext,
                          ),
                        ),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => requireAuth(
                              context,
                              action: () => _openDirectChat(context),
                            ),
                            icon: Icon(Icons.chat_bubble_outline_rounded,
                                size: 16.sp),
                            label: Text(
                              'Message',
                              style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: ext.greetingColor,
                              side: BorderSide(
                                  color: ext.searchHintColor
                                      .withValues(alpha: 0.4)),
                              padding: EdgeInsets.symmetric(vertical: 13.h),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  if (_isOwner)
                    SizedBox(
                      width: double.infinity,
                      height: 50.h,
                      child: ElevatedButton.icon(
                        onPressed: () => requireAuth(
                          context,
                          action: () => _openDirectChat(context),
                        ),
                        icon: Icon(Icons.chat_bubble_outline_rounded,
                            size: 18.sp),
                        label: Text(
                          'Chat with ${p.name.split(' ').first}',
                          style: TextStyle(
                              fontSize: 15.sp, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ext.accentGold,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  SizedBox(height: 8.h),
                ],
              ),
            ),
          ),

          // ── Pinned tab bar ─────────────────────────────────────────────
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              TabBar(
                controller: _tabController,
                labelColor: ext.accentGold,
                unselectedLabelColor: ext.searchHintColor,
                indicatorColor: ext.accentGold,
                indicatorSize: TabBarIndicatorSize.label,
                labelStyle: TextStyle(
                    fontSize: 13.sp, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Sample Work'),
                  Tab(text: 'Events'),
                ],
              ),
              backgroundColor: ext.homeBackground,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            // ── Sample Work tab ──────────────────────────────────────────
            _SamplesTab(
              photographerId: p.id,
              isOwner: _isOwner,
              ext: ext,
            ),

            // ── Events tab ───────────────────────────────────────────────
            _EventsTab(
              photographerId: p.id,
              ext: ext,
            ),
          ],
        ),
      ),
    );
    return webWrap(page, backgroundColor: ext.homeBackground, width: kWebColumnWidthWide);
  }

  /// On web desktop, centre the page in a 480 dp column so fonts and spacing
  /// stay phone-sized rather than stretching across the full viewport.
}

// ── Samples tab ───────────────────────────────────────────────────────────────

class _SamplesTab extends StatefulWidget {
  const _SamplesTab({
    required this.photographerId,
    required this.isOwner,
    required this.ext,
  });

  final String photographerId;
  final bool isOwner;
  final AppThemeExtension ext;

  @override
  State<_SamplesTab> createState() => _SamplesTabState();
}

class _SamplesTabState extends State<_SamplesTab>
    with AutomaticKeepAliveClientMixin {
  final _picker = ImagePicker();
  List<PhotographerSample> _samples = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    setState(() { _loading = true; _error = null; });
    try {
      final s = await sl<GetPhotographerSamplesUseCase>()
          .call(widget.photographerId);
      if (mounted) setState(() { _samples = s; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _pickAndUpload() async {
    final picked = await _picker.pickMultiImage(imageQuality: 85);
    if (picked.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      final files = picked.map((x) => File(x.path)).toList();
      final updated = await sl<UploadSamplesUseCase>().call(
        photographerId: widget.photographerId,
        files: files,
      );
      if (mounted) setState(() => _samples = updated);
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _confirmDelete(PhotographerSample sample) async {
    final ext = widget.ext;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: ext.cardSurface,
        title: Text('Remove sample?',
            style: TextStyle(color: ext.greetingColor, fontSize: 15.sp)),
        content: Text('This photo will be removed from your portfolio.',
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel',
                style: TextStyle(color: ext.searchHintColor)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await sl<DeleteSampleUseCase>().call(
        sampleId: sample.id,
        photographerId: widget.photographerId,
      );
      if (mounted) {
        setState(() => _samples.removeWhere((s) => s.id == sample.id));
      }
    } catch (e) {
      if (mounted) AppSnackBar.error(context, 'Could not remove sample: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ext = widget.ext;

    if (_loading) {
      return Center(child: CircularProgressIndicator(color: ext.accentGold));
    }

    if (_error != null && _samples.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Could not load samples.',
                style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp)),
            SizedBox(height: 10.h),
            TextButton(
              onPressed: _loadSamples,
              child: Text('Retry', style: TextStyle(color: ext.accentGold)),
            ),
          ],
        ),
      );
    }

    // Total cells = samples + (owner ? 1 add-button : 0)
    final cellCount = _samples.length + (widget.isOwner ? 1 : 0);

    if (cellCount == 0) {
      return Center(
        child: Text('No sample images yet.',
            style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp)),
      );
    }

    return Stack(
      children: [
        GridView.builder(
          padding: EdgeInsets.all(4.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.h,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            // Last cell is the "add" button for owners
            if (widget.isOwner && index == cellCount - 1) {
              return GestureDetector(
                onTap: _uploading ? null : _pickAndUpload,
                child: Container(
                  decoration: BoxDecoration(
                    color: ext.cardSurface,
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(
                      color: ext.accentGold.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: _uploading
                      ? Center(
                          child: CircularProgressIndicator(
                              color: ext.accentGold, strokeWidth: 2),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate_outlined,
                                color: ext.accentGold, size: 28.sp),
                            SizedBox(height: 4.h),
                            Text('Add',
                                style: TextStyle(
                                    color: ext.accentGold,
                                    fontSize: 11.sp,
                                    fontWeight: FontWeight.w600)),
                          ],
                        ),
                ),
              );
            }

            final sample = _samples[index];
            return Stack(
              fit: StackFit.expand,
              children: [
                PhotographerSampleTile(
                  sample: sample,
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => SamplesFullscreenPage(
                        samples: _samples, initialIndex: index),
                  )),
                ),
                if (widget.isOwner)
                  Positioned(
                    top: 4.h,
                    right: 4.w,
                    child: GestureDetector(
                      onTap: () => _confirmDelete(sample),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.close_rounded,
                            color: Colors.white, size: 13.sp),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Events tab (paginated, load on demand) ────────────────────────────────────

class _EventsTab extends StatefulWidget {
  const _EventsTab({required this.photographerId, required this.ext});

  final String photographerId;
  final AppThemeExtension ext;

  @override
  State<_EventsTab> createState() => _EventsTabState();
}

class _EventsTabState extends State<_EventsTab>
    with AutomaticKeepAliveClientMixin {
  static const _limit = 10;

  final _scrollCtrl = ScrollController();
  final _events = <PhotographerEvent>[];

  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await sl<GetPhotographerEventsUseCase>().call(
        photographerId: widget.photographerId,
        page: _page,
        limit: _limit,
      );
      if (!mounted) return;
      setState(() {
        _events.addAll(result.events);
        _page++;
        _hasMore = result.hasNext;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final ext = widget.ext;

    if (_loading && _events.isEmpty) {
      return Center(child: CircularProgressIndicator(color: ext.accentGold));
    }

    if (_error != null && _events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            TextButton(
              onPressed: _loadMore,
              child: Text('Retry', style: TextStyle(color: ext.accentGold)),
            ),
          ],
        ),
      );
    }

    if (_events.isEmpty && !_loading) {
      return Center(
        child: Text(
          'No events yet.',
          style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
        ),
      );
    }

    // 2-column grid: image card with event name beneath
    return GridView.builder(
      controller: _scrollCtrl,
      padding: EdgeInsets.all(12.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10.w,
        mainAxisSpacing: 10.h,
        childAspectRatio: 0.78,
      ),
      itemCount: _events.length + (_hasMore || _loading ? 1 : 0),
      itemBuilder: (context, index) {
        // Trailing spinner / load-more trigger
        if (index == _events.length) {
          if (!_loading) _loadMore();
          return Center(
            child: Padding(
              padding: EdgeInsets.all(16.w),
              child: CircularProgressIndicator(
                  color: ext.accentGold, strokeWidth: 2),
            ),
          );
        }

        final event = _events[index];
        return GestureDetector(
          onTap: () {
            context.read<HomeBloc>().add(HomeImagesSearched(
                  eventId: event.id,
                  eventName: event.eventName,
                ));
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<HomeBloc>(),
                child: const SearchResultsPage(),
              ),
            ));
          },
          child: ClipRRect(
          borderRadius: BorderRadius.circular(14.r),
          child: Container(
            color: ext.cardSurface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: event.url.isNotEmpty
                      ? Image.network(
                          event.url,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) =>
                              progress == null
                                  ? child
                                  : Container(
                                      color: const Color(0xFF1E2230),
                                      child: const Center(
                                        child: CircularProgressIndicator(
                                            color: Colors.white38,
                                            strokeWidth: 2),
                                      ),
                                    ),
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF1E2230),
                            child: const Center(
                              child: Icon(Icons.broken_image_outlined,
                                  color: Colors.white38, size: 32),
                            ),
                          ),
                        )
                      : Container(
                          color: const Color(0xFF1E2230),
                          child: Icon(Icons.event_rounded,
                              color: ext.accentGold, size: 36.sp),
                        ),
                ),
                Padding(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
                  child: Text(
                    event.eventName,
                    style: TextStyle(
                      color: ext.greetingColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.sp,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }
}

// ── Pinned tab bar delegate ───────────────────────────────────────────────────

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  const _TabBarDelegate(this.tabBar, {required this.backgroundColor});

  final TabBar tabBar;
  final Color backgroundColor;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) =>
      old.tabBar != tabBar || old.backgroundColor != backgroundColor;
}

// ── Follow stats row ──────────────────────────────────────────────────────────

class _FollowStatsRow extends StatelessWidget {
  const _FollowStatsRow({required this.stats, required this.ext});
  final FollowStats stats;
  final AppThemeExtension ext;

  String _fmt(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(label: 'Followers', value: _fmt(stats.followers), ext: ext),
        SizedBox(width: 24.w),
        _Stat(label: 'Following', value: _fmt(stats.following), ext: ext),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, required this.ext});
  final String label;
  final String value;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            color: ext.greetingColor,
            fontSize: 17.sp,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: ext.searchHintColor,
            fontSize: 11.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ── Profile-level Follow button ───────────────────────────────────────────────

class _ProfileFollowButton extends StatefulWidget {
  const _ProfileFollowButton({
    required this.photographerId,
    required this.ext,
  });
  final String photographerId;
  final AppThemeExtension ext;

  @override
  State<_ProfileFollowButton> createState() => _ProfileFollowButtonState();
}

class _ProfileFollowButtonState extends State<_ProfileFollowButton> {
  late bool _following;
  bool _loading = false;
  final _repo = FollowRepository();

  @override
  void initState() {
    super.initState();
    _following =
        FollowRepository.followedIds.contains(widget.photographerId);
  }

  Future<void> _toggle(BuildContext context) async {
    if (_loading) return;
    final willFollow = !_following;
    setState(() {
      _following = willFollow;
      _loading = true;
    });
    try {
      if (willFollow) {
        await _repo.follow(widget.photographerId);
      } else {
        await _repo.unfollow(widget.photographerId);
      }
    } catch (_) {
      if (mounted) setState(() => _following = !willFollow);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    return SizedBox(
      height: 50.h,
      child: ElevatedButton(
        onPressed: () => requireAuth(context, action: () => _toggle(context)),
        style: ElevatedButton.styleFrom(
          backgroundColor: _following ? ext.searchFieldFill : ext.accentGold,
          foregroundColor: _following ? ext.greetingColor : Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14.r),
            side: _following
                ? BorderSide(
                    color: ext.searchHintColor.withValues(alpha: 0.35))
                : BorderSide.none,
          ),
        ),
        child: _loading
            ? SizedBox(
                width: 18.w,
                height: 18.w,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _following ? ext.searchHintColor : Colors.white,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _following
                        ? Icons.person_remove_outlined
                        : Icons.person_add_outlined,
                    size: 16.sp,
                  ),
                  SizedBox(width: 6.w),
                  Text(
                    _following ? 'Following' : 'Follow',
                    style: TextStyle(
                        fontSize: 14.sp, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }
}
