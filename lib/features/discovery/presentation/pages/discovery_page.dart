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
  final _activeCardIndex = ValueNotifier<int>(0);
  final _cardKeys = <String, GlobalKey>{};

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _activeCardIndex.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      context.read<DiscoveryBloc>().add(const DiscoveryLoadMoreRequested());
    }
  }

  /// Mark the card whose centre is closest to the viewport centre as active.
  void _updateActiveCard(List<EventDiscovery> events) {
    if (!mounted) return;
    final screenH = MediaQuery.sizeOf(context).height;
    final viewportMid = screenH / 2;

    int? bestIdx;
    double bestDist = double.infinity;

    for (int i = 0; i < events.length; i++) {
      final key = _cardKeys[events[i].id];
      if (key == null) continue;
      final ctx = key.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      final cardCenter = pos.dy + box.size.height / 2;
      final dist = (cardCenter - viewportMid).abs();
      if (dist < bestDist) {
        bestDist = dist;
        bestIdx = i;
      }
    }

    if (bestIdx != null && bestIdx != _activeCardIndex.value) {
      _activeCardIndex.value = bestIdx;
    }
  }

  void _onCardTap(BuildContext context, EventDiscovery event) {
    showLoginSheet(
      context,
      onLoginSuccess: () =>
          Navigator.of(context).pushReplacementNamed(HomePage.routeName),
    );
  }

  void _onHide(String eventId) {
    // Capture the bloc before any async gap so the closure stays valid
    // even if the widget is later unmounted.
    final bloc = context.read<DiscoveryBloc>();

    // Mark card as pending-hide → collapses immediately via AnimatedAlign.
    bloc.add(DiscoveryEventHideRequested(eventId));

    // Dismiss any in-flight snackbar so only one undo prompt shows at a time.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            backgroundColor: const Color(0xFF2C2C2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: const Text(
              'Content hidden',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
            action: SnackBarAction(
              label: 'Undo',
              textColor: const Color(0xFFF5A623),
              onPressed: () => bloc.add(const DiscoveryEventHideUndone()),
            ),
          ),
        )
        .closed
        .then((reason) {
      // Snackbar dismissed without Undo → commit (remove from list + persist).
      if (reason != SnackBarClosedReason.action && !bloc.isClosed) {
        bloc.add(DiscoveryEventHideCommitted(eventId));
      }
    });
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

                  return NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification ||
                          notification is ScrollEndNotification) {
                        WidgetsBinding.instance.addPostFrameCallback(
                            (_) => _updateActiveCard(state.events));
                      }
                      return false;
                    },
                    child: ListView.builder(
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
                        final isPending = state.pendingHideEventId == ev.id;
                        // AnimatedAlign + heightFactor is the most reliable
                        // way to collapse a ListView item smoothly. The card
                        // stays in the tree (no child-swap reconciliation
                        // issues); only the rendered height animates to 0.
                        return ClipRect(
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 380),
                            curve: Curves.easeInOut,
                            alignment: Alignment.topCenter,
                            heightFactor: isPending ? 0.0 : 1.0,
                            child: IgnorePointer(
                              ignoring: isPending,
                              child: EventDiscoveryCard(
                                key: _keyFor(ev.id),
                                event: ev,
                                cardIndex: index,
                                activeCardIndex: _activeCardIndex,
                                onTap: () => _onCardTap(context, ev),
                                isOwner: state.currentUserId != null &&
                                    state.currentUserId == ev.photographerId,
                                onHide: () => _onHide(ev.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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

