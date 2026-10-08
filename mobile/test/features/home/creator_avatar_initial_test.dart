import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/common/widgets/user_avatar.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/home/presentation/widgets/creator_mode_menu.dart';
import 'package:jperg_app/services/auth_service.dart';

/// The creator's own avatar, in the control that switches them to the
/// dashboard.
///
/// With no profile picture it drew a question mark: the control passed
/// `initial: ''` and [UserAvatar] falls back to '?' for an empty string. That
/// is the one avatar in the app that is never a stranger — it belongs to the
/// person looking at it.
///
/// The name had to become a [ValueNotifier] to fix it, and that is the part
/// worth guarding. This sits in the feed's top bar, which is built once and
/// kept, so a one-shot `getName()` keeps whatever storage held at build time —
/// on a fresh sign-in, nothing. The avatar would have shown '?' and never
/// corrected itself, which is exactly the bug the comment on
/// `AuthService.profileUrl` already records for the picture.
Widget host() => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: const Scaffold(
          body: CreatorModeMenu(overSolidBackground: true),
        ),
      ),
    );

void main() {
  setUp(() {
    AuthService.role.value = 'photographer';
    AuthService.profileUrl.value = '';
    AuthService.name.value = '';
  });

  tearDown(() {
    AuthService.role.value = '';
    AuthService.profileUrl.value = '';
    AuthService.name.value = '';
  });

  testWidgets('draws the creator initial, not a question mark', (t) async {
    AuthService.name.value = 'Ama Serwaa';

    await t.pumpWidget(host());
    await t.pump();

    expect(find.text('A'), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('picks it up when the name arrives after the first build',
      (t) async {
    // The regression this design exists for: the top bar is built once and
    // kept, so a name read at build time is the name it keeps. On a fresh
    // sign-in there is nothing in storage yet.
    await t.pumpWidget(host());
    await t.pump();
    expect(find.text('?'), findsOneWidget);

    AuthService.name.value = 'Kofi Mensah';
    await t.pump();

    expect(find.text('K'), findsOneWidget);
    expect(find.text('?'), findsNothing);
  });

  testWidgets('still hands the picture to the avatar when there is one',
      (t) async {
    // Which of the two wins is [UserAvatar]'s business, and it cannot be
    // asserted by what is painted here: the test harness fails every image
    // request, so the avatar falls back to the letter exactly as it should
    // for a broken URL. What belongs to this widget is that the URL is passed
    // at all — adding the name must not have displaced it.
    AuthService.name.value = 'Ama Serwaa';
    AuthService.profileUrl.value = 'https://images.jperg.com/newImages/a.jpg';

    await t.pumpWidget(host());
    await t.pump();

    final avatar = t.widget<UserAvatar>(find.byType(UserAvatar));
    expect(avatar.imageUrl, 'https://images.jperg.com/newImages/a.jpg');
    expect(avatar.initial, 'Ama Serwaa');
  });

  testWidgets('passes no URL at all when there is no picture', (t) async {
    // Null rather than an empty string, or the avatar tries to load ''.
    AuthService.name.value = 'Ama Serwaa';

    await t.pumpWidget(host());
    await t.pump();

    expect(t.widget<UserAvatar>(find.byType(UserAvatar)).imageUrl, isNull);
  });

  testWidgets('falls back to the question mark rather than inventing a letter',
      (t) async {
    await t.pumpWidget(host());
    await t.pump();

    expect(find.text('?'), findsOneWidget);
  });

  testWidgets('is not drawn at all for a client', (t) async {
    // A viewer has no second mode to switch to, so there is no control and no
    // avatar to put a letter in.
    AuthService.role.value = 'user';
    AuthService.name.value = 'Ama Serwaa';

    await t.pumpWidget(host());
    await t.pump();

    expect(find.text('A'), findsNothing);
    expect(find.byType(CreatorModeMenu), findsOneWidget);
  });
}
