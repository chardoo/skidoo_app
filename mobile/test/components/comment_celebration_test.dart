import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_sheet_shell.dart';
import 'package:jperg_app/core/celebration/comment_milestone.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The confetti, from the sheet's point of view.
///
/// The watcher is [CommentMilestoneWatcher], which the shell wraps around every
/// comment sheet — so this is the one place the wiring can be checked, and the
/// one place it can break for all of them at once.
void main() {
  Widget host() => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme:
              ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: const Scaffold(
            body: CommentSheetShell(child: SizedBox.shrink()),
          ),
        ),
      );

  tearDown(CommentMilestones.instance.consume);

  testWidgets('a milestone comment is celebrated over the sheet', (t) async {
    await t.pumpWidget(host());

    CommentMilestones.instance.report(100);
    // The overlay opens from a post-frame callback — the notifier fires inside
    // a bloc handler, which can land mid-build.
    await t.pump();
    await t.pump();

    expect(find.text('You are the 100th comment 🎉'), findsOneWidget);

    // Let the animation finish so the entry removes itself rather than leaking
    // into the next test.
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('being first says so in its own words', (t) async {
    await t.pumpWidget(host());

    CommentMilestones.instance.report(1);
    await t.pump();
    await t.pump();

    expect(find.text("You're the first to comment 🎉"), findsOneWidget);
    await t.pump(const Duration(seconds: 3));
  });

  testWidgets('an ordinary comment is left alone', (t) async {
    // Almost every comment ever posted takes this path. An interruption here
    // would be the feature's whole cost with none of its point.
    await t.pumpWidget(host());

    CommentMilestones.instance.report(42);
    await t.pump();
    await t.pump();

    expect(find.textContaining('🎉'), findsNothing);
  });

  testWidgets('it clears itself, so a rebuild cannot replay it', (t) async {
    await t.pumpWidget(host());

    CommentMilestones.instance.report(1000);
    await t.pump();
    await t.pump();
    expect(find.textContaining('🎉'), findsOneWidget);

    // Gone by the time the animation is over, and nothing left behind to fire
    // again on the next frame.
    await t.pump(const Duration(seconds: 3));
    expect(find.textContaining('🎉'), findsNothing);
    expect(CommentMilestones.instance.pending.value, isNull);
  });

  testWidgets('the banner is not drawn in the unstyled fallback', (t) async {
    // The banner is inserted into an Overlay, which has no Material ancestor of
    // its own. Text with nothing Material above it falls back to Flutter's
    // unstyled default, and that default is drawn with a double yellow
    // underline on purpose — to make exactly this mistake visible. It was doing
    // its job: the banner shipped with a yellow line struck under the message.
    await t.pumpWidget(host());

    CommentMilestones.instance.report(1);
    await t.pump();
    await t.pump();

    final text = t.widget<Text>(find.text("You're the first to comment 🎉"));
    final style = text.style!;

    expect(style.decoration, TextDecoration.none,
        reason: 'a yellow underline under the message means no Material above');
    // The fallback is also the wrong colour and the wrong size. Asserting the
    // real values pins that the banner is styled by its own code and not by
    // whatever Flutter fell back to.
    expect(style.color, const Color(0xFF14171A));
    expect(style.fontWeight, FontWeight.w700);

    // And a Material really is above it, which is what makes the ink, the
    // shadow and the default text style work at all.
    expect(
      find.ancestor(of: find.byType(Text), matching: find.byType(Material)),
      findsWidgets,
    );

    await t.pump(const Duration(seconds: 3));
  });
}
