import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/components/comments/comment_input_bar_widget.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';

/// Editing a comment happens in the composer, not in a dialog.
///
/// It used to open an AlertDialog over the sheet, which covers the thread the
/// comment belongs to — you rewrote it with no sight of what you were replying
/// to or what you had said above it. The chat room has always loaded a message
/// into its composer instead, and a comment sheet is a conversation by another
/// name.
Widget _host({String? editingContent, String? replyingToName, VoidCallback? onCancelEdit}) {
  final ctrl = TextEditingController();
  return ScreenUtilInit(
    designSize: const Size(390, 844),
    builder: (_, __) => MaterialApp(
      theme:
          ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
      home: Scaffold(
        body: CommentInputBarWidget(
          controller: ctrl,
          focusNode: FocusNode(),
          onSend: () {},
          ext: AppThemeExtension.dark,
          replyingToName: replyingToName,
          editingContent: editingContent,
          onCancelEdit: onCancelEdit,
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('composing a new comment', () {
    testWidgets('says nothing about editing', (t) async {
      await t.pumpWidget(_host());

      expect(find.text('Edit comment'), findsNothing);
      expect(find.byIcon(Icons.send_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNothing);
    });
  });

  group('editing one', () {
    testWidgets('a banner says which comment is being changed', (t) async {
      await t.pumpWidget(_host(editingContent: 'the light is unreal'));

      expect(find.text('Edit comment'), findsOneWidget);
      // The words about to be typed over. The composer holds the same text,
      // so this is the only thing left on screen saying what is changing.
      expect(find.text('the light is unreal'), findsOneWidget);
    });

    testWidgets('send becomes a confirm', (t) async {
      await t.pumpWidget(_host(editingContent: 'x'));

      // A check, not a paper plane — nothing new is being sent.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.send_rounded), findsNothing);
    });

    testWidgets('the field says what it is for', (t) async {
      await t.pumpWidget(_host(editingContent: 'x'));

      expect(
        t.widget<TextField>(find.byType(TextField)).decoration!.hintText,
        'Edit your comment…',
      );
    });

    testWidgets('it can be abandoned', (t) async {
      var cancelled = false;
      await t.pumpWidget(
          _host(editingContent: 'x', onCancelEdit: () => cancelled = true));

      await t.tap(find.bySemanticsLabel('Cancel edit'));

      expect(cancelled, isTrue);
    });

    testWidgets('an edit takes the composer from a reply', (t) async {
      // Both own the composer. A reply left staged would be attached to
      // nothing once the edit applied, so the banner shows one or the other.
      await t.pumpWidget(
          _host(editingContent: 'x', replyingToName: 'Kofi'));

      expect(find.text('Edit comment'), findsOneWidget);
      expect(find.textContaining('Replying to'), findsNothing);
    });
  });
}
