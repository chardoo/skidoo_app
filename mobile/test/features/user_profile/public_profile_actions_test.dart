import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/common/widgets/profile_pill_button.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/chat/data/datasources/chat_rest_data_source.dart'
    show CanMessageResult;
import 'package:jperg_app/features/chat/domain/repositories/chat_repository.dart';
import 'package:jperg_app/features/chat/domain/usecases/chat_usecases.dart';
import 'package:jperg_app/features/user_profile/data/repositories/public_profile_repository.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/public_profile_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// An ordinary person's profile: one button, in the middle, there immediately.
///
/// It used to carry Followers / Following and a Follow button beside Message.
/// Following is a *creator* relationship — it feeds the Following tab, which
/// exists to show you work — so following somebody who posts nothing
/// subscribes you to nothing, and the two zeroes under their name were a
/// scoreboard for a game they are not playing.
///
/// The timing is the other half. The row was gated on `_loaded == true`, which
/// waited for the profile fetch, so every button on every profile arrived a
/// beat after the rest of the page.
mixin _Unused {
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName} is not used here');
}

/// Answers the can-message check, and can be held open to inspect the frame
/// before it returns — which is where "appears instantly" is decided.
class _Chat with _Unused implements ChatRepository {
  _Chat({this.allowed = true, this.hold = false});

  final bool allowed;
  final bool hold;
  final _pending = <Completer<CanMessageResult>>[];

  void release() {
    for (final c in _pending) {
      if (!c.isCompleted) c.complete(CanMessageResult(canMessage: allowed));
    }
    _pending.clear();
  }

  @override
  Future<CanMessageResult> canMessage(String targetUserId) {
    if (!hold) return Future.value(CanMessageResult(canMessage: allowed));
    final completer = Completer<CanMessageResult>();
    _pending.add(completer);
    return completer.future;
  }
}

/// The page refetches on open; this keeps that off the network. A failure is
/// fine — the seed is what the screen draws either way.
class _Auth with _Unused implements AuthService {}

/// Answers the profile refetch at once. Without it the real adapter opens a
/// connection whose timeout outlives the test, and the harness fails on that
/// rather than on anything asserted here.
class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"data": {}}', 200, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  void close({bool force = false}) {}
}

Widget host(PublicProfile profile) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
          splashFactory: NoSplash.splashFactory,
        ),
        home: PublicProfilePage(profile: profile),
      ),
    );

PublicProfile person({String id = 'u1'}) => PublicProfile(
      id: id,
      name: 'naa',
      username: 'naa9444',
      followers: 12,
      following: 7,
    );

Finder get _message => find.widgetWithText(ProfilePillButton, 'Message');

void setUpChat(_Chat chat) {
  if (GetIt.I.isRegistered<CanMessageUseCase>()) {
    GetIt.I.unregister<CanMessageUseCase>();
  }
  GetIt.I.registerSingleton<CanMessageUseCase>(CanMessageUseCase(chat));
}

void main() {
  late HttpClientAdapter realAdapter;

  setUp(() {
    realAdapter = Api().dio.httpClientAdapter;
    Api().dio.httpClientAdapter = _Offline();

    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    AuthService.userId.value = 'me';
    GetIt.I.registerSingleton<AuthService>(_Auth());
    setUpChat(_Chat());
  });

  tearDown(() {
    AuthService.userId.value = '';
    Api().dio.httpClientAdapter = realAdapter;
    GetIt.I.reset();
  });

  group('what the screen offers', () {
    testWidgets('no follower counts', (t) async {
      await t.pumpWidget(host(person()));
      await t.pump();

      expect(find.text('Followers'), findsNothing);
      expect(find.text('Following'), findsNothing);
      // Nor the figures themselves, which would be a scoreboard with no label.
      expect(find.text('12'), findsNothing);
      expect(find.text('7'), findsNothing);

      // The refetch is still in flight; drain it so the harness does not
      // fail on a pending timer after the frame under test.
      await t.pumpAndSettle();
    });

    testWidgets('no Follow button', (t) async {
      await t.pumpWidget(host(person()));
      await t.pump();

      expect(find.text('Follow'), findsNothing);
      expect(find.text('Following'), findsNothing);

      // The refetch is still in flight; drain it so the harness does not
      // fail on a pending timer after the frame under test.
      await t.pumpAndSettle();
    });

    testWidgets('Message is the only action, and it is centred', (t) async {
      await t.pumpWidget(host(person()));
      await t.pump();

      expect(find.byType(ProfilePillButton), findsOneWidget);

      final button = t.getCenter(_message);
      final screen = t.getSize(find.byType(MaterialApp)).width;
      expect(button.dx, moreOrLessEquals(screen / 2, epsilon: 1.0));

      // The refetch is still in flight; drain it so the harness does not
      // fail on a pending timer after the frame under test.
      await t.pumpAndSettle();
    });

    testWidgets('and nothing at all on your own profile', (t) async {
      await t.pumpWidget(host(person(id: 'me')));
      await t.pump();

      expect(find.byType(ProfilePillButton), findsNothing);

      // The refetch is still in flight; drain it so the harness does not
      // fail on a pending timer after the frame under test.
      await t.pumpAndSettle();
    });
  });

  group('when it appears', () {
    testWidgets('on the first frame, before any request answers', (t) async {
      // The whole complaint: it used to wait for the profile fetch *and* the
      // can-message check. One pump is the frame the page is built in.
      final chat = _Chat(hold: true);
      setUpChat(chat);

      await t.pumpWidget(host(person()));
      await t.pump();

      expect(_message, findsOneWidget);
      expect(t.widget<ProfilePillButton>(_message).enabled, isTrue,
          reason: 'live while the check is still in flight');

      chat.release();
      await t.pumpAndSettle();
    });

    testWidgets('own profile is recognised on the first frame too', (t) async {
      // From the primed id rather than the server's `isMe`, so the button is
      // never drawn and then taken away.
      await t.pumpWidget(host(person(id: 'me')));
      await t.pump();

      expect(find.byType(ProfilePillButton), findsNothing);

      // The refetch is still in flight; drain it so the harness does not
      // fail on a pending timer after the frame under test.
      await t.pumpAndSettle();
    });
  });

  group('when they do not take messages', () {
    testWidgets('the button is there but disabled', (t) async {
      setUpChat(_Chat(allowed: false));

      await t.pumpWidget(host(person()));
      await t.pumpAndSettle();

      expect(_message, findsOneWidget,
          reason: 'removing it is indistinguishable from still loading');
      expect(t.widget<ProfilePillButton>(_message).enabled, isFalse);
    });

    testWidgets('and it stays live when they do', (t) async {
      await t.pumpWidget(host(person()));
      await t.pumpAndSettle();

      expect(t.widget<ProfilePillButton>(_message).enabled, isTrue);
    });
  });
}
