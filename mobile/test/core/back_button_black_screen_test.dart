import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';

/// The black screen: Back with nothing underneath.
///
/// [AppBackButton]'s own default is `maybePop`, which does nothing when there
/// is nothing to go back to. But around 25 screens override `onPressed` with a
/// bare `Navigator.pop()` — they have a result to return, and `pop` is the
/// obvious way to return one. On any path where that screen is the only route
/// on the stack, its arrow empties the navigator and the app renders nothing at
/// all. Which path that is decides whether it happens, so the same button works
/// every time until it doesn't.
Widget app(Widget home, {GlobalKey<NavigatorState>? navigator}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        theme: Styles.dark,
        home: home,
      ),
    );

/// A screen written the way the app writes one now: the arrow returns a result
/// without reaching for `Navigator.pop`.
Widget screen(String label, {Object? result}) => Scaffold(
      appBar: AppBar(leading: AppBackButton(result: result)),
      body: Center(child: Text(label)),
    );

void main() {
  testWidgets('the last route survives its own back arrow', (t) async {
    await t.pumpWidget(app(screen('only')));
    await t.pumpAndSettle();

    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();

    // Popping here would leave the navigator with no routes — the black screen.
    expect(find.text('only'), findsOneWidget);
  });

  testWidgets('a pushed screen still goes back normally', (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(
      const Scaffold(body: Center(child: Text('beneath'))),
      navigator: navigator,
    ));
    await t.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => screen('pushed'),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();

    expect(find.text('beneath'), findsOneWidget);
    expect(find.text('pushed'), findsNothing);
  });

  testWidgets('the result a screen pops with still arrives', (t) async {
    // The guard must not cost the screens their return value — that is why
    // they were written with a bare `pop` in the first place.
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(
      const Scaffold(body: Center(child: Text('beneath'))),
      navigator: navigator,
    ));
    await t.pumpAndSettle();

    final popped = navigator.currentState!.push(MaterialPageRoute<Object?>(
      builder: (_) => screen('pushed', result: 'changed'),
    ));
    await t.pumpAndSettle();

    await t.tap(find.byType(AppBackButton));
    await t.pumpAndSettle();

    expect(await popped, 'changed');
  });

  testWidgets('a second press during the exit does not take another route',
      (t) async {
    // Two routes go missing for one press when a stale press lands while the
    // route is still animating out: the widget is not disposed until the
    // transition ends, so `mounted` is still true and the handler still runs —
    // but the navigator has already moved on, so the second pop takes the page
    // underneath. From a shallow stack that is the black screen again.
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(
      const Scaffold(body: Center(child: Text('root'))),
      navigator: navigator,
    ));
    await t.pumpAndSettle();

    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => screen('middle')));
    await t.pumpAndSettle();
    navigator.currentState!
        .push(MaterialPageRoute<void>(builder: (_) => screen('top')));
    await t.pumpAndSettle();

    final arrow = find.byType(AppBackButton).last;
    await t.tap(arrow, warnIfMissed: false);
    // No settle: the route is mid-exit and its subtree is still mounted.
    await t.pump(const Duration(milliseconds: 40));
    await t.tap(arrow, warnIfMissed: false);
    await t.pumpAndSettle();

    expect(find.text('middle'), findsOneWidget,
        reason: 'one press should cost one route');
  });

  test('no screen reaches past the arrow for its own pop', () {
    // The fix is only a fix while it holds everywhere. `AppBackButton()` and
    // `AppBackButton(result: x)` both decline to pop the last route; a call
    // site that passes its own `pop` closure opts out of that, and it is the
    // natural thing to write when you have a value to return — which is how
    // ~25 screens came to have it.
    //
    // A back arrow that genuinely does something else (a wizard stepping back
    // through its own pages) is fine and stays: it names a method, not a pop.
    final offenders = <String>[];
    final call = RegExp(
      r'AppBackButton\([^)]*onPressed:[^)]*Navigator\.of\(\w+\)\.pop\(',
      dotAll: true,
    );

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (call.hasMatch(source)) offenders.add(entity.path);
    }

    expect(offenders, isEmpty,
        reason: 'these screens can empty the navigator from their back arrow:\n'
            '${offenders.join("\n")}');
  });
}
