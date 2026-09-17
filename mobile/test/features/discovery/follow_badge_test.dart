import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/card_interaction_bar.dart';
import 'package:jperg_app/core/theme/app_icons.dart';
import '../../support/icon_finders.dart';

/// The + badge under a creator's avatar has to look like a button.
///
/// It was a 20dp disc with a 1.5dp white ring and a 14sp plus in it. Subtract
/// the ring and the glyph and almost no accent was left showing, so what people
/// saw was a white outline with a plus inside — decoration on the avatar, not
/// something to press. Nobody knew tapping it followed the creator.
///
/// So the thing to hold is the *ratio*: the disc has to be wide enough, and the
/// glyph small enough, that the accent is the largest thing in the badge. A
/// future tweak that grows the icon or shrinks the circle puts the bug back
/// without changing a single colour, which is why this measures both rather
/// than asserting a fill colour and calling it done.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme:
            ThemeData.dark().copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: Center(child: child)),
      ),
    );

Widget badge({bool following = false}) => FollowButton(
      photographerId: 'p1',
      compact: true,
      onImage: true,
      initialFollowing: following,
      // Keeps the tap off the network — this test never presses it, but the
      // callback is what the unauthenticated feed passes and it costs nothing
      // to be explicit that no repository call is expected.
      onLoginRequired: () {},
    );

void main() {
  AnimatedContainer discOf(WidgetTester t) =>
      t.widget<AnimatedContainer>(find.byType(AnimatedContainer).first);

  BoxDecoration decorationOf(WidgetTester t) =>
      discOf(t).decoration! as BoxDecoration;

  testWidgets('the unfollowed badge is filled with the accent, not outlined',
      (t) async {
    await t.pumpWidget(host(badge()));
    await t.pump();

    final decoration = decorationOf(t);
    expect(decoration.color, AppThemeExtension.dark.accentGold);
    expect(decoration.shape, BoxShape.circle);
    // Transparent or a bare ring is the bug.
    expect(decoration.color, isNot(Colors.transparent));
    expect(decoration.color!.a, 1.0,
        reason: 'a see-through fill reads as an outline over a photo');
  });

  testWidgets('the glyph does not crowd out the fill', (t) async {
    await t.pumpWidget(host(badge()));
    await t.pump();

    final disc = t.getSize(find.byType(AnimatedContainer).first);
    final glyph = t.widget<Icon>(findAppIcon(AppIcons.add));

    // A proportion, not a measurement in pixels.
    //
    // ScreenUtil scales `.w` and `.sp` by the surface width — about 2x on the
    // default test window — so any absolute threshold here says more about the
    // test surface than about the badge. The ratio is what actually went
    // wrong and the only part that survives the scaling: the plus was 14 on a
    // 20dp disc, or 70% of it, leaving a hairline of green. It is 13 on 24 now,
    // near enough 54%.
    final occupancy = glyph.size! / disc.width;

    expect(occupancy, lessThan(0.6),
        reason: 'at 0.70 — the old 14sp plus on a 20dp disc — the accent '
            'survives only as a hairline and the badge reads as an outline');
  });

  testWidgets('it carries a shadow so it survives a bright photo', (t) async {
    await t.pumpWidget(host(badge()));
    await t.pump();

    expect(decorationOf(t).boxShadow, isNotNull);
    expect(decorationOf(t).boxShadow, isNotEmpty);
  });

  testWidgets('the followed state stays quiet', (t) async {
    // Already-following is not a call to action, so it keeps the translucent
    // treatment — the fix is for the unfollowed badge only.
    await t.pumpWidget(host(badge(following: true)));
    await t.pump();

    expect(findAppIcon(AppIcons.check), findsOneWidget);
    expect(decorationOf(t).color, isNot(AppThemeExtension.dark.accentGold));
    expect(decorationOf(t).boxShadow, anyOf(isNull, isEmpty));
  });

  testWidgets('it says what it does, for anyone not looking at it', (t) async {
    await t.pumpWidget(host(badge()));
    await t.pump();

    expect(
      find.bySemanticsLabel('Follow'),
      findsOneWidget,
      reason: 'the plus is the only label this button has',
    );
  });
}
