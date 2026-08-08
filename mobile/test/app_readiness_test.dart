import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/app_readiness.dart';

void main() {
  setUp(AppReadiness.resetForTest);

  testWidgets('does not flip synchronously, and does not stall when idle',
      (t) async {
    var fired = 0;
    void l() => fired++;
    AppReadiness.isReady.addListener(l);

    // Static tree: nothing schedules a frame on its own. A bare
    // addPostFrameCallback would never run here and the link would die silently.
    await t.pumpWidget(const SizedBox());
    AppReadiness.markReady();
    expect(AppReadiness.isReady.value, isFalse,
        reason: 'must not flip inside the caller\'s synchronous span');

    await t.pump();
    expect(AppReadiness.isReady.value, isTrue,
        reason: 'ensureVisualUpdate must guarantee the frame that flips it');
    expect(fired, 1);

    AppReadiness.markReady();
    await t.pump();
    expect(fired, 1, reason: 'idempotent');
    AppReadiness.isReady.removeListener(l);
  });

  testWidgets('a listener that pushes raises nothing and still opens the link',
      (t) async {
    final nav = GlobalKey<NavigatorState>();
    await t.pumpWidget(MaterialApp(
      navigatorKey: nav,
      home: const Scaffold(body: Text('splash')),
    ));

    AppReadiness.isReady.addListener(() {
      nav.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('deep'))));
    });

    // The real shape: splash replaces the top, then marks ready immediately.
    nav.currentState!.pushReplacement(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('home'))));
    AppReadiness.markReady();

    await t.pumpAndSettle();
    expect(TestWidgetsFlutterBinding.instance.takeException(), isNull);
    expect(find.text('deep'), findsOneWidget, reason: 'held link followed');
  });
}
