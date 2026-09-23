import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:jperg_app/core/theme/app_typography.dart';
import 'package:jperg_app/l10n/app_localizations.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/services/auth_service.dart';
import 'package:jperg_app/core/theme/theme_cubit.dart';
import 'package:jperg_app/core/deep_links/deep_link_host.dart';
import 'package:jperg_app/core/navigation/app_navigator.dart';
import 'package:jperg_app/core/navigation/route_trace_observer.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/features/auth/presentation/pages/interests_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/login_page.dart';
import 'package:jperg_app/features/auth/presentation/pages/signup_page.dart';
import 'package:jperg_app/features/cart/presentation/bloc/cart_bloc.dart';
import 'package:jperg_app/features/chat/presentation/bloc/rooms/chat_rooms_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/features/splash/presentation/pages/splash_page.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';

// ── Root application widget ───────────────────────────────────────────────────

class MyApp extends StatelessWidget {
  final String token;

  /// True when [FlutterJailbreakDetection] flagged the device as rooted /
  /// jailbroken.
  final bool isDeviceCompromised;

  /// True once the first-run onboarding carousel has been shown (Skip or
  /// finishing the last slide) — mobile-only, gates the cold-start route.
  final bool hasSeenOnboarding;

  const MyApp({
    super.key,
    required this.token,
    this.isDeviceCompromised = false,
    this.hasSeenOnboarding = false,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: sl<CartBloc>()),
        BlocProvider.value(value: sl<ThemeCubit>()),
        // ChatRoomsBloc lives here (root level) so it is always alive regardless
        // of which page is shown.  This ensures the WS background-message
        // subscription (_bgMsgSub) keeps the unread-count badge up to date even
        // when the user is on DiscoveryPage and has never visited /home.
        BlocProvider(
          create: (_) =>
              sl<ChatRoomsBloc>()..add(const ChatRoomsLoadRequested()),
        ),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => _MobileApp(
          token: token,
          isDeviceCompromised: isDeviceCompromised,
          hasSeenOnboarding: hasSeenOnboarding,
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
    required this.hasSeenOnboarding,
    required this.themeMode,
  });

  final String token;
  final bool isDeviceCompromised;
  final bool hasSeenOnboarding;
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
        hasSeenOnboarding: hasSeenOnboarding,
        themeMode: themeMode,
      ),
    );
  }
}

// ── Shared MaterialApp shell ──────────────────────────────────────────────────

class _AppMaterial extends StatelessWidget {
  const _AppMaterial({
    required this.token,
    required this.isDeviceCompromised,
    required this.hasSeenOnboarding,
    required this.themeMode,
  });

  final String token;
  final bool isDeviceCompromised;
  final bool hasSeenOnboarding;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    // Above MaterialApp so it survives every route change: it starts the deep
    // link listener once and resumes a link that had to wait for the Navigator
    // or for sign-in.
    return DeepLinkHost(
      child: MaterialApp(
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
        // No ambient SelectionArea: it fought with double-tap-to-like,
        // long-press-for-options, and swipe gestures on feed cards/chat
        // bubbles, popping the native "Select All" menu unpredictably, and
        // could crash on nested Scrollables (flutter/flutter#111690).
        builder: _appBuilder,
        navigatorObservers: [
          // Debug-only route trace. Every deep-link report so far has been
          // "it opened and then I was somewhere else", with no record of what
          // arrived or in what order.
          if (kDebugMode) RouteTraceObserver.instance,
        ],
        // Every cold start plays the branded splash first (including
        // already-logged-in users, who previously had no splash moment at
        // all), then hands off to the real destination: returning users (valid
        // token) go to /home; first-ever launch (no token, onboarding never
        // shown) goes to the 3-screen intro carousel; every other logged-out
        // cold start (including after "Continue as guest") goes straight to
        // Discovery.
        initialRoute: SplashPage.routeName,
        // The same table `routes:` used to hold, one level down.
        //
        // It is here rather than there because `routes:` decides what a screen
        // is and not how it arrives: every entry in it becomes a
        // MaterialPageRoute wearing the app's Cupertino slide, and there is one
        // navigation in the app that must not slide — the splash handing over,
        // which dissolves. `routes:` is also consulted *before* `onGenerateRoute`
        // by WidgetsApp, so the two cannot be mixed: a name in the map never
        // reaches here. Everything else about this is unchanged, including
        // falling through to [onUnknownRoute] on a name that isn't listed.
        onGenerateRoute: (settings) {
          final WidgetBuilder? builder = switch (settings.name) {
            SplashPage.routeName => (_) => SplashPage(
                  nextRoute: token.isNotEmpty
                      ? HomePage.routeName
                      : !hasSeenOnboarding
                          ? OnboardingPage.routeName
                          : DiscoveryPage.routeName,
                ),
            OnboardingPage.routeName => (_) =>
                const _GuestGuard(child: OnboardingPage()),
            DiscoveryPage.routeName => (_) => _GuestGuard(
                  child: isDeviceCompromised
                      ? const _SecurityWarningPage()
                      : const DiscoveryPage(),
                ),
            LoginPage.routeName => (_) => const _GuestGuard(child: LoginPage()),
            SignUpPage.routeName => (_) =>
                const _GuestGuard(child: SignUpPage()),
            HomePage.routeName => (_) => _AuthGuard(
                  child: isDeviceCompromised
                      ? const _SecurityWarningPage()
                      : const HomePage(),
                ),
            InterestsPage.routeName => (_) => const _AuthGuard(
                  child: InterestsPage(),
                ),
            _ => null,
          };
          if (builder == null) return null; // → onUnknownRoute

          // How it arrives, as opposed to what it shows — see [appRouteFor].
          return appRouteFor(settings, builder);
        },
        // Names that reach here are a bug, not a destination — this silently
        // showed DiscoveryPage instead, which reads as "logged out" and hid the
        // cause for days. Every deep link used to arrive here as "/e/<id>",
        // pushed by Flutter's own routing on top of the screen the link had
        // already opened (now disabled per-platform; see AndroidManifest.xml
        // and Info.plist). Say so loudly in debug rather than showing a feed
        // and hoping someone notices.
        onUnknownRoute: (settings) {
          assert(() {
            debugPrint('[Nav] onUnknownRoute: "${settings.name}" is not in the '
                'routes map — falling back to a feed. This is a bug: either '
                'register the route or stop navigating to that name.');
            return true;
          }());
          return MaterialPageRoute(
            settings: RouteSettings(name: 'unknown:${settings.name}'),
            builder: (_) =>
                token.isEmpty ? const LoginPage() : const DiscoveryPage(),
          );
        },
      ),
    );
  }

  /// Root builder: clamps the OS font-scale setting.
  ///
  /// Every text size in the app is a `.sp` value scaled by flutter_screenutil
  /// against a 390 dp design width. The OS accessibility font-scale multiplies
  /// on top of that, so a large phone at 200 % text size compounds both and
  /// overflows the denser screens (account page, campaign forms, chat). The
  /// clamp keeps large-text settings meaningfully larger without letting the
  /// two multipliers stack unbounded.
  static Widget _appBuilder(BuildContext ctx, Widget? child) {
    final scaled = MediaQuery.withClampedTextScaling(
      minScaleFactor: 0.9,
      maxScaleFactor: 1.3,
      child: child ?? const SizedBox.shrink(),
    );
    return scaled;
  }
}

// ── Auth route guard ─────────────────────────────────────────────────────────

/// Checks whether a valid session exists before rendering [child].
/// If the token is missing or empty the user is redirected to [LoginPage].
///
/// Used to protect named routes that can be reached directly — a deep link to
/// `/home`, say — without being authenticated.
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
          // Token check in flight — show a neutral background.
          return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
        }
        if (!snap.data!) {
          // Not logged in — redirect after this frame so the navigator is ready.
          debugPrint('[AuthGuard] no token → replacing with /login. If a deep '
              'link was open, this is what took its place.');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(LoginPage.routeName);
            }
          });
          return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
        }
        return widget.child;
      },
    );
  }
}

// ── Guest route guard ─────────────────────────────────────────────────────────

/// Inverse of [_AuthGuard]: protects pages that must only be visible to
/// **unauthenticated** users (Discovery, Login, Sign-up).
///
/// If [AuthService.isAuthenticated] is already true (seeded synchronously at
/// startup before the first frame), the user is redirected to [HomePage]
/// rather than landing on the guest UI — which a deep link into one of these
/// routes would otherwise do.
class _GuestGuard extends StatefulWidget {
  const _GuestGuard({required this.child});
  final Widget child;

  @override
  State<_GuestGuard> createState() => _GuestGuardState();
}

class _GuestGuardState extends State<_GuestGuard> {
  /// Captured once in [initState] so repeated [build] calls are idempotent.
  late final bool _shouldRedirect;

  @override
  void initState() {
    super.initState();
    // Redirect on all platforms when the user is already authenticated.
    // AuthService.isAuthenticated is seeded from Secure Storage before runApp
    // so this is a synchronous, zero-latency check — no frame flash.
    _shouldRedirect = AuthService.isAuthenticated.value;
    if (_shouldRedirect) {
      // Clears the whole stack. If a deep-link route was on it, it is gone.
      debugPrint('[GuestGuard] authenticated on a guest page → resetting to '
          '/home and clearing the stack');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            HomePage.routeName,
            (route) => false,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldRedirect) {
      // Show neutral background while the post-frame redirect fires.
      return const Scaffold(backgroundColor: Color(0xFF0D0D0D));
    }
    return widget.child;
  }
}

// ── Security warning page ─────────────────────────────────────────────────────

class _SecurityWarningPage extends StatelessWidget {
  const _SecurityWarningPage();

  @override
  Widget build(BuildContext context) {
    final page = Scaffold(
      backgroundColor: const Color(0xFF0D0D0D),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: AppSpacing.xxxl.w, vertical: 48.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.shield_outlined,
                color: const Color(0xFF1D9E75),
                size: 72.sp,
              ),
              SizedBox(height: AppSpacing.xxl.h),
              Text(
                AppLocalizations.of(context)!.securityWarningTitle,
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: AppTypography.displayFontFamily,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.lg.h),
              Text(
                AppLocalizations.of(context)!.securityWarningBody,
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: 14.sp,
                  height: 1.6,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: AppSpacing.huge.h),
              AppButton(
                fullWidth: true,
                label: AppLocalizations.of(context)!.securityWarningContinue,
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed(
                    DiscoveryPage.routeName,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
    return page;
  }
}
