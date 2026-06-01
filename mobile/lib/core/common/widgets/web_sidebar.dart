import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/navigation/app_navigator.dart';
import 'package:skidoo_app/core/navigation/web_route_observer.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:skidoo_app/features/chat/presentation/widgets/web_messages_panel.dart';
import 'package:skidoo_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_navigation_page.dart';
import 'package:skidoo_app/features/user_profile/presentation/pages/account_page.dart';
import 'package:skidoo_app/services/auth_service.dart';

const double _kSidebarWidth = 240.0;
const String _kCreatorUrl = 'https://picco-v2.onrender.com/';

// Viewport width below which the desktop sidebar won't fit. Matches app.dart.
// (Kept private — app.dart inlines its own copy of the same value.)

/// Persistent left-side navigation panel shown only on web.
class WebSidebar extends StatelessWidget {
  const WebSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        WebRouteObserver.currentRouteName,
        HomePage.webSelectedTab,
        AuthService.isAuthenticated,
      ]),
      builder: (context, _) {
        final selectedTab = HomePage.webSelectedTab.value;
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        final isLoggedIn = AuthService.isAuthenticated.value;
        // Logged-in users always see their full nav (Home/Gallery/Photographers/
        // Search) regardless of the current route. This prevents a race between
        // the _GuestGuard redirect and the sidebar render on hard refresh where
        // the route observer briefly shows /discovery while the user is already
        // authenticated. The sidebar width (240px) is unchanged in both states
        // so the content column and card layouts are not affected.
        return _SidebarShell(
          ext: ext,
          child: isLoggedIn
              ? _LoggedInNav(ext: ext, selectedTab: selectedTab)
              : _DiscoveryModeNav(ext: ext, isLoggedIn: isLoggedIn),
        );
      },
    );
  }
}

// ── Shell ─────────────────────────────────────────────────────────────────────

class _SidebarShell extends StatelessWidget {
  const _SidebarShell({required this.ext, required this.child});
  final AppThemeExtension ext;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // The sidebar lives in MaterialApp.builder — above the Navigator — so
    // it has no Overlay ancestor. We provide Material + a local Overlay so
    // TextField (selection handles) and any other overlay-dependent widgets
    // work correctly. The typeahead dropdown intentionally bypasses this
    // local overlay and inserts into AppNavigator's overlay so it appears
    // above all page content.
    return Material(
      color: ext.homeBackground,
      child: SizedBox(
        width: _kSidebarWidth,
        height: double.infinity,
        child: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (_) => DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: ext.searchHintColor.withValues(alpha: 0.10),
                      width: 0.5,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Logo ────────────────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [ext.accentGold, const Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              alignment: Alignment.center,
                              child: const Text(
                                'S',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'SKIDDO',
                              style: TextStyle(
                                color: ext.logoTextColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                letterSpacing: 3,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Expanded(child: child),

                      // ── Footer ──────────────────────────────────────────
                      _SidebarFooter(ext: ext),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sidebar search field ──────────────────────────────────────────────────────

/// Compact search field at the top of the logged-in sidebar.
///
/// Implements a typeahead dropdown that overlays the nav items below:
///   • Results appear from the 2nd character onwards (no Enter needed).
///   • The dropdown is an [OverlayEntry] anchored via [CompositedTransformFollower]
///     so it sits directly below the field and floats over the nav items.
///   • Selecting an event dispatches [HomeNavigationPage.dispatchEventTap],
///     which opens the inline photo panel in the content area.
class _SidebarSearchField extends StatefulWidget {
  const _SidebarSearchField({required this.ext});
  final AppThemeExtension ext;

  @override
  State<_SidebarSearchField> createState() => _SidebarSearchFieldState();
}

class _SidebarSearchFieldState extends State<_SidebarSearchField> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    HomeNavigationPage.webEventResults.addListener(_onResultsChanged);
    _focus.addListener(_onFocusChanged);
    _ctrl.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    HomeNavigationPage.webEventResults.removeListener(_onResultsChanged);
    _focus.removeListener(_onFocusChanged);
    _ctrl.removeListener(_onControllerChanged);
    _removeOverlay();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── Event handlers ──────────────────────────────────────────────────────────

  void _onResultsChanged() => _syncOverlay();

  void _onControllerChanged() {
    // Trigger rebuild so the clear-X button appears/disappears.
    if (mounted) setState(() {});
  }

  void _onFocusChanged() {
    if (!_focus.hasFocus) {
      // Delay removal so that a tap on a dropdown item fires before it disappears.
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted && !_focus.hasFocus) _removeOverlay();
      });
    } else {
      _syncOverlay();
    }
  }

  void _onChanged(String value) {
    final q = value.trim();
    if (q.length < 2) {
      // Query too short — clear results and hide dropdown.
      if (HomeNavigationPage.webEventResults.value.isNotEmpty) {
        HomeNavigationPage.webEventResults.value = [];
      }
      _removeOverlay();
      return;
    }
    HomeNavigationPage.dispatchSearch(q);
  }

  void _clearSearch() {
    _ctrl.clear();
    HomeNavigationPage.webEventResults.value = [];
    _removeOverlay();
  }

  void _onEventSelected(String eventId, String eventName) {
    _ctrl.clear();
    HomeNavigationPage.webEventResults.value = [];
    _removeOverlay();
    HomeNavigationPage.dispatchEventTap(eventId, eventName);
  }

  // ── Overlay management ──────────────────────────────────────────────────────

  void _syncOverlay() {
    final results = HomeNavigationPage.webEventResults.value;
    final q = _ctrl.text.trim();
    if (results.isNotEmpty && q.length >= 2 && _focus.hasFocus) {
      _showOverlay(results);
    } else {
      _removeOverlay();
    }
  }

  void _showOverlay(List<dynamic> results) {
    _removeOverlay();
    if (!mounted) return;

    // The sidebar lives in MaterialApp.builder — above the Navigator — so
    // Overlay.of(context) finds nothing. Use the Navigator's own overlay via
    // the global key instead.
    final overlay = AppNavigator.navigatorKey.currentState?.overlay;
    if (overlay == null) return;

    _overlayEntry = OverlayEntry(
      builder: (_) => _SidebarTypeaheadDropdown(
        layerLink: _layerLink,
        ext: widget.ext,
        onSelect: _onEventSelected,
      ),
    );
    overlay.insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hasText = _ctrl.text.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
      child: CompositedTransformTarget(
        link: _layerLink,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: widget.ext.glassFill,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: widget.ext.glassBorder, width: 1.0),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Icon(Icons.search_rounded, color: widget.ext.glassIcon, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: TextStyle(
                      color: widget.ext.greetingColor, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Search events',
                    hintStyle: TextStyle(
                        color: widget.ext.searchHintColor, fontSize: 13),
                    border: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: (_) {
                    // Keep dropdown open on Enter — user can click a result.
                  },
                ),
              ),
              // Clear button — shown when field has text.
              if (hasText)
                MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Semantics(button: true, label: 'Clear search', child: GestureDetector(
                    onTap: _clearSearch,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.close_rounded,
                          color: widget.ext.searchHintColor, size: 14),
                    ),
                  )),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Typeahead dropdown overlay ────────────────────────────────────────────────

/// Floating event-suggestion panel anchored below [_SidebarSearchField].
/// Positioned via [CompositedTransformFollower] so it always tracks the
/// search field even when the sidebar scrolls.
class _SidebarTypeaheadDropdown extends StatelessWidget {
  const _SidebarTypeaheadDropdown({
    required this.layerLink,
    required this.ext,
    required this.onSelect,
  });

  final LayerLink layerLink;
  final AppThemeExtension ext;
  final void Function(String eventId, String eventName) onSelect;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<dynamic>>(
      valueListenable: HomeNavigationPage.webEventResults,
      builder: (context, events, _) {
        if (events.isEmpty) return const SizedBox.shrink();

        return CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          // Anchor the dropdown's top-left to the search field's bottom-left.
          targetAnchor: Alignment.bottomLeft,
          followerAnchor: Alignment.topLeft,
          offset: const Offset(0, 4),
          child: Material(
            color: Colors.transparent,
            child: Container(
              // Match the usable width inside the sidebar padding (240 - 24).
              width: _kSidebarWidth - 24,
              constraints: const BoxConstraints(maxHeight: 300),
              decoration: BoxDecoration(
                color: ext.homeBackground,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: ext.searchHintColor.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  shrinkWrap: true,
                  itemCount: events.length,
                  itemBuilder: (context, i) => _TypeaheadItem(
                    event: events[i],
                    ext: ext,
                    onTap: () => onSelect(
                      '${events[i].id}',
                      '${events[i].eventName}',
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TypeaheadItem extends StatefulWidget {
  const _TypeaheadItem({
    required this.event,
    required this.ext,
    required this.onTap,
  });
  final dynamic event;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_TypeaheadItem> createState() => _TypeaheadItemState();
}

class _TypeaheadItemState extends State<_TypeaheadItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          color: _hovered
              ? widget.ext.accentGold.withValues(alpha: 0.08)
              : Colors.transparent,
          child: Row(
            children: [
              Icon(Icons.event_rounded,
                  color: widget.ext.searchHintColor.withValues(alpha: 0.7),
                  size: 14),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${widget.event.eventName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: widget.ext.greetingColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ('${widget.event.photographer}'.isNotEmpty)
                      Text(
                        '${widget.event.photographer}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.ext.searchHintColor,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: widget.ext.searchHintColor.withValues(alpha: 0.4),
                  size: 14),
            ],
          ),
        ),
      )),
    );
  }
}

// ── Discovery-mode nav (shown on /discovery for both logged-in and guests) ────
//
// Logged-in users on /discovery see the same minimal sidebar as guests so that
// the content column width and reactions layout are identical in both states.
// The only visual difference is the auth buttons: Logout vs Sign up / Log in.

class _DiscoveryModeNav extends StatelessWidget {
  const _DiscoveryModeNav({required this.ext, required this.isLoggedIn});
  final AppThemeExtension ext;
  final bool isLoggedIn;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _NavItem(
          icon: Icons.explore_rounded,
          label: 'Discovery',
          active: true,
          ext: ext,
          onTap: () {},
        ),
        const SizedBox(height: 8),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            height: 1,
          ),
        ),
        const SizedBox(height: 20),

        // Sign up as Creator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CreatorTile(ext: ext),
        ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            height: 1,
          ),
        ),
        const SizedBox(height: 16),

        if (isLoggedIn) ...[
          // Logged in on Discovery — single Log out action
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _TextActionButton(
              label: 'Log out',
              ext: ext,
              onTap: () async {
                await sl<AuthService>().removeToken();
                AppNavigator.navigatorKey.currentState
                    ?.pushNamedAndRemoveUntil(
                  DiscoveryPage.routeName,
                  (route) => false,
                );
              },
            ),
          ),
        ] else ...[
          // Guest — Sign up + Log in
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _TextActionButton(
              label: 'Sign up',
              ext: ext,
              onTap: () => AppNavigator.navigatorKey.currentState
                  ?.pushNamed(SignUpPage.routeName),
            ),
          ),
          const SizedBox(height: 8),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: _PrimaryButton(
              label: 'Log in',
              ext: ext,
              onTap: () {
                final ctx = AppNavigator.navigatorKey.currentContext;
                if (ctx == null) return;
                showLoginSheet(
                  ctx,
                  onLoginSuccess: () =>
                      AppNavigator.navigatorKey.currentState
                          ?.pushNamedAndRemoveUntil(
                              HomePage.routeName, (route) => false),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

// ── Logged-in nav ─────────────────────────────────────────────────────────────

class _LoggedInNav extends StatelessWidget {
  const _LoggedInNav({required this.ext, required this.selectedTab});
  final AppThemeExtension ext;
  final int selectedTab;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SidebarSearchField(ext: ext),
        _NavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          active: selectedTab == 0,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 0,
        ),
        _NavItem(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          active: selectedTab == 2,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 2,
        ),
        _NavItem(
          icon: Icons.camera_alt_outlined,
          label: 'Photographers',
          active: selectedTab == 3,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 3,
        ),

        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            height: 1,
          ),
        ),
        const SizedBox(height: 20),

        // Sign up as Creator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _CreatorTile(ext: ext),
        ),

        const Spacer(),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Divider(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            height: 1,
          ),
        ),
        const SizedBox(height: 16),

        // Log out
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _TextActionButton(
            label: 'Log out',
            ext: ext,
            onTap: () async {
              await sl<AuthService>().removeToken();
              AppNavigator.navigatorKey.currentState?.pushNamedAndRemoveUntil(
                DiscoveryPage.routeName,
                (route) => false,
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────

/// Tappable nav row with hover highlight — no Material/InkWell required.
class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.ext,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool active;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color =
        widget.active ? widget.ext.accentGold : widget.ext.searchHintColor;
    final bg = widget.active || _hovered
        ? widget.ext.accentGold.withValues(alpha: 0.07)
        : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: color, size: 22),
              const SizedBox(width: 12),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 15,
                  fontWeight: widget.active ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: 0.1,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

/// "Sign up as Creator" branded row — transparent background, gold accent.
class _CreatorTile extends StatefulWidget {
  const _CreatorTile({required this.ext});
  final AppThemeExtension ext;

  @override
  State<_CreatorTile> createState() => _CreatorTileState();
}

class _CreatorTileState extends State<_CreatorTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, label: 'External application', child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(_kCreatorUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.ext.accentGold.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: widget.ext.accentGold.withValues(alpha: _hovered ? 0.7 : 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 18,
                color: widget.ext.accentGold,
              ),
              const SizedBox(width: 10),
              Text(
                'Sign up as Creator',
                style: TextStyle(
                  color: widget.ext.accentGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

/// Filled primary action button (Log in).
class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({
    required this.label,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.ext.accentGold.withValues(alpha: 0.85)
                : widget.ext.accentGold,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      )),
    );
  }
}

/// Low-key text-style action (Sign up, Log out).
class _TextActionButton extends StatefulWidget {
  const _TextActionButton({
    required this.label,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_TextActionButton> createState() => _TextActionButtonState();
}

class _TextActionButtonState extends State<_TextActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.ext.searchHintColor.withValues(alpha: 0.06)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            widget.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.ext.searchHintColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      )),
    );
  }
}

// ── Footer ────────────────────────────────────────────────────────────────────

/// Legal links + copyright — always visible at the bottom of the sidebar.
/// Replace the empty URL strings with real URLs when ready.
class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.ext});
  final AppThemeExtension ext;

  static const _links = [
    ('Terms of Service', ''),
    ('Privacy Policy',   ''),
    ('Cookie Policy',    ''),
    ('About',            ''),
  ];

  @override
  Widget build(BuildContext context) {
    final muted = ext.searchHintColor.withValues(alpha: 0.45);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(
            color: ext.searchHintColor.withValues(alpha: 0.10),
            height: 1,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 4,
            children: _links
                .map((e) => _FooterLink(label: e.$1, url: e.$2, color: muted))
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            '© ${DateTime.now().year} SKIDDO',
            style: TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  const _FooterLink({
    required this.label,
    required this.url,
    required this.color,
  });
  final String label;
  final String url;
  final Color color;

  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final hasUrl = widget.url.isNotEmpty;
    return MouseRegion(
      cursor: hasUrl ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, label: 'External application', child: GestureDetector(
        onTap: hasUrl
            ? () => launchUrl(Uri.parse(widget.url),
                mode: LaunchMode.externalApplication)
            : null,
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hovered && hasUrl
                ? widget.color.withValues(alpha: 1.0)
                : widget.color,
            fontSize: 11,
            decoration: TextDecoration.none,
          ),
        ),
      )),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Mobile-web top navigation bar
// Shown when viewport width < 720 px (sidebar + content column won't fit).
// Logo is pinned on the left; nav items scroll horizontally; auth CTA on right.
// ══════════════════════════════════════════════════════════════════════════════

/// Horizontally-scrollable top nav bar — used on mobile web viewports.
class WebTopNav extends StatelessWidget {
  const WebTopNav({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        WebRouteObserver.currentRouteName,
        HomePage.webSelectedTab,
        AuthService.isAuthenticated,
      ]),
      builder: (context, _) {
        final selectedTab = HomePage.webSelectedTab.value;
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        final isLoggedIn = AuthService.isAuthenticated.value;

        return _TopNavBar(
          ext: ext,
          isLoggedIn: isLoggedIn,
          selectedTab: selectedTab,
        );
      },
    );
  }
}

class _TopNavBar extends StatelessWidget {
  const _TopNavBar({
    required this.ext,
    required this.isLoggedIn,
    required this.selectedTab,
  });

  final AppThemeExtension ext;
  final bool isLoggedIn;
  final int selectedTab;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ext.homeBackground,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: ext.searchHintColor.withValues(alpha: 0.10),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 52,
            child: Row(
              children: [
                // ── Logo (pinned) ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [ext.accentGold, const Color(0xFFFF6B35)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'S',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'SKIDDO',
                        style: TextStyle(
                          color: ext.logoTextColor,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Divider ───────────────────────────────────────────────────
                VerticalDivider(
                  color: ext.searchHintColor.withValues(alpha: 0.15),
                  width: 1,
                  thickness: 0.5,
                  indent: 10,
                  endIndent: 10,
                ),

                // ── Scrollable nav pills ──────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      children: isLoggedIn
                          ? _loggedInPills()
                          : _loggedOutPills(),
                    ),
                  ),
                ),

                // ── Auth actions (pinned right) ────────────────────────────────
                if (isLoggedIn)
                  _TopNavTextBtn(
                    label: 'Logout',
                    ext: ext,
                    onTap: () async {
                      await sl<AuthService>().removeToken();
                      AppNavigator.navigatorKey.currentState
                          ?.pushNamedAndRemoveUntil(
                        DiscoveryPage.routeName,
                        (route) => false,
                      );
                    },
                  )
                else ...[
                  _TopNavTextBtn(
                    label: 'Sign up',
                    ext: ext,
                    onTap: () => AppNavigator.navigatorKey.currentState
                        ?.pushNamed(SignUpPage.routeName),
                  ),
                  _TopNavFilledBtn(
                    label: 'Log in',
                    ext: ext,
                    onTap: () {
                      final ctx = AppNavigator.navigatorKey.currentContext;
                      if (ctx == null) return;
                      showLoginSheet(
                        ctx,
                        onLoginSuccess: () =>
                            AppNavigator.navigatorKey.currentState
                                ?.pushNamedAndRemoveUntil(
                                    HomePage.routeName, (route) => false),
                      );
                    },
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _loggedOutPills() => [
        _TopNavPill(
          icon: Icons.explore_rounded,
          label: 'Discovery',
          active: true,
          ext: ext,
          onTap: () {},
        ),
        const SizedBox(width: 6),
        _TopNavCreatorPill(ext: ext),
      ];

  List<Widget> _loggedInPills() => [
        _TopNavPill(
          icon: Icons.home_rounded,
          label: 'Home',
          active: selectedTab == 0,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 0,
        ),
        const SizedBox(width: 6),
        _TopNavPill(
          icon: Icons.photo_library_outlined,
          label: 'Gallery',
          active: selectedTab == 2,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 2,
        ),
        const SizedBox(width: 6),
        _TopNavPill(
          icon: Icons.camera_alt_outlined,
          label: 'Photographers',
          active: selectedTab == 3,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 3,
        ),
        const SizedBox(width: 6),
        _TopNavCreatorPill(ext: ext),
      ];
}

// ── Top-nav sub-widgets ───────────────────────────────────────────────────────

class _TopNavPill extends StatefulWidget {
  const _TopNavPill({
    required this.icon,
    required this.label,
    required this.active,
    required this.ext,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_TopNavPill> createState() => _TopNavPillState();
}

class _TopNavPillState extends State<_TopNavPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = widget.active
        ? widget.ext.accentGold
        : widget.ext.searchHintColor;
    final bg = widget.active
        ? widget.ext.accentGold.withValues(alpha: 0.12)
        : _hovered
            ? widget.ext.accentGold.withValues(alpha: 0.06)
            : Colors.transparent;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: widget.active
                ? Border.all(
                    color: widget.ext.accentGold.withValues(alpha: 0.4),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: color, size: 15),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight:
                      widget.active ? FontWeight.w700 : FontWeight.w500,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

class _TopNavCreatorPill extends StatefulWidget {
  const _TopNavCreatorPill({required this.ext});
  final AppThemeExtension ext;

  @override
  State<_TopNavCreatorPill> createState() => _TopNavCreatorPillState();
}

class _TopNavCreatorPillState extends State<_TopNavCreatorPill> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, label: 'External application', child: GestureDetector(
        onTap: () => launchUrl(
          Uri.parse(_kCreatorUrl),
          mode: LaunchMode.externalApplication,
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.ext.accentGold.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.ext.accentGold
                  .withValues(alpha: _hovered ? 0.7 : 0.4),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_a_photo_outlined,
                size: 14,
                color: widget.ext.accentGold,
              ),
              const SizedBox(width: 5),
              Text(
                'Sign up as Creator',
                style: TextStyle(
                  color: widget.ext.accentGold,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      )),
    );
  }
}

class _TopNavTextBtn extends StatefulWidget {
  const _TopNavTextBtn({
    required this.label,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_TopNavTextBtn> createState() => _TopNavTextBtnState();
}

class _TopNavTextBtnState extends State<_TopNavTextBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hovered
                  ? widget.ext.searchHintColor
                  : widget.ext.searchHintColor.withValues(alpha: 0.7),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      )),
    );
  }
}

class _TopNavFilledBtn extends StatefulWidget {
  const _TopNavFilledBtn({
    required this.label,
    required this.ext,
    required this.onTap,
  });
  final String label;
  final AppThemeExtension ext;
  final VoidCallback onTap;

  @override
  State<_TopNavFilledBtn> createState() => _TopNavFilledBtnState();
}

class _TopNavFilledBtnState extends State<_TopNavFilledBtn> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Semantics(button: true, child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.only(left: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.ext.accentGold.withValues(alpha: 0.85)
                : widget.ext.accentGold,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            widget.label,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              decoration: TextDecoration.none,
            ),
          ),
        ),
      )),
    );
  }
}

// ── Global top-right action cluster ───────────────────────────────────────────

/// Persistent top-right actions (Get-the-app, Messages, Profile) shown on every
/// web screen at the same position, so they don't disappear when navigating away
/// from the home feed. Only rendered for authenticated users. Self-contained:
/// uses the root [ChatRoomsBloc] and the root navigator so it works regardless
/// of the current route.
class WebTopActions extends StatefulWidget {
  const WebTopActions({super.key});

  @override
  State<WebTopActions> createState() => _WebTopActionsState();
}

class _WebTopActionsState extends State<WebTopActions> {
  String _initial = 'U';

  @override
  void initState() {
    super.initState();
    AuthService.isAuthenticated.addListener(_onAuthChanged);
    _loadInitial();
  }

  void _onAuthChanged() {
    if (!mounted) return;
    _loadInitial();
    setState(() {});
  }

  Future<void> _loadInitial() async {
    final name = await sl<AuthService>().getName();
    if (mounted) {
      setState(() => _initial =
          name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'U');
    }
  }

  @override
  void dispose() {
    AuthService.isAuthenticated.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _openMessages() => WebMessagesPanel.open();

  void _openAccount() {
    final nav = AppNavigator.navigatorKey.currentState;
    if (nav == null) return;
    nav.push(
      MaterialPageRoute<void>(
        builder: (_) => BlocProvider<DiscoveryBloc>(
          create: (_) => sl<DiscoveryBloc>(),
          child: const AccountPage(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: AuthService.isAuthenticated,
      builder: (context, isLoggedIn, _) {
        if (!isLoggedIn) return const SizedBox.shrink();
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        // Single grouped capsule: action items, a divider, then the avatar.
        return Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            decoration: BoxDecoration(
              color: ext.cardSurface,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: ext.glassBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CapsuleItem(
                  ext: ext,
                  icon: Icons.smartphone_rounded,
                  label: 'Get app',
                  onTap: () => launchUrl(
                    Uri.parse('https://skidoo.app'),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
                BlocSelector<ChatRoomsBloc, ChatRoomsState, int>(
                  selector: (s) =>
                      s.unreadCounts.values.fold(0, (sum, c) => sum + c),
                  builder: (context, unread) => _CapsuleItem(
                    ext: ext,
                    icon: Icons.chat_bubble_rounded,
                    label: 'Messages',
                    badgeCount: unread,
                    onTap: _openMessages,
                  ),
                ),
                Container(
                  width: 1,
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  color: ext.glassBorder,
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child:
                      _ActionAvatar(ext: ext, initial: _initial, onTap: _openAccount),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// An inline action inside the top-right capsule: an icon + label that
/// highlights on hover. Shows a small unread badge on the icon when
/// [badgeCount] > 0.
class _CapsuleItem extends StatefulWidget {
  const _CapsuleItem({
    required this.ext,
    required this.icon,
    required this.label,
    required this.onTap,
    this.badgeCount = 0,
  });

  final AppThemeExtension ext;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  State<_CapsuleItem> createState() => _CapsuleItemState();
}

class _CapsuleItemState extends State<_CapsuleItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final ext = widget.ext;
    final icon = Icon(widget.icon, size: 16, color: ext.greetingColor);
    return Semantics(
      button: true,
      label: widget.badgeCount > 0
          ? '${widget.label}, ${widget.badgeCount} unread'
          : widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _hovered
                  ? ext.accentGold.withValues(alpha: 0.14)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                widget.badgeCount > 0
                    ? Badge(
                        label: Text(
                          widget.badgeCount > 9 ? '9+' : '${widget.badgeCount}',
                          style: const TextStyle(
                            fontSize: 9,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        backgroundColor: Colors.redAccent,
                        child: icon,
                      )
                    : icon,
                const SizedBox(width: 6),
                Text(
                  widget.label,
                  style: TextStyle(
                    color: ext.greetingColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
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

class _ActionAvatar extends StatelessWidget {
  const _ActionAvatar({
    required this.ext,
    required this.initial,
    required this.onTap,
  });

  final AppThemeExtension ext;
  final String initial;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Your profile and account',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [ext.accentGold, const Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: ext.glassFill,
              child: Text(
                initial,
                style: TextStyle(
                  color: ext.glassIcon,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  decoration: TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
