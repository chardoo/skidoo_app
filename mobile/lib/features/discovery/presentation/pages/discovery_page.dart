import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/utils/responsive.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
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
  final _feedFocusNode = FocusNode();
  // Guard: only one _updateActiveCard per frame, no matter how many
  // ScrollUpdateNotifications fire between frames.
  bool _activeCardUpdateScheduled = false;

  GlobalKey _keyFor(String id) =>
      _cardKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    if (kIsWeb) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _feedFocusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _activeCardIndex.dispose();
    _feedFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollCtrl.hasClients) return;
    final bloc = context.read<DiscoveryBloc>();
    if (!bloc.state.hasMore) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 400) {
      bloc.add(const DiscoveryLoadMoreRequested());
    }
  }

  /// Schedule exactly one active-card update per frame.
  void _scheduleActiveCardUpdate(List<EventDiscovery> events) {
    // On web, no videos autoplay so active-card tracking adds per-frame
    // O(n) localToGlobal work with zero benefit — skip entirely.
    if (kIsWeb) return;
    if (_activeCardUpdateScheduled) return;
    _activeCardUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _activeCardUpdateScheduled = false;
      _updateActiveCard(events);
    });
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

  // ── Keyboard navigation (web desktop/laptop only) ────────────────────────

  /// Scroll the card at [index] into view and update [_activeCardIndex].
  void _scrollToCard(String eventId, int index) {
    _activeCardIndex.value = index;
    final key = _cardKeys[eventId];
    final ctx = key?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.0, // align top of card with top of viewport
      );
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final events = context.read<DiscoveryBloc>().state.events;
    if (events.isEmpty) return KeyEventResult.ignored;
    final current = _activeCardIndex.value;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      final next = (current + 1).clamp(0, events.length - 1);
      if (next != current) _scrollToCard(events[next].id, next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      final prev = (current - 1).clamp(0, events.length - 1);
      if (prev != current) _scrollToCard(events[prev].id, prev);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.space) {
      if (current < events.length) _onCardTap(context, events[current]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onCardTap(BuildContext context, EventDiscovery event) {
    showLoginSheet(
      context,
      onLoginSuccess: () => Navigator.of(context)
          .pushNamedAndRemoveUntil(HomePage.routeName, (route) => false),
    );
  }

  void _onHide(String eventId) {
    // Capture the bloc before any async gap so the closure stays valid
    // even if the widget is later unmounted.
    final bloc = context.read<DiscoveryBloc>();

    // Mark card as pending-hide → collapses immediately via AnimatedAlign.
    bloc.add(DiscoveryEventHideRequested(eventId));

    AppSnackBar.withAction(
      context,
      AppLocalizations.of(context)!.discoveryContentHidden,
      actionLabel: AppLocalizations.of(context)!.discoveryUndo,
      onAction: () => bloc.add(const DiscoveryEventHideUndone()),
    ).then((reason) {
      // Snackbar dismissed without Undo → commit (remove from list + persist).
      if (reason != SnackBarClosedReason.action && !bloc.isClosed) {
        bloc.add(DiscoveryEventHideCommitted(eventId));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final ext = Theme.of(context).extension<AppThemeExtension>()!;

    final page = Scaffold(
      backgroundColor: ext.homeBackground,
      body: Focus(
        focusNode: _feedFocusNode,
        onKeyEvent: kIsWeb ? _handleKeyEvent : null,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // ── App bar — hidden on web (sidebar handles logo + auth) ────
            if (!kIsWeb) _FeedAppBar(ext: ext),

            // ── Feed ─────────────────────────────────────────────────────
            Expanded(
              child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
                // Exclude savedEventIds/savedItemRecordIds/hiddenEventIds —
                // they're handled by inner BlocBuilders inside each card,
                // so they must not trigger a full ListView rebuild mid-scroll.
                buildWhen: (prev, next) =>
                    prev.events != next.events ||
                    prev.isLoading != next.isLoading ||
                    prev.isLoadingMore != next.isLoadingMore ||
                    prev.errorMessage != next.errorMessage ||
                    prev.hasMore != next.hasMore ||
                    prev.pendingHideEventId != next.pendingHideEventId ||
                    prev.currentUserId != next.currentUserId,
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

                  final feed = NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification is ScrollUpdateNotification ||
                          notification is ScrollEndNotification) {
                        _scheduleActiveCardUpdate(state.events);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollCtrl,
                      physics: kIsWeb
                          ? const ClampingScrollPhysics()
                          : const BouncingScrollPhysics(
                              parent: AlwaysScrollableScrollPhysics(),
                            ),
                      cacheExtent: kIsWeb ? 2400 : 800,
                      // No padding — cards are edge-to-edge
                      padding: EdgeInsets.zero,
                      itemCount: state.events.length +
                          (state.isLoadingMore && state.hasMore ? 1 : 0),
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
                        return RepaintBoundary(
                          child: ClipRect(
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
                                  isAuthenticated: (state.currentUserId ?? '').isNotEmpty,
                                  onHide: () => _onHide(ev.id),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  );

                  if (!kIsWeb && isTablet(context)) {
                    return Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 680.w),
                        child: feed,
                      ),
                    );
                  }
                  return feed;
                },
              ),
            ),
          ],
        ),
      ),
    ),
    );
    return page;
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
          // Logo — Flexible so it can shrink on narrow viewports (e.g. web)
          Flexible(
            child: Row(
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
                Flexible(
                  child: Text(
                    'SKIDDO',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: ext.logoTextColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20.sp,
                      letterSpacing: 3,
                    ),
                  ),
                ),
              ],
            ),
          ), // Flexible

          // Right: sign-up + log-in CTAs
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(button: true, label: 'Sign up', child: GestureDetector(
                onTap: () => Navigator.of(context)
                    .pushNamed(SignUpPage.routeName),
                child: Text(
                  'Sign up',
                  style: TextStyle(
                    color: ext.searchHintColor,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
              SizedBox(width: 12.w),
              Semantics(button: true, label: 'Log in', child: GestureDetector(
                onTap: () => showLoginSheet(
                  context,
                  onLoginSuccess: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                          HomePage.routeName, (route) => false),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: ext.accentGold,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    'Log in',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              )),
            ],
          ),
        ],
      ),
    );
  }
}


