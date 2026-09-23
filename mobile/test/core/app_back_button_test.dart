import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

Widget host(Widget child, {GlobalKey<NavigatorState>? navigator}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        theme:
            ThemeData.dark().copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

/// Going back used to look like a different control on nearly every screen:
/// four different glyphs at five different sizes, plus Flutter's [BackButton],
/// which renders a *different* icon per platform. One chevron now, everywhere
/// — the full arrow reads as an Android control on an iPhone.
void main() {
  testWidgets('draws the chevron, not a full arrow', (t) async {
    await t.pumpWidget(host(const AppBackButton()));
    await t.pumpAndSettle();

    expect(
      t.widget<Icon>(find.byType(Icon)).icon,
      Icons.arrow_back_ios_new_rounded,
    );
  });

  testWidgets('pops the route it is on', (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(host(const Text('first'), navigator: navigator));
    await t.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: AppBackButton()),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
  });

  test('no screen rolls its own back icon', () {
    final offenders = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (entity.path.endsWith('app_back_button.dart')) continue;

      final source = entity.readAsStringSync();
      // `BackButton(` is Flutter's own, whose glyph follows the platform.
      // Any `Icons.arrow_back*` named outside the widget is a screen picking
      // its own glyph again — including the chevron, which has to stay one
      // constant so the next change to it lands everywhere at once.
      if (source.contains('Icons.arrow_back') ||
          RegExp(r'\bBackButton\(').hasMatch(source)) {
        offenders.add(entity.path);
      }
    }

    expect(offenders, isEmpty,
        reason: 'use AppBackButton (or AppBackButton.icon) instead');
  });
}
