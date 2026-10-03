import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/media/media_rail_action.dart';
import 'package:jperg_app/core/common/widgets/reaction_pop.dart';

/// What the heart actually does, measured as the **net** scale arriving at the
/// glyph: every ancestor transform multiplied, which is what the eye sees.
///
/// The pop controller's own value is not enough to test. The bar used to wrap
/// its heart in an `AnimatedSwitcher` keyed on `liked`, which scaled the
/// incoming filled heart in from zero at the same time the pop scaled it up
/// from one — so the glyph measured 0.56 and *grew*, and a like read as the
/// icon being replaced rather than acknowledged. The pop was firing perfectly
/// and was invisible. These tests measure the product, so that cannot recur.
void main() {
  double glyphScale(WidgetTester tester, Finder icon) =>
      tester.renderObject<RenderBox>(icon).getTransformTo(null).storage[0];

  Finder heart() => find.byWidgetPredicate((w) =>
      w is Icon &&
      (w.icon == Icons.favorite_rounded ||
          w.icon == Icons.favorite_border_rounded));

  /// peak, lowest, and how many frames are big enough to register.
  Future<({double peak, double low, int visibleFrames})> trace(
    WidgetTester tester,
  ) async {
    var peak = 1.0, low = 1.0, visible = 0;
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 12));
      if (heart().evaluate().length != 1) continue;
      final s = glyphScale(tester, heart());
      if (s > peak) peak = s;
      if (s < low) low = s;
      if (s > 1.1) visible++;
    }
    return (peak: peak, low: low, visibleFrames: visible);
  }

  void expectReadsAsAPop(
    ({double peak, double low, int visibleFrames}) r, {
    required String surface,
  }) {
    expect(r.peak, greaterThan(1.7),
        reason: '$surface: the glyph never got big enough to notice '
            '(peak ${r.peak.toStringAsFixed(2)})');
    expect(r.low, lessThan(1.0),
        reason: '$surface: no squash after the stretch '
            '(low ${r.low.toStringAsFixed(2)})');
    expect(r.low, greaterThan(0.85),
        reason: '$surface: the glyph collapsed — something else is scaling it '
            'down, which is what an AnimatedSwitcher over the pop does '
            '(low ${r.low.toStringAsFixed(2)})');
    expect(r.visibleFrames, greaterThan(8),
        reason: '$surface: the pop was over too fast to see '
            '(${r.visibleFrames} frames above 1.1)');
  }

  testWidgets('the feed rail heart reads as a pop', (tester) async {
    var liked = false;
    await tester.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: StatefulBuilder(
              builder: (context, setState) => MediaRailAction(
                icon: liked
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                label: '12',
                active: liked,
                onTap: () => setState(() => liked = true),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(heart());
    await tester.pump();
    expectReadsAsAPop(await trace(tester), surface: 'rail');
  });

  testWidgets('the bar heart reads as a pop', (tester) async {
    // The bar's structure: the press dip around the whole control, the pop
    // around the glyph alone, nothing else scaling it.
    var liked = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => GestureDetector(
              onTap: () => setState(() => liked = true),
              child: ReactionPop(
                active: liked,
                feedback: false,
                child: Icon(
                  liked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: 26,
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(heart());
    await tester.pump();
    expectReadsAsAPop(await trace(tester), surface: 'bar');
  });

  testWidgets('an AnimatedSwitcher over the pop would be caught',
      (tester) async {
    // The regression itself, reconstructed: this is what the bar used to do,
    // and it must still measurably collapse the glyph — otherwise the guard
    // above has stopped guarding anything.
    var liked = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: StatefulBuilder(
            builder: (context, setState) => GestureDetector(
              onTap: () => setState(() => liked = true),
              child: ReactionPop(
                active: liked,
                feedback: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.elasticOut,
                  transitionBuilder: (child, anim) =>
                      ScaleTransition(scale: anim, child: child),
                  child: Icon(
                    liked
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    key: ValueKey(liked),
                    size: 26,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(heart());
    await tester.pump();

    // The *incoming* filled heart specifically. Mid-transition both hearts are
    // mounted, and the small one is the whole point — a finder that insists on
    // exactly one glyph skips precisely the frames that show the collapse.
    Finder filled() => find
        .byWidgetPredicate((w) => w is Icon && w.icon == Icons.favorite_rounded);

    var low = 1.0;
    for (var i = 0; i < 45; i++) {
      await tester.pump(const Duration(milliseconds: 12));
      if (filled().evaluate().length != 1) continue;
      final s = glyphScale(tester, filled());
      if (s < low) low = s;
    }
    expect(low, lessThan(0.85),
        reason: 'the switcher should be measurably collapsing the glyph');
  });
}
