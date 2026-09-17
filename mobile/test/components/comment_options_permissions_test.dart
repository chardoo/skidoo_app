import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_dialogs.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Who is offered what on a comment.
///
/// Two grants, and deliberately not the same one:
///
///   * **Edit** — the author alone. Changing what somebody said under their own
///     name is not moderation.
///   * **Delete** — the author, or the creator of the content it sits on. A
///     photographer has to be able to take something off their own album.
///
/// The server enforces both. This is about not offering an option that would
/// come back 403, which reads as the app being broken rather than as a rule.
void main() {
  Future<void> open(
    WidgetTester t, {
    required bool canEdit,
    required bool canDelete,
  }) async {
    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => showCommentOptionsSheet(
                context,
                ext: Theme.of(context).extension<AppThemeExtension>()!,
                canEdit: canEdit,
                canDelete: canDelete,
                onEdit: () {},
                onDelete: () {},
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));
    await t.tap(find.text('open'));
    await t.pumpAndSettle();
  }

  final edit = find.text('Edit comment');
  final del = find.text('Delete comment');

  testWidgets('the author is offered both', (t) async {
    await open(t, canEdit: true, canDelete: true);

    expect(edit, findsOneWidget);
    expect(del, findsOneWidget);
  });

  testWidgets('the creator is offered delete and not edit', (t) async {
    // The heart of the rule. They may moderate their album; they may not put
    // words in somebody's mouth.
    await open(t, canEdit: false, canDelete: true);

    expect(edit, findsNothing);
    expect(del, findsOneWidget);
  });

  testWidgets('edit without delete is possible on its own', (t) async {
    // Not a combination the app produces today — the author always has both —
    // but the two are separately granted, so neither may assume the other.
    await open(t, canEdit: true, canDelete: false);

    expect(edit, findsOneWidget);
    expect(del, findsNothing);
  });

  testWidgets('a stranger gets no sheet at all', (t) async {
    // An empty sheet reads as a broken screen rather than as "you may not do
    // this", so it does not open.
    await open(t, canEdit: false, canDelete: false);

    expect(edit, findsNothing);
    expect(del, findsNothing);
    expect(find.byType(BottomSheet), findsNothing);
  });
}
