import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/create_bottom_sheet.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/search_results_page.dart';
import 'package:skidoo_app/features/home/presentation/widgets/web_search_photos_panel.dart';
import 'package:skidoo_app/features/home/presentation/widgets/events_feed.dart';
import 'package:skidoo_app/features/home/presentation/widgets/home_empty_state.dart';
import 'package:skidoo_app/features/home/presentation/widgets/feed_top_bar.dart';
import 'package:skidoo_app/features/home/presentation/widgets/search_events_list.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/common/widgets/feed_launch_overlay.dart';
import 'package:skidoo_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:skidoo_app/features/gallery/presentation/found/found_feed.dart';
import 'package:flutter/foundation.dart';
import 'package:skidoo_app/core/utils/video_pause_notifier.dart';
import 'package:skidoo_app/core/utils/web_wrap.dart';
import 'package:skidoo_app/features/home/presentation/pages/qr_scan_page.dart';

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  /// Web-only: sidebar calls [dispatchSearch] to dispatch a BLoC event search.
  /// Using a callback instead of ValueNotifier avoids the "same value silently
  /// dropped" edge case that broke debounced keystrokes.
  static void Function(String query)? _webSearchHandler;
  static void dispatchSearch(String query) => _webSearchHandler?.call(query);

  /// Web-only: mirrors the live event search results so the sidebar typeahead
  /// dropdown can display them without needing BLoC access.
  static final webEventResults = ValueNotifier<List<dynamic>>([]);

  /// Web-only: called by the sidebar when the user picks an event from the
  /// typeahead dropdown. Opens the inline photo-results panel in the content
  /// area and fetches the event's photos.
  static void Function(String eventId, String eventName)? _webEventTapHandler;
  static void dispatchEventTap(String eventId, String eventName) =>
      _webEventTapHandler?.call(eventId, eventName);

  /// Any caller can write a pill index here (0 = Found, 1 = For You,
  /// 2 = Following) to request a pill switch, e.g. after a purchase that
  /// lands new photos in the Found tab. Cleared after being handled.
  static final pillTabRequest = ValueNotifier<int?>(null);

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  bool _isSearchOpen = false;
  // 0 = Found, 1 = For You, 2 = Following. Defaults to For You (unchanged
  // landing tab from before Found was added).
  int _selectedTab = 1;

  // Web desktop: show photo results inline (no Navigator push).
  bool _showPhotosInline = false;
  String _inlineEventName = '';

  bool _headerVisible = false;
  double _headerDownAccum = 0;
  static const _headerHideThreshold = 28.0;

  // Measured height of the floating header overlay — used as list top padding.
  final _headerKey = GlobalKey();
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    HomeNavigationPage.pillTabRequest.addListener(_onPillTabRequest);
    if (kIsWeb) {
      // Typeahead: only dispatch the BLoC event search — don't open the content
      // overlay. The sidebar dropdown shows suggestions; the inline photos panel
      // only opens after the user taps an event (via _webEventTapHandler).
      HomeNavigationPage._webSearchHandler = (q) {
        if (!mounted || q.isEmpty) return;
        context.read<HomeBloc>().add(HomeEventSearched(q));
      };
      HomeNavigationPage._webEventTapHandler = (eventId, eventName) {
        if (!mounted) return;
        final homeBloc = context.read<HomeBloc>();
        homeBloc.add(
            HomeImagesSearched(eventId: eventId, eventName: eventName));
        // Route to the search-event page on the ROOT navigator so it opens on
        // top of whatever page/tab the user is currently on (Gallery, a
        // profile, chat, …) — the inline panel only showed on the Home tab.
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute<void>(
            builder: (_) => BlocProvider.value(
              value: homeBloc,
              child: WebSearchPhotosPage(eventName: eventName),
            ),
          ),
        );
      };
    }
  }

  @override
  void dispose() {
    HomeNavigationPage.pillTabRequest.removeListener(_onPillTabRequest);
    if (kIsWeb) {
      HomeNavigationPage._webSearchHandler = null;
      HomeNavigationPage._webEventTapHandler = null;
    }
    super.dispose();
  }

  void _onPillTabRequest() {
    final tab = HomeNavigationPage.pillTabRequest.value;
    if (tab != null) {
      _selectTab(tab);
      HomeNavigationPage.pillTabRequest.value = null;
    }
  }

  /// Single entry point for switching pills so the header rule below can't be
  /// forgotten at one of the call sites.
  void _selectTab(int index) {
    setState(() {
      _selectedTab = index;
      // Found never hides its header (see [_onScrollNotification]), so make
      // sure arriving on it from a tab that had scrolled the header away
      // brings it back.
      if (index == 0) {
        _headerVisible = true;
        _headerDownAccum = 0;
      }
    });
  }

  void _measureHeaderHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box = _headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null) return;
      final h = box.size.height;
      if (h != _headerHeight) setState(() => _headerHeight = h);
    });
  }

  void _openSearch() {
    _headerDownAccum = 0;
    setState(() {
      _isSearchOpen = true;
      _headerVisible = true;
      _selectedTab = 1; // always show For You when searching
    });
  }

  void _closeSearch() {
    _headerDownAccum = 0;
    setState(() {
      _isSearchOpen = false;
      _headerVisible = false;
      _showPhotosInline = false;
      _inlineEventName = '';
    });
    HomeNavigationPage.webEventResults.value = [];
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

  void _openCreate() => CreateBottomSheet.show(context);

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
    // Found is a grid, not full-bleed media: its content is padded to start
    // below the header rather than running under it, so hiding the header
    // would only open a blank strip. Keep it pinned there.
    if (_selectedTab == 0) return false;

    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final atTop = notification.metrics.pixels <= 0;

      if (delta > 0 && !atTop) {
        // Scrolling down (and not at the top boundary) — accumulate and hide.
        _headerDownAccum += delta;
        if (_headerDownAccum >= _headerHideThreshold && _headerVisible) {
          setState(() => _headerVisible = false);
        }
      } else if (delta < 0 || atTop) {
        // Scrolling up, or bounce-back at top — show header, reset accum.
        _headerDownAccum = 0;
        if (!_headerVisible) setState(() => _headerVisible = true);
      }
    } else if (notification is ScrollEndNotification) {
      // Scrolling stopped — header stays exactly as it is (visible or
      // hidden); it never auto-hides on a timer once at rest.
      _headerDownAccum = 0;
      if (notification.metrics.pixels <= 0 && !_headerVisible) {
        setState(() => _headerVisible = true);
      }
    }
    return false;
  }

  /// Media is always full-bleed edge-to-edge (including under the status
  /// bar) — the Found/For You/Following header floats transparently on top
  /// of it rather than reserving its own opaque strip, matching the design.
  double get _feedTopPadding => 0;

  /// Found is the one tab that isn't full-bleed media: it's a scrolling grid
  /// of album sections, so its content has to start *below* the floating
  /// header instead of running under it. Falls back to a sensible estimate
  /// until the header has been measured.
  double get _foundTopPadding {
    if (kIsWeb) return 0;
    if (_headerHeight > 0) return _headerHeight;
    return MediaQuery.of(context).padding.top + 48;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final homeState = context.watch<HomeBloc>().state;
    final discoveryState = context.watch<DiscoveryBloc>().state;

    // ── Web: compact top bar (tabs + avatar) + Column layout ─────────────────
    if (kIsWeb) {
      // Keep webEventResults in sync with BLoC state so the sidebar typeahead
      // dropdown can display results without direct BLoC access.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          HomeNavigationPage.webEventResults.value = homeState.events;
        }
      });

      return FeedLaunchOverlay(
        child: Stack(
          children: [
            Scaffold(
              backgroundColor: ext.homeBackground,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Compact top bar: tabs + avatar, or search-open state ────────
                  SizedBox(
                    height: 54,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                      child: Row(
                        children: [
                          if (_isSearchOpen) ...[
                            Icon(Icons.search_rounded,
                                size: 16, color: ext.accentGold),
                            const SizedBox(width: 8),
                            Text(
                              'Search results',
                              style: TextStyle(
                                color: ext.greetingColor,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Spacer(),
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              child: Semantics(button: true, label: 'Close search', child: GestureDetector(
                                onTap: _closeSearch,
                                child: Icon(Icons.close_rounded,
                                    color: ext.searchHintColor, size: 20),
                              )),
                            ),
                          ] else ...[
                            _PillTab(
                              label: 'Found',
                              active: _selectedTab == 0,
                              ext: ext,
                              onTap: () {
                                VideoPauseNotifier.pauseAll();
                                setState(() => _selectedTab = 0);
                              },
                            ),
                            const SizedBox(width: 8),
                            _PillTab(
                              label: 'For You',
                              active: _selectedTab == 1,
                              ext: ext,
                              onTap: () {
                                VideoPauseNotifier.pauseAll();
                                setState(() => _selectedTab = 1);
                              },
                            ),
                            const SizedBox(width: 8),
                            _PillTab(
                              label: 'Following',
                              active: _selectedTab == 2,
                              ext: ext,
                              onTap: () {
                                VideoPauseNotifier.pauseAll();
                                setState(() => _selectedTab = 2);
                              },
                            ),
                            const Spacer(),
                            // Get-the-app / Messages / Profile now live in the
                            // global WebTopActions cluster (app shell) so they
                            // appear on every screen at the same position. Leave
                            // room here so the tabs don't sit under it.
                            const SizedBox(width: 240),
                          ],
                        ],
                      ),
                    ),
                  ),
                  // ── Feed content ────────────────────────────────────────────────
                  Expanded(
                    child: NotificationListener<ScrollNotification>(
                      onNotification: _onScrollNotification,
                      child:
                          _buildBody(context, ext, homeState, discoveryState),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // ── Mobile: floating overlay header that slides in/out on scroll ──────────
    final topPadding = MediaQuery.of(context).padding.top;
    _measureHeaderHeight();

    return FeedLaunchOverlay(
      child: PopScope(
        // While search is open, the system back gesture/button closes search
        // instead of leaving the tab (there was previously no way back other
        // than spotting the small close icon in the header).
        canPop: !_isSearchOpen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _isSearchOpen) _closeSearch();
        },
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

            // Top scrim — media is full-bleed behind the header now, so this
            // keeps the Found/For You/Following labels legible over bright
            // photos/videos instead of relying on an opaque reserved strip.
            // Found needs no scrim: its header sits on the solid page
            // background, where a gradient would just read as a smudge.
            if (_selectedTab != 0)
              const Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: 140,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x99000000), Color(0x00000000)],
                      ),
                    ),
                  ),
                ),
              ),

            // Header slides in/out from top (Transform.translate — no layout
            // shift).
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: AnimatedSlide(
                offset: _headerVisible ? Offset.zero : const Offset(0, -1),
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Padding(
                  key: _headerKey,
                  padding: EdgeInsets.only(top: topPadding),
                  child: FeedTopBar(
                    selectedTab: _selectedTab,
                    onTabChanged: (i) {
                      VideoPauseNotifier.pauseAll();
                      _selectTab(i);
                    },
                    isSearchOpen: _isSearchOpen,
                    onSearchOpen: _openSearch,
                    onSearchClose: _closeSearch,
                    onSearchChanged: _onSearchChanged,
                    onQrScan: _openQrScan,
                    onCreatePressed: (AppConfigRepository.current.adsEnabled ||
                            AppConfigRepository.current.requestsEnabled)
                        ? _openCreate
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
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
    // IndexedStack keeps both tabs mounted, so without gating the inactive
    // tab's top video would auto-play too. TickerMode(enabled: …) pauses every
    // video in the inactive tab (SkidooVideoPlayer reads TickerMode.of) and
    // resumes the active one — so only the visible tab plays.
    return IndexedStack(
      index: _selectedTab,
      children: [
        // ── Found ────────────────────────────────────────────────────────────
        TickerMode(
          enabled: _selectedTab == 0,
          child: FoundFeed(topPadding: _foundTopPadding),
        ),
        // ── For You ──────────────────────────────────────────────────────────
        TickerMode(
          enabled: _selectedTab == 1,
          child: RefreshIndicator(
            onRefresh: _onRefresh,
            color: ext.accentGold,
            backgroundColor: ext.homeBackground,
            child: _buildForYouContent(context, ext, homeState, discoveryState),
          ),
        ),
        // ── Following ────────────────────────────────────────────────────────
        TickerMode(
          enabled: _selectedTab == 2,
          child: FollowingFeed(topPadding: _feedTopPadding),
        ),
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
          onLoadMore: () => context
              .read<DiscoveryBloc>()
              .add(const DiscoveryLoadMoreRequested()),
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
              child: _showPhotosInline
                  // ── Web desktop: inline photo results panel ────────────────
                  // Constrained to the standard centred web column (webWrap),
                  // matching Gallery/Photographers. The back arrow returns to
                  // the home feed (not the in-content suggestion overlay).
                  ? webWrap(
                      WebSearchPhotosPanel(
                        ext: ext,
                        eventName: _inlineEventName,
                        onBack: _closeSearch,
                        onClose: _closeSearch,
                      ),
                      backgroundColor: ext.homeBackground,
                      width: kWebColumnWidthWide,
                    )
                  // ── Event suggestion list (all platforms) ──────────────────
                  // Offset below the floating header (status bar + search bar)
                  // plus a little breathing room, so results never slide up
                  // under the app bar. Falls back to a sensible estimate until
                  // the header has been measured.
                  : Padding(
                      padding: EdgeInsets.only(
                        top: (_headerHeight > 0
                                ? _headerHeight
                                : MediaQuery.of(context).padding.top + 64) +
                            12,
                      ),
                      child: _buildSearchOverlay(context, ext, homeState),
                    ),
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
          if (kIsWeb) {
            // Desktop/laptop web: show photos inline — no page transition.
            setState(() {
              _showPhotosInline = true;
              _inlineEventName = '${event.eventName}';
            });
          } else {
            // Mobile: navigate to the full SearchResultsPage.
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BlocProvider.value(
                  value: context.read<HomeBloc>(),
                  child: const SearchResultsPage(),
                ),
              ),
            );
          }
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
    return Semantics(button: true, label: label, child: GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color:
              active ? ext.accentGold.withValues(alpha: 0.92) : ext.glassFill,
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
    ));
  }
}

