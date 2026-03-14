import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/bloc/gallery_bloc.dart';
import 'package:skidoo_app/features/gallery/presentation/pages/gallery_page.dart';
import 'package:skidoo_app/features/home/presentation/bloc/home_bloc.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:skidoo_app/features/photographers/presentation/bloc/photographer_bloc.dart';
import 'package:skidoo_app/features/photographers/presentation/pages/photographers_page.dart';
import 'package:skidoo_app/features/user_profile/presentation/bloc/user_profile_bloc.dart';
import 'package:skidoo_app/components/common/navbar.dart';

class HomePage extends StatefulWidget {
  static const routeName = '/home';
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;

  void _changeTab(int index) {
    setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<HomeBloc>()..add(const HomeInitialized())),
        BlocProvider(
            create: (_) => sl<GalleryBloc>()..add(const GalleryLoadRequested())),
        BlocProvider(
            create: (_) => sl<PhotographerBloc>()
              ..add(const PhotographersLoadRequested())),
        BlocProvider(
            create: (_) => sl<UserProfileBloc>()
              ..add(const UserProfileLoadRequested())),
        BlocProvider.value(value: sl<CartBloc>()),
      ],
      child: _HomeView(
        selectedTab: _selectedTab,
        onTabChanged: _changeTab,
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  final int selectedTab;
  final ValueChanged<int> onTabChanged;

  const _HomeView({
    required this.selectedTab,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pages = [
      const HomeNavigationPage(),
      const GalleryPage(),
      const PhotographersPage(),
    ];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: pages[selectedTab],
      bottomNavigationBar: AppNavbar(
        selectedIndex: selectedTab,
        onchange: onTabChanged,
      ),
    );
  }
}
