import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_item_widget.dart';
import 'package:jperg_app/components/comments/comment_row_data.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// The heart beside Reply, as the design draws it.
///
/// Both controls live on one row and both are optional: a surface that does
/// not offer liking draws no heart rather than a dead one, and the count only
/// appears once somebody has actually pressed it.
void main() {
  Widget host(CommentRowData data) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme:
              ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: Scaffold(
            body: CommentItemWidget(data: data, ext: AppThemeExtension.dark),
          ),
        ),
      );

  CommentRowData row({
    int likeCount = 0,
    bool viewerLiked = false,
    VoidCallback? onLike,
    VoidCallback? onReply,
  }) =>
      CommentRowData(
        id: 'c1',
        label: 'Kofi Kwame',
        content: 'This edit is incredible!',
        timeLabel: '2h ago',
        isMe: false,
        likeCount: likeCount,
        viewerLiked: viewerLiked,
        onLike: onLike,
        onReply: onReply,
      );

  testWidgets('a liked comment shows a filled heart and its count', (t) async {
    await t.pumpWidget(host(row(likeCount: 45, viewerLiked: true, onLike: () {})));

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
    expect(find.text('45'), findsOneWidget);
  });

  testWidgets('an unliked comment shows the outline', (t) async {
    await t.pumpWidget(host(row(likeCount: 45, onLike: () {})));

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_rounded), findsNothing);
  });

  testWidgets('a comment nobody has liked shows no number', (t) async {
    // Not a "0". An unliked comment reads as unliked, rather than as one that
    // was offered a score and got none.
    await t.pumpWidget(host(row(onLike: () {})));

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('the heart reports the tap', (t) async {
    var taps = 0;
    await t.pumpWidget(host(row(likeCount: 3, onLike: () => taps++)));

    await t.tap(find.byIcon(Icons.favorite_border_rounded));
    expect(taps, 1);
  });

  testWidgets('no heart at all where liking is not offered', (t) async {
    // A comment still on its way to the server has no id to file a like
    // against, and a heart that silently does nothing is worse than none.
    await t.pumpWidget(host(row(onReply: () {})));

    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.text('Reply'), findsOneWidget);
  });

  testWidgets('the heart and Reply sit on the same line', (t) async {
    await t.pumpWidget(host(row(likeCount: 18, onLike: () {}, onReply: () {})));

    final heart = t.getRect(find.byIcon(Icons.favorite_border_rounded));
    final reply = t.getRect(find.text('Reply'));

    expect(heart.center.dy, closeTo(reply.center.dy, 4),
        reason: 'one row, as the design draws it');
    expect(heart.right, lessThan(reply.left), reason: 'the heart comes first');
  });

  testWidgets('it says what it is to a screen reader', (t) async {
    await t.pumpWidget(host(row(likeCount: 45, viewerLiked: true, onLike: () {})));

    final semantics = t.widget<Semantics>(
      find
          .ancestor(
            of: find.byIcon(Icons.favorite_rounded),
            matching: find.byType(Semantics),
          )
          .first,
    );
    expect(semantics.properties.label, 'Unlike, 45 likes');
    expect(semantics.properties.selected, isTrue);
  });
}
