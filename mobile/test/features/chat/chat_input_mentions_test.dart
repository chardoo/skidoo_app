import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/presentation/mentions.dart';
import 'package:jperg_app/features/chat/presentation/widgets/chat_input_bar.dart';
import 'package:jperg_app/features/chat/presentation/widgets/mention_picker.dart';
import 'package:jperg_app/models/chat/chat_room.dart';

ChatParticipant _p(String id, String name) => ChatParticipant(
      userId: id,
      userRole: 'user',
      userName: name,
      joinedAt: DateTime(2026, 8, 24),
    );

final _people = [
  _p('u1', 'Devon A'),
  _p('u2', 'Michael B D'),
  _p('u3', 'Sara Johnson'),
];

Widget host(TextEditingController controller,
        {List<ChatParticipant>? candidates}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: ChatInputBar(
              controller: controller,
              onSend: () {},
              ext: AppThemeExtension.light,
              mentionCandidates: candidates ?? _people,
              mentionHandles: Mentions.handlesFor(candidates ?? _people),
            ),
          ),
        ),
      ),
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

  testWidgets('typing @ opens the picker with every member', (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(host(controller));
    expect(find.byType(MentionPicker), findsNothing);

    controller.value = const TextEditingValue(
      text: "Let's ask @",
      selection: TextSelection.collapsed(offset: 11),
    );
    await t.pump();

    expect(find.byType(MentionPicker), findsOneWidget);
    expect(find.text('Devon A'), findsOneWidget);
    expect(find.text('Michael B D'), findsOneWidget);
    expect(find.text('Sara Johnson'), findsOneWidget);
  });

  testWidgets('the list narrows as the handle is typed', (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(host(controller));

    controller.value = const TextEditingValue(
      text: "Let's ask @d",
      selection: TextSelection.collapsed(offset: 12),
    );
    await t.pump();

    expect(find.text('Devon A'), findsOneWidget);
    expect(find.text('Sara Johnson'), findsNothing);
  });

  testWidgets('picking a member inserts their handle and closes the picker',
      (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(host(controller));

    controller.value = const TextEditingValue(
      text: "Let's ask @d",
      selection: TextSelection.collapsed(offset: 12),
    );
    await t.pump();
    await t.tap(find.text('Devon A'));
    await t.pump();

    expect(controller.text, "Let's ask @devon_a ");
    expect(controller.selection.baseOffset, controller.text.length);
    expect(find.byType(MentionPicker), findsNothing);
  });

  testWidgets('a DM never opens the picker', (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(host(controller, candidates: const []));

    controller.value = const TextEditingValue(
      text: 'mail me at sam@',
      selection: TextSelection.collapsed(offset: 15),
    );
    await t.pump();

    expect(find.byType(MentionPicker), findsNothing);
  });

  testWidgets('an email address does not open the picker', (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(host(controller));

    controller.value = const TextEditingValue(
      text: 'write to sam@dev',
      selection: TextSelection.collapsed(offset: 16),
    );
    await t.pump();

    expect(find.byType(MentionPicker), findsNothing);
  });

  testWidgets('the picker closes once the mention is finished', (t) async {
    final controller = TextEditingController();
    await t.pumpWidget(host(controller));

    controller.value = const TextEditingValue(
      text: '@devon_a',
      selection: TextSelection.collapsed(offset: 8),
    );
    await t.pump();
    expect(find.byType(MentionPicker), findsOneWidget);

    controller.value = const TextEditingValue(
      text: '@devon_a thanks',
      selection: TextSelection.collapsed(offset: 15),
    );
    await t.pump();
    expect(find.byType(MentionPicker), findsNothing);
  });
}
