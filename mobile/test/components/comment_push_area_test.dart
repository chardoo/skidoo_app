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
  /// The rect the pushed child actually occupies.
  ///
  /// Measured off the child rather than read off any wrapper widget: what the
  /// user sees is where the media ends up, and that is the only thing worth
  /// asserting on.
  Rect paintedRect(WidgetTester t) => t.getRect(find.byKey(const Key('page')));

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

  /// The card as the real feeds build it: inside a vertical [PageView], which
  /// hands its pages **tight** constraints.
  Widget tightHost() => MaterialApp(
        home: Scaffold(
          body: PageView(
            scrollDirection: Axis.vertical,
            children: [
              CommentPushArea(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    const SizedBox.expand(key: Key('page')),
                    Builder(
                      builder: (context) => TextButton(
                        onPressed: () => showCommentSheet<void>(
                          context,
                          builder: (_) => const SizedBox(height: 300),
                        ),
                        child: const Text('comments'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  setUp(CommentSheetScope.reset);
  tearDown(CommentSheetScope.reset);

  testWidgets('inserts no extra box while no sheet is open', (t) async {
    // Not a box sized to the full screen — no box at all. This widget wraps
    // every feed card and photo viewer in the app, so its resting state has to
    // be free.
    await t.pumpWidget(host());

    expect(
      find.descendant(
        of: find.byType(CommentPushArea),
        matching: find.byType(OverflowBox),
      ),
      findsNothing,
    );
  });

  testWidgets('the media fills the strip — full width, not a centred thumbnail',
      (t) async {
    // The bug this replaced: a uniform scale-down shrank the width along with
    // the height, leaving a small photo marooned mid-band with empty margins
    // either side. The designs fill that band edge to edge.
    await t.pumpWidget(host());
    final screen = t.getSize(find.byType(MaterialApp));

    await t.tap(find.text('comments'));
    await t.pumpAndSettle();

    final media = paintedRect(t);
    expect(media.height,
        closeTo(screen.height * (1 - kCommentSheetFraction), 1));
    expect(media.width, closeTo(screen.width, 0.5),
        reason: 'the media must span the full width of the strip');
  });

  testWidgets('pushes under TIGHT constraints — the shape the real feeds use',
      (t) async {
    // Every feed card and photo viewer is a PageView page, and a PageView
    // hands its pages tight constraints. Under a tight constraint a box cannot
    // make itself shorter than its parent says, so a SizedBox-based push
    // silently does nothing there and the old look stays on screen. A Scaffold
    // body hands out loose constraints, so testing only through [host] would
    // report success either way. Hence this one.
    await t.pumpWidget(tightHost());
    final screen = t.getSize(find.byType(MaterialApp));

    await t.tap(find.text('comments'));
    await t.pumpAndSettle();

    expect(
      t.getRect(find.byKey(const Key('page'))).height,
      closeTo(screen.height * (1 - kCommentSheetFraction), 1),
      reason: 'a layout push that ignores tight constraints does nothing here',
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
    expect(paintedRect(t).height, lessThan(resting));

    Navigator.of(t.element(find.text('comments'))).pop();
    await t.pumpAndSettle();

    expect(paintedRect(t).height, closeTo(resting, 0.5));
  });

  group('the media stays live behind the sheet', () {
    // A modal barrier spans the whole screen and wins the gesture arena for
    // every pointer that lands on it, colour or no colour. That made the band
    // above the sheet a picture of a carousel rather than a carousel. The
    // reader has to be able to swipe a post's photos while reading about them.
    Widget carouselHost(PageController controller,
            {bool allowMediaGestures = true}) =>
        MaterialApp(
          home: Scaffold(
            body: CommentPushArea(
              child: Stack(fit: StackFit.expand, children: [
                PageView(
                  controller: controller,
                  children: const [
                    ColoredBox(color: Color(0xFFFF0000)),
                    ColoredBox(color: Color(0xFF00FF00)),
                  ],
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showCommentSheet<void>(
                        context,
                        allowMediaGestures: allowMediaGestures,
                        builder: (_) => const SizedBox(height: 300),
                      ),
                      child: const Text('comments'),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        );

    testWidgets('the carousel still swipes with the sheet open', (t) async {
      final controller = PageController();
      addTearDown(controller.dispose);
      await t.pumpWidget(carouselHost(controller));

      await t.tap(find.text('comments'));
      await t.pumpAndSettle();
      expect(controller.page, 0.0);

      // Inside the band, well above the sheet's top edge.
      await t.dragFrom(const Offset(600, 80), const Offset(-400, 0));
      await t.pumpAndSettle();

      expect(controller.page, 1.0, reason: 'the swipe must reach the carousel');
      expect(CommentSheetScope.isOpen, isTrue,
          reason: 'swiping the photo must not close the comments');
    });

    testWidgets('a viewer keeps the band sealed — one photo, one thread',
        (t) async {
      // The opposite case, and it is not a nicety. A viewer is a PageView of
      // unrelated photos and its sheet is bound to one picture id, so a swipe
      // that reached the carousel would leave the reader under photo B looking
      // at photo A's comments, with a like button wired to A.
      final controller = PageController();
      addTearDown(controller.dispose);
      await t.pumpWidget(carouselHost(controller, allowMediaGestures: false));

      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      await t.dragFrom(const Offset(600, 80), const Offset(-400, 0));
      await t.pumpAndSettle();

      expect(controller.page, 0.0,
          reason: 'the viewer must not swipe off the commented photo');
    });

    testWidgets('tapping the media does not dismiss the sheet', (t) async {
      // It is the subject of the conversation, not somewhere "outside" the
      // sheet. Dismissal is the ✕, a downward drag, or back.
      final controller = PageController();
      addTearDown(controller.dispose);
      await t.pumpWidget(carouselHost(controller));

      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      await t.tapAt(const Offset(400, 60));
      await t.pumpAndSettle();

      expect(CommentSheetScope.isOpen, isTrue);
    });
  });

  group('a column-shaped card', () {
    // header / media / reaction bar. A Column does not shrink to fit, so the
    // strip-height box the media-shaped cards get would overflow it — stripes
    // in debug, silently clipped in release. Those cards opt out and are
    // clipped to the band instead.
    Widget columnHost() => MaterialApp(
          home: Scaffold(
            body: ListView(children: [
              CommentPushArea(
                fillsBand: false,
                child: Column(children: [
                  Container(height: 60, color: Colors.grey),
                  Container(height: 500, color: Colors.blue, key: const Key('page')),
                  Builder(
                    builder: (context) => TextButton(
                      onPressed: () => showCommentSheet<void>(
                        context,
                        builder: (_) => const SizedBox(height: 300),
                      ),
                      child: const Text('comments'),
                    ),
                  ),
                ]),
              ),
            ]),
          ),
        );

    testWidgets('does not overflow', (t) async {
      await t.pumpWidget(columnHost());
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      // pumpAndSettle rethrows the overflow FlutterError, so getting here is
      // the assertion. Confirm nothing was swallowed either.
      expect(t.takeException(), isNull);
    });

    testWidgets('is still clipped to the band', (t) async {
      await t.pumpWidget(columnHost());
      final screen = t.getSize(find.byType(MaterialApp));

      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      final clip = find.descendant(
        of: find.byType(CommentPushArea),
        matching: find.byType(ClipRect),
      );
      final clipper = t.widget<ClipRect>(clip).clipper!;
      expect(
        clipper.getClip(t.getSize(clip)).height,
        closeTo(screen.height * (1 - kCommentSheetFraction), 1),
      );
    });
  });

  group('CommentSheetHide', () {
    Widget hideHost() => MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showCommentSheet<void>(
                      context,
                      builder: (_) => const SizedBox(height: 300),
                    ),
                    child: const Text('comments'),
                  ),
                ),
                const CommentSheetHide(child: Text('like', key: Key('rail'))),
              ],
            ),
          ),
        );

    double railOpacity(WidgetTester t) => t
        .widget<Opacity>(find
            .ancestor(
              of: find.byKey(const Key('rail')),
              matching: find.byType(Opacity),
            )
            .first)
        .opacity;

    testWidgets('the engagement rail is there with no sheet open', (t) async {
      await t.pumpWidget(hideHost());
      expect(railOpacity(t), 1);
    });

    testWidgets('the engagement rail goes when the sheet opens', (t) async {
      await t.pumpWidget(hideHost());
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();
      expect(railOpacity(t), 0);
    });

    testWidgets('a hidden rail takes no taps', (t) async {
      // Still in the tree — removing it would relayout the stack mid-animation
      // — so it has to stop accepting the taps meant for the sheet over it.
      await t.pumpWidget(hideHost());
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      expect(
        t
            .widget<IgnorePointer>(find
                .ancestor(
                  of: find.byKey(const Key('rail')),
                  matching: find.byType(IgnorePointer),
                )
                .first)
            .ignoring,
        isTrue,
      );
    });

    testWidgets('it comes back when the sheet closes', (t) async {
      await t.pumpWidget(hideHost());
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();

      Navigator.of(t.element(find.text('comments'))).pop();
      await t.pumpAndSettle();

      expect(railOpacity(t), 1);
    });
  });

  group('the open flag', () {
    testWidgets('is dropped when the sheet is dismissed by the barrier',
        (t) async {
      // A barrier tap pops the route without telling anyone, which is exactly
      // the case a naive "set false when I close it" would miss.
      await t.pumpWidget(host());
      final screen = t.getSize(find.byType(MaterialApp));
      await t.tap(find.text('comments'));
      await t.pumpAndSettle();
      expect(CommentSheetScope.isOpen, isTrue);

      // Below the media band, where the barrier still is — see the
      // pass-through test above for why the band itself no longer dismisses.
      await t.tapAt(Offset(
        10,
        screen.height * (1 - kCommentSheetFraction) + 10,
      ));
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
