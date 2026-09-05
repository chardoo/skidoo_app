/// The board screen refuses on its own, not just via the tile that opens it.
///
/// Hiding the "Request Board" row on the account page is most of the fix, but
/// it is not the whole of it: a `request_board` push and its deep link both
/// push this page directly, without passing the tile. So the rule lives here
/// too, where every route in has to meet it.
///
/// The old behaviour was worse than a refusal. The page fetched, the server
/// answered with the empty list it answers every client with, and the reader
/// got "No open requests found" — which reads as *come back later*, when in
/// fact there was never going to be anything.
library;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/common/widgets/app_widgets.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/ad_model.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/request_board_page.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Answers the board's two calls with nothing, and records that it was asked.
///
/// The recording is the point of one of these tests: a client must be refused
/// locally, without a round trip to be told what the app already knows.
class _SpyRepo implements AdsRepository {
  bool asked = false;

  @override
  Future<List<FeedRequestModel>> getRequests({
    String? eventType,
    String? location,
    int page = 1,
    int limit = 20,
    String? view,
  }) async {
    asked = true;
    return const [];
  }

  /// Typed, because the board asks for its sponsored slot alongside the
  /// requests and a bare `noSuchMethod` hands back a `Future<dynamic>` that
  /// fails the cast — which the page catches and turns into an error view,
  /// quietly costing the test what it was checking.
  @override
  Future<AdModel?> serveAd({
    String placement = '',
    String? contextEventId,
    String? contextEventType,
    String? contextLocation,
  }) async =>
      null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future<dynamic>.value(null);
}

Widget host(AdsRepository repo) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: RequestBoardPage(repository: repo),
      ),
    );

Future<void> signInAs(String role) async {
  // The keychain, not SharedPreferences — mocking the wrong backend reads back
  // null and every role looks like a guest.
  FlutterSecureStorage.setMockInitialValues({'auth.role': role});
  if (GetIt.I.isRegistered<AuthService>()) {
    await GetIt.I.reset();
  }
  GetIt.I.registerSingleton<AuthService>(AuthService());
  await GetIt.I<AuthService>().primeRole();
}

void main() {
  tearDown(() async {
    AuthService.role.value = '';
    if (GetIt.I.isRegistered<AuthService>()) await GetIt.I.reset();
  });

  testWidgets('a client is told the board is not for them', (t) async {
    await signInAs('user');
    await t.pumpWidget(host(_SpyRepo()));
    await t.pump();

    expect(find.textContaining('for photographers'), findsOneWidget);
    // Not the generic empty state, which would read as a board that happens to
    // be empty today.
    expect(find.text('No open requests found'), findsNothing);
    // And it points somewhere real: posting a request is still theirs to do.
    expect(find.textContaining('Create'), findsOneWidget);
  });

  testWidgets('a client never asks the server for the board', (t) async {
    // The refusal is decided locally. Fetching would spend a round trip to be
    // told what the app already knows, and it is the fetch resolving to empty
    // that produced the misleading screen in the first place.
    final repo = _SpyRepo();
    await signInAs('user');
    await t.pumpWidget(host(repo));
    await t.pump();

    expect(repo.asked, isFalse, reason: 'the board was fetched for a client');
    // A load in flight or finished would have shown one of these.
    expect(find.byType(AppLoadingIndicator), findsNothing);
    expect(find.byType(AppErrorView), findsNothing);
  });

  testWidgets('the filter control is gone with the board', (t) async {
    // It would open a sheet of event types over an explanation.
    await signInAs('user');
    await t.pumpWidget(host(_SpyRepo()));
    await t.pump();

    expect(find.byIcon(Icons.tune_rounded), findsNothing);
  });

  testWidgets('a photographer gets the board, not the refusal', (t) async {
    final repo = _SpyRepo();
    await signInAs('photographer');
    await t.pumpWidget(host(repo));
    await t.pump();

    expect(find.textContaining('for photographers'), findsNothing);
    expect(repo.asked, isTrue, reason: 'a photographer should get a real board');
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
  });

  testWidgets('a signed-out visitor is refused too', (t) async {
    await signInAs('');
    await t.pumpWidget(host(_SpyRepo()));
    await t.pump();

    expect(find.textContaining('for photographers'), findsOneWidget);
  });
}
