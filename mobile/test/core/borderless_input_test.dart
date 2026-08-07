import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/search_field.dart';
import 'package:jperg_app/core/theme/app_input.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_top_bar.dart';

/// [Styles.themeData] sizes text with `.sp`, so it can only be built once
/// ScreenUtil has been initialised — which is why every case here is a widget
/// test rather than a plain one.
Widget host(bool dark, Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: Styles.themeData(dark),
        home: Scaffold(body: child),
      ),
    );

/// The decoration the field will actually paint, after the app theme has
/// filled in every slot the call site left empty. That merge is what used to
/// reintroduce the outline, so it is the thing worth asserting.
InputDecoration resolvedDecoration(WidgetTester t) {
  final theme = Theme.of(t.element(find.byType(TextField)));
  return t
      .widget<TextField>(find.byType(TextField))
      .decoration!
      .applyDefaults(theme.inputDecorationTheme);
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  for (final (name, dark) in [('dark', true), ('light', false)]) {
    group('$name theme', () {
      testWidgets('defines no per-state border for a call site to fight',
          (t) async {
        // The bug: a theme-level `focusedBorder` outranks the call site's
        // `border`, so `InputBorder.none` was silently ignored on focus. The
        // theme's `border` is the single source for every state now.
        late InputDecorationThemeData input;
        await t.pumpWidget(host(
          dark,
          Builder(builder: (context) {
            input = Theme.of(context).inputDecorationTheme;
            return const SizedBox();
          }),
        ));

        expect(input.focusedBorder, isNull);
        expect(input.enabledBorder, isNull);
        // Ordinary form fields still get their outline from here.
        expect(input.border, isA<OutlineInputBorder>());
      });

      testWidgets('the shared SearchField draws no inner outline', (t) async {
        await t.pumpWidget(
            host(dark, SearchField(controller: TextEditingController())));

        final decoration = resolvedDecoration(t);
        expect(decoration.border, InputBorder.none);
        expect(decoration.focusedBorder, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
      });

      testWidgets('the search bar draws no inner outline, focused or not',
          (t) async {
        // Focus is what surfaced the regression in the first place: the bar
        // autofocuses, so the very first frame the user sees had two outlines.
        final focusNode = FocusNode();
        await t.pumpWidget(host(
          dark,
          SearchTopBar(
            controller: TextEditingController(text: 'Hussein'),
            focusNode: focusNode,
            onChanged: (_) {},
            onSubmitted: (_) {},
            onBack: () {},
          ),
        ));
        await t.pump();

        expect(focusNode.hasFocus, isTrue, reason: 'the field autofocuses');
        final decoration = resolvedDecoration(t);
        expect(decoration.focusedBorder, InputBorder.none);
        expect(decoration.border, InputBorder.none);
        expect(decoration.enabledBorder, InputBorder.none);
      });

      testWidgets('a field that does not opt out keeps the theme outline',
          (t) async {
        // The fix must not strip the border from ordinary form fields.
        await t.pumpWidget(host(
          dark,
          const TextField(decoration: InputDecoration(hintText: 'Email')),
        ));

        expect(resolvedDecoration(t).border, isA<OutlineInputBorder>());
      });
    });
  }

  test('kBorderlessInput survives copyWith', () {
    // copyWith is how every call site adds its hint and padding; it must not
    // drop the cleared slots on the way through.
    final decoration = kBorderlessInput.copyWith(hintText: 'Search');

    expect(decoration.hintText, 'Search');
    for (final border in [
      decoration.border,
      decoration.enabledBorder,
      decoration.focusedBorder,
      decoration.disabledBorder,
      decoration.errorBorder,
      decoration.focusedErrorBorder,
    ]) {
      expect(border, InputBorder.none);
    }
  });

  test('kBorderlessInput cannot be reopened by a theme that defines borders',
      () {
    // Guards the call sites against the theme regressing: even a theme that
    // sets every state border cannot put an outline back.
    final decoration = kBorderlessInput.applyDefaults(
      const InputDecorationTheme(
        border: OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(),
        focusedBorder: OutlineInputBorder(),
      ),
    );

    expect(decoration.border, InputBorder.none);
    expect(decoration.enabledBorder, InputBorder.none);
    expect(decoration.focusedBorder, InputBorder.none);
  });
}
