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
import 'package:skidoo_app/features/follow/presentation/pages/following_feed_page.dart';
import 'package:skidoo_app/features/home/presentation/pages/qr_scan_page.dart';

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  bool _isSearchOpen = false;

  /// Whether the header is currently visible. Toggled by scroll direction.
  bool _headerVisible = true;

  /// The scroll offset captured on the previous notification, used to compute
  /// delta and decide whether the user is scrolling up or down.
  double _lastScrollOffset = 0;

  void _openSearch() {
    setState(() {
      _isSearchOpen = true;
      _headerVisible = true;
    });
  }

  void _closeSearch() {
    setState(() {
      _isSearchOpen = false;
      _headerVisible = true;
    });
    context.read<HomeBloc>().add(const HomeSearchClosed());
  }

  void _onSearchChanged(String query) {
    context.read<HomeBloc>().add(HomeEventSearched(query));
  }

  void _openQrScan() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
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

  /// Returns false so notifications continue to bubble up the tree.
  bool _onScrollNotification(ScrollNotification notification) {
    // Never auto-hide the header while the search bar is open.
    if (_isSearchOpen) return false;

    if (notification is ScrollUpdateNotification) {
      final current = notification.metrics.pixels;
      final delta = current - _lastScrollOffset;
      _lastScrollOffset = current;

      if (delta > 8 && _headerVisible) {
        // Scrolling down past threshold → hide header.
        setState(() => _headerVisible = false);
      } else if (delta < 0 && !_headerVisible) {
        // Any upward movement → show header immediately.
        setState(() => _headerVisible = true);
      }
    } else if (notification is ScrollEndNotification) {
      _lastScrollOffset = notification.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final homeState = context.watch<HomeBloc>().state;
    final discoveryState = context.watch<DiscoveryBloc>().state;
    final userState = context.watch<UserProfileBloc>().state;
    final userName = userState.name.isNotEmpty ? userState.name : 'User';

    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: Column(
        children: [
          // ── Header — collapses on scroll-down, snaps back on any scroll-up ─
          ClipRect(
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              alignment: Alignment.topCenter,
              heightFactor: _headerVisible ? 1.0 : 0.0,
              child: Padding(
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
            ),
          ),

          // ── "For You / Following" pill tabs ──────────────────────────────
          if (!_isSearchOpen)
            _FeedTabBar(ext: ext),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: RefreshIndicator(
                onRefresh: _onRefresh,
                color: ext.accentGold,
                backgroundColor: ext.homeBackground,
                child: _buildBody(context, ext, homeState, discoveryState),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppThemeExtension ext,
    HomeState homeState,
    DiscoveryState discoveryState,
  ) {
    // ── Search mode ──────────────────────────────────────────────────────────
    if (_isSearchOpen && homeState.isLoadingEvents) {
      return const CustomScrollView(slivers: [
        SliverFillRemaining(hasScrollBody: false, child: AppLoadingIndicator()),
      ]);
    }

    if (_isSearchOpen && homeState.events.isNotEmpty) {
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

    if (_isSearchOpen && homeState.isSearching && homeState.events.isEmpty) {
      return CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: HomeEmptyState(
            ext: ext,
            icon: Icons.event_busy_outlined,
            message: AppLocalizations.of(context)!.homeNoEventsFound,
          ),
        ),
      ]);
    }

    // ── Normal mode ──────────────────────────────────────────────────────────
    if (discoveryState.isLoading) {
      return const CustomScrollView(slivers: [
        SliverFillRemaining(hasScrollBody: false, child: AppLoadingIndicator()),
      ]);
    }

    if (discoveryState.events.isEmpty) {
      return CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: HomeEmptyState(
            ext: ext,
            icon: Icons.photo_library_outlined,
            message: AppLocalizations.of(context)!.homeNoEventsYet,
          ),
        ),
      ]);
    }

    return EventsFeed(
      discoveryState: discoveryState,
      onCardTap: (event) => _openEventImages(context, event),
      onCommentTap: (event) => _openEventComments(context, event),
      onLoadMore: () =>
          context.read<DiscoveryBloc>().add(const DiscoveryLoadMoreRequested()),
    );
  }
}

class _FeedTabBar extends StatelessWidget {
  final AppThemeExtension ext;
  const _FeedTabBar({required this.ext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _PillTab(
            label: 'For You',
            active: true,
            ext: ext,
            onTap: () {},
          ),
          const SizedBox(width: 8),
          _PillTab(
            label: 'Following',
            active: false,
            ext: ext,
            onTap: () {
              final discoveryBloc = context.read<DiscoveryBloc>();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => BlocProvider.value(
                    value: discoveryBloc,
                    child: const FollowingFeedPage(),
                  ),
                ),
              );
            },
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: active ? ext.accentGold : Colors.transparent,
          border: Border.all(
            color: active ? ext.accentGold : ext.searchHintColor.withValues(alpha: 0.4),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? Colors.black : ext.greetingColor,
            fontSize: 13,
            fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.2,
          ),
        ),
      ),
    );
  }
}
