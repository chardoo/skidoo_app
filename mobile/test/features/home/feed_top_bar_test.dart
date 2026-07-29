import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/home/presentation/widgets/feed_top_bar.dart';

Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [ext]),
        home: Scaffold(body: child),
      ),
    );

FeedTopBar bar({
  List<String> tabs = const ['Found', 'For You', 'Following'],
  int selected = 1,
  bool solid = false,
  bool searchOpen = false,
  String? initialQuery,
  VoidCallback? onUnlock,
}) =>
    FeedTopBar(
      tabs: tabs,
      selectedTab: selected,
      overSolidBackground: solid,
      onTabChanged: (_) {},
      isSearchOpen: searchOpen,
      onSearchOpen: () {},
      onSearchClose: () {},
      onSearchChanged: (_) {},
      initialQuery: initialQuery,
      onUnlockPressed: onUnlock,
    );

Color labelColour(WidgetTester t, String label) =>
    t.widget<Text>(find.text(label)).style!.color!;

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('guests get Found | Explore, and no Following', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark,
        bar(tabs: const ['Found', 'Explore'], selected: 1)));
    expect(find.text('Found'), findsOneWidget);
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('For You'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('signed in keeps the three-tab set', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    for (final l in ['Found', 'For You', 'Following']) {
      expect(find.text(l), findsOneWidget);
    }
    expect(find.text('Explore'), findsNothing);
  });

  testWidgets('the leading action is the QR mark, not a plus', (t) async {
    var taps = 0;
    await t.pumpWidget(
        host(AppThemeExtension.dark, bar(onUnlock: () => taps++)));

    // The design's leading icon is a QR glyph; "+" (create) is not on this bar.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    final unlock = find.bySemanticsLabel('Unlock private photos');
    expect(unlock, findsOneWidget);

    await t.tap(unlock);
    expect(taps, 1);
  });

  testWidgets('the leading action is hidden when no handler is given',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    expect(find.bySemanticsLabel('Unlock private photos'), findsNothing);
  });

  testWidgets('opening search on the user\'s behalf seeds the field',
      (t) async {
    // Closed first, so the transition into the open state is what's tested —
    // that's the only moment the seed is read.
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    await t.pumpWidget(
        host(AppThemeExtension.dark, bar(searchOpen: true, initialQuery: 'AFRICA-26')));
    await t.pump();

    expect(find.text('AFRICA-26'), findsOneWidget);
  });

  testWidgets('opening search by tapping the icon leaves the field empty',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    await t.pumpWidget(host(AppThemeExtension.dark, bar(searchOpen: true)));
    await t.pump();

    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });

  // One theme per test: pumping two themes into the same widget tree reuses
  // the element and the second theme doesn't take, which silently passes the
  // assertion for the wrong reason.
  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('over media the labels stay white — $name', (t) async {
      await t.pumpWidget(host(ext, bar(selected: 1, solid: false)));
      expect(labelColour(t, 'For You'), Colors.white);
      // A drop shadow is what keeps it legible over an arbitrary photo.
      expect(t.widget<Text>(find.text('For You')).style!.shadows, isNotNull);
    });

    testWidgets('on the Found tab the labels follow the theme — $name',
        (t) async {
      // The regression this guards: white-on-white in light mode, because the
      // Found tab renders on the page background rather than over media.
      await t.pumpWidget(host(
          ext, bar(tabs: const ['Found', 'Explore'], selected: 0, solid: true)));
      expect(labelColour(t, 'Found'), ext.greetingColor);
      expect(labelColour(t, 'Explore'), ext.searchHintColor);
      expect(t.widget<Text>(find.text('Found')).style!.shadows, isNull);
    });
  }
}
