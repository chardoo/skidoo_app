import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_back_button.dart';
import 'package:jperg_app/core/navigation/app_page_routes.dart';
import 'package:jperg_app/core/theme/customThemeData.dart';

/// Going back, from both ends: the arrow looks the same on every screen, and
/// every screen can be dragged off from the leading edge.
///
/// Both used to be true only of the screens that opted in — the ~50 that pass
/// an [AppBackButton] as their `leading`, and the handful pushed with an
/// explicit `CupertinoPageRoute`. The other route into each behaviour is the
/// theme, and that is what these lock down.
Widget app(GlobalKey<NavigatorState> navigator) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        navigatorKey: navigator,
        theme: Styles.dark,
        home: const Scaffold(body: Center(child: Text('first'))),
      ),
    );

void main() {
  testWidgets('the back arrow an AppBar draws for itself is the app arrow',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator));
    await t.pumpAndSettle();

    // No `leading:` — which is how a third of the app's screens are written.
    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(appBar: AppBar(title: const Text('second'))),
    ));
    await t.pumpAndSettle();

    final icon = t.widget<Icon>(
      find.descendant(of: find.byType(BackButton), matching: find.byType(Icon)),
    );
    expect(icon.icon, AppBackButton.icon);
  });

  testWidgets('a pushed screen pops when dragged from the leading edge',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator));
    await t.pumpAndSettle();

    navigator.currentState!.push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('second'))),
    ));
    await t.pumpAndSettle();
    expect(find.text('second'), findsOneWidget);

    await t.dragFrom(const Offset(4, 300), const Offset(500, 0));
    await t.pumpAndSettle();

    expect(find.text('first'), findsOneWidget);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('a horizontally paged screen keeps the drag for itself',
      (t) async {
    final navigator = GlobalKey<NavigatorState>();
    await t.pumpWidget(app(navigator));
    await t.pumpAndSettle();

    // What the photo viewers push: the edge belongs to the pager, so a thumb
    // that lands slightly too far left turns the page instead of leaving.
    navigator.currentState!.push(NoSwipeBackPageRoute<void>(
      builder: (_) => const Scaffold(body: Center(child: Text('viewer'))),
    ));
    await t.pumpAndSettle();

    await t.dragFrom(const Offset(4, 300), const Offset(500, 0));
    await t.pumpAndSettle();

    expect(find.text('viewer'), findsOneWidget);
  });
}
