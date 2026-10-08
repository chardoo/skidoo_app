/// A reaction only sounds when a finger caused it.
///
/// `ReactionPop` fires on `active` changing, and treated every change as a
/// gesture. But `active` flips for reasons nobody touched:
///
///   * the server's value lands and disagrees with the optimistic one;
///   * a list patches rows in underneath — events finishing their watermarks,
///     say — and the row redraws with fresh values;
///   * a scrolling list recycles a row's widgets onto a *different* item whose
///     reaction happens to differ. This one can fire several at once, from
///     photographs nobody has been near.
///
/// So a quiet screen would clack and buzz on its own while it updated. The
/// widget's own doc already named the hazard — `feedback: false` is documented
/// as being "for a surface where the state can change without the viewer
/// having touched anything" — but the escape hatch was never applied, and
/// opting out one call site at a time is the wrong shape for a rule that holds
/// everywhere.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/reaction_feedback.dart';
import 'package:jperg_app/core/common/widgets/reaction_pop.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    ReactionFeedback.disarm();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'HapticFeedback.vibrate' ||
          call.method == 'SystemSound.play') {
        calls.add(call);
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    ReactionFeedback.disarm();
  });

  Future<void> pump(WidgetTester tester, ValueNotifier<bool> active) =>
      tester.pumpWidget(MaterialApp(
        home: ValueListenableBuilder<bool>(
          valueListenable: active,
          builder: (_, on, __) => ReactionPop(
            active: on,
            child: const Icon(Icons.bookmark_rounded),
          ),
        ),
      ));

  group('a change nobody caused', () {
    testWidgets('turning on is silent', (tester) async {
      final active = ValueNotifier(false);
      await pump(tester, active);
      calls.clear();

      // The server said so, or the row was patched, or the widget was
      // recycled onto a different photograph. No finger either way.
      active.value = true;
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('turning off is silent', (tester) async {
      final active = ValueNotifier(true);
      await pump(tester, active);
      calls.clear();

      active.value = false;
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });

    testWidgets('it still draws the pop', (tester) async {
      // Silent, not invisible. The glyph changing is how the screen says what
      // it now holds; the sound is what claims somebody did it.
      final active = ValueNotifier(false);
      await pump(tester, active);

      active.value = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));

      final t = tester.widget<Transform>(find.descendant(
        of: find.byType(ReactionPop),
        matching: find.byType(Transform),
      ));
      expect(t.transform.storage[0], greaterThan(1.0));
    });

    testWidgets('a whole list patching at once stays quiet', (tester) async {
      // The shape of the complaint: several rows changing in one frame.
      final rows = List.generate(6, (_) => ValueNotifier(false));
      await tester.pumpWidget(MaterialApp(
        home: Column(
          children: [
            for (final row in rows)
              ValueListenableBuilder<bool>(
                valueListenable: row,
                builder: (_, on, __) => ReactionPop(
                  active: on,
                  child: const Icon(Icons.bookmark_rounded),
                ),
              ),
          ],
        ),
      ));
      calls.clear();

      for (final row in rows) {
        row.value = true;
      }
      await tester.pumpAndSettle();

      expect(calls, isEmpty);
    });
  });

  group('a change a finger caused', () {
    testWidgets('turning on taps and clicks', (tester) async {
      final active = ValueNotifier(false);
      await pump(tester, active);
      calls.clear();

      ReactionFeedback.arm();
      active.value = true;
      await tester.pumpAndSettle();

      expect(calls.map((c) => c.method),
          containsAll(['HapticFeedback.vibrate', 'SystemSound.play']));
    });

    testWidgets('turning off taps', (tester) async {
      final active = ValueNotifier(true);
      await pump(tester, active);
      calls.clear();

      ReactionFeedback.arm();
      active.value = false;
      await tester.pumpAndSettle();

      expect(calls.map((c) => c.method), contains('HapticFeedback.vibrate'));
    });

    testWidgets('one tap is one acknowledgement', (tester) async {
      // The arm is consumed. A tap flips the glyph, then the server's answer
      // arrives and flips it back — that second change is reconciliation, not
      // a second like, and must not sound like one.
      final active = ValueNotifier(false);
      await pump(tester, active);
      calls.clear();

      ReactionFeedback.arm();
      active.value = true;
      await tester.pumpAndSettle();
      final afterTap = calls.length;
      expect(afterTap, greaterThan(0));

      active.value = false;
      await tester.pumpAndSettle();

      expect(calls.length, afterTap, reason: 'the arm was already spent');
    });
  });

  group('arming()', () {
    test('runs the handler it wraps', () {
      var ran = false;
      ReactionFeedback.arming(() => ran = true)();
      expect(ran, isTrue);
    });

    test('a null handler stays null, so the control stays hidden', () {
      expect(ReactionFeedback.armingOrNull(null), isNull);
    });
  });

  group('every heart arms its own tap', () {
    const sites = <String, String>{
      'lib/features/discovery/presentation/widgets/card_interaction_bar.dart':
          'like, dislike and bookmark on the event card',
      'lib/components/media/media_rail_action.dart': "the feed rail's actions",
      'lib/components/comments/comment_item_widget.dart': 'a comment row',
      'lib/features/chat/presentation/pages/chat_room_page.dart':
          'liking a message',
    };

    for (final entry in sites.entries) {
      test('${entry.key.split('/').last} — ${entry.value}', () {
        // Every file that draws a ReactionPop has to say when a finger moved,
        // or its reaction is silent for good.
        final source = File(entry.key).readAsStringSync();
        expect(
          source.contains('ReactionFeedback.arm'),
          isTrue,
          reason: '${entry.key} draws a ReactionPop but never arms it',
        );
      });
    }
  });
}
