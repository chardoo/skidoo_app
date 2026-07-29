import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/widgets/skidoo_image.dart';

Color fillOf(WidgetTester t) => t
    .widget<ColoredBox>(find.descendant(
      of: find.byType(SkidooImagePlaceholder),
      matching: find.byType(ColoredBox),
    ))
    .color;

Widget host(AppThemeExtension ext, Widget child) => MaterialApp(
      theme: ThemeData.dark().copyWith(extensions: [ext]),
      home: Scaffold(body: child),
    );

/// The bug these lock down: image slots each hardcoded their own near-black,
/// so a loading grid punched black holes into the light theme and, in dark
/// mode, sat *darker* than the #111110 surround instead of reading as a slot.
void main() {
  testWidgets('dark theme -> dark fill', (t) async {
    await t.pumpWidget(
        host(AppThemeExtension.dark, const SkidooImagePlaceholder()));
    expect(fillOf(t), AppThemeExtension.dark.searchFieldFill);
  });

  testWidgets('light theme -> light fill', (t) async {
    await t.pumpWidget(
        host(AppThemeExtension.light, const SkidooImagePlaceholder()));
    expect(fillOf(t), AppThemeExtension.light.searchFieldFill);
  });

  testWidgets('alwaysDark stays dark even under the light theme', (t) async {
    await t.pumpWidget(
        host(AppThemeExtension.light, const SkidooImagePlaceholder(alwaysDark: true)));
    expect(fillOf(t), AppThemeExtension.dark.searchFieldFill);
  });

  testWidgets('spinner is opt-in', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, const SkidooImagePlaceholder()));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    await t.pumpWidget(
        host(AppThemeExtension.dark, const SkidooImagePlaceholder(spinner: true)));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
