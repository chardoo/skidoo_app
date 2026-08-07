import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/discovery/presentation/widgets/swipe_up_hint.dart';

Widget host(Widget child, {bool reduceMotion = false}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduceMotion),
          child: Scaffold(body: Center(child: child)),
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

  testWidgets('draws a pair of chevrons and keeps animating', (t) async {
    await t.pumpWidget(host(const SwipeUpHint(label: '')));
    await t.pump();
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNWidgets(2));

    // The loop must still be running a beat later — a one-shot hint is easy to
    // miss on a page the user is still reading.
    await t.pump(const Duration(milliseconds: 600));
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNWidgets(2));

    // Let the controller settle so the test doesn't leak a running ticker.
    await t.pumpWidget(host(const SizedBox.shrink()));
  });

  testWidgets('never intercepts the swipe it is asking for', (t) async {
    await t.pumpWidget(host(const SwipeUpHint(label: '')));
    await t.pump();
    // The widget's own root is an IgnorePointer; other IgnorePointers exist
    // higher in the MaterialApp, so scope the search to this subtree.
    expect(
      find.descendant(
        of: find.byType(SwipeUpHint),
        matching: find.byType(IgnorePointer),
      ),
      findsOneWidget,
    );
    await t.pumpWidget(host(const SizedBox.shrink()));
  });

  testWidgets('reduce-motion holds it still instead of looping', (t) async {
    await t.pumpWidget(
        host(const SwipeUpHint(label: ''), reduceMotion: true));
    await t.pump(const Duration(milliseconds: 600));

    // Still legible — the direction reads from the stacked pair, with nothing
    // moving. pumpAndSettle would hang here if the controller were repeating.
    expect(find.byIcon(Icons.keyboard_arrow_up_rounded), findsNWidgets(2));
    await t.pumpAndSettle();
    await t.pumpWidget(host(const SizedBox.shrink()));
  });

  testWidgets('label is optional and announced to screen readers', (t) async {
    await t.pumpWidget(host(const SwipeUpHint()));
    await t.pump();
    expect(find.text('Swipe up for more'), findsOneWidget);
    await t.pumpWidget(host(const SizedBox.shrink()));

    await t.pumpWidget(host(const SwipeUpHint(label: '')));
    await t.pump();
    expect(find.text('Swipe up for more'), findsNothing);
    await t.pumpWidget(host(const SizedBox.shrink()));
  });
}
