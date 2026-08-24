import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/jperg_image.dart';
import 'package:jperg_app/core/widgets/media_backdrop.dart';

/// A photo that does not match the screen's shape used to sit in empty bands.
/// The backdrop fills them with the photo's own colours: the same image drawn
/// twice, once blown up and blurred behind, once at its true size in front.
Widget host(Widget child, {Brightness brightness = Brightness.dark}) =>
    MaterialApp(
      theme: ThemeData(
        extensions: [
          brightness == Brightness.dark
              ? AppThemeExtension.dark
              : AppThemeExtension.light,
        ],
      ),
      home: Scaffold(body: child),
    );

void main() {
  group('MediaBackdrop', () {
    testWidgets('draws the media twice — blurred cover behind, child in front',
        (t) async {
      await t.pumpWidget(host(const MediaBackdrop(
        url: 'https://res.cloudinary.com/demo/image/upload/a.jpg',
        child: Text('the real photo'),
      )));

      // Two JpergImages would mean two fetches; the backdrop is one of them and
      // it must be the cheap one.
      final images = t.widgetList<JpergImage>(find.byType(JpergImage));
      expect(images.length, 1);
      final backdrop = images.single;
      expect(backdrop.isBlurBackground, isTrue);
      expect(backdrop.fit, BoxFit.cover);

      expect(find.text('the real photo'), findsOneWidget);
    });

    testWidgets('the child is painted over the backdrop, not under it',
        (t) async {
      await t.pumpWidget(host(const MediaBackdrop(
        url: 'https://res.cloudinary.com/demo/image/upload/a.jpg',
        child: Text('the real photo'),
      )));

      final stack = t.widget<Stack>(find.descendant(
        of: find.byType(MediaBackdrop),
        matching: find.byType(Stack),
      ));
      expect(stack.children.length, 3);
      expect(stack.children.first, isA<ImageFiltered>()); // blurred copy
      expect(stack.children[1], isA<ColoredBox>()); // veil
      expect(stack.children.last, isA<Text>()); // the real media, on top
    });

    testWidgets('blurs hard enough that the backdrop is not a second photo',
        (t) async {
      await t.pumpWidget(host(const MediaBackdrop(
        url: 'https://res.cloudinary.com/demo/image/upload/a.jpg',
        child: SizedBox(),
      )));

      final filtered = t.widget<ImageFiltered>(find.byType(ImageFiltered));
      expect(filtered.imageFilter, isA<ui.ImageFilter>());
      // The sigma itself is the knob everything else is tuned against.
      expect(MediaBackdrop.blurSigma, greaterThanOrEqualTo(30));
    });

    /// Read off the Stack rather than by type: the placeholder standing in for
    /// the unloaded backdrop has a ColoredBox of its own.
    Color veilOf(WidgetTester t) {
      final stack = t.widget<Stack>(find.descendant(
        of: find.byType(MediaBackdrop),
        matching: find.byType(Stack),
      ));
      return (stack.children[1] as ColoredBox).color;
    }

    testWidgets('veils with black in dark mode', (t) async {
      await t.pumpWidget(host(
        const MediaBackdrop(
          url: 'https://res.cloudinary.com/demo/image/upload/a.jpg',
          child: SizedBox(),
        ),
      ));
      expect(veilOf(t), AppThemeExtension.dark.mediaBackdropVeil);
    });

    testWidgets('veils with the page colour in light mode, not a dark slab',
        (t) async {
      await t.pumpWidget(host(
        const MediaBackdrop(
          url: 'https://res.cloudinary.com/demo/image/upload/a.jpg',
          child: SizedBox(),
        ),
        brightness: Brightness.light,
      ));
      expect(veilOf(t), AppThemeExtension.light.mediaBackdropVeil);
    });
  });

  group('the veil strength', () {
    // It used to be 33% in dark and 70% in light. At 70% the veil is opaque
    // enough to erase what it sits on, so the light-mode backdrop stopped
    // reading as the photo's colour and became a flat pale slab.
    test('is the same in both themes, and leaves the backdrop visible', () {
      final dark = AppThemeExtension.dark.mediaBackdropVeil;
      final light = AppThemeExtension.light.mediaBackdropVeil;

      expect(dark.a, closeTo(light.a, 0.02),
          reason: 'themes should differ in colour, not in strength');
      for (final veil in [dark, light]) {
        expect(veil.a, lessThan(0.6),
            reason: 'past ~60% the veil erases the backdrop instead of '
                'knocking it back');
        expect(veil.a, greaterThan(0.35),
            reason: 'below this the backdrop competes with the real image');
      }
    });
  });
}
