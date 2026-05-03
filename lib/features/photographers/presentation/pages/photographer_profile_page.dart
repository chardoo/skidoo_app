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
import 'package:skidoo_app/features/photographers/domain/usecases/get_photographer_samples_usecase.dart';
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
  late final Future<List<PhotographerSample>> _samplesFuture;
  bool _isBlocked = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _samplesFuture =
        sl<GetPhotographerSamplesUseCase>().call(widget.photographer.id);
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

    return Scaffold(
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
              samplesFuture: _samplesFuture,
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
  }
}

// ── Samples tab ───────────────────────────────────────────────────────────────

class _SamplesTab extends StatelessWidget {
  const _SamplesTab({required this.samplesFuture, required this.ext});

  final Future<List<PhotographerSample>> samplesFuture;
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<PhotographerSample>>(
      future: samplesFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: ext.accentGold),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return Center(
            child: Text(
              snap.hasError ? 'Could not load samples.' : 'No sample images yet.',
              style: TextStyle(color: ext.searchHintColor, fontSize: 13.sp),
            ),
          );
        }
        final samples = snap.data!;
        return GridView.builder(
          padding: EdgeInsets.all(4.w),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4.w,
            mainAxisSpacing: 4.h,
          ),
          itemCount: samples.length,
          itemBuilder: (context, index) => PhotographerSampleTile(
            sample: samples[index],
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) => SamplesFullscreenPage(
                  samples: samples, initialIndex: index),
            )),
          ),
        );
      },
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
