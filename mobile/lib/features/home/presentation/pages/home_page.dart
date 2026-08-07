import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/utils/responsive.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:jperg_app/features/gallery/presentation/found/bloc/found_bloc.dart';
import 'package:jperg_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:jperg_app/features/notifications/presentation/pages/notifications_page.dart';
import 'package:jperg_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:jperg_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/user_profile_page.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/face_recognition_page.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/chat/presentation/pages/chat_rooms_page.dart';
import 'package:jperg_app/components/common/navbar.dart';
import 'package:jperg_app/core/utils/video_pause_notifier.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

class HomePage extends StatelessWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  /// Any nested route can write an index here to request a tab switch.
  /// `_HomeViewState` listens and clears it after switching.
  static final tabRequest = ValueNotifier<int?>(null);

  /// Fires (incremented) by `HomeNavigationPage` on every deliberate tap so
  /// `_HomeViewState` can show the bottom nav and start its auto-hide timer.
  static final homeTapSignal = ValueNotifier<int>(0);

  /// Tracks the active tab index on web so the [WebSidebar] can highlight
  /// the correct item without being coupled to [_HomeViewState].
  static final webSelectedTab = ValueNotifier<int>(0);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HomeBloc>()..add(const HomeInitialized())),
        BlocProvider(
            create: (_) =>
                sl<DiscoveryBloc>()..add(const DiscoveryLoadRequested())),
        BlocProvider(create: (_) => sl<GalleryBloc>()),
        BlocProvider(create: (_) => sl<FoundBloc>()),
        BlocProvider(create: (_) => sl<PhotographerBloc>()),
        BlocProvider(
            create: (_) => sl<UserProfileBloc>()
              ..add(const UserProfileLoadRequested())),
        BlocProvider.value(value: sl<CartBloc>()),
        // ChatRoomsBloc is provided at the root level (app.dart) so that
        // the unread-count badge works even when the user is on DiscoveryPage.
        // Do NOT create a second instance here — use the inherited one.
      ],
      child: const _HomeView(),
    );
  }
}

class _HomeView extends StatefulWidget {
  const _HomeView();

  @override
  State<_HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<_HomeView> {
  // SharedPreferences key used to persist the active tab on web so that a
  // page refresh restores the user to the same section they were viewing.
  static const _kWebTabKey = 'home.selected_tab';

  int _selectedTab = 0;
  // Tab 0 starts with chrome hidden — shows only on deliberate tap.
  bool _navBarVisible = false;

  // Accumulates downward scroll px. Resets on any upward movement or tab
  // switch. The nav bar hides only after the user has scrolled down a clear,
  // intentional distance — avoids hiding on micro-bounces or tap-holds.
  double _downAccum = 0;
  static const _hideThreshold = 28.0;

  // Tracks which tabs have been loaded so we only fire load events once.
  final _loadedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    HomePage.tabRequest.addListener(_onTabRequest);
    HomePage.homeTapSignal.addListener(_onHomeTap);
    // On web: restore the tab the user was viewing before the last refresh.
    // Deferred to post-frame so Navigator/BLoC providers are fully ready.
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restoreWebTab());
    }
    // Nudge the user to add their reference photos (first login + every 4 days)
    // until they've done so. Deferred so the home tree is laid out first.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptAddFaces());
  }

  /// Shows the "add your photos" prompt when the user hasn't added faces and it
  /// hasn't been shown in the last 4 days. The last-shown time is stored so it
  /// reappears at most once every 4 days.
  Future<void> _maybePromptAddFaces() async {
    if (!mounted) return;
    try {
      final auth = sl<AuthService>();
      // Only clients are matched against galleries; skip photographers.
      if ((await auth.getRole()) == 'photographer') return;
      if (await auth.getHasAddedFaces()) return; // already added their photos
      final last = await auth.getLastFacePrompt();
      if (last != null &&
          DateTime.now().difference(last) < const Duration(days: 4)) {
        return;
      }
      await auth.setLastFacePrompt(DateTime.now());
      if (mounted) _showAddFacesDialog();
    } catch (_) {
      // Storage unavailable — skip the nudge silently.
    }
  }

  void _showAddFacesDialog() {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final gold = ext.accentGold;
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 28.w),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: ext.cardSurface,
            borderRadius: BorderRadius.circular(26.r),
            boxShadow: [
              BoxShadow(
                color: gold.withValues(alpha: 0.18),
                blurRadius: 36.r,
                spreadRadius: 2.r,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Gradient hero with a glowing face badge ──────────────────
              Container(
                width: double.infinity,
                padding: EdgeInsets.only(top: 30.h, bottom: AppSpacing.xxl.h),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      gold.withValues(alpha: 0.28),
                      gold.withValues(alpha: 0.04),
                    ],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 88.r,
                    height: 88.r,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [gold, gold.withValues(alpha: 0.7)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: gold.withValues(alpha: 0.45),
                          blurRadius: 22.r,
                          spreadRadius: 1.r,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.face_retouching_natural_rounded,
                      color: Colors.white,
                      size: 46.sp,
                    ),
                  ),
                ),
              ),
              // ── Body ─────────────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(24.w, 22.h, 24.w, 24.h),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add your photos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ext.greetingColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 20.sp,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'Add a few selfies so we can automatically find you in '
                      'event galleries and unlock the full Jperg experience.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: ext.searchHintColor,
                        fontSize: 13.5.sp,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: 18.h),
                    _faceBenefitRow(
                      ext,
                      Icons.auto_awesome_rounded,
                      'Get tagged in galleries automatically',
                    ),
                    SizedBox(height: 10.h),
                    _faceBenefitRow(
                      ext,
                      Icons.lock_rounded,
                      'Private & only used to recognise you',
                    ),
                    SizedBox(height: AppSpacing.xxl.h),
                    // ── Primary action ──────────────────────────────────────
                    AppButton(
                      fullWidth: true,
                      label: 'Add my photos',
                      onPressed: () {
                        Navigator.of(dialogCtx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const FaceRecognitionPage()),
                        );
                      },
                    ),
                    SizedBox(height: 6.h),
                    TextButton(
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      child: Text(
                        'Maybe later',
                        style: TextStyle(
                          color: ext.searchHintColor,
                          fontSize: 13.5.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A single "why add your face" perk row used inside [_showAddFacesDialog].
  Widget _faceBenefitRow(AppThemeExtension ext, IconData icon, String label) {
    final gold = ext.accentGold;
    return Row(
      children: [
        Container(
          width: 32.r,
          height: 32.r,
          decoration: BoxDecoration(
            color: gold.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: gold, size: 17.sp),
        ),
        SizedBox(width: AppSpacing.md.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: ext.greetingColor,
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  /// Reads the last-used tab from SharedPreferences and switches to it.
  /// Called once on first frame (web only). No-ops silently on any error.
  Future<void> _restoreWebTab() async {
    if (!mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getInt(_kWebTabKey) ?? 0;
      if (mounted && saved != _selectedTab) {
        _changeTab(saved);
      }
    } catch (_) {
      // SharedPreferences unavailable — stay on tab 0.
    }
  }

  @override
  void dispose() {
    HomePage.tabRequest.removeListener(_onTabRequest);
    HomePage.homeTapSignal.removeListener(_onHomeTap);
    super.dispose();
  }

  void _onTabRequest() {
    final idx = HomePage.tabRequest.value;
    if (idx != null) {
      _changeTab(idx);
      HomePage.tabRequest.value = null;
    }
  }

  // No longer used — nav visibility is driven by scroll direction only.
  void _onHomeTap() {}

  /// The Profile tab's index, and a handle on its state so it can be told to
  /// reload when the tab is opened.
  static const _profileTab = 3;
  final _profileKey = GlobalKey<UserProfilePageState>();

  void _changeTab(int index) {
    if (kIsWeb) {
      // Pop any sub-pages (SearchResults, EventPictures, AccountPage, etc.)
      // that were pushed on top of HomePage before switching tabs.
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name == HomePage.routeName || route.isFirst,
      );
      HomePage.webSelectedTab.value = index;
      // Persist for page-refresh recovery (fire-and-forget).
      SharedPreferences.getInstance()
          .then((p) => p.setInt(_kWebTabKey, index))
          .ignore();
    }
    VideoPauseNotifier.pauseAll();
    _downAccum = 0;

    // Nav bar always shows on a deliberate tab switch — it only hides again
    // in response to an actual downward scroll, never on a timer.
    setState(() {
      _selectedTab = index;
      _navBarVisible = true;
    });

    if (index == 1) {
      // Full reload so any newly created rooms appear immediately.
      context.read<ChatRoomsBloc>().add(const ChatRoomsLoadRequested());
    }

    if (index == _profileTab) {
      // Same reason as the chat reload above. The IndexedStack builds this page
      // once at start-up — before there is a token to load with, and long
      // before anything is liked or bookmarked — so opening the tab is what
      // makes it fetch.
      _profileKey.currentState?.refresh();
    }

    _loadedTabs.add(index);
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;

      if (delta > 0) {
        // Downward — accumulate and hide once past threshold.
        _downAccum += delta;
        if (_downAccum >= _hideThreshold && _navBarVisible) {
          setState(() => _navBarVisible = false);
        }
      } else if (delta < 0) {
        // Upward — always show nav (home tab included). No layout shift because
        // AnimatedSlide + extendBody means the body height never changes.
        _downAccum = 0;
        if (!_navBarVisible) {
          setState(() => _navBarVisible = true);
        }
      }
    } else if (notification is ScrollEndNotification) {
      // Scrolling stopped — nav stays exactly as it is (visible or hidden);
      // it never auto-hides on a timer once at rest.
      _downAccum = 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && isTablet(context)) {
      return _buildTabletLayout(context);
    }
    return _buildPhoneLayout(context);
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        extendBody: true,
        body: IndexedStack(
          index: _selectedTab,
          children: [
            const HomeNavigationPage(),
            const ChatRoomsPage(),
            const NotificationsPage(),
            UserProfilePage(key: _profileKey),
          ],
        ),
        bottomNavigationBar: kIsWeb ? null : AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: _navBarVisible ? Offset.zero : const Offset(0, 1),
          child: IgnorePointer(
            ignoring: !_navBarVisible,
            child: BlocSelector<ChatRoomsBloc, ChatRoomsState, int>(
              selector: (state) =>
                  state.unreadCounts.values.fold(0, (sum, c) => sum + c),
              builder: (context, totalUnread) => AppNavbar(
                selectedIndex: _selectedTab,
                onchange: _changeTab,
                messageUnreadCount: totalUnread,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletLayout(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Row(
        children: [
          BlocSelector<ChatRoomsBloc, ChatRoomsState, int>(
            selector: (state) =>
                state.unreadCounts.values.fold(0, (sum, c) => sum + c),
            builder: (context, totalUnread) => NavigationRail(
              backgroundColor: ext.cardSurface,
              selectedIndex: _selectedTab,
              onDestinationSelected: _changeTab,
              extended: MediaQuery.of(context).size.width >= 900,
              selectedIconTheme: IconThemeData(color: ext.accentGold),
              unselectedIconTheme: IconThemeData(color: ext.searchHintColor),
              selectedLabelTextStyle: TextStyle(color: ext.accentGold),
              unselectedLabelTextStyle: TextStyle(color: ext.searchHintColor),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded),
                  label: Text('Home'),
                ),
                NavigationRailDestination(
                  icon: Badge(
                    label: Text('$totalUnread'),
                    isLabelVisible: totalUnread > 0,
                    child: const Icon(Icons.chat_bubble_outline_rounded),
                  ),
                  selectedIcon: Badge(
                    label: Text('$totalUnread'),
                    isLabelVisible: totalUnread > 0,
                    child: const Icon(Icons.chat_bubble_rounded),
                  ),
                  label: const Text('Messages'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.notifications_none_rounded),
                  selectedIcon: Icon(Icons.notifications_rounded),
                  label: Text('Notifications'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.person_outline_rounded),
                  selectedIcon: Icon(Icons.person_rounded),
                  label: Text('Profile'),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                const HomeNavigationPage(),
                const ChatRoomsPage(),
                const NotificationsPage(),
                UserProfilePage(key: _profileKey),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

