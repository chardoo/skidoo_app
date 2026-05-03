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

class HomePage extends StatelessWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HomeBloc>()..add(const HomeInitialized())),
        BlocProvider(
            create: (_) =>
                sl<DiscoveryBloc>()..add(const DiscoveryLoadRequested())),
        BlocProvider(
            create: (_) => sl<GalleryBloc>()..add(const GalleryLoadRequested())),
        BlocProvider(
            create: (_) => sl<PhotographerBloc>()
              ..add(const PhotographersLoadRequested())),
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
  bool _navBarVisible = true;
  double _lastScrollOffset = 0;

  void _changeTab(int index) {
    setState(() {
      _selectedTab = index;
      _navBarVisible = true;
    });
    if (index == 1) {
      // Full reload so any newly created rooms appear immediately.
      context.read<ChatRoomsBloc>().add(const ChatRoomsLoadRequested());
    }
  }

  bool _onScrollNotification(ScrollNotification notification) {
    // Only auto-hide the nav bar on the home tab.
    if (_selectedTab != 0) return false;

    if (notification is ScrollUpdateNotification) {
      final current = notification.metrics.pixels;
      final delta = current - _lastScrollOffset;
      _lastScrollOffset = current;

      if (delta > 8 && _navBarVisible) {
        setState(() => _navBarVisible = false);
      } else if (delta < 0 && !_navBarVisible) {
        setState(() => _navBarVisible = true);
      }
    } else if (notification is ScrollEndNotification) {
      _lastScrollOffset = notification.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (isTablet(context)) {
      return _buildTabletLayout(context);
    }
    return _buildPhoneLayout(context);
  }

  Widget _buildPhoneLayout(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onScrollNotification,
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: IndexedStack(
          index: _selectedTab,
          children: const [
            HomeNavigationPage(),
            ChatRoomsPage(),
            GalleryPage(),
            PhotographersPage(),
          ],
        ),
        bottomNavigationBar: ClipRect(
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            heightFactor: _navBarVisible ? 1.0 : 0.0,
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
              extended: false,
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
                  icon: Icon(Icons.photo_library_outlined),
                  selectedIcon: Icon(Icons.photo_library_rounded),
                  label: Text('Gallery'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.camera_alt_outlined),
                  selectedIcon: Icon(Icons.camera_alt_rounded),
                  label: Text('Creators'),
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
