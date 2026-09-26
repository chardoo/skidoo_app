import 'dart:convert';

import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/settings/data/payments_api.dart';
import 'package:jperg_app/features/settings/presentation/pages/payments_page.dart';

/// Settings → Payments: what was paid, and whether it went through.
///
/// The money used to be spread across three screens that each showed one
/// slice — bought photos in the gallery, ad spend in the campaign pages,
/// payouts in Earnings — and a payment that *failed* appeared on none of them.
///
/// Two services answer and the app merges them, so the tests that matter are
/// about the merge: that both halves arrive, that one service being down does
/// not take the screen with it, and that a payout reads as money coming in
/// rather than as another expense.
void main() {
  Map<String, dynamic> row(
    String kind, {
    String direction = 'out',
    String title = 'Photos',
    String? subtitle,
    double amount = 60,
    String status = 'success',
    String date = '2026-09-20T10:00:00Z',
  }) =>
      {
        'id': '$kind-$date-$amount',
        'kind': kind,
        'direction': direction,
        'title': title,
        'subtitle': subtitle,
        'amount': amount,
        'currency': 'GHS',
        'status': status,
        'date': date,
      };

  /// Answers the two endpoints from memory, and can fail either one.
  dio.Dio fakeDio({
    List<Map<String, dynamic>> main = const [],
    List<Map<String, dynamic>> ads = const [],
    bool adsFails = false,
    bool mainFails = false,
  }) {
    final client = dio.Dio();
    client.httpClientAdapter = _Adapter((path) {
      final isAds = path.contains('/ads/');
      if (isAds && adsFails) throw StateError('ads is down');
      if (!isAds && mainFails) throw StateError('main is down');
      return {'success': true, 'data': isAds ? ads : main};
    });
    return client;
  }

  Widget host(dio.Dio client) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
          home: PaymentsPage(api: PaymentsApi(client: client)),
        ),
      );

  testWidgets('both services land in one list', (t) async {
    // The ads half still matters to an explorer: a deposit on a photographer
    // is recorded there. A boost would not appear — that is studio money and
    // this screen does not carry it; see payments_explorer_only_test.
    await t.pumpWidget(host(fakeDio(
      main: [row('purchase', title: 'Photos', subtitle: '3 photos')],
      ads: [row('booking', title: 'Deposit', subtitle: 'Wedding shoot')],
    )));
    await t.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
    expect(find.text('Deposit'), findsOneWidget);
  });

  testWidgets('newest first, however the two interleave', (t) async {
    await t.pumpWidget(host(fakeDio(
      main: [row('purchase', title: 'Older', date: '2026-09-01T10:00:00Z')],
      ads: [row('booking', title: 'Newer', date: '2026-09-25T10:00:00Z')],
    )));
    await t.pumpAndSettle();

    final titles = t.widgetList<Text>(find.byType(Text)).map((w) => w.data);
    expect(titles.toList().indexOf('Newer'),
        lessThan(titles.toList().indexOf('Older')));
  });

  testWidgets('one service being down does not take the screen with it',
      (t) async {
    // A history missing its boosts is worth more than an error screen — and
    // the commonest reason for a failure here is an account that has never
    // touched that service at all.
    await t.pumpWidget(host(fakeDio(
      main: [row('purchase', title: 'Photos')],
      adsFails: true,
    )));
    await t.pumpAndSettle();

    expect(find.text('Photos'), findsOneWidget);
  });

  testWidgets('money coming back reads as coming in', (t) async {
    // The sign, which is the thing being checked. A payout used to stand in
    // for it and no longer reaches this screen — payouts are studio money —
    // so the case is a refunded booking, which an explorer genuinely has.
    await t.pumpWidget(host(fakeDio(
      ads: [
        row('booking', direction: 'in', title: 'Refund', amount: 180)
      ],
    )));
    await t.pumpAndSettle();

    expect(find.text('+GHS 180.00'), findsOneWidget);
  });

  testWidgets('money out carries no sign', (t) async {
    await t.pumpWidget(host(fakeDio(main: [row('purchase')])));
    await t.pumpAndSettle();

    expect(find.text('GHS 60.00'), findsOneWidget);
  });

  testWidgets('a failed payment says so', (t) async {
    // The state that had nowhere to appear before this screen existed.
    // Scoped to the row: "Failed" is also a filter chip, and a test that
    // could not tell them apart would pass on the chip alone.
    final data = row('purchase', status: 'failed');
    await t.pumpWidget(host(fakeDio(main: [data])));
    await t.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ValueKey('payment-${data['id']}')),
        matching: find.text('Failed'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('filtering by status hides the rest', (t) async {
    await t.pumpWidget(host(fakeDio(main: [
      row('purchase', title: 'Went through', status: 'success'),
      row('purchase', title: 'Did not', status: 'failed'),
    ])));
    await t.pumpAndSettle();

    await t.tap(find.text('Failed').first);
    await t.pumpAndSettle();

    expect(find.text('Did not'), findsOneWidget);
    expect(find.text('Went through'), findsNothing);
  });

  testWidgets('only the kinds this account has get a chip', (t) async {
    // Chips where nothing applies is a filter bar that mostly filters to
    // nothing. Somebody who has only bought photos gets All and Purchases.
    await t.pumpWidget(host(fakeDio(main: [row('purchase')])));
    await t.pumpAndSettle();

    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Bookings'), findsNothing);
  });

  testWidgets('and a booking they made gets one', (t) async {
    await t.pumpWidget(host(fakeDio(
      main: [row('purchase')],
      ads: [row('booking', title: 'Deposit')],
    )));
    await t.pumpAndSettle();

    expect(find.text('Purchases'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
  });

  testWidgets('an account with no payments says so', (t) async {
    await t.pumpWidget(host(fakeDio()));
    await t.pumpAndSettle();

    expect(find.text('No payments yet'), findsOneWidget);
  });

  testWidgets('filters that match nothing say that instead', (t) async {
    // Different sentence, because the two states mean different things: one
    // is "you have never paid for anything", the other is "look again".
    await t.pumpWidget(host(fakeDio(
      main: [row('purchase', status: 'success')],
    )));
    await t.pumpAndSettle();

    await t.tap(find.text('Failed').first);
    await t.pumpAndSettle();

    expect(find.text('Nothing matches those filters'), findsOneWidget);
  });
}

/// Answers every request from a callback, with no socket.
class _Adapter implements dio.HttpClientAdapter {
  _Adapter(this.respond);

  final Map<String, dynamic> Function(String path) respond;

  @override
  Future<dio.ResponseBody> fetch(dio.RequestOptions options,
      Stream<List<int>>? _, Future<void>? __) async {
    return dio.ResponseBody.fromString(
      jsonEncode(respond(options.path)),
      200,
      headers: {
        dio.Headers.contentTypeHeader: [dio.Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
