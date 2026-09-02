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
    GlassSurface.debugFrostedOverride = false;
    await t.pumpWidget(host(brightness: Brightness.dark));

    final container = t.widgetList<Container>(find.byType(Container)).first;
    final color = (container.decoration as BoxDecoration).color!;
    expect(color.a, lessThan(1.0), reason: 'the photo has to come through');
    expect(color.a, greaterThan(0.4), reason: 'white text has to stay legible');
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
