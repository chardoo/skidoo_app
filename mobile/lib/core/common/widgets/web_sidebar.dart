import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/navigation/app_navigator.dart';
import 'package:skidoo_app/core/navigation/web_route_observer.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/auth/presentation/widgets/login_bottom_sheet.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';
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
      ]),
      builder: (context, _) {
        final routeName = WebRouteObserver.currentRouteName.value;
        final isLoggedIn = routeName == HomePage.routeName;
        final selectedTab = HomePage.webSelectedTab.value;
        final ext = Theme.of(context).extension<AppThemeExtension>()!;

        return _SidebarShell(
          ext: ext,
          child: isLoggedIn
              ? _LoggedInNav(ext: ext, selectedTab: selectedTab)
              : _LoggedOutNav(ext: ext),
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
    return Container(
      width: _kSidebarWidth,
      height: double.infinity,
      color: ext.homeBackground,
      child: DecoratedBox(
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
              // ── Logo ──────────────────────────────────────────────────────
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

              // ── Footer ────────────────────────────────────────────────────
              _SidebarFooter(ext: ext),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Logged-out nav ────────────────────────────────────────────────────────────

class _LoggedOutNav extends StatelessWidget {
  const _LoggedOutNav({required this.ext});
  final AppThemeExtension ext;

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

        // Sign up
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

        // Log in
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
                onLoginSuccess: () => AppNavigator.navigatorKey.currentState
                    ?.pushReplacementNamed(HomePage.routeName),
              );
            },
          ),
        ),
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
        _NavItem(
          icon: Icons.home_rounded,
          label: 'Home',
          active: selectedTab == 0,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 0,
        ),
        _NavItem(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Messages',
          active: selectedTab == 1,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 1,
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
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
      ]),
      builder: (context, _) {
        final routeName = WebRouteObserver.currentRouteName.value;
        final isLoggedIn = routeName == HomePage.routeName;
        final selectedTab = HomePage.webSelectedTab.value;
        final ext = Theme.of(context).extension<AppThemeExtension>()!;

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
    return Container(
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
                                ?.pushReplacementNamed(HomePage.routeName),
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
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Messages',
          active: selectedTab == 1,
          ext: ext,
          onTap: () => HomePage.tabRequest.value = 1,
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
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
      child: GestureDetector(
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
      ),
    );
  }
}
