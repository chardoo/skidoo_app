import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:skidoo_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:skidoo_app/core/di/service_locator.dart';
import 'package:skidoo_app/core/theme/customThemeData.dart';
import 'package:skidoo_app/services/auth_service.dart';
import 'package:skidoo_app/core/theme/theme_cubit.dart';
import 'package:skidoo_app/core/navigation/app_navigator.dart';
import 'package:skidoo_app/core/navigation/web_route_observer.dart';
import 'package:skidoo_app/core/common/widgets/web_sidebar.dart';
import 'package:skidoo_app/features/auth/presentation/pages/interests_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/login_page.dart';
import 'package:skidoo_app/features/auth/presentation/pages/signup_page.dart';
import 'package:skidoo_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:skidoo_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:skidoo_app/features/home/presentation/pages/home_page.dart';

// ── Web layout constants ──────────────────────────────────────────────────────

/// Width of the main content column on web (≈ iPhone 15 Pro Max).
const double _kWebColumnWidth = 480;

/// Below this viewport width the left sidebar won't fit — switch to top nav.
const double _kWebMobileBreakpoint = 240 + _kWebColumnWidth; // sidebar + content


// ── Root application widget ───────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  final String token;

  /// True when [FlutterJailbreakDetection] flagged the device as rooted /
  /// jailbroken.
  final bool isDeviceCompromised;

  const MyApp({
    super.key,
    required this.token,
    this.isDeviceCompromised = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<CartBloc>()),
        BlocProvider.value(value: sl<ThemeCubit>()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => kIsWeb
            ? _WebApp(
                token: token,
                isDeviceCompromised: isDeviceCompromised,
                themeMode: themeMode,
              )
            : _MobileApp(
                token: token,
                isDeviceCompromised: isDeviceCompromised,
                themeMode: themeMode,
              ),
      ),
    );
  }
}

// ── Mobile branch ─────────────────────────────────────────────────────────────

class _MobileApp extends StatelessWidget {
  const _MobileApp({
    required this.token,
    required this.isDeviceCompromised,
    required this.themeMode,
  });

  final String token;
  final bool isDeviceCompromised;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (_, __) => _AppMaterial(
        token: token,
        isDeviceCompromised: isDeviceCompromised,
        themeMode: themeMode,
      ),
    );
  }
}

// ── Web branch ────────────────────────────────────────────────────────────────

/// Web root: configures ScreenUtil synchronously in [initState] so that the
/// [ScreenUtil] singleton is ready before the first [build] frame — preventing
/// the [LateInitializationError] that [ScreenUtilInit]'s [LayoutBuilder]
/// approach causes on web.
class _WebApp extends StatefulWidget {
  const _WebApp({
    required this.token,
    required this.isDeviceCompromised,
    required this.themeMode,
  });

  final String token;
  final bool isDeviceCompromised;
  final ThemeMode themeMode;

  @override
  State<_WebApp> createState() => _WebAppState();
}

class _WebAppState extends State<_WebApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _configureScreenUtil();
    // Seed the route observer so the sidebar shows the correct state immediately.
    // Both logged-in and logged-out users start on the Discovery page.
    WebRouteObserver.currentRouteName.value = DiscoveryPage.routeName;
  }

  @override
  void didChangeMetrics() => _configureScreenUtil();

  /// Initialise ScreenUtil with [_kWebColumnWidth] as the logical width so
  /// that all `.w` / `.h` / `.sp` extensions scale against the 480 dp column
  /// rather than the full browser viewport.
  void _configureScreenUtil() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    final dpr = view?.devicePixelRatio ?? 1.0;
    final logicalH =
        view != null ? view.physicalSize.height / dpr : 844.0;

    ScreenUtil.configure(
      data: MediaQueryData(
        size: Size(_kWebColumnWidth, logicalH),
        devicePixelRatio: dpr,
      ),
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: false,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _AppMaterial(
      token: widget.token,
      isDeviceCompromised: widget.isDeviceCompromised,
      themeMode: widget.themeMode,
    );
  }
}

// ── Shared MaterialApp shell ──────────────────────────────────────────────────

class _AppMaterial extends StatelessWidget {
  const _AppMaterial({
    required this.token,
    required this.isDeviceCompromised,
    required this.themeMode,
  });

  final String token;
  final bool isDeviceCompromised;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      color: Colors.transparent,
      navigatorKey: AppNavigator.navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: Styles.light,
      darkTheme: Styles.dark,
      themeMode: themeMode,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
      ],
      scrollBehavior: kIsWeb ? const _WebScrollBehavior() : null,
      // On web: sidebar + centred 480 dp column.
      // On mobile: no wrapper — ScreenUtilInit already wraps the navigator.
      builder: kIsWeb ? _webLayoutBuilder : null,
      navigatorObservers: kIsWeb ? [WebRouteObserver.instance] : [],
      // Always land on Discovery — logged-in users navigate to /home from
      // the sidebar/navbar when they want chat, gallery, or photographers.
      initialRoute: DiscoveryPage.routeName,
      routes: {
        DiscoveryPage.routeName: (_) => isDeviceCompromised
            ? const _SecurityWarningPage()
            : const DiscoveryPage(),
        LoginPage.routeName: (_) => const LoginPage(),
        SignUpPage.routeName: (_) => const SignUpPage(),
        HomePage.routeName: (_) => _AuthGuard(
              child: isDeviceCompromised
                  ? const _SecurityWarningPage()
                  : const HomePage(),
            ),
        InterestsPage.routeName: (_) => const _AuthGuard(
              child: InterestsPage(),
            ),
      },
      onUnknownRoute: (settings) => MaterialPageRoute(
        builder: (_) => token.isEmpty
            ? const LoginPage()
            : const DiscoveryPage(),
      ),
    );
  }

  /// Web layout — adapts to viewport width:
  ///   ≥ 720 px (desktop): left sidebar + centred column (480→760 px) + download button
  ///   <  720 px (mobile):  horizontally-scrollable top nav bar + full-width content
  ///
  /// The content column grows dynamically from 480 px → 760 px as the viewport
  /// expands beyond the sidebar + card width. The card's own LayoutBuilder
  /// switches to the external panel layout once it has ≥ 60 px of spare room
  /// (viewport ≈ 780 px — any laptop at a normal, non-tiny window size).
  /// Desktop layout: sidebar (240 px) + full remaining width for content.
  /// The card inside fixes itself to 480 px; reactions and comments fill the
  /// rest — identical to TikTok's web layout.
  /// Mobile web (< 720 px): top nav + full-width content (no sidebar).
  static Widget _webLayoutBuilder(BuildContext ctx, Widget? child) {
    final bg = Theme.of(ctx).scaffoldBackgroundColor;
    final viewportW = MediaQuery.of(ctx).size.width;
    final isMobileWeb = viewportW < _kWebMobileBreakpoint;

    return DefaultTextStyle(
      style: DefaultTextStyle.of(ctx).style.copyWith(decoration: TextDecoration.none),
      child: ColoredBox(
        color: bg,
        child: Column(
          children: [
            Expanded(
              child: isMobileWeb
            // ── Mobile web: top nav + full-width content ────────────────────
            ? Column(
                children: [
                  const WebTopNav(),
                  Expanded(child: ClipRect(child: child!)),
                ],
              )
            // ── Desktop web: sidebar + full remaining width ─────────────
            : Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const WebSidebar(),
                  Expanded(child: ClipRect(child: child!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Web scroll behaviour ──────────────────────────────────────────────────────

/// Enables mouse and trackpad dragging (Flutter web only enables touch by
/// default) and removes the Android overscroll glow that looks wrong in a
/// browser. Physics are left to each scroll view — see [kWebScrollPhysics].
class _WebScrollBehavior extends MaterialScrollBehavior {
  const _WebScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) =>
      child; // No glow / stretch on web.
}

// ── Auth route guard ─────────────────────────────────────────────────────────

/// Checks whether a valid session exists before rendering [child].
/// If the token is missing or empty the user is redirected to [LoginPage].
///
/// Used to protect named routes on web where someone can navigate directly to
/// a URL like `/home` without being authenticated.
class _AuthGuard extends StatefulWidget {
  const _AuthGuard({required this.child});
  final Widget child;

  @override
  State<_AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<_AuthGuard> {
  late final Future<bool> _authorized;

  @override
  void initState() {
    super.initState();
    _authorized = sl<AuthService>().getToken().then((t) => t.isNotEmpty);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authorized,
      builder: (context, snap) {
        if (!snap.hasData) {
          // Token check in flight — show neutral background (< 5 ms on web).
          return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
        }
        if (!snap.data!) {
          // Not logged in — redirect after this frame so the navigator is ready.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context)
                  .pushReplacementNamed(LoginPage.routeName);
            }
          });
          return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
        }
        return widget.child;
      },
    );
  }
}

// ── Security warning page ─────────────────────────────────────────────────────

class _SecurityWarningPage extends StatelessWidget {
  const _SecurityWarningPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 48.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                color: const Color(0xFFF5A623),
                size: 72.sp,
              ),
              SizedBox(height: 24.h),
              Text(
                AppLocalizations.of(context)!.securityWarningTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                AppLocalizations.of(context)!.securityWarningBody,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14.sp,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFF5A623),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.r),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed(
                      DiscoveryPage.routeName,
                    );
                  },
                  child: Text(
                    AppLocalizations.of(context)!.securityWarningContinue,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
