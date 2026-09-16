import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_row_data.dart';
import 'package:jperg_app/components/comments/threaded_comment_widget.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Expanding a comment's thread is a round trip, not a reveal.
///
/// A comment room's history is top-level only, so the replies are fetched when
/// somebody asks for them. The widget used to draw the thread only once the
/// replies were in hand — so between the tap and the response the toggle
/// flipped to "Hide replies" and nothing else happened at all, which on a slow
/// connection is seconds of a control that looks broken.
CommentRowData _row(String id, {int replyCount = 0}) => CommentRowData(
      id: id,
      label: 'Ama',
      content: 'comment $id',
      timeLabel: '2h',
      isMe: false,
      replyCount: replyCount,
    );

Widget _host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    );

Widget _thread({
  required bool isExpanded,
  bool isLoadingReplies = false,
  List<CommentRowData> replies = const [],
  int replyCount = 3,
}) =>
    ThreadedCommentWidget(
      comment: _row('c1', replyCount: replyCount),
      replies: replies,
      ext: AppThemeExtension.dark,
      isExpanded: isExpanded,
      isLoadingReplies: isLoadingReplies,
      onToggleReplies: () {},
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('the toggle', () {
    testWidgets('offers the thread on the server count alone', (t) async {
      // Before the replies exist locally. This is the whole point: the sheet
      // has the number and none of the text until somebody asks.
      await t.pumpWidget(_host(_thread(isExpanded: false)));

      expect(find.text('3 replies'), findsOneWidget);
    });

    testWidgets('says reply, singular, for one', (t) async {
      await t.pumpWidget(_host(_thread(isExpanded: false, replyCount: 1)));

      expect(find.text('1 reply'), findsOneWidget);
    });

    testWidgets('a comment with no thread offers nothing', (t) async {
      await t.pumpWidget(_host(_thread(isExpanded: false, replyCount: 0)));

      expect(find.textContaining('repl'), findsNothing);
    });
  });

  group('while the thread is on its way', () {
    testWidgets('something happens', (t) async {
      await t.pumpWidget(_host(
        _thread(isExpanded: true, isLoadingReplies: true),
      ));

      // The regression: expanded, nothing fetched yet, and the widget drew
      // nothing but a relabelled toggle.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('and it stops once they arrive', (t) async {
      await t.pumpWidget(_host(_thread(
        isExpanded: true,
        replies: [_row('r1'), _row('r2')],
      )));

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('comment r1'), findsOneWidget);
      expect(find.text('comment r2'), findsOneWidget);
    });

    testWidgets('a thread being paged keeps what it already has', (t) async {
      await t.pumpWidget(_host(_thread(
        isExpanded: true,
        isLoadingReplies: true,
        replies: [_row('r1')],
      )));

      // Below the replies already in hand, so the list does not jump.
      expect(find.text('comment r1'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('collapsed means collapsed, spinner or not', (t) async {
      await t.pumpWidget(_host(
        _thread(isExpanded: false, isLoadingReplies: true),
      ));

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
