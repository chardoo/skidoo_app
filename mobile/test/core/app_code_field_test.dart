import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_code_field.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The six boxes an emailed code is typed into.
///
/// Both code screens — signup verification and password reset — held their own
/// copy of this, and the copies had already drifted. What is pinned here is the
/// part that was actually wrong on a device: an empty box drew a transparent
/// border, so on the light theme the row was #EFEFE9 on #F7F7F2 — a contrast
/// ratio of about 1.06. The slots were invisible. All you could see were the
/// digits you had already typed, with no way to tell how many were left, which
/// is the one thing this control exists to show.

Widget host(Widget child, {bool dark = false}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          extensions: [dark ? AppThemeExtension.dark : AppThemeExtension.light],
        ),
        home: Scaffold(body: child),
      ),
    );

/// The six decoration boxes, in order. Matched by shape — a Container with a
/// border — because the field lays a real TextField over them.
Iterable<BoxDecoration> boxes(WidgetTester t) => t
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.border != null);

Color borderOf(BoxDecoration d) => (d.border as Border).top.color;

void main() {
  late TextEditingController controller;
  late FocusNode focusNode;

  setUp(() {
    controller = TextEditingController();
    focusNode = FocusNode();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    controller.dispose();
    focusNode.dispose();
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  Future<void> pump(WidgetTester t,
      {bool dark = false, bool hasError = false}) async {
    await t.pumpWidget(host(
      AppCodeField(
        controller: controller,
        focusNode: focusNode,
        hasError: hasError,
      ),
      dark: dark,
    ));
    await t.pump();
  }

  testWidgets('every empty box is visible against the page', (t) async {
    await pump(t);

    const ext = AppThemeExtension.light;
    for (final box in boxes(t)) {
      // Not transparent, which is what it used to be: an invisible slot on a
      // fill that is itself nearly the page colour.
      expect(borderOf(box), isNot(Colors.transparent));
      expect(borderOf(box).a, greaterThan(0.2),
          reason: 'the hairline has to actually read on the page');
    }
    expect(boxes(t), hasLength(6));
    expect(ext.searchFieldFill, isNot(ext.homeBackground));
  });

  testWidgets('the three states are told apart', (t) async {
    controller.text = '28';
    focusNode.requestFocus();
    await pump(t);
    await t.pump();

    const ext = AppThemeExtension.light;
    final drawn = boxes(t).map(borderOf).toList();

    // Filled boxes carry a tint of the accent, so progress reads at a glance.
    expect(drawn[0], ext.accentGold.withValues(alpha: 0.35));
    expect(drawn[1], ext.accentGold.withValues(alpha: 0.35));
    // The box awaiting the next digit takes the full accent.
    expect(drawn[2], ext.accentGold);
    // Untouched boxes take the grey hairline.
    expect(drawn[3], ext.searchHintColor.withValues(alpha: 0.30));
    expect(drawn[3], isNot(drawn[2]));
    expect(drawn[3], isNot(drawn[0]));
  });

  testWidgets('a rejected code turns the boxes red', (t) async {
    controller.text = '284913';
    await pump(t, hasError: true);

    // The banner explains it, but the eye is on the boxes — leaving them
    // looking accepted while the message says otherwise reads as two screens
    // disagreeing.
    const ext = AppThemeExtension.light;
    for (final box in boxes(t)) {
      expect(borderOf(box).r, ext.errorRed.r);
      expect(borderOf(box), isNot(ext.accentGold));
    }
  });

  testWidgets('onCompleted fires once, on the last digit', (t) async {
    final completed = <String>[];
    await t.pumpWidget(host(AppCodeField(
      controller: controller,
      focusNode: focusNode,
      onCompleted: completed.add,
    )));
    await t.pump();

    await t.enterText(find.byType(TextField), '28491');
    await t.pump();
    expect(completed, isEmpty, reason: 'five digits is not a code');

    await t.enterText(find.byType(TextField), '284913');
    await t.pump();
    expect(completed, ['284913']);
  });

  testWidgets('only digits get in, and only six of them', (t) async {
    await pump(t);

    await t.enterText(find.byType(TextField), '12ab34cd5678');
    await t.pump();

    expect(controller.text, '123456');
  });

  testWidgets('nothing offers to select the invisible text', (t) async {
    await pump(t);

    // A long press would otherwise put a magnifier and two drag handles over
    // the boxes, aimed at text that is transparent and 0.01 tall — and on
    // Android a Paste bubble on top of the row.
    final field = t.widget<TextField>(find.byType(TextField));
    expect(field.enableInteractiveSelection, isFalse);

    // `TextMagnifierConfiguration.disabled` is a builder that returns null
    // rather than a flag, so that is what has to be asked. Its
    // `shouldDisplayHandlesInMagnifier` stays true even when disabled, which
    // makes it the wrong thing to assert on.
    final magnifier = field.magnifierConfiguration!.magnifierBuilder(
      t.element(find.byType(TextField)),
      MagnifierController(),
      ValueNotifier(const MagnifierInfo(
        globalGesturePosition: Offset.zero,
        caretRect: Rect.zero,
        fieldBounds: Rect.zero,
        currentLineBoundaries: Rect.zero,
      )),
    );
    expect(magnifier, isNull);
  });

  test('both code screens use it — no screen rolls its own', () {
    for (final path in const [
      'lib/features/auth/presentation/pages/email_verification_page.dart',
      'lib/features/auth/presentation/pages/verify_reset_code_page.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source, contains('AppCodeField('), reason: path);
      // The shape of the hand-rolled version: a Stack of decoration boxes with
      // a transparent TextField laid over it.
      expect(source, isNot(contains('AutofillHints.oneTimeCode')),
          reason: '$path is building its own code field again');
    }
  });
}
