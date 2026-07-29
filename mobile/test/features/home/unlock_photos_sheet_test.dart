import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/home/presentation/widgets/unlock_photos_sheet.dart';

/// Hosts a button that opens the sheet, so the tests exercise the real
/// [UnlockPhotosSheet.show] route rather than a hand-mounted widget — the
/// value it pops is the whole contract.
Widget host(AppThemeExtension ext, void Function(String?) onResult) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.dark
              ? Brightness.dark
              : Brightness.light,
          extensions: [ext],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  onResult(await UnlockPhotosSheet.show(context)),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  // One theme per test: the sheet is rebuilt from scratch each time, and
  // asserting both themes in one pump would only prove the first one.
  for (final (name, ext) in [
    ('dark', AppThemeExtension.dark),
    ('light', AppThemeExtension.light),
  ]) {
    testWidgets('opens with the code tab and both modes offered — $name',
        (t) async {
      await t.pumpWidget(host(ext, (_) {}));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      expect(find.text('Unlock private photos'), findsOneWidget);
      expect(find.text('Enter Code'), findsOneWidget);
      expect(find.text('Scan QR'), findsOneWidget);
      // Code entry is the landing mode — the field is there without tapping.
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('text is drawn from the theme, never hard-coded — $name',
        (t) async {
      await t.pumpWidget(host(ext, (_) {}));
      await t.tap(find.text('open'));
      await t.pumpAndSettle();

      // The regression this guards: a sheet built for dark mode only, whose
      // near-white title vanishes on the light background.
      expect(
        t.widget<Text>(find.text('Unlock private photos')).style!.color,
        ext.greetingColor,
      );
      // The inactive segment sits on the sheet background, so it takes the
      // muted text colour; the active one is white on the accent.
      expect(t.widget<Text>(find.text('Scan QR')).style!.color,
          ext.searchHintColor);
      expect(
          t.widget<Text>(find.text('Enter Code')).style!.color, Colors.white);
    });
  }

  testWidgets('a typed code is what the sheet resolves to', (t) async {
    String? result;
    await t.pumpWidget(host(AppThemeExtension.dark, (r) => result = r));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.enterText(find.byType(TextField), ' africa-26 ');
    await t.pump();
    await t.tap(find.text('Unlock photos'));
    await t.pumpAndSettle();

    // Trimmed — a code pasted with a stray space is still that code.
    expect(result, 'africa-26');
    expect(find.text('Unlock private photos'), findsNothing);
  });

  testWidgets('an empty field cannot be submitted', (t) async {
    String? result;
    var called = false;
    await t.pumpWidget(host(AppThemeExtension.dark, (r) {
      called = true;
      result = r;
    }));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tap(find.text('Unlock photos'));
    await t.pumpAndSettle();

    // Still open, nothing resolved.
    expect(called, isFalse);
    expect(result, isNull);
    expect(find.text('Unlock private photos'), findsOneWidget);
  });

  testWidgets('dismissing resolves to null so callers can tell it apart',
      (t) async {
    String? result = 'sentinel';
    var called = false;
    await t.pumpWidget(host(AppThemeExtension.dark, (r) {
      called = true;
      result = r;
    }));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();

    await t.tapAt(const Offset(200, 40)); // the barrier above the sheet
    await t.pumpAndSettle();

    expect(called, isTrue);
    expect(result, isNull);
  });
}
