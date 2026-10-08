import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/share_target_sheet.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The sheet that replaced a pair of rail glyphs.
///
/// The rails used to carry a paper plane for the in-app DM picker and a share
/// arrow beside it — two buttons for one intention, told apart only by two
/// similar icons. "Send" and "share" name the same act to anyone who has not
/// read the code, so which did what was a guess that resolved after the tap.
///
/// It then spent a while as two circles, "In app" and "External", which had
/// the same fault one level up: **"External" was one word for two different
/// acts.** A link goes instantly and opens for anybody; saving fetches the
/// rendered file, watermarks it and takes a moment. Every destination names
/// itself now, and says what happens if you pick it.
void main() {
  // A phone, not the 800x600 the binding defaults to. A bottom sheet is capped
  // at a fraction of the screen height, and this one carries a preview and
  // three rows — on the default surface that cap is tighter than the content,
  // which is a fact about the test window rather than about any real device.
  setUp(() {
    final view =
        TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = const Size(1170, 2532);
    view.devicePixelRatio = 3;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(body: child),
        ),
      );

  /// Pumps a button that opens the sheet, and records which route was taken.
  Future<List<String>> openSheet(
    WidgetTester t, {
    String? title,
    bool withDownload = true,
    String? previewTitle,
    String? previewSubtitle,
  }) async {
    final taken = <String>[];
    await t.pumpWidget(host(Builder(
      builder: (context) => TextButton(
        onPressed: () => ShareTargetSheet.show(
          context,
          title: title ?? 'Share this photo',
          onInApp: () => taken.add('in-app'),
          onExternal: () => taken.add('external'),
          onDownload: withDownload ? () => taken.add('download') : null,
          previewTitle: previewTitle,
          previewSubtitle: previewSubtitle,
        ),
        child: const Text('open'),
      ),
    )));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
    return taken;
  }

  group('what it offers', () {
    testWidgets('every destination names itself', (t) async {
      await openSheet(t);

      expect(find.text('Send in jperg'), findsOneWidget);
      expect(find.text('Share a link'), findsOneWidget);
      expect(find.text('Save the photo'), findsOneWidget);
    });

    testWidgets('and says what picking it does', (t) async {
      // The line that carries the whole difference between the two outward
      // routes: one is a link anybody can open, one is a file on your phone.
      await openSheet(t);

      expect(find.text('Anyone with the link can open it'), findsOneWidget);
      expect(find.text('Watermarked, to your device'), findsOneWidget);
    });

    testWidgets('the watermark is said before the tap, not after', (t) async {
      // Somebody saving a photo to post elsewhere should learn it carries a
      // mark while they can still change their mind.
      await openSheet(t);

      expect(
        find.textContaining('Watermarked'),
        findsOneWidget,
        reason: 'the save row has to disclose the mark up front',
      );
    });

    testWidgets('a surface with no download does not offer one', (t) async {
      // Left out rather than shown greyed: a disabled row invites a tap that
      // can never work, and answers nothing.
      await openSheet(t, withDownload: false);

      expect(find.text('Save the photo'), findsNothing);
      expect(find.text('Share a link'), findsOneWidget);
    });
  });

  group('what it shows', () {
    testWidgets('the thing being shared is named', (t) async {
      // The sheet opens over the photograph it is about and hides it, so the
      // subject has to come back somewhere — and it doubles as the check that
      // this is the right one.
      await openSheet(
        t,
        previewTitle: 'Sports Championship Finals',
        previewSubtitle: 'by Kofi Mensah',
      );

      expect(find.text('Sports Championship Finals'), findsOneWidget);
      expect(find.text('by Kofi Mensah'), findsOneWidget);
    });

    testWidgets('with no event named, the heading still says something',
        (t) async {
      // A sheet with no words at all is worse than a generic heading.
      await openSheet(t, title: 'Share this event');

      expect(find.text('Share this event'), findsOneWidget);
    });
  });

  group('taking a route', () {
    // Each one closes the sheet *before* it routes. Every destination opens
    // something of its own — the DM picker, the OS sheet, a progress overlay —
    // and stacking one on another leaves the reader two pops from where they
    // started.

    testWidgets('in app closes the sheet, then routes', (t) async {
      final taken = await openSheet(t);

      await t.tap(find.text('Send in jperg'));
      await t.pumpAndSettle();

      expect(taken, ['in-app']);
      expect(find.text('Send in jperg'), findsNothing, reason: 'sheet closed');
    });

    testWidgets('the link closes the sheet, then routes', (t) async {
      final taken = await openSheet(t);

      await t.tap(find.text('Share a link'));
      await t.pumpAndSettle();

      expect(taken, ['external']);
      expect(find.text('Share a link'), findsNothing, reason: 'sheet closed');
    });

    testWidgets('saving closes the sheet, then routes', (t) async {
      final taken = await openSheet(t);

      await t.tap(find.text('Save the photo'));
      await t.pumpAndSettle();

      expect(taken, ['download']);
      expect(find.text('Save the photo'), findsNothing, reason: 'sheet closed');
    });

    testWidgets('choosing one does not fire the others', (t) async {
      final taken = await openSheet(t);

      await t.tap(find.text('Share a link'));
      await t.pumpAndSettle();

      expect(taken, hasLength(1));
    });

    testWidgets('dismissing takes no route at all', (t) async {
      final taken = await openSheet(t);

      await t.tapAt(const Offset(200, 60));
      await t.pumpAndSettle();

      expect(taken, isEmpty);
    });
  });

  testWidgets('a screen reader hears one sentence per row', (t) async {
    // Each row carries a title and a detail. Announced separately that is
    // three readings of one control, and the repetition says less than the
    // sentence did.
    await openSheet(t);

    for (final sentence in [
      'Send to someone in the app',
      'Share a link outside the app',
      'Save the photo to this device',
    ]) {
      expect(
        find.bySemanticsLabel(sentence),
        findsOneWidget,
        reason: sentence,
      );
    }
  });
}
