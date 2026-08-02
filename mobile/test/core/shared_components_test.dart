import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/common/widgets/app_drag_handle.dart';
import 'package:skidoo_app/core/common/widgets/app_section_label.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';

Widget host(AppThemeExtension ext, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.light
              ? Brightness.light
              : Brightness.dark,
          extensions: [ext],
        ),
        home: Scaffold(body: child),
      ),
    );

/// Reads every `.dart` under lib once, so the duplication guards below don't
/// each walk the tree.
final _sources = [
  for (final e in Directory('lib').listSync(recursive: true))
    if (e is File && e.path.endsWith('.dart')) (path: e.path, text: e.readAsStringSync()),
];

List<String> filesDeclaring(String className) => [
      for (final s in _sources)
        if (RegExp('class $className extends State(less|ful)Widget')
            .hasMatch(s.text))
          s.path,
    ];

void main() {
  group('AppSectionLabel', () {
    testWidgets('uppercases, whatever case the caller passes', (t) async {
      await t.pumpWidget(
          host(AppThemeExtension.dark, const AppSectionLabel('Suggested creators')));
      expect(find.text('SUGGESTED CREATORS'), findsOneWidget);
    });

    testWidgets('follows the dark theme', (t) async {
      await t.pumpWidget(
          host(AppThemeExtension.dark, const AppSectionLabel('Menu')));
      expect(t.widget<Text>(find.text('MENU')).style!.color,
          AppThemeExtension.dark.searchHintColor);
    });

    testWidgets('follows the light theme', (t) async {
      await t.pumpWidget(
          host(AppThemeExtension.light, const AppSectionLabel('Menu')));
      expect(t.widget<Text>(find.text('MENU')).style!.color,
          AppThemeExtension.light.searchHintColor);
    });

    testWidgets('carries no padding unless asked', (t) async {
      await t.pumpWidget(host(AppThemeExtension.dark, const AppSectionLabel('A')));
      expect(find.byType(Padding), findsNothing);

      await t.pumpWidget(host(AppThemeExtension.dark,
          const AppSectionLabel('A', padding: EdgeInsets.all(8))));
      expect(find.byType(Padding), findsOneWidget);
    });
  });

  group('AppDragHandle', () {
    testWidgets('renders a themed bar without a colour being passed',
        (t) async {
      await t.pumpWidget(host(AppThemeExtension.dark, const AppDragHandle()));

      final box = t.widget<Container>(find.byType(Container));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color,
          AppThemeExtension.dark.searchHintColor.withValues(alpha: 0.5));
    });
  });

  // What the user asked for in as many words: one of each, used everywhere.
  group('nothing is declared twice', () {
    test('the section label lives in exactly one file', () {
      expect(filesDeclaring('_SectionLabel'), isEmpty,
          reason: 'use AppSectionLabel');
      expect(filesDeclaring('AppSectionLabel').length, 1);
    });

    test('the error state lives in exactly one file', () {
      expect(filesDeclaring('_ErrorState'), isEmpty, reason: 'use AppErrorView');
      expect(filesDeclaring('_ErrorView'), isEmpty, reason: 'use AppErrorView');
      expect(filesDeclaring('AppErrorView').length, 1);
    });

    test('the drag handle lives in exactly one file', () {
      expect(filesDeclaring('_DragHandle'), isEmpty,
          reason: 'use AppDragHandle');
      expect(filesDeclaring('AppDragHandle').length, 1);
    });

    test('the avatar lives in exactly one file', () {
      expect(filesDeclaring('_Avatar'), isEmpty, reason: 'use UserAvatar');
      expect(filesDeclaring('UserAvatar').length, 1);
    });

    test('the back button and logo stay single', () {
      expect(filesDeclaring('AppBackButton').length, 1);
      expect(filesDeclaring('JpergLogo').length, 1);
    });
  });
}
