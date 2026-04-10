import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/event_discovery_card.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';

class DiscoveryPage extends StatelessWidget {
  static const routeName = '/discovery';
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          sl<DiscoveryBloc>()..add(const DiscoveryLoadRequested()),
      child: const _DiscoveryView(),
    );
  }
}

// ── Stateful view ─────────────────────────────────────────────────────────────

class _DiscoveryView extends StatefulWidget {
  const _DiscoveryView();

  @override
  State<_DiscoveryView> createState() => _DiscoveryViewState();
}

class _DiscoveryViewState extends State<_DiscoveryView> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      context.read<DiscoveryBloc>().add(const DiscoveryLoadMoreRequested());
    }
  }

  void _onCardTap(BuildContext context, EventDiscovery event) {
    showLoginSheet(
      context,
      onLoginSuccess: () =>
          Navigator.of(context).pushReplacementNamed(HomePage.routeName),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    return Scaffold(
      backgroundColor: ext.homeBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── App bar ──────────────────────────────────────────────────
            _FeedAppBar(ext: ext),

            // ── Feed ─────────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                builder: (context, state) {
                  if (state.isLoading) return const AppLoadingIndicator();

                  if (state.errorMessage != null && state.events.isEmpty) {
                    return AppErrorView(
                      message: state.errorMessage!,
                      icon: Icons.cloud_off_outlined,
                      onRetry: () => context
                          .read<DiscoveryBloc>()
                          .add(const DiscoveryLoadRequested()),
                    );
                  }

                  if (state.events.isEmpty) {
                    return const AppEmptyState(
                      icon: Icons.photo_library_outlined,
                      message: 'No events yet',
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    // No padding — cards are edge-to-edge
                    padding: EdgeInsets.zero,
                    itemCount:
                        state.events.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.events.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.h),
                          child: const AppLoadingIndicator(),
                        );
                      }
                      final ev = state.events[index];
                      return EventDiscoveryCard(
                        event: ev,
                        onTap: () => _onCardTap(context, ev),
                        isOwner: state.currentUserId != null &&
                            state.currentUserId == ev.photographerId,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed app bar ──────────────────────────────────────────────────────────────

class _FeedAppBar extends StatelessWidget {
  const _FeedAppBar({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: ext.homeBackground,
        border: Border(
          bottom: BorderSide(
            color: ext.searchHintColor.withValues(alpha: 0.08),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28.w,
                height: 28.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      ext.accentGold,
                      const Color(0xFFFF6B35),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(7.r),
                ),
                alignment: Alignment.center,
                child: Text(
                  'S',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16.sp,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                'SKIDDO',
                style: TextStyle(
                  color: ext.logoTextColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 20.sp,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),

          // Right actions
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _AppBarIcon(
                icon: Icons.search_rounded,
                ext: ext,
                onTap: () {},
              ),
              SizedBox(width: 4.w),
              _AppBarIcon(
                icon: Icons.notifications_none_rounded,
                ext: ext,
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppBarIcon extends StatelessWidget {
  const _AppBarIcon({
    required this.icon,
    required this.ext,
    required this.onTap,
  });
  final IconData icon;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36.w,
        height: 36.h,
        decoration: BoxDecoration(
          color: ext.searchFieldFill,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: ext.greetingColor, size: 20.sp),
      ),
    );
  }
}

