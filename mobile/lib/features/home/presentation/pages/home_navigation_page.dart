import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/dark_media_surface.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_pictures_page.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:jperg_app/features/search/presentation/pages/search_page.dart';
import 'package:jperg_app/features/home/presentation/widgets/web_search_photos_panel.dart';
import 'package:jperg_app/features/home/presentation/widgets/events_feed.dart';
import 'package:jperg_app/features/home/presentation/widgets/home_empty_state.dart';
import 'package:jperg_app/features/home/presentation/widgets/feed_top_bar.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/event_scan_result_page.dart';
import 'package:jperg_app/features/home/presentation/widgets/unlock_photos_sheet.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_feed.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/utils/video_pause_notifier.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';

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

  /// Any caller can write a pill index here (0 = Found, 1 = Feed,
  /// 2 = Following) to request a pill switch, e.g. after a purchase that
  /// lands new photos in the Found tab. Cleared after being handled.
  static final pillTabRequest = ValueNotifier<int?>(null);

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  // 0 = Found, 1 = Feed, 2 = Following. Defaults to Feed (unchanged
  // landing tab from before Found was added).
  int _selectedTab = 1;

  /// Guests get a two-tab bar — Found and Explore — per the guest designs.
  /// "Feed" and "Following" both presuppose an account, so they collapse
  /// into one Explore tab rather than showing a Following feed that can only
  /// ever be empty.
  ///
  /// Null until the first check resolves; the bar renders the signed-in set
  /// meanwhile, since that's what most sessions are.
  bool? _isGuest;

  static const _guestTabs = ['Found', 'Explore'];
  static const _memberTabs = ['Found', 'Feed', 'Following'];

  /// True while the unlock sheet is up, so the bar's QR glyph can show it.
  bool _unlockSheetOpen = false;

  List<String> get _tabs => _isGuest == true ? _guestTabs : _memberTabs;

  bool _headerVisible = false;
  double _headerDownAccum = 0;
  static const _headerHideThreshold = 28.0;

  // Measured height of the floating header overlay — used as list top padding.
  final _headerKey = GlobalKey();
  double _headerHeight = 0;

  @override
  void initState() {
    super.initState();
    _resolveGuest();
    HomeNavigationPage.pillTabRequest.addListener(_onPillTabRequest);
    // A request can be posted *before* this page mounts — the guest shell sets
    // it as it hands off after sign-up. A ValueNotifier only notifies on
    // change, so the listener above would never see it; consume it here.
    // Assigned directly rather than via _selectTab because setState is illegal
    // before the first build (and pointless — nothing has rendered yet).
    final pendingTab = HomeNavigationPage.pillTabRequest.value;
    if (pendingTab != null) {
      _selectedTab = pendingTab;
      if (pendingTab == 0) {
        _headerVisible = true;
        _headerDownAccum = 0;
      }
      HomeNavigationPage.pillTabRequest.value = null;
    }
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

  Future<void> _resolveGuest() async {
    final isGuest = (await sl<AuthService>().getToken()).isEmpty;
    if (!mounted || isGuest == _isGuest) return;
    setState(() {
      _isGuest = isGuest;
      // Following (2) has no guest equivalent; anyone parked there when the
      // check resolves lands on Explore rather than on a tab that no longer
      // exists.
      if (isGuest && _selectedTab >= _guestTabs.length) _selectedTab = 1;
    });
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

  /// Search is a screen of its own — recents, three result chips and a
  /// suggestion grid — rather than an overlay on the feed. [query] pre-fills
  /// the field when search is opened on the user's behalf.
  void _openSearch({String? query}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SearchPage(initialQuery: query),
      ),
    );
  }

  /// Resolves an event code — scanned or typed — into that event's photos.
  ///
  /// The code *is* the event id, which is why it can be handed straight to a
  /// screen that filters by one. It deliberately does not go through
  /// [HomeEventSearched]: that is a text search over event *names*, and a code
  /// is an identifier, not a name — it would never match.
  ///
  /// Every entry point funnels through here so scanning and typing cannot
  /// diverge.
  void _openEventByCode(String code) {
    // Straight to the scan result, not a search results page. A code scanned
    // off a private event is a question — "are there photos of me in here?" —
    // and this is the screen that answers it, then hands over to the album
    // with the matches preselected for review.
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventScanResultPage(code: code),
      ),
    );
  }

  /// Leading action on the feed bar: a code the user types, or one scanned
  /// from the preview embedded in the same sheet. Both are the same code and
  /// take the same path as [_openQrScan].
  Future<void> _openUnlock() async {
    setState(() => _unlockSheetOpen = true);
    try {
      final code = await UnlockPhotosSheet.show(context);
      if (!mounted || code == null || code.isEmpty) return;
      _openEventByCode(code);
    } finally {
      // In a finally so the glyph un-tints however the sheet went away —
      // submitted, dismissed by the handle, or tapped out of.
      if (mounted) setState(() => _unlockSheetOpen = false);
    }
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
    if (kIsWeb) return false;
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
  /// bar) — the Found/Feed/Following header floats transparently on top
  /// of it rather than reserving its own opaque strip, matching the design.
  double get _feedTopPadding => 0;

  /// How far a surface has to start below the floating header to clear it.
  ///
  /// Full-bleed media runs *under* the header by design — see
  /// [_feedTopPadding]. Anything made of text cannot: it lands on the status
  /// bar and behind the tab labels. That covers the Found grid, and the
  /// Following tab whenever it is showing its empty state or a suggested-
  /// creators card rather than a photo.
  ///
  /// Falls back to a sensible estimate until the header has been measured.
  double get _headerClearance {
    if (kIsWeb) return 0;
    if (_headerHeight > 0) return _headerHeight;
    return MediaQuery.of(context).padding.top + 48;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final discoveryState = context.watch<DiscoveryBloc>().state;

    // ── Web: compact top bar (tabs + avatar) + Column layout ─────────────────
    if (kIsWeb) {
      // Keep webEventResults in sync with BLoC state so the sidebar typeahead
      // dropdown can display results without direct BLoC access. Watched here
      // and not above: the feed itself no longer reads HomeBloc — search moved
      // to its own screen — so on mobile this would only cost rebuilds.
      final homeState = context.watch<HomeBloc>().state;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          HomeNavigationPage.webEventResults.value = homeState.events;
        }
      });

      return Stack(
        children: [
          Scaffold(
            backgroundColor: ext.homeBackground,
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Compact top bar: tabs + search ──────────────────────────────
                SizedBox(
                  height: 54,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                    child: Row(
                      children: [
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
                          label: 'Feed',
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
                        const SizedBox(width: 12),
                        MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Semantics(
                            button: true,
                            label: 'Open search',
                            child: GestureDetector(
                              onTap: _openSearch,
                              child: Icon(Icons.search_rounded,
                                  color: ext.glassIcon, size: 20),
                            ),
                          ),
                        ),
                        const Spacer(),
                        // Get-the-app / Messages / Profile now live in the
                        // global WebTopActions cluster (app shell) so they
                        // appear on every screen at the same position. Leave
                        // room here so the tabs don't sit under it.
                        const SizedBox(width: 240),
                      ],
                    ),
                  ),
                ),
                // ── Feed content ────────────────────────────────────────────────
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _onScrollNotification,
                    child: _buildBody(context, ext, discoveryState),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── Mobile: floating overlay header that slides in/out on scroll ──────────
    final topPadding = MediaQuery.of(context).padding.top;
    _measureHeaderHeight();

    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: Stack(
        children: [
          // Body fills entire screen — header/tab bar float above it.
          Positioned.fill(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScrollNotification,
              child: _buildBody(context, ext, discoveryState),
            ),
          ),

          // Top scrim — media is full-bleed behind the header now, so this
          // keeps the Found/Feed/Following labels legible over bright
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
                  tabs: _tabs,
                  // Found is the one tab on the page's own background — see
                  // the scrim above, which skips it for the same reason.
                  overSolidBackground: _selectedTab == 0,
                  selectedTab: _selectedTab,
                  onTabChanged: (i) {
                    VideoPauseNotifier.pauseAll();
                    _selectTab(i);
                  },
                  onSearchOpen: _openSearch,
                  // Shown to guests too: an event code is exactly how
                  // someone without an account gets at photos of themselves.
                  onUnlockPressed: _openUnlock,
                  unlockActive: _unlockSheetOpen,
                ),
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
    DiscoveryState discoveryState,
  ) {
    // IndexedStack keeps both tabs mounted, so without gating the inactive
    // tab's top video would auto-play too. TickerMode(enabled: …) pauses every
    // video in the inactive tab (JpergVideoPlayer reads TickerMode.of) and
    // resumes the active one — so only the visible tab plays.
    return IndexedStack(
      index: _selectedTab,
      children: [
        // ── Found ────────────────────────────────────────────────────────────
        TickerMode(
          enabled: _selectedTab == 0,
          child: FoundFeed(topPadding: _headerClearance),
        ),
        // ── Feed ─────────────────────────────────────────────────────────────
        // Both media feeds are dark whatever the app's theme is — see
        // [DarkMediaSurface]. Read `ext` from inside the wrapper, not the
        // outer one this method was handed, or the feed's own chrome keeps
        // resolving light colours onto a dark surround.
        TickerMode(
          enabled: _selectedTab == 1,
          child: DarkMediaSurface(
            child: Builder(
              builder: (context) {
                final darkExt =
                    Theme.of(context).extension<AppThemeExtension>()!;
                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: darkExt.accentGold,
                  backgroundColor: darkExt.homeBackground,
                  child: _buildForYouContent(context, darkExt, discoveryState),
                );
              },
            ),
          ),
        ),
        // ── Following ────────────────────────────────────────────────────────
        TickerMode(
          enabled: _selectedTab == 2,
          child: DarkMediaSurface(
            child: FollowingFeed(chromeTopPadding: _headerClearance),
          ),
        ),
      ],
    );
  }

  Widget _buildForYouContent(
    BuildContext context,
    AppThemeExtension ext,
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
      ],
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

