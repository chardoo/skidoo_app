import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/utils/focus_utils.dart';
import 'package:jperg_app/core/utils/snackbar_utils.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/full_bleed_event_card.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/models/event_discovery/event_discovery.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/utils/video_pause_notifier.dart';
import 'package:jperg_app/features/gallery/presentation/found/found_access.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/face_gate_prompt.dart';
import 'package:jperg_app/features/home/presentation/pages/search_results_page.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/swipe_up_hint.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/features/home/presentation/pages/home_navigation_page.dart';

class DiscoveryPage extends StatelessWidget {
  static const routeName = '/discovery';
  const DiscoveryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<DiscoveryBloc>()..add(const DiscoveryLoadRequested()),
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

  /// 0 = Found, 1 = Explore. Guests land on Explore — Found has nothing to
  /// show until they have an account and a face on file, so opening there
  /// would greet a first-time visitor with a gate instead of the feed.
  int _selectedTab = 1;

  static const _tabs = ['Found', 'Explore'];

  void _selectTab(int index) {
    if (index == _selectedTab) return;
    // The Explore feed autoplays video; leaving it running behind the Found
    // tab would play audio over a screen that shows no video at all.
    VideoPauseNotifier.pauseAll();
    setState(() => _selectedTab = index);
  }

  /// Leaves the guest shell once an account exists.
  ///
  /// This page is guest-only: its Found tab always renders the *signed-out*
  /// gate, sign-in link and all. Simply rebuilding after sign-up would leave a
  /// now-authenticated user staring at "Already have an account? Sign in" —
  /// the `_GuestGuard` redirect that would otherwise catch this is web-only,
  /// so on mobile nothing moves them off the page.
  ///
  /// Handing them to /home also puts them on the real Found tab, which asks
  /// for a face (and only a face) if they still have none.
  void _onGateResolved() {
    if (!mounted) return;
    HomeNavigationPage.pillTabRequest.value = 0;
    Navigator.of(context)
        .pushNamedAndRemoveUntil(HomePage.routeName, (route) => false);
  }

  /// Whether to show the swipe-up hint over the first card. Starts false so a
  /// returning visitor never sees it flash before the stored flag resolves.
  bool _showSwipeHint = false;

  Future<void> _resolveSwipeHint() async {
    if (await sl<AuthService>().getHasSeenSwipeHint()) return;
    if (mounted) setState(() => _showSwipeHint = true);
  }

  /// Retires the hint the moment the gesture is performed — and remembers it,
  /// so it teaches once rather than nagging on every cold start.
  void _dismissSwipeHint() {
    if (!_showSwipeHint) return;
    setState(() => _showSwipeHint = false);
    sl<AuthService>().setHasSeenSwipeHint();
  }

  @override
  void initState() {
    super.initState();
    _resolveSwipeHint();
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
    // They've found the gesture — the hint has done its job.
    _dismissSwipeHint();
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
            // ── Found — the face gate. Guests have no account and therefore
            // no face on file, so this is always the signed-out variant; the
            // signed-in "no face yet" case lives on the authenticated feed.
            if (_selectedTab == 0)
              Positioned.fill(
                child: ColoredBox(
                  color: ext.homeBackground,
                  child: SafeArea(
                    child: Padding(
                      // Clears the floating tab bar above it.
                      padding: EdgeInsets.only(top: 56.h),
                      child: FaceGatePrompt(
                        reason: FaceGateReason.signedOut,
                        onPrimaryAction: () => promptSignUp(
                          context,
                          onAuthenticated: _onGateResolved,
                        ),
                        onSignIn: () => openSignIn(
                          context,
                          onAuthenticated: _onGateResolved,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

            // ── Explore — fills the entire screen; the app bar floats on top,
            // matching the logged-in Home feed (no solid bar pushing it down).
            if (_selectedTab == 1)
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

            // ── Swipe-up hint — first card only, first session only. Sits
            // above the feed but below the tab bar, and ignores pointers so
            // it never eats the swipe it asks for.
            if (_selectedTab == 1 && _showSwipeHint)
              Positioned(
                left: 0,
                right: 0,
                // Clear of the card's title/photographer cluster, which the
                // design puts just below it.
                bottom: 24.h,
                child: const Center(child: SwipeUpHint(label: '')),
              ),

            // ── Tab bar — floats on top; hidden on web (sidebar handles
            // logo + auth) ──────────────────────────────────────────────
            if (!kIsWeb)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: _GuestTabBar(
                    ext: ext,
                    tabs: _tabs,
                    selected: _selectedTab,
                    onTabChanged: _selectTab,
                    // Found sits on the page background rather than over the
                    // feed's media, so its labels need the theme's colours —
                    // white would vanish in light mode.
                    onSolid: _selectedTab == 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    return page;
  }
}

// ── Guest tab bar ────────────────────────────────────────────────────────────

/// The guest feed's top bar: centred Found / Explore tabs with a search icon,
/// per the guest designs.
///
/// This replaces the old logo + "Sign up / Log in" bar. Those CTAs moved into
/// the Found tab, which asks for an account in context ("Add my face", plus an
/// "Already have an account? Sign in" line) rather than as permanent chrome
/// over the feed.
///
/// It mirrors the signed-in [FeedTopBar] deliberately — same 15sp labels, same
/// 16dp underline, same 18dp gap — so switching from guest to member doesn't
/// visibly move the header.
class _GuestTabBar extends StatelessWidget {
  const _GuestTabBar({
    required this.ext,
    required this.tabs,
    required this.selected,
    required this.onTabChanged,
    required this.onSolid,
  });

  final AppThemeExtension ext;
  final List<String> tabs;
  final int selected;
  final ValueChanged<int> onTabChanged;

  /// True when the bar sits on the page background (the Found tab) rather than
  /// over the feed's full-bleed media.
  final bool onSolid;

  static const _shadows = [Shadow(blurRadius: 10, color: Colors.black87)];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: AppSpacing.lg.w, vertical: 10.h),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < tabs.length; i++) ...[
                if (i > 0) SizedBox(width: 18.w),
                _GuestTab(
                  label: tabs[i],
                  active: selected == i,
                  ext: ext,
                  onSolid: onSolid,
                  onTap: () => onTabChanged(i),
                ),
              ],
            ],
          ),
          Positioned(
            right: 0,
            child: Semantics(
              button: true,
              label: 'Search',
              child: GestureDetector(
                onTap: () => Navigator.of(context)
                    .pushNamed(SearchResultsPage.routeName),
                child: Icon(
                  Icons.search_rounded,
                  color: onSolid ? ext.greetingColor : Colors.white,
                  size: 24.sp,
                  shadows: onSolid ? null : _shadows,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestTab extends StatelessWidget {
  const _GuestTab({
    required this.label,
    required this.active,
    required this.ext,
    required this.onSolid,
    required this.onTap,
  });

  final String label;
  final bool active;
  final AppThemeExtension ext;
  final bool onSolid;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = onSolid
        ? (active ? ext.greetingColor : ext.searchHintColor)
        : (active ? Colors.white : Colors.white60);

    return Semantics(
      button: true,
      selected: active,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: foreground,
                fontSize: 15.sp,
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                shadows: onSolid ? null : _GuestTabBar._shadows,
              ),
            ),
            SizedBox(height: AppSpacing.xs.h),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: active ? 16.w : 0,
              height: 2,
              decoration: BoxDecoration(
                color: onSolid ? ext.greetingColor : Colors.white,
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
