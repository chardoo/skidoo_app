import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/features/chat/presentation/typing_announcer.dart';

/// Fake elapsed time as a wall-clock instant, so the announcer's send throttle
/// and its idle timer are driven by the one clock the test controls.
extension on Duration {
  DateTime get asDateTime =>
      DateTime.fromMillisecondsSinceEpoch(inMilliseconds, isUtc: true);
}

/// The bug these pin down: nothing ever announced that typing had *stopped*.
///
/// The composer reports "the field is non-empty" on each edit, so someone who
/// typed a sentence and then paused — text still in the box, which is what
/// people do while they think — emitted no further events at all. No `false`
/// was ever sent, and the indicator on the other screen sat there until the
/// receiver's expiry lapsed, counted from the last throttled frame rather than
/// from when they actually stopped.
void main() {
  group('TypingAnnouncer', () {
    /// Runs [body] with a recorder of every frame the announcer emits.
    void withAnnouncer(
      void Function(TypingAnnouncer typing, List<bool> sent, FakeAsync async)
          body,
    ) {
      fakeAsync((async) {
        final sent = <bool>[];
        // The throttle clock is driven by the same fake time as the timers, so
        // `async.elapse` advances both together.
        final typing = TypingAnnouncer(send: sent.add, clock: () => async.elapsed.asDateTime);
        body(typing, sent, async);
        typing.dispose();
      });
    }

    test('the first keystroke announces typing', () {
      withAnnouncer((typing, sent, _) {
        typing.markTyping();
        expect(sent, [true]);
        expect(typing.isAnnounced, isTrue);
      });
    });

    test('going quiet announces the stop on its own', () {
      withAnnouncer((typing, sent, async) {
        typing.markTyping();
        sent.clear();

        // Still inside the idle window — nothing yet.
        async.elapse(const Duration(seconds: 3));
        expect(sent, isEmpty);

        async.elapse(const Duration(seconds: 2));
        expect(sent, [false], reason: 'idle timeout should announce the stop');
        expect(typing.isAnnounced, isFalse);
      });
    });

    test('a steady typist keeps the deadline pushed out', () {
      withAnnouncer((typing, sent, async) {
        typing.markTyping();
        sent.clear();

        // A keystroke every 2s for 10s — never idle, so never a stop.
        for (var i = 0; i < 5; i++) {
          async.elapse(const Duration(seconds: 2));
          typing.markTyping();
        }
        expect(sent, isNot(contains(false)));

        // And once they do stop, it lands.
        async.elapse(const Duration(seconds: 5));
        expect(sent.last, isFalse);
      });
    });

    test('keystrokes are throttled into at most one frame per interval', () {
      withAnnouncer((typing, sent, async) {
        // Twenty keystrokes inside one second must not be twenty frames.
        for (var i = 0; i < 20; i++) {
          typing.markTyping();
          async.elapse(const Duration(milliseconds: 50));
        }
        expect(sent, [true]);

        // Past the interval, a refresh is allowed through.
        async.elapse(const Duration(seconds: 3));
        typing.markTyping();
        expect(sent.where((s) => s).length, 2);
      });
    });

    test('an explicit stop is never throttled', () {
      withAnnouncer((typing, sent, _) {
        typing.markTyping();
        typing.markStopped();
        expect(sent, [true, false]);
      });
    });

    test('stopping twice announces once', () {
      withAnnouncer((typing, sent, _) {
        typing.markTyping();
        typing.markStopped();
        typing.markStopped();
        expect(sent, [true, false]);
      });
    });

    test('stopping without having started says nothing', () {
      withAnnouncer((typing, sent, _) {
        typing.markStopped();
        expect(sent, isEmpty);
      });
    });

    test('no stray stop fires after an explicit one', () {
      // The idle timer must be cancelled by markStopped, or leaving the room
      // would emit a second, pointless frame moments later.
      withAnnouncer((typing, sent, async) {
        typing.markTyping();
        typing.markStopped();
        sent.clear();

        async.elapse(const Duration(seconds: 30));
        expect(sent, isEmpty);
      });
    });

    test('typing again after a stop re-announces immediately', () {
      // The throttle clock is reset by a stop, so resuming must not be held
      // back by a frame sent before it.
      withAnnouncer((typing, sent, async) {
        typing.markTyping();
        typing.markStopped();
        sent.clear();

        async.elapse(const Duration(milliseconds: 100));
        typing.markTyping();
        expect(sent, [true]);
      });
    });

    test('dispose leaves no timer behind and announces nothing', () {
      fakeAsync((async) {
        final sent = <bool>[];
        final typing = TypingAnnouncer(send: sent.add);
        typing.markTyping();
        sent.clear();

        typing.dispose();
        async.elapse(const Duration(seconds: 30));
        expect(sent, isEmpty);
      });
    });
  });
}
