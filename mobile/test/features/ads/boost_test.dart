import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/models/boost_tier.dart';
import 'package:jperg_app/features/ads/presentation/pages/boost_success_page.dart';
import 'package:jperg_app/features/ads/presentation/widgets/boost_active_bar.dart';
import 'package:jperg_app/features/ads/presentation/widgets/boost_request_sheet.dart';

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(extensions: const [AppThemeExtension.light]),
        home: Scaffold(body: child),
      ),
    );

/// The menu as the server sends it — nothing here is hardcoded in the client.
BoostCatalogue _catalogue() => BoostCatalogue.fromJson(const {
      'currency': 'GHS',
      'tiers': [
        {
          'days': 3,
          'price_ghs': 30.0,
          'label': '3 Days',
          'blurb': 'Quick boost for urgent requests',
          'best_value': false,
        },
        {
          'days': 7,
          'price_ghs': 50.0,
          'label': '7 Days',
          'blurb': 'Perfect duration for maximum response',
          'best_value': true,
        },
        {
          'days': 14,
          'price_ghs': 80.0,
          'label': '14 Days',
          'blurb': 'Long-term exposure for larger events',
          'best_value': false,
        },
      ],
      'benefits': [
        'Appear at the top of photographer feeds',
        'Priority placement in discovery and search',
        'Instant push notification to nearby pros',
      ],
    });

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 1400 * 3);
    view.devicePixelRatio = 3;
  });

  group('BoostCatalogue', () {
    test('parses the menu the server sends', () {
      final catalogue = _catalogue();
      expect(catalogue.tiers.map((t) => t.days), [3, 7, 14]);
      expect(catalogue.tiers.map((t) => t.priceGhs), [30.0, 50.0, 80.0]);
      expect(catalogue.benefits.length, 3);
      expect(catalogue.currency, 'GHS');
    });

    test('opens on the best-value tier', () {
      expect(_catalogue().defaultTier!.days, 7);
    });

    test('falls back to the first tier when none is flagged', () {
      final catalogue = BoostCatalogue.fromJson(const {
        'tiers': [
          {'days': 3, 'price_ghs': 30.0, 'label': '3 Days', 'blurb': ''},
        ],
      });
      expect(catalogue.defaultTier!.days, 3);
    });

    test('an empty menu has nothing to open on', () {
      expect(BoostCatalogue.empty.defaultTier, isNull);
    });
  });

  group('BoostRequestSheet', () {
    testWidgets('lists every tier with its price and blurb', (t) async {
      await t.pumpWidget(host(BoostRequestSheet(catalogue: _catalogue())));

      expect(find.text('Boost Your Request'), findsOneWidget);
      expect(find.text('3 Days'), findsOneWidget);
      expect(find.text('GHS 30'), findsOneWidget);
      expect(find.text('GHS 50'), findsOneWidget);
      expect(find.text('GHS 80'), findsOneWidget);
      expect(find.text('Quick boost for urgent requests'), findsOneWidget);
      expect(find.text('BEST VALUE'), findsOneWidget);
    });

    testWidgets('the button opens priced at the best-value tier', (t) async {
      await t.pumpWidget(host(BoostRequestSheet(catalogue: _catalogue())));
      expect(find.text('Pay - GHS 50'), findsOneWidget);
    });

    testWidgets('choosing another tier reprices the button', (t) async {
      await t.pumpWidget(host(BoostRequestSheet(catalogue: _catalogue())));

      await t.tap(find.text('14 Days'));
      await t.pump();

      expect(find.text('Pay - GHS 80'), findsOneWidget);
      expect(find.text('Pay - GHS 50'), findsNothing);
    });

    testWidgets('the benefits are printed under the tiers', (t) async {
      await t.pumpWidget(host(BoostRequestSheet(catalogue: _catalogue())));
      expect(find.text('Appear at the top of photographer feeds'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
    });

    testWidgets('pops with the tier that was chosen', (t) async {
      BoostTier? chosen;
      await t.pumpWidget(ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData(extensions: const [AppThemeExtension.light]),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  chosen = await showModalBottomSheet<BoostTier>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => BoostRequestSheet(catalogue: _catalogue()),
                  );
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ));

      await t.tap(find.text('open'));
      await t.pumpAndSettle();
      await t.tap(find.text('3 Days'));
      await t.pump();
      await t.tap(find.text('Pay - GHS 30'));
      await t.pumpAndSettle();

      expect(chosen?.days, 3);
      expect(chosen?.priceGhs, 30.0);
    });

    testWidgets('an empty menu offers no purchase it cannot price', (t) async {
      await t.pumpWidget(host(
        const BoostRequestSheet(catalogue: BoostCatalogue.empty),
      ));

      final button = t.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });
  });

  group('BoostActiveBar', () {
    testWidgets('says how much of the run is left', (t) async {
      await t.pumpWidget(
          host(const BoostActiveBar(daysRemaining: 5, totalDays: 7)));

      expect(find.text('Boost Active'), findsOneWidget);
      expect(find.text('5 of 7 days remaining'), findsOneWidget);

      final bar = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, closeTo(5 / 7, 0.001));
    });

    testWidgets('a total of zero does not divide by it', (t) async {
      await t.pumpWidget(
          host(const BoostActiveBar(daysRemaining: 0, totalDays: 0)));
      final bar = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 0);
    });

    testWidgets('more remaining than the total cannot overflow the track',
        (t) async {
      // A boost extended after this screen was built.
      await t.pumpWidget(
          host(const BoostActiveBar(daysRemaining: 12, totalDays: 7)));
      final bar = t.widget<LinearProgressIndicator>(
          find.byType(LinearProgressIndicator));
      expect(bar.value, 1.0);
    });
  });

  group('BoostSuccessPage', () {
    testWidgets('names the request and the days that were bought', (t) async {
      await t.pumpWidget(host(const BoostSuccessPage(
        requestTitle: "Naomi's Bridal Shower",
        days: 7,
      )));

      expect(find.text('Request Boosted!'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);

      final rich = t.widget<Text>(find.byType(Text).at(1));
      final text = rich.textSpan!.toPlainText();
      expect(text, contains("Naomi's Bridal Shower"));
      expect(text, contains('boosted for 7 days'));
    });

    testWidgets('a one-day boost is not "1 days"', (t) async {
      await t.pumpWidget(host(const BoostSuccessPage(
        requestTitle: 'Quick one',
        days: 1,
      )));
      final rich = t.widget<Text>(find.byType(Text).at(1));
      expect(rich.textSpan!.toPlainText(), contains('boosted for 1 day.'));
    });
  });

  group('the card decides when to offer a boost', () {
    FeedRequestModel request(Map<String, dynamic> overrides) =>
        FeedRequestModel.fromJson({
          'id': 'r1',
          'requester_id': 'u1',
          'title': 'A shoot',
          'status': 'open',
          ...overrides,
        });

    test('an active, unboosted request can be boosted', () {
      expect(request(const {}).canBoost, isTrue);
    });

    test('an already-boosted request is not offered it again', () {
      expect(request(const {'is_boosted': true}).canBoost, isFalse);
    });

    test('a closed request has nothing to promote', () {
      expect(request(const {'status': 'closed'}).canBoost, isFalse);
    });

    test('an expired request has nothing to promote', () {
      final past = DateTime.now()
          .toUtc()
          .subtract(const Duration(days: 1))
          .toIso8601String();
      expect(request({'expires_at': past}).canBoost, isFalse);
    });

    test('the countdown survives the round trip', () {
      final req = request(const {
        'is_boosted': true,
        'boost_days': 7,
        'boost_days_remaining': 5,
        'boosted_until': '2026-09-01T00:00:00Z',
      });
      expect(req.isBoosted, isTrue);
      expect(req.boostDays, 7);
      expect(req.boostDaysRemaining, 5);
      expect(req.boostedUntil, isNotNull);
    });
  });
}
