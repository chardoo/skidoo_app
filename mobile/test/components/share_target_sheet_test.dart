import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/share_target_sheet.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The sheet that replaced a pair of rail glyphs.
///
/// The rails used to carry a paper plane for the in-app DM picker and a share
/// arrow beside it for the OS sheet — two buttons for one intention, told
/// apart only by two similar icons. "Send" and "share" name the same act to
/// anyone who has not read the code, so which one did what was a guess that
/// resolved only after the tap. Now one button opens this, and the two
/// destinations are named.
void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(body: child),
        ),
      );

  /// Pumps a button that opens the sheet, and records which route was taken.
  Future<List<String>> openSheet(WidgetTester t, {String? title}) async {
    final taken = <String>[];
    await t.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () => ShareTargetSheet.show(
          context,
          title: title ?? 'Share this photo',
          onInApp: () => taken.add('in-app'),
          onExternal: () => taken.add('external'),
        ),
        child: const Text('open'),
      ),
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return taken;
  }

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('offers both destinations, side by side', (t) async {
    await openSheet(t);

    expect(find.byType(ShareTargetSheet), findsOneWidget);
    expect(find.text('In app'), findsOneWidget);
    expect(find.text('External'), findsOneWidget);

    // Side by side, not stacked: same row, so the same vertical centre.
    expect(
      t.getCenter(find.text('In app')).dy,
      t.getCenter(find.text('External')).dy,
    );
    // And in app on the left, external on the right.
    expect(
      t.getCenter(find.text('In app')).dx,
      lessThan(t.getCenter(find.text('External')).dx),
    );
  });

  testWidgets('names the destinations rather than relying on the glyph',
      (t) async {
    // The whole point of the sheet. A screen reader gets the full sentence,
    // since "In app" on its own is not one.
    await openSheet(t);

    expect(find.bySemanticsLabel('Send to someone in the app'), findsOneWidget);
    expect(find.bySemanticsLabel('Share outside the app'), findsOneWidget);
  });

  testWidgets('in app closes the sheet, then routes', (t) async {
    // Order matters: the in-app route opens the DM picker, which is itself a
    // modal sheet. Left open, this one would sit under it and leave the user
    // two pops from where they started.
    final taken = await openSheet(t);

    await t.tap(find.text('In app'));
    await t.pumpAndSettle();

    expect(taken, ['in-app']);
    expect(find.byType(ShareTargetSheet), findsNothing);
  });

  testWidgets('external closes the sheet, then routes', (t) async {
    final taken = await openSheet(t);

    await t.tap(find.text('External'));
    await t.pumpAndSettle();

    expect(taken, ['external']);
    expect(find.byType(ShareTargetSheet), findsNothing);
  });

  testWidgets('choosing one does not fire the other', (t) async {
    final taken = await openSheet(t);

    await t.tap(find.text('External'));
    await t.pumpAndSettle();

    expect(taken, isNot(contains('in-app')));
  });

  testWidgets('the title is the callers, since not everything is a photo',
      (t) async {
    // The feed card shares an event, not a picture.
    await openSheet(t, title: 'Share this event');

    expect(find.text('Share this event'), findsOneWidget);
  });

  testWidgets('dismissing takes neither route', (t) async {
    final taken = await openSheet(t);

    // Tap the barrier above the sheet.
    await t.tapAt(const Offset(10, 10));
    await t.pumpAndSettle();

    expect(taken, isEmpty);
    expect(find.byType(ShareTargetSheet), findsNothing);
  });
}
