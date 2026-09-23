import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_input_bar_widget.dart';
import 'package:jperg_app/components/comments/comment_sheet_shell.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/emoji_panel.dart';

/// The sheet's one line of chrome, and the composer under it.
///
/// Both pin down a subtraction: the header used to name the post, which is on
/// screen directly above the sheet, and the composer used to carry a second
/// door to the emoji picker the keyboard already has.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  setUp(() {
    // A phone, not the 800x600 test window: every size in the sheet is scaled
    // off a 390-point design width, so the default window inflates the type by
    // 2x and nothing lands where it does on a device.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  group('the header', () {
    testWidgets('names the surface and the order, never the post', (t) async {
      await t.pumpWidget(host(const CommentSheetShell(
        title: 'Comments',
        sort: CommentSort.newest,
        onSortChanged: _ignore,
        child: SizedBox.expand(),
      )));

      expect(find.text('Comments'), findsOneWidget);
      // The order is readable without opening anything — the question a reader
      // of a busy thread has before they have scrolled it.
      expect(find.text('Newest'), findsOneWidget);
    });

    testWidgets('offers both orders and reports the one chosen', (t) async {
      CommentSort? chosen;
      await t.pumpWidget(host(StatefulBuilder(
        builder: (_, __) => CommentSheetShell(
          title: 'Comments',
          sort: CommentSort.newest,
          onSortChanged: (value) => chosen = value,
          child: const SizedBox.expand(),
        ),
      )));

      await t.tap(find.text('Newest'));
      await t.pumpAndSettle();

      expect(find.text('Newest first'), findsOneWidget);
      expect(find.text('Oldest first'), findsOneWidget);

      await t.tap(find.text('Oldest first'));
      await t.pumpAndSettle();

      expect(chosen, CommentSort.oldest);
    });

    testWidgets('drawn only where there is a say in it', (t) async {
      await t.pumpWidget(host(const CommentSheetShell(
        title: 'Comments',
        child: SizedBox.expand(),
      )));

      expect(find.text('Comments'), findsOneWidget);
      expect(find.byType(PopupMenuButton<CommentSort>), findsNothing);
    });
  });

  group('the order', () {
    // Every surface is fed a newest-first list — the chat room sorts its
    // messages that way, the feed's endpoint returns them that way — so this
    // is the one place that knows which way round "apply" turns them.
    const newestFirst = ['c', 'b', 'a'];

    test('newest is the list as it arrives', () {
      expect(CommentSort.newest.apply(newestFirst), newestFirst);
    });

    test('oldest turns it over', () {
      expect(CommentSort.oldest.apply(newestFirst), ['a', 'b', 'c']);
    });

    test('neither touches the list it was given', () {
      final source = [...newestFirst];
      CommentSort.oldest.apply(source);
      expect(source, newestFirst, reason: 'the bloc still owns this list');
    });
  });

  testWidgets('the composer has no emoji button of its own', (t) async {
    // Every keyboard this app runs under has one. A second door to the same
    // picker cost a button beside the field and a keyboard that closed and
    // reopened as the two traded focus.
    final controller = TextEditingController();
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await t.pumpWidget(host(Builder(
      builder: (context) => Align(
        alignment: Alignment.bottomCenter,
        child: CommentInputBarWidget(
          controller: controller,
          focusNode: focusNode,
          onSend: () {},
          ext: Theme.of(context).extension<AppThemeExtension>()!,
        ),
      ),
    )));

    expect(find.byType(EmojiButton), findsNothing);
    expect(find.byType(EmojiPickerPanel), findsNothing);
    // The field and the send button are still there — this removed a button,
    // not the bar.
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}

void _ignore(CommentSort _) {}
