import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class HomeNavigationPage extends StatefulWidget {
  const HomeNavigationPage({super.key});

  @override
  State<HomeNavigationPage> createState() => _HomeNavigationPageState();
}

class _HomeNavigationPageState extends State<HomeNavigationPage> {
  bool _isSearchOpen = false;

  void _openSearch() => setState(() => _isSearchOpen = true);

  void _closeSearch() {
    setState(() => _isSearchOpen = false);
    context.read<HomeBloc>().add(const HomeSearchClosed());
  }

  void _onSearchChanged(String query) {
    context.read<HomeBloc>().add(HomeEventSearched(query));
  }

  void _openEventImages(BuildContext context, EventDiscovery event) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventPicturesPage(event: event),
      ),
    );
  }

  void _openEventComments(BuildContext context, EventDiscovery event) {
    EventCommentPage.show(context, event);
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;
    final homeState = context.watch<HomeBloc>().state;
    final discoveryState = context.watch<DiscoveryBloc>().state;
    final userState = context.watch<UserProfileBloc>().state;
    final userName = userState.name.isNotEmpty ? userState.name : 'User';

    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: SafeArea(
              bottom: false,
              child: HomeHeaderWidget(
                userName: userName,
                userInitial: userName[0].toUpperCase(),
                isSearchOpen: _isSearchOpen,
                onSearchOpen: _openSearch,
                onSearchClose: _closeSearch,
                onSearchChanged: _onSearchChanged,
                onAvatarTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AccountPage()),
                ),
              ),
            ),
          ),
        ],
        body: _buildBody(context, ext, homeState, discoveryState),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppThemeExtension ext,
    HomeState homeState,
    DiscoveryState discoveryState,
  ) {
    // ── Search mode ─────────────────────────────────────────────────────────
    if (_isSearchOpen && homeState.isLoadingEvents) {
      return const CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppLoadingIndicator(),
        ),
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
            message: 'No events found',
          ),
        ),
      ]);
    }

    // ── Normal mode ──────────────────────────────────────────────────────────
    if (discoveryState.isLoading) {
      return const CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: AppLoadingIndicator(),
        ),
      ]);
    }

    if (discoveryState.events.isEmpty) {
      return CustomScrollView(slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: HomeEmptyState(
            ext: ext,
            icon: Icons.photo_library_outlined,
            message: 'No events yet',
          ),
        ),
      ]);
    }

    return EventsFeed(
      discoveryState: discoveryState,
      onCardTap: (event) => _openEventImages(context, event),
      onCommentTap: (event) => _openEventComments(context, event),
      onLoadMore: () => context
          .read<DiscoveryBloc>()
          .add(const DiscoveryLoadMoreRequested()),
    );
  }
}

