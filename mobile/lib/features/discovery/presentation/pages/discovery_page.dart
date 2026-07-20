import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/common/widgets/app_widgets.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/utils/focus_utils.dart';
import 'package:skidoo_app/core/utils/snackbar_utils.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/models/event_discovery/event_discovery.dart';
import 'package:skidoo_app/core/theme/app_radius.dart';
import 'package:skidoo_app/core/theme/app_spacing.dart';

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
  final _pageCtrl = PageController();
  final _activeCardIndex = ValueNotifier<int>(0);
  final _feedFocusNode = FocusNode();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // NOTE: deliberately NOT auto-focusing the feed on web — grabbing focus on
    // load captured the browser's input focus and blocked the sidebar search
    // field (above the Navigator) from receiving keystrokes. The j/k/space
    // shortcuts still work once the user clicks/scrolls the feed.
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _activeCardIndex.dispose();
    _feedFocusNode.dispose();
    super.dispose();
  }

  void _onPageChanged(List<EventDiscovery> events, int index) {
    _currentPage = index;
    _activeCardIndex.value = index;
    if (index >= events.length - 3) {
      final bloc = context.read<DiscoveryBloc>();
      if (bloc.state.hasMore && !bloc.state.isLoadingMore) {
        bloc.add(const DiscoveryLoadMoreRequested());
      }
    }
  }

  // ── Keyboard navigation (web desktop/laptop only) ────────────────────────

  void _goToPage(int index) {
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    // Don't hijack keys while the user is typing in a text field (e.g. the
    // comment box): space, j and k must reach the field, not scroll the feed
    // or open the event.
    if (isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    final events = context.read<DiscoveryBloc>().state.events;
    if (events.isEmpty) return KeyEventResult.ignored;
    final current = _currentPage;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown ||
        event.logicalKey == LogicalKeyboardKey.keyJ) {
      final next = (current + 1).clamp(0, events.length - 1);
      if (next != current) _goToPage(next);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp ||
        event.logicalKey == LogicalKeyboardKey.keyK) {
      final prev = (current - 1).clamp(0, events.length - 1);
      if (prev != current) _goToPage(prev);
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
        child: Stack(
          children: [
            // ── Feed — fills the entire screen; the app bar floats on top,
            // matching the logged-in Home feed (no solid bar pushing it down).
            Positioned.fill(
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

                  // Same full-bleed TikTok-style vertical PageView the
                  // logged-in Home feed uses — FullBleedEventCard runs in
                  // guest mode here (isAuthenticated: false), so every
                  // reaction prompts login via onTap instead of acting.
                  return PageView.builder(
                    controller: _pageCtrl,
                    scrollDirection: Axis.vertical,
                    itemCount: state.events.length,
                    onPageChanged: (i) => _onPageChanged(state.events, i),
                    itemBuilder: (context, index) {
                      final ev = state.events[index];
                      return FullBleedEventCard(
                        key: ValueKey('discovery_${ev.id}'),
                        event: ev,
                        cardIndex: index,
                        activeCardIndex: _activeCardIndex,
                        onTap: () => _onCardTap(context, ev),
                        onHide: () => _onHide(ev.id),
                        isAuthenticated: false,
                      );
                    },
                  );
                },
              ),
            ),

            // ── App bar — floats on top; hidden on web (sidebar handles
            // logo + auth) ──────────────────────────────────────────────
            if (!kIsWeb)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(bottom: false, child: _FeedAppBar(ext: ext)),
              ),
          ],
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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 10.h),
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
                        ext.accentGoldDark,
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
                SizedBox(width: AppSpacing.sm.w),
                Flexible(
                  child: Text(
                    'JPERG',
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(
                      color: Colors.white,
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
                    color: Colors.white70,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )),
              SizedBox(width: AppSpacing.md.w),
              Semantics(button: true, label: 'Log in', child: GestureDetector(
                onTap: () => showLoginSheet(
                  context,
                  onLoginSuccess: () => Navigator.of(context)
                      .pushNamedAndRemoveUntil(
                          HomePage.routeName, (route) => false),
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg.w, vertical: AppSpacing.sm.h),
                  decoration: BoxDecoration(
                    color: ext.accentGold,
                    borderRadius: BorderRadius.circular(AppRadius.xl.r),
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


