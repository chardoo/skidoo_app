import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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

// ── Stateful view — owns ScrollController + auto-scroll timer ─────────────────

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
    if (pos.pixels >= pos.maxScrollExtent - 300) {
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
            _DiscoveryHeader(ext: ext),
            Expanded(
              child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                builder: (context, state) {
                  if (state.isLoading) {
                    return Center(
                      child: CircularProgressIndicator(
                          color: ext.accentGold, strokeWidth: 2),
                    );
                  }

                  if (state.errorMessage != null && state.events.isEmpty) {
                    return _ErrorView(
                      ext: ext,
                      message: state.errorMessage!,
                      onRetry: () => context
                          .read<DiscoveryBloc>()
                          .add(const DiscoveryLoadRequested()),
                    );
                  }

                  if (state.events.isEmpty) {
                    return Center(
                      child: Text(
                        'No events yet',
                        style: TextStyle(
                            color: ext.searchHintColor, fontSize: 15.sp),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollCtrl,
                    physics: const BouncingScrollPhysics(),
                    itemCount:
                        state.events.length + (state.isLoadingMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.events.length) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 20.h),
                          child: Center(
                            child: CircularProgressIndicator(
                                color: ext.accentGold, strokeWidth: 2),
                          ),
                        );
                      }
                      return EventDiscoveryCard(
                        event: state.events[index],
                        onTap: () =>
                            _onCardTap(context, state.events[index]),
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

// ── Header ────────────────────────────────────────────────────────────────────

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader({required this.ext});
  final AppThemeExtension ext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 30.w,
            height: 30.h,
            decoration: BoxDecoration(
              color: ext.logoBadgeBackground,
              borderRadius: BorderRadius.circular(7.r),
            ),
            alignment: Alignment.center,
            child: Text(
              'S',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 17.sp,
              ),
            ),
          ),
          SizedBox(width: 8.w),
          Text(
            'SKIDDO',
            style: TextStyle(
              color: ext.logoTextColor,
              fontWeight: FontWeight.bold,
              fontSize: 20.sp,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Error view ────────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView(
      {required this.ext, required this.message, required this.onRetry});
  final AppThemeExtension ext;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 56.sp, color: ext.searchHintColor),
          SizedBox(height: 12.h),
          Text(message,
              style: TextStyle(color: ext.searchHintColor, fontSize: 14.sp),
              textAlign: TextAlign.center),
          SizedBox(height: 16.h),
          TextButton(
            onPressed: onRetry,
            child: Text('Retry',
                style: TextStyle(color: ext.accentGold, fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }
}
