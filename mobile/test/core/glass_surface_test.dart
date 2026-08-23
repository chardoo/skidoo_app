import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/glass_surface.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The platforms disagree about floating chrome and both are right: iOS frosts
/// it, Material 3 gives it an opaque tonal surface. This is the one place that
/// branch lives, so it is the one place worth pinning.
void main() {
  Widget host(AppThemeExtension ext, {bool? onDark}) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.light
              ? Brightness.light
              : Brightness.dark,
          extensions: [ext],
        ),
        home: Scaffold(
          body: GlassSurface(
            borderRadius: BorderRadius.circular(20),
            onDark: onDark,
            child: const SizedBox(width: 100, height: 40),
          ),
        ),
      );

  tearDown(() => GlassSurface.debugFrostedOverride = null);

  group('frosted (iOS)', () {
    setUp(() => GlassSurface.debugFrostedOverride = true);

    testWidgets('blurs what is behind it', (t) async {
      await t.pumpWidget(host(AppThemeExtension.dark));

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets('lets the content show through', (t) async {
      // The whole point of frosting. An opaque fill over a blur is just an
      // expensive way to draw a box.
      await t.pumpWidget(host(AppThemeExtension.dark));

      final box = t.widget<DecoratedBox>(find.descendant(
        of: find.byType(BackdropFilter),
        matching: find.byType(DecoratedBox),
      ));
      final color = (box.decoration as BoxDecoration).color!;
      expect(color.a, lessThan(1.0));
      expect(color.a, greaterThan(0.0));
    });

    testWidgets('is clipped to its own shape', (t) async {
      // Without the clip the blur is applied to the whole layer, so the frost
      // bleeds past the rounded corners it is supposed to fill.
      await t.pumpWidget(host(AppThemeExtension.dark));

      expect(
        find.ancestor(
          of: find.byType(BackdropFilter),
          matching: find.byType(ClipRRect),
        ),
        findsOneWidget,
      );
    });
  });

  group('tonal (Android and web)', () {
    setUp(() => GlassSurface.debugFrostedOverride = false);

    testWidgets('does not pay for a blur', (t) async {
      // The nav bar is on screen for the whole session, so a blur there is
      // paid every frame of it — on the platform where cheap hardware is the
      // common case, and for a look Material 3 does not ask for.
      await t.pumpWidget(host(AppThemeExtension.dark));

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets('is opaque', (t) async {
      // A translucent fill with nothing blurred behind it is a washed-out box
      // showing the content through it — worse than either treatment done
      // properly.
      await t.pumpWidget(host(AppThemeExtension.light));

      final container = t.widgetList<Container>(find.byType(Container)).first;
      final color = (container.decoration as BoxDecoration).color!;
      expect(color.a, 1.0);
    });

    testWidgets('earns an edge from a shadow instead', (t) async {
      await t.pumpWidget(host(AppThemeExtension.light));

      final container = t.widgetList<Container>(find.byType(Container)).first;
      expect((container.decoration as BoxDecoration).boxShadow, isNotNull);
    });
  });

  testWidgets('onDark overrides the theme, on either treatment', (t) async {
    // Some ground is dark whatever the app theme is — the feed is a deliberate
    // dark island and a photo viewer is black. Chrome there has to match what
    // is behind it, which is not what Theme.of knows.
    GlassSurface.debugFrostedOverride = false;
    await t.pumpWidget(host(AppThemeExtension.light, onDark: true));

    final container = t.widgetList<Container>(find.byType(Container)).first;
    final color = (container.decoration as BoxDecoration).color!;
    expect(color.computeLuminance(), lessThan(0.2),
        reason: 'a light pill on dark media is glare');
  });
}
