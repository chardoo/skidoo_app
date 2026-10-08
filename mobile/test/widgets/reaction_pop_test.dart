import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/reaction_feedback.dart';
import 'package:jperg_app/core/common/widgets/reaction_pop.dart';

/// What a like does when it lands: it pops, the device taps, and the platform
/// clicks — once, on the way in only.
void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });

  List<Object?> argsFor(String method) =>
      calls.where((c) => c.method == method).map((c) => c.arguments).toList();

  /// Just the haptics and sounds. `MaterialApp` talks on this same channel at
  /// startup (`SystemChrome.*`), which is not what any of this is about.
  List<MethodCall> feedback() => calls
      .where((c) =>
          c.method == 'HapticFeedback.vibrate' ||
          c.method == 'SystemSound.play')
      .toList();

  double scaleOf(WidgetTester tester) {
    final t = tester.widget<Transform>(find.descendant(
      of: find.byType(ReactionPop),
      matching: find.byType(Transform),
    ));
    return t.transform.storage[0];
  }

  Future<void> pumpPop(WidgetTester tester, ValueNotifier<bool> active) =>
      tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, on, __) => ReactionPop(
            active: on,
            child: const Icon(Icons.favorite_rounded),
          ),
        ),
      ));

  testWidgets('turning on pops past the old peak and settles back to 1',
      (tester) async {
    final active = ValueNotifier(false);
    await pumpPop(tester, active);
    expect(scaleOf(tester), 1.0);

    active.value = true;
    await tester.pump();

    // Sampled across the whole thing. Two reports of "it does not pop" came
    // from peaks of 1.35 and then 1.55, so the floor here is deliberately
    // well above both.
    var peak = 1.0;
    var low = 1.0;
    for (var i = 0; i < 24; i++) {
      await tester.pump(const Duration(milliseconds: 15));
      final s = scaleOf(tester);
      if (s > peak) peak = s;
      if (s < low) low = s;
    }
    expect(peak, greaterThan(1.7),
        reason: 'the pop has to be unmistakable, not marginally bigger');
    expect(peak, lessThan(2.0), reason: 'and not cartoonish');

    // The squash after the stretch — this is what makes it read as a pop
    // rather than a zoom, and it is the half that was missing.
    expect(low, lessThan(1.0),
        reason: 'it must settle back *through* resting size, not down to it');
    expect(low, greaterThan(0.85), reason: 'a dip, not a second animation');

    // Settled, exactly back to resting size.
    await tester.pumpAndSettle();
    expect(scaleOf(tester), moreOrLessEquals(1.0, epsilon: 0.001));
  });

  testWidgets('turning on taps the device and clicks once', (tester) async {
    final active = ValueNotifier(false);
    await pumpPop(tester, active);
    expect(feedback(), isEmpty, reason: 'nothing fires on first build');

    // A tap, said out loud. Feedback answers a finger, not a value — see
    // ReactionFeedback.arm.
    ReactionFeedback.arm();
    active.value = true;
    await tester.pumpAndSettle();

    expect(argsFor('HapticFeedback.vibrate'),
        ['HapticFeedbackType.mediumImpact']);
    expect(argsFor('SystemSound.play'), ['SystemSoundType.click']);
  });

  testWidgets('turning off is the light tap, and is silent', (tester) async {
    final active = ValueNotifier(true);
    await pumpPop(tester, active);
    calls.clear();

    ReactionFeedback.arm();
    active.value = false;
    await tester.pumpAndSettle();

    expect(
        argsFor('HapticFeedback.vibrate'), ['HapticFeedbackType.lightImpact']);
    expect(argsFor('SystemSound.play'), isEmpty,
        reason: 'the click is the sound of a thing landing, not of an undo');
    expect(scaleOf(tester), 1.0, reason: 'un-liking does not pop');
  });

  testWidgets('a rebuild that changes nothing is silent and still',
      (tester) async {
    final active = ValueNotifier(true);
    await pumpPop(tester, active);
    calls.clear();

    // Same value, pushed again — what a list rebuild or an unrelated state
    // change looks like from in here.
    active.notifyListeners();
    await tester.pumpAndSettle();

    expect(feedback(), isEmpty);
    expect(scaleOf(tester), 1.0);
  });

  testWidgets('feedback: false draws the pop silently', (tester) async {
    final active = ValueNotifier(false);
    await tester.pumpWidget(MaterialApp(
      home: ValueListenableBuilder<bool>(
        valueListenable: active,
        builder: (_, on, __) => ReactionPop(
          active: on,
          feedback: false,
          child: const Icon(Icons.favorite_rounded),
        ),
      ),
    ));

    active.value = true;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    expect(scaleOf(tester), greaterThan(1.0), reason: 'it still pops');
    await tester.pumpAndSettle();
    expect(feedback(), isEmpty);
  });
}
