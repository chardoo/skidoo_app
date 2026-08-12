import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/settings/presentation/widgets/settings_section.dart';

/// Every row the settings designs draw, and the shape they draw it in.
///
/// The rows are what the screens are — a label, sometimes a second line, and
/// one of three things on the right. These pin the pieces that are easy to get
/// subtly wrong: a switch that also navigates, a heading with nothing under it,
/// a busy row that still takes taps.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

void main() {
  group('a row is one thing at a time', () {
    testWidgets('a row that opens a screen draws a chevron and no switch',
        (t) async {
      await t.pumpWidget(host(SettingsSection(
        children: [SettingsRow(label: 'Privacy', onTap: () {})],
      )));
      await t.pump();

      expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
    });

    testWidgets('a row that toggles draws a switch and no chevron', (t) async {
      await t.pumpWidget(host(SettingsSection(
        children: [
          SettingsRow(label: 'Dark Mode', value: true, onChanged: (_) {}),
        ],
      )));
      await t.pump();

      expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('tapping anywhere on a toggle row flips it', (t) async {
      var value = false;
      await t.pumpWidget(host(SettingsSection(
        children: [
          SettingsRow(
            label: 'Share Usage Data',
            value: value,
            onChanged: (v) => value = v,
          ),
        ],
      )));
      await t.pump();

      // The label, not the switch — a 40px target on a full-width row is the
      // whole row as far as anybody using it is concerned.
      await t.tap(find.text('Share Usage Data'));
      expect(value, isTrue);
    });

    testWidgets('a row waiting on the server takes no taps', (t) async {
      var taps = 0;
      await t.pumpWidget(host(SettingsSection(
        children: [
          SettingsRow(
            label: 'Two-Factor Authentication',
            value: false,
            isBusy: true,
            onChanged: (_) => taps++,
          ),
        ],
      )));
      await t.pump();

      await t.tap(find.text('Two-Factor Authentication'));
      expect(taps, 0, reason: 'a second press would start a second request');
    });
  });

  group('a section', () {
    testWidgets('can carry a switch on its heading', (t) async {
      // The Notifications screen: the master switch governs the section, so it
      // sits on the heading rather than in a row of the list it controls.
      await t.pumpWidget(host(SettingsSection(
        title: 'Push notifications',
        trailing: Switch.adaptive(value: true, onChanged: (_) {}),
        children: const [],
      )));
      await t.pump();

      expect(find.text('PUSH NOTIFICATIONS'), findsOneWidget);
      expect(find.byType(Switch), findsOneWidget);
    });

    testWidgets('draws no card when it has no rows', (t) async {
      await t.pumpWidget(host(SettingsSection(
        title: 'Push notifications',
        children: const [],
      )));
      await t.pump();

      expect(find.byType(DecoratedBox), findsNothing,
          reason: 'an empty card is a box with nothing in it');
    });

    testWidgets('a destructive row is red', (t) async {
      await t.pumpWidget(host(SettingsSection(
        children: [
          SettingsRow(label: 'Delete Account', destructive: true, onTap: () {}),
        ],
      )));
      await t.pump();

      final text = t.widget<Text>(find.text('Delete Account'));
      expect(text.style?.color, const Color(0xFFB00020));
    });
  });
}
