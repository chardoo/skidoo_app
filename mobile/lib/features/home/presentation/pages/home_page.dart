import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/responsive.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/pages/gallery_page.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographers_page.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/pages/chat_rooms_page.dart';
import 'package:skidoo_app/components/common/navbar.dart';
import 'package:skidoo_app/core/utils/video_pause_notifier.dart';
import 'package:skidoo_app/features/ads/presentation/widgets/create_bottom_sheet.dart';
import 'package:skidoo_app/features/admin/data/models/app_config.dart';
import 'package:skidoo_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';

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
        BlocProvider(create: (_) => sl<PhotographerBloc>()),
        BlocProvider(
            create: (_) => sl<UserProfileBloc>()
              ..add(const UserProfileLoadRequested())),
        BlocProvider.value(value: sl<CartBloc>()),
        BlocProvider(
          create: (_) =>
              sl<ChatRoomsBloc>()..add(const ChatRoomsLoadRequested()),
        ),
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
  int _selectedTab = 0;
  // Tab 0 starts with chrome hidden — shows only on deliberate tap.
  bool _navBarVisible = false;

  // Accumulates downward scroll px. Resets on any upward movement or tab
  // switch. The nav bar hides only after the user has scrolled down a clear,
  // intentional distance — avoids hiding on micro-bounces or tap-holds.
  double _downAccum = 0;
  static const _hideThreshold = 28.0;

  // Auto-hide timer for tab 0 chrome.
  Timer? _chromeTimer;

  // Tracks which tabs have been loaded so we only fire load events once.
  final _loadedTabs = <int>{0};

  @override
  void initState() {
    super.initState();
    HomePage.tabRequest.addListener(_onTabRequest);
    HomePage.homeTapSignal.addListener(_onHomeTap);
  }

  @override
  void dispose() {
    HomePage.tabRequest.removeListener(_onTabRequest);
    HomePage.homeTapSignal.removeListener(_onHomeTap);
    _chromeTimer?.cancel();
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

  void _changeTab(int index) {
    if (kIsWeb) {
      // Pop any sub-pages (SearchResults, EventPictures, AccountPage, etc.)
      // that were pushed on top of HomePage before switching tabs.
      Navigator.of(context).popUntil(
        (route) =>
            route.settings.name == HomePage.routeName || route.isFirst,
      );
      HomePage.webSelectedTab.value = index;
    }
    VideoPauseNotifier.pauseAll();
    _downAccum = 0;
    _chromeTimer?.cancel();

    if (index == 0) {
      // Home tab: show chrome briefly for orientation, then auto-hide.
      setState(() {
        _selectedTab = index;
        _navBarVisible = true;
      });
      _startAutoHideTimer();
    } else {
      // All other tabs: chrome always visible, no timer.
      setState(() {
        _selectedTab = index;
        _navBarVisible = true;
      });
    }

    if (index == 1) {
      // Full reload so any newly created rooms appear immediately.
      context.read<ChatRoomsBloc>().add(const ChatRoomsLoadRequested());
    }

    // Lazy-load heavy tabs on first visit so they don't block startup.
    if (!_loadedTabs.contains(index)) {
      _loadedTabs.add(index);
      if (index == 2) {
        context.read<GalleryBloc>().add(const GalleryLoadRequested());
      } else if (index == 3) {
        context.read<PhotographerBloc>().add(const PhotographersLoadRequested());
      }
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;

      if (delta > 0) {
        // Downward — accumulate and hide once past threshold.
        _downAccum += delta;
        if (_downAccum >= _hideThreshold && _navBarVisible) {
          setState(() => _navBarVisible = false);
          _chromeTimer?.cancel();
        }
      } else if (delta < 0) {
        // Upward — always show nav (home tab included). No layout shift because
        // AnimatedSlide + extendBody means the body height never changes.
        _downAccum = 0;
        if (!_navBarVisible) {
          setState(() => _navBarVisible = true);
          if (_selectedTab == 0) _startAutoHideTimer();
        }
      }
    } else if (notification is ScrollEndNotification) {
      _downAccum = 0;
      // Home tab: (re)start auto-hide once the fling settles.
      if (_selectedTab == 0 && _navBarVisible) _startAutoHideTimer();
    }
    return false;
  }

  void _startAutoHideTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _selectedTab == 0) setState(() => _navBarVisible = false);
    });
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
          children: const [
            HomeNavigationPage(),
            if (kIsWeb) _WebMessagesDisabled() else ChatRoomsPage(),
            GalleryPage(),
            PhotographersPage(),
          ],
        ),
        bottomNavigationBar: kIsWeb ? null : AnimatedSlide(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          offset: _navBarVisible ? Offset.zero : const Offset(0, 1),
          child: IgnorePointer(
            ignoring: !_navBarVisible,
            child: ValueListenableBuilder<AppConfig>(
              valueListenable: AppConfigRepository.notifier,
              builder: (context, cfg, _) =>
                  BlocSelector<ChatRoomsBloc, ChatRoomsState, int>(
                selector: (state) =>
                    state.unreadCounts.values.fold(0, (sum, c) => sum + c),
                builder: (context, totalUnread) => AppNavbar(
                  selectedIndex: _selectedTab,
                  onchange: _changeTab,
                  onCreateTap: () => CreateBottomSheet.show(context),
                  messageUnreadCount: totalUnread,
                  showCreate: cfg.adsEnabled || cfg.requestsEnabled,
                ),
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
                NavigationRailDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home_rounded),
                  label: Text(AppLocalizations.of(context)!.navHome),
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
                  label: Text(AppLocalizations.of(context)!.navMessages),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.photo_library_outlined),
                  selectedIcon: const Icon(Icons.photo_library_rounded),
                  label: Text(AppLocalizations.of(context)!.navGallery),
                ),
                NavigationRailDestination(
                  icon: const Icon(Icons.camera_alt_outlined),
                  selectedIcon: const Icon(Icons.camera_alt_rounded),
                  label: Text(AppLocalizations.of(context)!.navCreators),
                ),
              ],
            ),
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: const [
                HomeNavigationPage(),
                ChatRoomsPage(),
                GalleryPage(),
                PhotographersPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Web: Messages unavailable placeholder ─────────────────────────────────────

class _WebMessagesDisabled extends StatelessWidget {
  const _WebMessagesDisabled();

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.phone_iphone_rounded,
                  size: 56,
                  color: ext.searchHintColor.withValues(alpha: 0.4),
                ),
                const SizedBox(height: 20),
                Text(
                  'Messages are available on the app',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Download the SKIDDO app to send and receive messages.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: ext.searchHintColor.withValues(alpha: 0.55),
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
