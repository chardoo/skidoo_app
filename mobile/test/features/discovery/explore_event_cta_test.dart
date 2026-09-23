import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/event_card/explore_event_cta.dart';

/// The offer that stands in the middle of a feed photo.
///
/// Its treatment is the thing worth pinning. It sits *on* the picture rather
/// than in a corner, so a flat tint there stops the image dead at the pill's
/// edge — which is what it used to do, under a comment claiming it was glass.
/// These assert it is the app's real chrome now, and that the decision is made
/// by what is behind it rather than by whichever theme it is mounted under.
void main() {
  // The pill sizes itself with ScreenUtil, like the rest of the feed, so it
  // needs the same design size the app is initialised with.
  Widget host({required Brightness brightness}) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData(
            brightness: brightness,
            extensions: [
              brightness == Brightness.light
                  ? AppThemeExtension.light
                  : AppThemeExtension.dark
            ],
          ),
          home: Scaffold(
            body: Center(child: ExploreEventCta(onTap: () {})),
          ),
        ),
      );

  tearDown(() => GlassSurface.debugFrostedOverride = null);

  testWidgets('is the app chrome, not a hand-rolled pill', (t) async {
    await t.pumpWidget(host(brightness: Brightness.dark));

    expect(find.byType(GlassSurface), findsOneWidget);
  });

  testWidgets('frosts what is behind it where the platform frosts', (t) async {
    GlassSurface.debugFrostedOverride = true;
    await t.pumpWidget(host(brightness: Brightness.dark));

    // The photo has to carry through the pill. Without this it is a grey slab
    // punched into the middle of the image it is inviting you into.
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('lets the photo through where the platform does not frost',
      (t) async {
    // The regression this whole widget exists to avoid, in the one case where
    // it is easy to reintroduce: no blur on offer, so an opaque tonal surface
    // would be a hole punched in the middle of the picture.
    //
    // The upper bound is the reported bug. At 62 % — the value inherited from
    // the hand-rolled pill this widget replaced — the picture stopped dead at
    // the pill's edge and Android and web got a dark bar across the middle of
    // every photo carrying the offer, while iOS got glass. "Not opaque" was
    // true of that build too, which is why the ceiling is a number now.
    GlassSurface.debugFrostedOverride = false;
    await t.pumpWidget(host(brightness: Brightness.dark));

    final container = t.widgetList<Container>(find.byType(Container)).first;
    final color = (container.decoration as BoxDecoration).color!;
    expect(color.a, lessThan(0.55),
        reason: 'above this it reads as a bar laid over the photo');
    expect(color.a, greaterThan(0.3),
        reason: 'the text still needs something to sit on');
  });

  testWidgets('its glyphs carry their own legibility', (t) async {
    // The fill was lightened until the photo comes through it, so the fill is
    // no longer what makes white text readable over a bright picture — the
    // shadow is. Dropping it would put the pill back to relying on a tint
    // heavy enough to be the bar this stopped being.
    await t.pumpWidget(host(brightness: Brightness.dark));

    final label = t.widget<Text>(find.text('Explore event photos'));
    expect(label.style?.shadows, isNotEmpty);

    final arrow = t.widget<Icon>(find.byType(Icon));
    expect(arrow.shadows, isNotEmpty,
        reason: 'the arrow sits on the same photo as the words');
  });

  testWidgets('takes the dark treatment even in a light theme', (t) async {
    // The ground under it is a photograph whatever the app is set to. The feed
    // forces its own dark palette today, so this is about the widget being
    // asked the right question rather than about the feed as it stands.
    GlassSurface.debugFrostedOverride = true;
    await t.pumpWidget(host(brightness: Brightness.light));

    final glass = t.widget<GlassSurface>(find.byType(GlassSurface));
    expect(glass.onDark, isTrue);
  });

  testWidgets('still announces itself as a button', (t) async {
    // The pill is a GestureDetector over a Row, neither of which announces
    // anything — so the label and the button flag are all a screen reader has.
    // Asserted on the widget rather than the semantics tree because the Text
    // inside carries the same string, and the two nodes merge.
    await t.pumpWidget(host(brightness: Brightness.dark));

    final semantics = t.widget<Semantics>(
      find.ancestor(
        of: find.byType(GlassSurface),
        matching: find.byType(Semantics),
      ).first,
    );
    expect(semantics.properties.label, 'Explore event photos');
    expect(semantics.properties.button, isTrue);
  });
}
