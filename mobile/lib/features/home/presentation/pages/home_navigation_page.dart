import 'package:flutter/material.dart';
import 'package:jperg_app/features/home/presentation/widgets/feed_skeleton.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/navigation/chrome_visibility.dart';
import 'package:jperg_app/core/navigation/feed_chrome.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/dark_media_surface.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/event_comment_page.dart';
import 'package:jperg_app/features/discovery/presentation/utils/open_event_photos.dart';
import 'package:jperg_app/features/search/presentation/pages/search_page.dart';
import 'package:jperg_app/features/home/presentation/widgets/events_feed.dart';
import 'package:jperg_app/features/home/presentation/widgets/home_empty_state.dart';
import 'package:jperg_app/features/home/presentation/widgets/feed_top_bar.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/event_scan_result_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/face_gate_page.dart';
import 'package:jperg_app/features/home/presentation/widgets/unlock_photos_sheet.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_feed.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_feed.dart';
import 'package:flutter/foundation.dart';
import 'package:jperg_app/core/utils/video_pause_notifier.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/features/location/presentation/location_mismatch_prompt.dart';

/// Slides the header in and out with the feed's chrome.
///
/// Listens to [FeedChrome] rather than being handed a boolean, for the same
/// reason the bottom bar does (see `_HomeViewState._buildPhoneLayout`): the tap
/// that summons the chrome happens on a card, several widgets down, and flips
/// the notifier from outside this page entirely — nothing here would otherwise
/// know to rebuild. [visible] is read on each notification rather than captured,
/// so it can fold in the tab you are on as well.
class _WithHeaderVisibility extends StatelessWidget {
  const _WithHeaderVisibility({required this.visible, required this.child});

  final ValueGetter<bool> visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: FeedChrome.visible,
        builder: (context, _, child) => AnimatedSlide(
          offset: visible() ? Offset.zero : const Offset(0, -1),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: child,
        ),
        child: child,
      );
}

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  /// Any caller can write a pill index here (0 = Found, 1 = Feed,
  /// 2 = Following) to request a pill switch, e.g. after a purchase that
  /// lands new photos in the Found tab. Cleared after being handled.
  static final pillTabRequest = ValueNotifier<int?>(null);

  /// Bumped when Home is tapped while Home is already the tab you are on.
  ///
  /// The feed showing at that moment goes back to its first card and refetches
  /// — see [EventsFeedState.resetAndRefresh]. A counter rather than a flag
  /// because the same request can arrive twice in a row and a `ValueNotifier`
  /// only notifies when the value changes; two taps are two resets.
  ///
  /// Only [HomePage] writes here, and only for a genuine tap. Arriving on Home
  /// from another tab is not one: the feed is left exactly where it was, which
  /// is what makes stepping into a chat and back cost nothing.
  static final feedResetRequest = ValueNotifier<int>(0);

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

  /// Whether the Found/Feed/Following header is on screen.
  ///
  /// Derived, never stored. The header is the top half of the feed's chrome and
  /// the floating nav bar is the bottom half; they answer to one gesture — a tap
  /// on a photo — and [FeedChrome] is where that answer lives. Given a copy of
  /// the state each, the two halves drift, and the drift is exactly what was
  /// reported: the bar and the sound control came up on a tap while the tabs
  /// stayed away, with no gesture left to bring them back but scrolling.
  ///
  /// Found is the one exception, and the only reason this is a rule rather than
  /// a plain read of the notifier: it is a grid whose content starts *below* the
  /// header rather than running under it, so hiding the header there would only
  /// open a blank strip.
  bool get _headerVisible => _selectedTab == 0 || FeedChrome.visible.value;

  // Measured height of the floating header overlay — used as list top padding.
  final _headerKey = GlobalKey();
  double _headerHeight = 0;

  /// Handles on the two feeds, so a Home tap can reach whichever is showing.
  ///
  /// The same shape the Profile tab already uses to refresh itself on open
  /// (`_profileKey` in HomePage). A notifier would not do: the answer is not a
  /// value either feed can watch for, it is an instruction to exactly one of
  /// them, chosen by which pill is up.
  final _feedKey = GlobalKey<EventsFeedState>();
  final _followingKey = GlobalKey<FollowingFeedState>();

  @override
  void initState() {
    super.initState();
    _resolveGuest();
    HomeNavigationPage.pillTabRequest.addListener(_onPillTabRequest);
    HomeNavigationPage.feedResetRequest.addListener(_onFeedReset);
    // A request can be posted *before* this page mounts — the guest shell sets
    // it as it hands off after sign-up. A ValueNotifier only notifies on
    // change, so the listener above would never see it; consume it here.
    // Assigned directly rather than via _selectTab because setState is illegal
    // before the first build (and pointless — nothing has rendered yet).
    final pendingTab = HomeNavigationPage.pillTabRequest.value;
    if (pendingTab != null) {
      _selectedTab = pendingTab;
      HomeNavigationPage.pillTabRequest.value = null;
    }
  }

  /// Home was tapped while already on Home: start the feed that is showing
  /// over again.
  ///
  /// Found is deliberately not one of them. It is not a feed of what is new —
  /// it is the photos somebody has been recognised in, which arrive when a
  /// photographer uploads rather than when you ask, and which the person is
  /// usually working through rather than browsing. Sending them back to the
  /// first one would lose their place in a list they were reading.
  void _onFeedReset() {
    if (!mounted) return;
    switch (_selectedTab) {
      case 1:
        // Feed for a member, Explore for a guest — same slot, same feed.
        _feedKey.currentState?.resetAndRefresh();
      case 2:
        _followingKey.currentState?.resetAndRefresh();
    }
  }

  @override
  void dispose() {
    HomeNavigationPage.pillTabRequest.removeListener(_onPillTabRequest);
    HomeNavigationPage.feedResetRequest.removeListener(_onFeedReset);
    super.dispose();
  }

  Future<void> _resolveGuest() async {
    final isGuest = (await sl<AuthService>().getToken()).isEmpty;
    if (!mounted) return;
    if (isGuest != _isGuest) {
      setState(() {
        _isGuest = isGuest;
        // Following (2) has no guest equivalent; anyone parked there when the
        // check resolves lands on Explore rather than on a tab that no longer
        // exists.
        if (isGuest && _selectedTab >= _guestTabs.length) _selectedTab = 1;
      });
    }
    if (!isGuest) _checkLocation();
  }

  /// Ask once, quietly, whether the account's location is still right.
  ///
  /// Deferred to after the first frame so the shell paints before anything
  /// can put a sheet over it, and unawaited because nothing about launching
  /// the app should wait on it. Signed-in only: a guest has no location to
  /// disagree with. See [LocationMismatchPrompt] for the rate limiting, which
  /// is most of why this is safe to call on every launch.
  void _checkLocation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) LocationMismatchPrompt.maybeShow(context);
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
    // A new tab starts at its own scroll position and the person is no longer
    // reading — a bar left collapsed here could only be reopened by finding
    // something to scroll, which on a short tab may not exist.
    ChromeVisibility.reset();
    // Found never hides its header — arriving on it from a feed whose chrome
    // was away brings the tabs back on its own. See [_headerVisible].
    setState(() => _selectedTab = index);
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
  ///
  /// Asks for a face first. Scanning a code answers "are there photos of me in
  /// here?", and face matching needs a reference selfie to answer it with —
  /// without one the scan runs, finds nothing, and reports an event that
  /// appears to hold no photos of them. That is the same screen the Found tab
  /// shows for the same reason, put in front of the tap instead of after it.
  Future<void> _openUnlock() async {
    if (await resolveFoundAccess() != FoundAccess.ready) {
      if (!mounted) return;
      // Comes back true once they are through it, so the scan they asked for
      // still happens instead of being lost to the detour.
      final passed = await FaceGatePage.show(context);
      if (!passed) return;
    }
    // Covers both paths out of the gate above — taken or skipped, an await has
    // happened and the feed may be gone.
    if (!mounted) return;

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

  void _openEventComments(BuildContext context, EventDiscovery event) {
    EventCommentPage.show(context, event);
  }

  Future<void> _onRefresh() {
    final bloc = context.read<DiscoveryBloc>();
    // They pulled: a new deal is exactly what was asked for.
    bloc.add(const DiscoveryLoadRequested(userInitiated: true));
    // Await until the bloc leaves its loading state (or 10 s timeout).
    return bloc.stream
        .firstWhere((s) => !s.isLoading)
        .timeout(const Duration(seconds: 10), onTimeout: () => bloc.state);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // The bottom bar collapses on every tab, Found included: it floats over
    // the content everywhere and narrowing it gives the grid its width back.
    ChromeVisibility.handle(notification);

    // Nothing here about the header. Reading down a feed takes it away and
    // coming back up returns it — but that is [FeedChrome]'s rule, applied to
    // both halves of the chrome at once by the shell's own scroll listener
    // (see [_HomeViewState._onScrollNotification]), which sees these same
    // notifications on their way up. This page used to keep a second copy of
    // that rule for the header alone, with its own accumulator and its own
    // threshold, and a second copy is a second answer.
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
    if (_headerHeight > 0) return _headerHeight;
    return MediaQuery.of(context).padding.top + 48;
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final discoveryState = context.watch<DiscoveryBloc>().state;

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
          //
          // On iOS this is frost instead of a gradient — the platform's own
          // bars separate from content by blurring it, and a black gradient
          // over a frosted bar would be two answers to one question. It rides
          // with the header, so scrolling away takes the frost with it rather
          // than leaving a smudged band over the photo.
          if (_selectedTab != 0)
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              // _headerHeight is measured on the Padding that already carries
              // topPadding, so adding it again drew a strip a status bar
              // taller than the header it was backing.
              height: _headerHeight > 0 ? _headerHeight : 140,
              child: IgnorePointer(
                child: _WithHeaderVisibility(
                  visible: () => _headerVisible,
                  child: GlassSurface.isFrosted
                      ? GlassSurface(
                          borderRadius: BorderRadius.zero,
                          bordered: false,
                          // The feed is a dark island whatever the app theme
                          // is, and this sits on it.
                          onDark: true,
                          child: const SizedBox.expand(),
                        )
                      : const DecoratedBox(
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
            ),

          // Header slides in/out from top (Transform.translate — no layout
          // shift).
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _WithHeaderVisibility(
              visible: () => _headerVisible,
              child: Padding(
                key: _headerKey,
                padding: EdgeInsets.only(top: topPadding),
                // Only the dot depends on this, so the listener wraps the bar
                // rather than the page — the Found tab publishes a pending
                // count on mount and after a review, and neither should
                // rebuild the feeds underneath.
                child: ValueListenableBuilder<int>(
                  valueListenable: FoundFeed.pendingCount,
                  builder: (context, pending, __) => FeedTopBar(
                    tabs: _tabs,
                    // Found carries a dot while photos of this person are
                    // waiting to be confirmed — see FoundFeed.pendingCount.
                    badgedTabs: pending > 0 ? const {0} : const {},
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
            child: FollowingFeed(
              key: _followingKey,
              chromeTopPadding: _headerClearance,
            ),
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
          key: _feedKey,
          discoveryState: discoveryState,
          topPadding: _feedTopPadding,
          // Keyboard only — see [EventsFeed.onCardTap]. A tap on a card belongs
          // to the chrome now, and the way into an album is the card's own
          // "Explore event photos".
          onCardTap: (event) => openEventPhotos(context, event),
          onCommentTap: (event) => _openEventComments(context, event),
          onLoadMore: () => context
              .read<DiscoveryBloc>()
              .add(const DiscoveryLoadMoreRequested()),
        ),
        // The wait, drawn as the thing being waited for.
        //
        // This was a spinner centred on an empty screen, which is what the
        // reader sees immediately after the launch logo — the app's second
        // impression, saying only that it is busy. The skeleton says what is
        // coming and where it will be, so the photograph arriving reads as the
        // picture appearing rather than as one screen replacing another.
        if (discoveryState.isLoading) const Positioned.fill(child: FeedSkeleton()),
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
