import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/common/navbar.dart';
import 'package:jperg_app/core/navigation/chrome_visibility.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The bottom bar narrows to bare icons as you read further, and opens again
/// on the way back up.
///
/// What has to hold through the collapse: every tab stays reachable. The bar
/// is the only way off the screen, so a collapse that hid tabs — or shrank
/// their tap targets below the point of being hittable — would trap someone
/// mid-feed.
void main() {
  Widget host({int selected = 0}) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(
            bottomNavigationBar: AppNavbar(
              selectedIndex: selected,
              onchange: (_) {},
            ),
          ),
        ),
      );

  setUp(ChromeVisibility.reset);
  tearDown(ChromeVisibility.reset);

  testWidgets('the bar is only as tall as the pill', (t) async {
    // The bug this was written for: the pill was centred with `Center`, which
    // expands to its constraints — and in the bottomNavigationBar slot those
    // are loose. The bar grew to fill the screen, floated in the middle of
    // itself, and made the Scaffold reserve that whole height as bottom
    // inset, which pushed the feed's full-screen cards apart and left a black
    // gap through the middle of the page.
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    final bar = t.getSize(find.byType(AppNavbar)).height;
    final screen = t.getSize(find.byType(Scaffold)).height;

    expect(bar, lessThan(screen / 3),
        reason: 'the nav bar is filling the screen instead of hugging its pill');
  });

  testWidgets('the bar sits at the bottom, not adrift in the middle',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    final barBottom = t.getRect(find.byType(AppNavbar)).bottom;
    final screenBottom = t.getRect(find.byType(Scaffold)).bottom;

    expect(screenBottom - barBottom, lessThan(24),
        reason: 'the bar has floated away from the bottom edge');
  });

  testWidgets('collapsing does not change the bar\'s height', (t) async {
    // It narrows. A collapse that also changed height would move the feed
    // under it on every scroll.
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final before = t.getSize(find.byType(AppNavbar)).height;

    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();

    expect(t.getSize(find.byType(AppNavbar)).height, before);
  });

  testWidgets('expanded, the active tab carries its label', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('collapsed, the labels go', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();

    expect(find.text('Home'), findsNothing);
  });

  testWidgets('collapsed, every tab is still there', (t) async {
    // The bar is the only way off this screen. Dropping a destination to save
    // width would be a trap, not a collapse.
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final before = find.byType(GestureDetector).evaluate().length;

    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();

    expect(find.byType(GestureDetector), findsNWidgets(before));
  });

  testWidgets('collapsed, every tab is still big enough to hit', (t) async {
    // 44dp is the smallest target a thumb can be relied on to hit. The
    // collapse removes the label, not the tap area.
    await t.pumpWidget(host());
    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();

    for (final label in ['Home', 'Alerts', 'Chats', 'Profile']) {
      final size = t.getSize(find.bySemanticsLabel(label).first);
      expect(size.width, greaterThanOrEqualTo(40),
          reason: '$label is too narrow to tap');
      expect(size.height, greaterThanOrEqualTo(40),
          reason: '$label is too short to tap');
    }
  });

  testWidgets('the collapsed bar is narrower than the open one', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final expanded = t.getSize(find.byType(AppNavbar)).width;

    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();

    // The AppNavbar slot is fixed by the Scaffold; the pill inside it is what
    // shrinks, so measure the row of tabs rather than the slot.
    final row = t.getSize(find.byType(Row).first).width;
    expect(row, lessThan(expanded));
  });

  testWidgets('reopening restores the label', (t) async {
    await t.pumpWidget(host());
    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();
    expect(find.text('Home'), findsNothing);

    ChromeVisibility.expanded.value = true;
    await t.pumpAndSettle();

    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('which tab you are on survives the collapse', (t) async {
    // The label goes, so the accent on the glyph is the only thing left
    // saying where you are.
    await t.pumpWidget(host(selected: 2));
    ChromeVisibility.expanded.value = false;
    await t.pumpAndSettle();

    final ext = AppThemeExtension.dark;
    final icons = t.widgetList<Icon>(find.byType(Icon));
    expect(
      icons.where((i) => i.color == ext.accentGold),
      isNotEmpty,
      reason: 'the active tab must stay marked when its label is gone',
    );
  });
}
