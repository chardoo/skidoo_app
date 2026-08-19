import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_sheet_scope.dart';

/// The YouTube arrangement: opening comments scales the page up into the strip
/// above the sheet, so the photo being discussed stays whole and lit instead of
/// sitting dimmed behind a modal.
///
/// What these pin down is the coupling — the sheet raising a flag, the page
/// reacting to it, and the flag surviving every way a sheet can close. Get the
/// last one wrong and the page stays shrunk over a screen with no sheet on it,
/// which is unrecoverable without leaving the route.
void main() {
  /// The rect the pushed child is actually painted into.
  ///
  /// Measured rather than read off the widget: [Transform.scale] does not
  /// populate its matrix until the render object is created, so introspecting
  /// the widget reports an identity that never reaches the screen. The global
  /// rect is the thing the user sees, and it is what the scale is *for*.
  Rect paintedRect(WidgetTester t) => t.getRect(find.byKey(const Key('page')));

  /// How much of its own size the child is currently drawn at.
  double paintedScale(WidgetTester t, {required double restingHeight}) =>
      paintedRect(t).height / restingHeight;

  Widget host({Key? childKey}) => MaterialApp(
        home: Scaffold(
          body: CommentPushArea(
            child: SizedBox.expand(
              key: childKey ?? const Key('page'),
              child: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCommentSheet<void>(
                    context,
                    builder: (_) => const SizedBox(height: 300),
                  ),
                  child: const Text('comments'),
                ),
              ),
            ),
          ),
        ),
      );

  setUp(CommentSheetScope.reset);
  tearDown(CommentSheetScope.reset);

  testWidgets('inserts no transform layer while no sheet is open', (t) async {
    // Not a transform of 1.0 — no transform layer at all. This widget wraps
    // every feed card and photo viewer in the app, so its resting state has to
    // be free.
    await t.pumpWidget(host());

    expect(
      find.descendant(
        of: find.byType(CommentPushArea),
        matching: find.byType(Transform),
      ),
      findsNothing,
    );
  });

  testWidgets('scales the page into the strip above the sheet', (t) async {
    await t.pumpWidget(host());
    final resting = paintedRect(t).height;

    await t.tap(find.text('comments'));
    await t.pumpAndSettle();

    // The sheet takes kCommentSheetFraction of the screen; what is left is
    // what the page is drawn into.
    expect(
      paintedScale(t, restingHeight: resting),
      closeTo((1 - kCommentSheetFraction) * 0.94, 0.001),
    );
  });

  testWidgets('anchors to the top, so the photo rises rather than centring',
      (t) async {
    await t.pumpWidget(host());
    final before = paintedRect(t);

    await t.tap(find.text('comments'));
    await t.pumpAndSettle();
    final after = paintedRect(t);

    // Scaled about the top edge: the top stays put and the bottom comes up,
    // which is what lands the photo in the strip rather than shrinking it
    // toward the middle of the screen.
    expect(after.top, closeTo(before.top, 0.5));
    expect(after.bottom, lessThan(before.bottom));
    // And still centred horizontally.
    expect(after.center.dx, closeTo(before.center.dx, 0.5));
  });

  testWidgets('returns to full size when the sheet closes', (t) async {
    await t.pumpWidget(host());
    final resting = paintedRect(t).height;

    await t.tap(find.text('comments'));
    await t.pumpAndSettle();
    expect(paintedScale(t, restingHeight: resting), lessThan(1));

    Navigator.of(t.element(find.text('comments'))).pop();
    await t.pumpAndSettle();

    expect(paintedScale(t, restingHeight: resting), closeTo(1, 0.001));
  });

  group('the open flag', () {
    testWidgets('is dropped when the sheet is dismissed by the barrier',
        (t) async {
      // A barrier tap pops the route without telling anyone, which is exactly
      // the case a naive "set false when I close it" would miss.
      await t.pumpWidget(host());
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();
      expect(CommentSheetScope.isOpen, isTrue);

      await t.tapAt(const Offset(10, 10));
      await t.pumpAndSettle();

      expect(CommentSheetScope.isOpen, isFalse);
    });

    testWidgets('survives overlapping sheets', (t) async {
      // A reply sheet opened from a comment. With a bool rather than a count,
      // closing the inner one would drop the page while the outer was still up.
      await t.pumpWidget(host());
      // Captured before the sheets go up: once two are stacked the button's
      // element is deactivated and cannot be looked up through.
      final nav = Navigator.of(t.element(find.text('comments')));

      showCommentSheet<void>(nav.context, builder: (_) => const Text('outer'));
      await t.pumpAndSettle();
      showCommentSheet<void>(nav.context, builder: (_) => const Text('inner'));
      await t.pumpAndSettle();

      nav.pop();
      await t.pumpAndSettle();

      expect(CommentSheetScope.isOpen, isTrue,
          reason: 'the outer sheet is still open');

      nav.pop();
      await t.pumpAndSettle();

      expect(CommentSheetScope.isOpen, isFalse);
    });

    testWidgets('never goes negative', (t) async {
      // A hot reload, or a route popped by something we never observed. A
      // negative count would leave the page unable to push ever again.
      CommentSheetScope.reset();
      await t.pumpWidget(host());
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      CommentSheetScope.reset();
      Navigator.of(t.element(find.text('comments'))).pop();
      await t.pumpAndSettle();

      expect(CommentSheetScope.openCount.value, greaterThanOrEqualTo(0));
      expect(CommentSheetScope.isOpen, isFalse);
    });
  });

  testWidgets('the sheet lays no scrim over the page', (t) async {
    // The whole point. A dimmed photo behind a sheet is the arrangement this
    // replaced — you could read the comments or look at the photo, not both.
    await t.pumpWidget(host());
    await t.tap(find.text('comments'));
    await t.pumpAndSettle();

    final barriers = t.widgetList<ModalBarrier>(find.byType(ModalBarrier));
    expect(
      barriers.every((b) => b.color == null || b.color!.a == 0),
      isTrue,
      reason: 'a coloured barrier would dim the photo',
    );
  });
}
