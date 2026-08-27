import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/common/widgets/app_loading_indicator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/core/theme/dark_media_surface.dart';
import 'package:jperg_app/features/discovery/presentation/bloc/discovery_bloc.dart';
import 'package:jperg_app/features/discovery/presentation/pages/discovery_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// A photo feed is dark because it is a photo feed, not because somebody
/// signed in.
///
/// The signed-in feed wraps itself in [DarkMediaSurface]; the guest feed —
/// a different page, reached by "Continue as guest" — did not. So the same
/// cards, in the same layout, came out cream-on-cream under a light theme:
/// the letterbox and blurred backdrop follow the theme by design, while the
/// overlays drawn on top of them (white caption, white counts, white hashtags)
/// are drawn for a dark ground and do not. The first screen a visitor ever
/// sees had unreadable text on it.
///
/// The Found tab is deliberately *not* dark — it is a gate on the page's own
/// background, not a photo filling the screen — so these pin both halves.

/// Stands in for the real bloc, which reaches into the service locator for
/// half a dozen collaborators in its constructor. `implements` rather than
/// `extends` to skip that entirely; the page only ever reads `state` and
/// pushes events at it.
class _LoadingDiscoveryBloc extends Bloc<DiscoveryEvent, DiscoveryState>
    implements DiscoveryBloc {
  _LoadingDiscoveryBloc() : super(const DiscoveryState(isLoading: true)) {
    on<DiscoveryEvent>((_, __) {});
  }
}

/// The theme is built *inside* the ScreenUtilInit builder: [Styles] sizes its
/// text with `.sp`, which throws if ScreenUtil has not initialised yet.
Widget host({required bool dark}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: dark ? Styles.dark : Styles.light,
        home: const DiscoveryPage(),
      ),
    );

/// The palette actually in force where the feed's content is drawn.
AppThemeExtension extAt(WidgetTester tester, Finder finder) =>
    Theme.of(tester.element(finder)).extension<AppThemeExtension>()!;

void main() {
  setUp(() async {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    FlutterSecureStorage.setMockInitialValues({});
    await GetIt.I.reset();
    GetIt.I.registerSingleton<AuthService>(AuthService());
    // A factory, not a singleton: BlocProvider closes the bloc it creates, and
    // a closed one cannot serve the next test.
    GetIt.I.registerFactory<DiscoveryBloc>(_LoadingDiscoveryBloc.new);
  });

  tearDown(() async {
    await GetIt.I.reset();
    final view = TestWidgetsFlutterBinding
        .instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('the guest feed is dark under the light theme', (tester) async {
    await tester.pumpWidget(host(dark: false));
    await tester.pump();

    // Guests land on Explore, so this is the first thing anyone sees.
    expect(find.byType(DarkMediaSurface), findsOneWidget);
    expect(extAt(tester, find.byType(AppLoadingIndicator)),
        AppThemeExtension.dark);
  });

  testWidgets('the guest feed is dark under the dark theme too', (tester) async {
    await tester.pumpWidget(host(dark: true));
    await tester.pump();

    expect(extAt(tester, find.byType(AppLoadingIndicator)),
        AppThemeExtension.dark);
  });

  testWidgets('nothing light shows around the feed', (tester) async {
    await tester.pumpWidget(host(dark: false));
    await tester.pump();

    // The Scaffold paints behind the safe-area insets, so a themed background
    // here is a cream band above and below a dark feed.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppThemeExtension.dark.homeBackground);
  });

  testWidgets('the Found tab still belongs to the app theme', (tester) async {
    await tester.pumpWidget(host(dark: false));
    await tester.pump();

    await tester.tap(find.text('Found'));
    await tester.pumpAndSettle();

    // Found is a gate on the page background, not a photo filling the screen.
    // Forcing it dark would be the mirror of the bug being fixed.
    expect(find.byType(DarkMediaSurface), findsNothing);
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, AppThemeExtension.light.homeBackground);
  });
}
