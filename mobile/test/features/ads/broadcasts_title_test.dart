/// What the page calls itself when campaigns are switched off.
///
/// "Broadcasts" is a collective noun for two shelves — the account's own
/// requests, and its campaigns. With campaigns off only one of them is left,
/// and the tab bar is already hidden for exactly that reason, so the title
/// named a section the reader could not see. It is the requests list, so it
/// says Requests.
library;

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/api/dio_client_service.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/admin/data/models/app_config.dart';
import 'package:jperg_app/features/admin/data/repositories/app_config_repository.dart';
import 'package:jperg_app/features/ads/presentation/pages/broadcasts_page.dart';

/// Answers every call at once with an empty list.
///
/// The two tabs fetch on mount, through `Api().dio`. Left alone they open a
/// real connection whose timeout is still pending when the test ends, and the
/// harness fails on that rather than on anything being asserted here. This is
/// not a stub of the lists — what they contain does not matter to a title —
/// only a way to stop them reaching for the network.
class _Offline implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
          Future<void>? cancelFuture) async =>
      ResponseBody.fromString('{"data": []}', 200,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType]
          });

  @override
  void close({bool force = false}) {}
}

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(412, 917),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: child,
      ),
    );

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(412 * 3, 917 * 3);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

void _config({bool campaigns = true}) {
  AppConfigRepository.current =
      AppConfig(adsEnabled: campaigns, requestsEnabled: true);
}

/// The title sits in the AppBar; the tab labels and the lists below carry the
/// same words, so a bare `find.text` would match either.
Finder _title(String text) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(text),
    );

void main() {
  late HttpClientAdapter realAdapter;

  setUp(() {
    _config();
    realAdapter = Api().dio.httpClientAdapter;
    Api().dio.httpClientAdapter = _Offline();
  });

  tearDown(() {
    AppConfigRepository.current = const AppConfig();
    Api().dio.httpClientAdapter = realAdapter;
  });

  testWidgets('campaigns off: the page is called Requests', (tester) async {
    _phone(tester);
    _config(campaigns: false);

    await tester.pumpWidget(_wrap(const BroadcastsPage()));
    // Settles the lists' own fetch: the stub answers at once, but the future
    // it completes is still a pending timer until the tree is pumped again.
    await tester.pumpAndSettle();

    expect(_title('Requests'), findsOneWidget);
    expect(_title('Broadcasts'), findsNothing);
  });

  testWidgets('campaigns on: it is still Broadcasts', (tester) async {
    _phone(tester);

    await tester.pumpWidget(_wrap(const BroadcastsPage()));
    // Settles the lists' own fetch: the stub answers at once, but the future
    // it completes is still a pending timer until the tree is pumped again.
    await tester.pumpAndSettle();

    expect(_title('Broadcasts'), findsOneWidget);
  });

  testWidgets('the title follows the switch while the page is open',
      (tester) async {
    // The switch moves under a live screen — an admin throws it and every
    // installed app has to follow within the session. The page already rebuilds
    // its tabs on that; the title has to come with them, or the heading
    // disagrees with the screen under it.
    _phone(tester);

    await tester.pumpWidget(_wrap(const BroadcastsPage()));
    // Settles the lists' own fetch: the stub answers at once, but the future
    // it completes is still a pending timer until the tree is pumped again.
    await tester.pumpAndSettle();
    expect(_title('Broadcasts'), findsOneWidget);

    AppConfigRepository.notifier.value =
        const AppConfig(adsEnabled: false, requestsEnabled: true);
    await tester.pumpAndSettle();

    expect(_title('Requests'), findsOneWidget);
    expect(_title('Broadcasts'), findsNothing);
  });

  testWidgets('and back again when it is switched on', (tester) async {
    _phone(tester);
    _config(campaigns: false);

    await tester.pumpWidget(_wrap(const BroadcastsPage()));
    // Settles the lists' own fetch: the stub answers at once, but the future
    // it completes is still a pending timer until the tree is pumped again.
    await tester.pumpAndSettle();
    expect(_title('Requests'), findsOneWidget);

    AppConfigRepository.notifier.value =
        const AppConfig(adsEnabled: true, requestsEnabled: true);
    await tester.pumpAndSettle();

    expect(_title('Broadcasts'), findsOneWidget);
  });
}
