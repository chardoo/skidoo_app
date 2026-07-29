import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/gallery/presentation/found/widgets/found_scanning_state.dart';

/// The "has a face, no matches yet" state. Distinct from the face gate: the
/// user has done everything asked of them, so it reports progress rather than
/// requesting an action, and offers only the photographer-code escape hatch.
Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: [ext],
          splashFactory: NoSplash.splashFactory,
        ),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('renders the design copy in $name mode', (t) async {
      await t.pumpWidget(host(ext, FoundScanningState(onEnterCode: () {})));
      await t.pump();

      expect(find.text('Scanning for your face'), findsOneWidget);
      expect(
        find.text("We haven't matched you to any photo yet. We'll notify you "
            'once we do.'),
        findsOneWidget,
      );
      expect(find.text('Have a code from a photographer?'), findsOneWidget);

      // Headline must take the theme's ink, not the other theme's.
      expect(
        t.widget<Text>(find.text('Scanning for your face')).style!.color,
        ext.greetingColor,
      );
    });
  }

  testWidgets('offers no primary button — nothing is being asked', (t) async {
    await t.pumpWidget(
        host(AppThemeExtension.dark, FoundScanningState(onEnterCode: () {})));
    await t.pump();
    expect(find.text('Take a selfie'), findsNothing);
    expect(find.text('Add my face'), findsNothing);
  });

  testWidgets('the code link fires', (t) async {
    var taps = 0;
    await t.pumpWidget(
        host(AppThemeExtension.dark, FoundScanningState(onEnterCode: () => taps++)));
    await t.pump();
    await t.tap(find.text('Have a code from a photographer?'));
    expect(taps, 1);
  });

  testWidgets('the link is hidden when no scanner is wired up', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, const FoundScanningState()));
    await t.pump();
    expect(find.text('Scanning for your face'), findsOneWidget);
    expect(find.text('Have a code from a photographer?'), findsNothing);
  });
}
