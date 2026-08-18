import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/di/service_locator.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/features/home/presentation/widgets/creator_mode_menu.dart';
import 'package:jperg_app/features/home/presentation/widgets/feed_top_bar.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Enough of an [AuthService] for the mode menu to decide it should draw: the
/// role, and an empty avatar url so the avatar falls back to its initials
/// rather than reaching for the network.
class _PhotographerAuth extends AuthService {
  @override
  Future<String> getRole() async => 'photographer';

  @override
  Future<String> getProfileUrl() async => '';
}

Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [ext]),
        home: Scaffold(body: child),
      ),
    );

/// The bar full-width at the top of the screen, the way the feed page mounts it
/// — the geometry assertions below are about where things land in that strip.
Widget topHost(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          fontFamily: Styles.fontFamily,
          extensions: const [AppThemeExtension.dark],
        ),
        home: Scaffold(
          body: Stack(children: [
            Positioned(top: 0, left: 0, right: 0, child: child),
          ]),
        ),
      ),
    );

/// Loads the real Poppins metrics.
///
/// The default test font gives every glyph the same square advance, so a bold
/// label and a medium one measure identically — which is exactly the difference
/// the layout-shift test needs to see. Without the real font that test passes
/// no matter what the widget does.
Future<void> loadPoppins() async {
  final loader = FontLoader(Styles.fontFamily);
  for (final weight in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(Future.value(ByteData.sublistView(
        File('assets/fonts/Poppins-$weight.ttf').readAsBytesSync())));
  }
  await loader.load();
}

FeedTopBar bar({
  List<String> tabs = const ['Found', 'Feed', 'Following'],
  int selected = 1,
  bool solid = false,
  VoidCallback? onSearch,
  VoidCallback? onUnlock,
}) =>
    FeedTopBar(
      tabs: tabs,
      selectedTab: selected,
      overSolidBackground: solid,
      onTabChanged: (_) {},
      onSearchOpen: onSearch ?? () {},
      onUnlockPressed: onUnlock,
    );

Color labelColour(WidgetTester t, String label) =>
    t.widget<Text>(find.text(label)).style!.color!;

void main() {
  // Real metrics for every test in the file: the bar's layout is driven by how
  // wide the labels actually are, and the test font's square glyphs make them
  // roughly twice Poppins' width — wide enough to change what fits.
  setUpAll(loadPoppins);

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
    expect(find.text('Feed'), findsNothing);
    expect(find.text('Following'), findsNothing);
  });

  testWidgets('signed in keeps the three-tab set', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, bar()));
    for (final l in ['Found', 'Feed', 'Following']) {
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

  testWidgets('the QR glyph takes the accent while its sheet is open',
      (t) async {
    const ext = AppThemeExtension.dark;

    // The glyph is a CustomPaint and its painter type is private to the widget
    // library, so the colour is read off it dynamically rather than by casting
    // to a type this file cannot name.
    Color glyphColour(WidgetTester t) {
      final painted = t
          .widgetList<CustomPaint>(find.descendant(
            of: find.bySemanticsLabel('Unlock private photos'),
            matching: find.byType(CustomPaint),
          ))
          .firstWhere((p) => p.painter != null);
      return (painted.painter as dynamic).color as Color;
    }

    await t.pumpWidget(host(
        ext,
        FeedTopBar(
          selectedTab: 1,
          onTabChanged: (_) {},
          onSearchOpen: () {},
          onUnlockPressed: () {},
        )));
    expect(glyphColour(t), Colors.white, reason: 'idle over media');

    await t.pumpWidget(host(
        ext,
        FeedTopBar(
          selectedTab: 1,
          onTabChanged: (_) {},
          onSearchOpen: () {},
          onUnlockPressed: () {},
          unlockActive: true,
        )));
    // Tinted over the tween's duration, not instantly.
    await t.pumpAndSettle();
    expect(glyphColour(t), ext.accentGold);
  });

  testWidgets('the search icon hands off to the Search screen', (t) async {
    // The bar itself no longer holds a query field — search is a route of its
    // own, so all this button owes anyone is the callback.
    var taps = 0;
    await t.pumpWidget(
        host(AppThemeExtension.dark, bar(onSearch: () => taps++)));

    expect(find.byType(TextField), findsNothing);
    await t.tap(find.bySemanticsLabel('Open search'));
    expect(taps, 1);
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
      expect(labelColour(t, 'Feed'), Colors.white);
      // A drop shadow is what keeps it legible over an arbitrary photo.
      expect(t.widget<Text>(find.text('Feed')).style!.shadows, isNotNull);
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

  // ── Layout and hit testing ──────────────────────────────────────────────────

  /// One tab's tap box.
  ///
  /// Found from its label rather than by position in a row: the bar is a single
  /// row now — QR, tabs, search, mode menu, all sharing out the slack — so
  /// "the GestureDetectors in the first Row" is every control on the bar.
  Rect tabBox(WidgetTester t, String label) => t.getRect(find
      .ancestor(of: find.text(label), matching: find.byType(GestureDetector))
      .first);

  const signedInTabs = ['Found', 'Feed', 'Following'];

  testWidgets('labels sit on the same optical line as the icons', (t) async {
    // They used to sit 3 dp higher: the label and its underline were centred as
    // one block, so the underline's share pushed the text up off the line the
    // leading and trailing glyphs are on.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    final iconCentre =
        t.getRect(find.bySemanticsLabel('Unlock private photos')).center.dy;
    expect(t.getRect(find.bySemanticsLabel('Open search')).center.dy,
        moreOrLessEquals(iconCentre, epsilon: 0.5));

    for (final l in ['Found', 'Feed', 'Following']) {
      expect(t.getRect(find.text(l)).center.dy,
          moreOrLessEquals(iconCentre, epsilon: 0.5),
          reason: '$l is off the icons\' line');
    }
  });

  testWidgets('every control clears the 48 dp minimum tap target', (t) async {
    // The bug this guards: a 27 dp tall tab whose top edge was flush with the
    // top of the glyphs, so a tap aimed at the label but landing a couple of
    // pixels high missed it entirely and nothing happened.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    for (final label in signedInTabs) {
      final r = tabBox(t, label);
      expect(r.height, greaterThanOrEqualTo(48),
          reason: '$label is too short');
      expect(r.width, greaterThanOrEqualTo(48), reason: '$label is too narrow');
    }
    for (final label in ['Unlock private photos', 'Open search']) {
      expect(t.getRect(find.bySemanticsLabel(label)).height,
          greaterThanOrEqualTo(48),
          reason: '$label is too short');
    }
  });

  testWidgets('a tap just above the label still selects the tab', (t) async {
    // The reported symptom, precisely: tapping the word did nothing and you had
    // to aim below it.
    var picked = -1;
    await t.pumpWidget(topHost(FeedTopBar(
      tabs: const ['Found', 'Feed', 'Following'],
      selectedTab: 0,
      onTabChanged: (i) => picked = i,
      onSearchOpen: () {},
    )));

    final word = t.getRect(find.text('Following'));
    for (final dy in [word.top - 4, word.center.dy, word.bottom + 3]) {
      picked = -1;
      await t.tapAt(Offset(word.center.dx, dy));
      await t.pump();
      expect(picked, 2, reason: 'missed at y=$dy');
    }
  });

  testWidgets('each label keeps a tappable margin around it', (t) async {
    // The tap boxes used to abut exactly, because the tabs were one packed row.
    // They no longer can — the slack is shared out between every neighbouring
    // pair, and some of it falls between two tabs — so what has to hold now is
    // that each box still reaches past its own word on both sides. That margin
    // is the fix for the original bug: a tap aimed at a label used to have to
    // land on the glyphs themselves.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    for (final label in signedInTabs) {
      final box = tabBox(t, label);
      final word = t.getRect(find.text(label));
      expect(word.left - box.left, greaterThanOrEqualTo(6),
          reason: '$label has no room to its left');
      expect(box.right - word.right, greaterThanOrEqualTo(6),
          reason: '$label has no room to its right');
    }
  });

  testWidgets('the slack is shared out equally, not pooled at one end',
      (t) async {
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    final strips = [
      for (var i = 1; i < signedInTabs.length; i++)
        tabBox(t, signedInTabs[i]).left - tabBox(t, signedInTabs[i - 1]).right,
    ];

    for (final strip in strips) {
      expect(strip, moreOrLessEquals(strips.first, epsilon: 1),
          reason: 'uneven strips between the tabs: $strips');
    }
  });

  testWidgets('the row is spread, not centred against a heavier end',
      (t) async {
    // The bug: the tabs were centred in the *bar*, and a photographer's
    // trailing end (search + avatar + chevron) is far wider than the leading QR
    // mark. The group ended up pushed right — a hole after the QR and
    // "Following" touching the search icon. Sharing the slack out is what fixes
    // it, so the two outer gaps have to be within a few points of each other.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    final leading = t.getRect(find.bySemanticsLabel('Unlock private photos'));
    final search = t.getRect(find.bySemanticsLabel('Open search'));

    final beforeFirst = tabBox(t, 'Found').left - leading.right;
    final afterLast = search.left - tabBox(t, 'Following').right;

    expect(beforeFirst, greaterThanOrEqualTo(0));
    expect(afterLast, greaterThanOrEqualTo(0));
    expect((beforeFirst - afterLast).abs(), lessThan(4),
        reason: 'the ends are lopsided: $beforeFirst before, $afterLast after');
  });

  testWidgets('the trailing controls stay in the corner', (t) async {
    // Search and the mode menu are one child of the row, so a client — whose
    // menu draws nothing — does not get search floating a gap short of the
    // edge, which is what a share of the slack would have opened up there.
    await t.pumpWidget(topHost(bar(onUnlock: () {})));

    final bar_ = t.getRect(find.byType(FeedTopBar));
    final search = t.getRect(find.bySemanticsLabel('Open search'));

    // 16 dp of bar padding, and nothing else between the icon and the edge.
    expect(bar_.right - search.right, moreOrLessEquals(16, epsilon: 1));
  });

  // ── The photographer's bar ──────────────────────────────────────────────────
  //
  // The heavy case, and the one the layout was getting wrong: search *plus* a
  // 32 dp avatar *plus* a chevron on the trailing end, against a 24 dp glyph on
  // the leading one. Centring the tabs in the bar put them nowhere near the
  // middle of the space they actually had.

  group('with a photographer signed in', () {
    setUp(() {
      sl.registerSingleton<AuthService>(_PhotographerAuth());
    });
    tearDown(sl.reset);

    Future<void> pumpBar(WidgetTester t) async {
      await t.pumpWidget(topHost(bar(onUnlock: () {})));
      // The mode menu resolves the role before it draws anything.
      await t.pumpAndSettle();
    }

    testWidgets('the avatar is there and the row still fits', (t) async {
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(d.exceptionAsString());
      await pumpBar(t);
      FlutterError.onError = previous;

      // By type, not by semantics label: the avatar inside carries its own
      // 'Profile picture' label, which merges with the button's and defeats an
      // exact-string finder. The menu is a SizedBox.shrink for everyone else,
      // so a non-zero width is what says it drew.
      expect(t.getSize(find.byType(CreatorModeMenu)).width, greaterThan(0));
      expect(errors, isEmpty, reason: 'the bar overflowed: ${errors.join()}');
    });

    testWidgets('the tabs are not pushed off-centre by it', (t) async {
      // The reported symptom: a hole between the QR mark and "Found", and
      // "Following" running into the search icon.
      await pumpBar(t);

      final leading = t.getRect(find.bySemanticsLabel('Unlock private photos'));
      final search = t.getRect(find.bySemanticsLabel('Open search'));

      final beforeFirst = tabBox(t, 'Found').left - leading.right;
      final afterLast = search.left - tabBox(t, 'Following').right;

      expect(beforeFirst, greaterThanOrEqualTo(0));
      expect(afterLast, greaterThanOrEqualTo(0));
      expect((beforeFirst - afterLast).abs(), lessThan(4),
          reason: 'lopsided: $beforeFirst before the tabs, $afterLast after');
    });

    testWidgets('the avatar is not crowding the search icon', (t) async {
      // They read as one clumsy blob at 8 dp apart. The design spaces them
      // about as far apart as anything else in the row.
      await pumpBar(t);

      final search = t.getRect(find.bySemanticsLabel('Open search'));
      final avatar = t.getRect(find.byType(UserAvatar));

      expect(avatar.left - search.right, greaterThanOrEqualTo(12));
    });
  });

  testWidgets('changing the selection does not slide the labels sideways',
      (t) async {
    // The active label is bolder, so it is wider. The row is sized to its
    // contents and centred, so without reserving the bold width the whole group
    // shifted a couple of pixels on every tab change.
    final lefts = <int, List<double>>{};
    for (final selected in [0, 1, 2]) {
      await t.pumpWidget(topHost(bar(selected: selected)));
      lefts[selected] = [
        for (final l in ['Found', 'Feed', 'Following'])
          t.getRect(find.text(l)).left,
      ];
    }

    for (final selected in [1, 2]) {
      for (var i = 0; i < 3; i++) {
        expect(lefts[selected]![i], moreOrLessEquals(lefts[0]![i], epsilon: 0.01),
            reason: 'label $i moved when tab $selected became active');
      }
    }
  });
}
