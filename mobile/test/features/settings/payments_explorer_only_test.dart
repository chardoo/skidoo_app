import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/settings/data/payments_api.dart';
import 'package:jperg_app/features/settings/presentation/pages/payments_page.dart';
import 'package:jperg_app/features/settings/presentation/widgets/payment_receipt_sheet.dart';
import 'package:jperg_app/services/auth_service.dart';

/// Payments is the explorer's screen.
///
/// A creator's money is studio work — boosts, campaign spend, payouts — and
/// the studio is on the web, where there is room to do it properly. Half of it
/// on a phone is worse than none. What an explorer has belongs here: they
/// bought a photo, and they want the receipt.
///
/// Two halves to keep apart, and the second is the one that bites. Hiding the
/// *chips* for studio money is not hiding the money: with no Boosts chip on
/// screen, `All` still meant every row both services returned.

class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter({this.main = const [], this.ads = const []});

  /// Rows from `main` (purchases, payouts) and from the ads service.
  final List<Map<String, dynamic>> main;
  final List<Map<String, dynamic>> ads;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<List<int>>? _, Future<void>? __) async {
    final rows = options.path.startsWith('/ads') ? ads : main;
    return ResponseBody.fromString(
      jsonEncode({'data': rows}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> row(
  String id,
  String kind, {
  String direction = 'out',
  String status = 'success',
  double amount = 20,
}) =>
    {
      'id': id,
      'kind': kind,
      'direction': direction,
      'title': '$kind $id',
      'subtitle': 'Kwame Studios',
      'amount': amount,
      'currency': 'GHS',
      'status': status,
      'reference': 'JPG-$id',
      'date': '2026-09-14T16:32:00Z',
    };

PaymentsApi apiWith(_FakeAdapter adapter) => PaymentsApi(
    client: Dio(BaseOptions(baseUrl: 'http://test'))
      ..httpClientAdapter = adapter);

Widget host(PaymentsApi api) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: PaymentsPage(api: api),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 2, 844 * 2);
    view.devicePixelRatio = 2;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('what the screen shows', () {
    testWidgets('an explorer sees their purchases', (t) async {
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase'), row('b', 'purchase')],
      ))));
      await t.pumpAndSettle();

      expect(find.text('purchase a'), findsOneWidget);
      expect(find.text('purchase b'), findsOneWidget);
    });

    testWidgets('studio money never reaches the list', (t) async {
      // The row the chips alone would not have removed. A creator opening this
      // by any route sees only the spending side.
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase'), row('p', 'payout', direction: 'in')],
        ads: [row('x', 'boost'), row('y', 'campaign')],
      ))));
      await t.pumpAndSettle();

      expect(find.text('purchase a'), findsOneWidget);
      expect(find.text('payout p'), findsNothing);
      expect(find.text('boost x'), findsNothing);
      expect(find.text('campaign y'), findsNothing);
    });

    testWidgets('and no chip offers them either', (t) async {
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase')],
        ads: [row('x', 'boost'), row('y', 'campaign')],
      ))));
      await t.pumpAndSettle();

      expect(find.text('Purchases'), findsOneWidget);
      expect(find.text('Boosts'), findsNothing);
      expect(find.text('Campaigns'), findsNothing);
      expect(find.text('Payouts'), findsNothing);
    });

    testWidgets('a booking deposit is the explorer\'s, and stays', (t) async {
      // Money they actually spent. Hiding it because one more chip felt like
      // one too many would be the app losing a payment somebody made.
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase')],
        ads: [row('b', 'booking')],
      ))));
      await t.pumpAndSettle();

      expect(find.text('booking b'), findsOneWidget);
      expect(find.text('Bookings'), findsOneWidget);
    });

    testWidgets('an account with nothing but studio money reads as empty',
        (t) async {
      // Not an error, and not a list of somebody else's rows: this screen has
      // nothing for them, and says so.
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        ads: [row('x', 'boost')],
      ))));
      await t.pumpAndSettle();

      expect(find.text('No payments yet'), findsOneWidget);
    });
  });

  group('the receipt', () {
    testWidgets('opens from a payment and carries what it has to', (t) async {
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase', amount: 45)],
      ))));
      await t.pumpAndSettle();

      await t.tap(find.text('purchase a'));
      await t.pumpAndSettle();

      expect(find.byType(PaymentReceiptSheet), findsOneWidget);
      // The amount, and the number they will be asked for if they write in.
      expect(find.text('GHS 45.00'), findsWidgets);
      expect(find.text('JPG-a'), findsOneWidget);
      expect(find.text('Share receipt'), findsOneWidget);
    });

    testWidgets('a failed payment has one too', (t) async {
      // The row somebody is most likely to need to show to somebody else.
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase', status: 'failed')],
      ))));
      await t.pumpAndSettle();

      await t.tap(find.text('purchase a'));
      await t.pumpAndSettle();

      expect(find.byType(PaymentReceiptSheet), findsOneWidget);
      expect(find.text('Failed'), findsWidgets);
    });

    testWidgets('is captured from one boundary, so the file matches the sheet',
        (t) async {
      // The share renders this subtree rather than laying the receipt out a
      // second time — two descriptions of one receipt is how the shared file
      // drifts from what was on screen.
      await t.pumpWidget(host(apiWith(_FakeAdapter(
        main: [row('a', 'purchase')],
      ))));
      await t.pumpAndSettle();
      await t.tap(find.text('purchase a'));
      await t.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(PaymentReceiptSheet),
          matching: find.byType(RepaintBoundary),
        ),
        findsWidgets,
      );
    });
  });

  group('who gets the screen at all', () {
    tearDown(() => AuthService.role.value = '');

    test('Settings offers it to an explorer and not to a creator', () {
      // The page is reached from one row, and the row is the gate. Asserted on
      // the source because Settings needs the whole profile bloc to pump.
      final source = File(
        'lib/features/settings/presentation/pages/settings_page.dart',
      ).readAsStringSync();

      final row = source.substring(
        source.indexOf("label: 'Payments'") - 800,
        source.indexOf("label: 'Payments'") + 200,
      );
      expect(row, contains('AuthService.role'));
      expect(row, contains("role == 'photographer'"));
      expect(row, contains('SizedBox.shrink()'));
    });
  });
}
