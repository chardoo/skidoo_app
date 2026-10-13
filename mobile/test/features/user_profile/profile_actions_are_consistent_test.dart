import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/profile_pill_button.dart';
import 'package:jperg_app/core/config/chat_config.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/user_profile/presentation/utils/open_author_profile.dart';
import 'package:jperg_app/features/user_profile/presentation/widgets/profile_actions.dart';
import 'package:jperg_app/services/auth_service.dart';

/// What a profile offers, and whether you can get to one from a comment.
///
/// Two reports, one cause each:
///
///  1. "Searching for an event / photographer / person / tag and tapping
///     through to a photographer shows no Message." The creator profile drew
///     its pair only once an ownership read came back, and dropped Message
///     outright whenever the can-message check said no or had not answered.
///  2. "From a comment I cannot get to the photographer's page." The photo
///     comment sheet wired no author tap at all, and the event thread wired
///     one only for creators.
///
/// Both are now one rule each — [ProfileActions] and [openAuthorProfileTap] —
/// so a new surface gets the behaviour by calling them rather than by
/// remembering it.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

Widget actions({
  required bool isCreator,
  String userId = 'pg-1',
  bool? canMessage,
}) =>
    host(Builder(
      builder: (context) => ProfileActions(
        userId: userId,
        ext: Theme.of(context).extension<AppThemeExtension>()!,
        isCreator: isCreator,
        canMessage: canMessage,
        onMessage: () {},
      ),
    ));

Finder get _message => find.widgetWithText(ProfilePillButton, 'Message');
Finder get _follow => find.widgetWithText(ProfilePillButton, 'Follow');

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
    AuthService.userId.value = 'me';
  });

  tearDown(() => AuthService.userId.value = '');

  group('a creator profile', () {
    testWidgets('offers Follow and Message on the first frame', (t) async {
      // One pump: the frame it is built in. No request has answered, and that
      // is the whole point — this used to wait for two.
      await t.pumpWidget(actions(isCreator: true));
      await t.pump();

      expect(_follow, findsOneWidget);
      expect(_message, findsOneWidget);
      expect(t.widget<ProfilePillButton>(_message).enabled, isTrue,
          reason: 'live while the can-message check is still in flight');
    });

    testWidgets('keeps Message but dims it when they take no DMs', (t) async {
      await t.pumpWidget(actions(isCreator: true, canMessage: false));
      await t.pump();

      expect(_message, findsOneWidget,
          reason: 'removing it is indistinguishable from still loading');
      expect(t.widget<ProfilePillButton>(_message).enabled, isFalse);
      // The refusal is about messaging, not about following.
      expect(t.widget<ProfilePillButton>(_follow).enabled, isTrue);
    });

    testWidgets('offers nothing on your own profile', (t) async {
      await t.pumpWidget(actions(isCreator: true, userId: 'me'));
      await t.pump();

      expect(find.byType(ProfilePillButton), findsNothing);
    });
  });

  group('a person profile', () {
    testWidgets('offers Message alone — no Follow', (t) async {
      // Following is a creator relationship: it feeds the Following tab, so
      // following somebody who posts nothing subscribes you to nothing.
      await t.pumpWidget(actions(isCreator: false, userId: 'u-1'));
      await t.pump();

      expect(_message, findsOneWidget);
      expect(find.byType(ProfilePillButton), findsOneWidget);
    });
  });

  group('a tap on a comment author', () {
    late List<String> opened;

    Widget tapHost({required String role, required bool isMe}) => host(Builder(
          builder: (context) {
            final tap = openAuthorProfileTap(
              context,
              authorId: isMe ? 'me' : 'a-1',
              authorName: 'Ama',
              authorRole: role,
              isMe: isMe,
            );
            return Text(tap == null ? 'no-tap' : 'tappable');
          },
        ));

    setUp(() => opened = []);

    testWidgets('a creator is tappable', (t) async {
      await t.pumpWidget(tapHost(role: ChatConfig.rolePhotographer, isMe: false));
      expect(find.text('tappable'), findsOneWidget);
      expect(opened, isEmpty);
    });

    testWidgets('so is an ordinary commenter', (t) async {
      // The event thread used to return null for anybody who was not a
      // creator, which left most avatars in a thread dead.
      await t.pumpWidget(tapHost(role: 'user', isMe: false));
      expect(find.text('tappable'), findsOneWidget);
    });

    testWidgets('and so is one whose role never arrived', (t) async {
      await t.pumpWidget(tapHost(role: '', isMe: false));
      expect(find.text('tappable'), findsOneWidget);
    });

    testWidgets('your own comment is not', (t) async {
      await t.pumpWidget(tapHost(role: 'user', isMe: true));
      expect(find.text('no-tap'), findsOneWidget);
    });
  });
}
