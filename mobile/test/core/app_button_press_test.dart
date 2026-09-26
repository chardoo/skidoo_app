import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/app_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// What a press does, and what a second press does not.
///
/// Both halves were reported together, and they are the same complaint from two
/// ends: a filled button barely shows Material's ink ripple, so between the tap
/// and whatever the network did next there was nothing on screen saying the tap
/// had landed — and a button that looks inert is a button people press again.
/// On a payment that second press is a second charge.
///
/// The guard is the button's, not the caller's: an `async` handler holds it
/// disabled until the work finishes. Every call site already written as
/// `onPressed: () => _somethingAsync()` gets that without being touched, which
/// is the point of widening the type rather than adding a flag nobody
/// remembers to pass.
void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark()
              .copyWith(extensions: const [AppThemeExtension.dark]),
          home: Scaffold(body: Center(child: child)),
        ),
      );

  group('a slow handler', () {
    testWidgets('runs once however many times it is pressed', (t) async {
      var calls = 0;
      final gate = Completer<void>();
      await t.pumpWidget(host(AppButton(
        label: 'Pay',
        onPressed: () async {
          calls++;
          await gate.future;
        },
      )));

      await t.tap(find.byType(AppButton));
      await t.pump();
      // The impatient second and third taps, while the first is still in the
      // air. This is the reported gesture, not a contrived one.
      await t.tap(find.byType(AppButton), warnIfMissed: false);
      await t.tap(find.byType(AppButton), warnIfMissed: false);
      await t.pump();

      expect(calls, 1);

      gate.complete();
      await t.pumpAndSettle();
    });

    testWidgets('says so, with the spinner in place of the label', (t) async {
      final gate = Completer<void>();
      await t.pumpWidget(host(AppButton(
        label: 'Pay',
        onPressed: () async => gate.future,
      )));

      expect(find.text('Pay'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await t.tap(find.byType(AppButton));
      await t.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Pay'), findsNothing);

      gate.complete();
      await t.pumpAndSettle();
    });

    testWidgets('can be pressed again once it has finished', (t) async {
      // The guard is for the double tap, not a one-shot fuse: a payment that
      // failed has to be retriable.
      var calls = 0;
      var gate = Completer<void>();
      await t.pumpWidget(host(AppButton(
        label: 'Pay',
        onPressed: () async {
          calls++;
          await gate.future;
        },
      )));

      await t.tap(find.byType(AppButton));
      await t.pump();
      gate.complete();
      await t.pumpAndSettle();

      gate = Completer<void>();
      await t.tap(find.byType(AppButton));
      await t.pump();

      expect(calls, 2);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.complete();
      await t.pumpAndSettle();
    });

    testWidgets('lets go of the button when the request fails', (t) async {
      // Otherwise one failed payment leaves a button that can never be pressed
      // again, and the screen has to be left and re-entered to retry — which
      // is the one moment a reader is most likely to try.
      //
      // The handler catches its own failure here because that is what these
      // screens do: they show a snackbar and stay put. What is being checked is
      // the button afterwards, not the error.
      var calls = 0;
      var gate = Completer<void>();
      await t.pumpWidget(host(AppButton(
        label: 'Pay',
        onPressed: () async {
          calls++;
          try {
            await gate.future;
          } catch (_) {
            // Reported to the reader by the screen; swallowed here.
          }
        },
      )));

      await t.tap(find.byType(AppButton));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.completeError(StateError('network'));
      await t.pumpAndSettle();

      // Back to a button, not a spinner — and it works.
      expect(find.text('Pay'), findsOneWidget);

      gate = Completer<void>();
      await t.tap(find.byType(AppButton));
      await t.pump();
      expect(calls, 2);

      gate.complete();
      await t.pumpAndSettle();
    });

    testWidgets('resets even if the handler lets the error escape', (t) async {
      // A handler that does not catch is a bug in that screen, but it must not
      // also leave the button wedged. `finally` is what guarantees that, and
      // this is the test that would notice it being dropped.
      final gate = Completer<void>();
      await t.pumpWidget(host(AppButton(
        label: 'Pay',
        onPressed: () async => gate.future,
      )));

      await t.tap(find.byType(AppButton));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      gate.completeError(StateError('network'));
      await t.pump();
      // The error still reaches the app's error reporting rather than being
      // swallowed by the button.
      expect(t.takeException(), isA<StateError>());
      await t.pumpAndSettle();

      expect(find.text('Pay'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('a handler that is not slow', () {
    testWidgets('is not disabled on the way through', (t) async {
      // A synchronous press — closing a sheet, flipping a filter — must not
      // flash a spinner or swallow the next tap.
      var calls = 0;
      await t.pumpWidget(host(AppButton(label: 'Close', onPressed: () => calls++)));

      await t.tap(find.byType(AppButton));
      await t.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await t.tap(find.byType(AppButton));
      await t.pump();

      expect(calls, 2);
    });
  });

  testWidgets('isLoading still disables it, for work it did not start',
      (t) async {
    // A bloc hands its work off and returns immediately, so there is no future
    // for the button to watch. Those screens pass their own state instead.
    var calls = 0;
    await t.pumpWidget(host(AppButton(
      label: 'Save',
      isLoading: true,
      onPressed: () => calls++,
    )));

    await t.tap(find.byType(AppButton), warnIfMissed: false);
    await t.pump();

    expect(calls, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  /// What the button is currently asking to be scaled to.
  ///
  /// The target rather than the painted matrix: the tween between the two is
  /// [AnimatedScale]'s and does not need testing here. What is ours is which
  /// number it is given, and when.
  double target(WidgetTester t) =>
      t.widget<AnimatedScale>(find.descendant(
        of: find.byType(AppButton),
        matching: find.byType(AnimatedScale),
      )).scale;

  testWidgets('shrinks under the finger and springs back', (t) async {
    await t.pumpWidget(host(AppButton(label: 'Pay', onPressed: () {})));
    expect(target(t), 1);

    final press = await t.startGesture(t.getCenter(find.byType(AppButton)));
    await t.pump();
    expect(target(t), lessThan(1),
        reason: 'the press has to be visible while the finger is down');

    await press.up();
    await t.pumpAndSettle();
    expect(target(t), 1);
  });

  testWidgets('a disabled button does not respond to the finger at all',
      (t) async {
    // Nothing to acknowledge: the press is not going to do anything, and a
    // button that answers a touch it will not act on is worse than one that
    // sits still.
    await t.pumpWidget(host(const AppButton(label: 'Pay')));

    final press = await t.startGesture(t.getCenter(find.byType(AppButton)));
    await t.pump();

    expect(target(t), 1);

    await press.up();
    await t.pumpAndSettle();
  });
}
