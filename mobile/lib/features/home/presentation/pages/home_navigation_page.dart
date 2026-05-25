import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/search_results_page.dart';
import 'package:skidoo_app/features/home/presentation/widgets/events_feed.dart';
import 'package:skidoo_app/features/home/presentation/widgets/home_empty_state.dart';
import 'package:skidoo_app/features/home/presentation/widgets/home_header_widget.dart';
import 'package:skidoo_app/features/home/presentation/widgets/search_events_list.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/features/user_profile/presentation/pages/account_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/common/widgets/feed_launch_overlay.dart';
import 'package:skidoo_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/features/home/presentation/pages/qr_scan_page.dart';

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  bool _isSearchOpen = false;
  int _selectedTab = 0; // 0 = For You, 1 = Following

  bool _headerVisible = false;
  double _headerDownAccum = 0;
  static const _headerHideThreshold = 28.0;

  // Measured height of the floating header overlay — used as list top padding.
  final _headerKey = GlobalKey();
  double _headerHeight = 0;

  Timer? _chromeTimer;

  @override
  void dispose() {
    _chromeTimer?.cancel();
    super.dispose();
  }

  void _measureHeaderHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if (h != _headerHeight) setState(() => _headerHeight = h);
    });
  }

  void _startHeaderAutoHideTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && !_isSearchOpen) setState(() => _headerVisible = false);
    });
  }

  void _openSearch() {
    _headerDownAccum = 0;
    _chromeTimer?.cancel();
    setState(() {
      _isSearchOpen = true;
      _headerVisible = true;
    });
  }

  void _closeSearch() {
    _headerDownAccum = 0;
    setState(() {
      _isSearchOpen = false;
      _headerVisible = false;
    });
    context.read<HomeBloc>().add(const HomeSearchClosed());
  }

  void _onSearchChanged(String query) {
    context.read<HomeBloc>().add(HomeEventSearched(query));
  }

  Future<void> _openQrScan() async {
    final eventId = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (!mounted || eventId == null || eventId.isEmpty) return;

    // Fire the same event the search flow uses, then push SearchResultsPage.
    final homeBloc = context.read<HomeBloc>();
    homeBloc.add(HomeImagesSearched(eventId: eventId, eventName: ''));
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: homeBloc,
          child: const SearchResultsPage(),
        ),
      ),
    );
  }

  void _openEventImages(BuildContext context, EventDiscovery event) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => EventPicturesPage(event: event)),
    );
  }

  void _openEventComments(BuildContext context, EventDiscovery event) {
    EventCommentPage.show(context, event);
  }

  Future<void> _onRefresh() {
    final bloc = context.read<DiscoveryBloc>();
    bloc.add(const DiscoveryLoadRequested());
    // Await until the bloc leaves its loading state (or 10 s timeout).
    return bloc.stream
        .firstWhere((s) => !s.isLoading)
        .timeout(const Duration(seconds: 10), onTimeout: () => bloc.state);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // On web the header is always visible (Column layout) — skip hide logic.
    if (kIsWeb || _isSearchOpen) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final atTop = notification.metrics.pixels <= 0;

      if (delta > 0 && !atTop) {
        // Scrolling down (and not at the top boundary) — accumulate and hide.
        _headerDownAccum += delta;
        if (_headerDownAccum >= _headerHideThreshold && _headerVisible) {
          setState(() => _headerVisible = false);
          _chromeTimer?.cancel();
        }
      } else if (delta < 0 || atTop) {
        // Scrolling up, or bounce-back at top — show header, reset accum.
        _headerDownAccum = 0;
        if (!_headerVisible) setState(() => _headerVisible = true);
        if (!atTop) _startHeaderAutoHideTimer();
      }
    } else if (notification is ScrollEndNotification) {
      _headerDownAccum = 0;
      if (notification.metrics.pixels <= 0) {
        // At the very top — keep header visible, cancel any pending hide.
        _chromeTimer?.cancel();
        if (!_headerVisible) setState(() => _headerVisible = true);
      } else if (_headerVisible) {
        _startHeaderAutoHideTimer();
      }
    }
    return false;
  }

  /// On web the header is part of the Column layout — no padding needed.
  /// On mobile it floats as an overlay, so the feed must clear it.
  double get _feedTopPadding =>
      kIsWeb ? 0 : (_headerVisible ? _headerHeight : 0);

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final homeState = context.watch<HomeBloc>().state;
    final discoveryState = context.watch<DiscoveryBloc>().state;
    final userState = context.watch<UserProfileBloc>().state;
    final userName = userState.name.isNotEmpty ? userState.name : 'User';

    // ── Web: permanent header + Column layout (no auto-hide) ─────────────────
    if (kIsWeb) {
      return FeedLaunchOverlay(
        child: Scaffold(
          backgroundColor: ext.homeBackground,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Search + avatar header — always visible on desktop ──────────
              HomeHeaderWidget(
                userName: userName,
                userInitial: userName[0].toUpperCase(),
                isSearchOpen: _isSearchOpen,
                onSearchOpen: _openSearch,
                onSearchClose: _closeSearch,
                onSearchChanged: _onSearchChanged,
                onQrScan: null,
                onAvatarTap: () {
                  final discoveryBloc = context.read<DiscoveryBloc>();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: discoveryBloc,
                        child: const AccountPage(),
                      ),
                    ),
                  );
                },
              ),
              // ── For You / Following tabs ────────────────────────────────────
              if (!_isSearchOpen)
                _FeedTabBar(
                  ext: ext,
                  selectedTab: _selectedTab,
                  onTabChanged: (i) => setState(() => _selectedTab = i),
                ),
              // ── Feed content ────────────────────────────────────────────────
              Expanded(
                child: NotificationListener<ScrollNotification>(
                  onNotification: _onScrollNotification,
                  child: _buildBody(context, ext, homeState, discoveryState),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Mobile: floating overlay header that slides in/out on scroll ──────────
    final topPadding = MediaQuery.of(context).padding.top;
    _measureHeaderHeight();

    return FeedLaunchOverlay(
      child: Scaffold(
        backgroundColor: ext.homeBackground,
        body: Stack(
          children: [
            // Body fills entire screen — header/tab bar float above it.
            Positioned.fill(
              child: NotificationListener<ScrollNotification>(
                onNotification: _onScrollNotification,
                child: _buildBody(context, ext, homeState, discoveryState),
              ),
            ),

            // Header + tab bar slide in/out from top (Transform.translate —
            // no layout shift).
            Positioned(
              top: 0, left: 0, right: 0,
              child: AnimatedSlide(
                offset: _headerVisible ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Column(
                  key: _headerKey,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: EdgeInsets.only(top: topPadding),
                      child: HomeHeaderWidget(
                        userName: userName,
                        userInitial: userName[0].toUpperCase(),
                        isSearchOpen: _isSearchOpen,
                        onSearchOpen: _openSearch,
                        onSearchClose: _closeSearch,
                        onSearchChanged: _onSearchChanged,
                        onQrScan: _openQrScan,
                        onAvatarTap: () {
                          final discoveryBloc = context.read<DiscoveryBloc>();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: discoveryBloc,
                                child: const AccountPage(),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (!_isSearchOpen)
                      _FeedTabBar(
                        ext: ext,
                        selectedTab: _selectedTab,
                        onTabChanged: (i) => setState(() => _selectedTab = i),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppThemeExtension ext,
    HomeState homeState,
    DiscoveryState discoveryState,
  ) {
    return IndexedStack(
      index: _selectedTab,
      children: [
        // ── For You ──────────────────────────────────────────────────────────
        RefreshIndicator(
          onRefresh: _onRefresh,
          color: ext.accentGold,
          backgroundColor: ext.homeBackground,
          child: _buildForYouContent(context, ext, homeState, discoveryState),
        ),
        // ── Following ────────────────────────────────────────────────────────
        FollowingFeed(topPadding: _feedTopPadding),
      ],
    );
  }

  Widget _buildForYouContent(
    BuildContext context,
    AppThemeExtension ext,
    HomeState homeState,
    DiscoveryState discoveryState,
  ) {
    // EventsFeed stays mounted at all times so its ad/request state is never
    // lost. Loading and empty states are overlaid on top of it.
    return Stack(
      children: [
        EventsFeed(
          discoveryState: discoveryState,
          topPadding: _feedTopPadding,
          onCardTap: (event) => _openEventImages(context, event),
          onCommentTap: (event) => _openEventComments(context, event),
          onLoadMore: () =>
              context.read<DiscoveryBloc>().add(const DiscoveryLoadMoreRequested()),
        ),
        if (discoveryState.isLoading)
          Positioned.fill(
            child: ColoredBox(
              color: ext.homeBackground,
              child: const CustomScrollView(slivers: [
                SliverFillRemaining(
                    hasScrollBody: false, child: AppLoadingIndicator()),
              ]),
            ),
          ),
        if (!discoveryState.isLoading && discoveryState.events.isEmpty)
          Positioned.fill(
            child: ColoredBox(
              color: ext.homeBackground,
              child: CustomScrollView(slivers: [
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: HomeEmptyState(
                    ext: ext,
                    icon: Icons.photo_library_outlined,
                    message: AppLocalizations.of(context)!.homeNoEventsYet,
                  ),
                ),
              ]),
            ),
          ),
        if (_isSearchOpen)
          Positioned.fill(
            child: ColoredBox(
              color: ext.homeBackground,
              child: _buildSearchOverlay(context, ext, homeState),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchOverlay(
    BuildContext context,
    AppThemeExtension ext,
    HomeState homeState,
  ) {
    if (homeState.isLoadingEvents) {
      return const AppLoadingIndicator();
    }
    if (homeState.events.isNotEmpty) {
      return SearchEventsList(
        homeState: homeState,
        ext: ext,
        onEventTap: (event) {
          context.read<HomeBloc>().add(HomeImagesSearched(
                eventId: event.id,
                eventName: event.eventName,
              ));
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<HomeBloc>(),
                child: const SearchResultsPage(),
              ),
            ),
          );
        },
      );
    }
    if (homeState.isSearching && homeState.events.isEmpty) {
      return HomeEmptyState(
        ext: ext,
        icon: Icons.event_busy_outlined,
        message: AppLocalizations.of(context)!.homeNoEventsFound,
      );
    }
    return const SizedBox.shrink();
  }
}

class _FeedTabBar extends StatelessWidget {
  final AppThemeExtension ext;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _FeedTabBar({
    required this.ext,
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _PillTab(
            label: 'For You',
            active: selectedTab == 0,
            ext: ext,
            onTap: () => onTabChanged(0),
          ),
          const SizedBox(width: 8),
          _PillTab(
            label: 'Following',
            active: selectedTab == 1,
            ext: ext,
            onTap: () => onTabChanged(1),
          ),
        ],
      ),
    );
  }
}

class _PillTab extends StatelessWidget {
  final String label;
  final bool active;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  const _PillTab({
    required this.label,
    required this.active,
    required this.ext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: active
              ? ext.accentGold.withValues(alpha: 0.92)
              : ext.glassFill,
          border: Border.all(
            color: active ? ext.accentGold : ext.glassBorder,
            width: 1.0,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : ext.glassIcon,
            fontSize: 12,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
