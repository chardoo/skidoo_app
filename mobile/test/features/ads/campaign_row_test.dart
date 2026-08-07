import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';
import 'package:jperg_app/features/ads/presentation/widgets/campaign_row.dart';

/// A row in Broadcasts → Campaigns.
///
/// It used to be a card with a budget bar, an edit pencil and a strip of
/// buttons — six of them made an unreadable wall, and none of it is what the
/// design draws. Three lines, a thumbnail and a status pill.
Widget host(Widget Function(AppThemeExtension) build) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension.light],
        ),
        home: Scaffold(
          body: Builder(
            builder: (context) =>
                build(Theme.of(context).extension<AppThemeExtension>()!),
          ),
        ),
      ),
    );

AdCampaign campaign(Map<String, dynamic> extra) => AdCampaign.fromJson({
      'id': 'c1',
      'name': 'Book Your Perfect Photoshoot',
      'headline': 'Book Your Perfect Photoshoot',
      'objective': 'leads',
      'budget_amount': 1120.0,
      'daily_budget': 80.0,
      'spent': 0,
      'currency': 'GHS',
      'status': 'paused',
      'createdAt': '2026-08-01T10:00:00Z',
      'updatedAt': '2026-08-01T10:00:00Z',
      ...extra,
    });

void main() {
  Future<void> pump(WidgetTester tester, AdCampaign c,
      {VoidCallback? onTap}) async {
    await tester.pumpWidget(host((ext) => CampaignRow(
          campaign: c,
          ext: ext,
          onTap: onTap ?? () {},
        )));
    await tester.pump();
  }

  testWidgets('the three lines the design draws', (tester) async {
    await pump(tester, campaign({'reach': 3200, 'clicks': 94, 'impressions': 9600}));
    expect(tester.takeException(), isNull);

    expect(find.text('Book Your Perfect Photoshoot'), findsOneWidget);
    // "Lead Generation • GHS 80/day" — objective and the per-day figure.
    expect(find.textContaining('Get Leads'), findsOneWidget);
    expect(find.textContaining('GHS 80/day'), findsOneWidget);
    // "3.2K reach • 94 clicks"
    expect(find.textContaining('3.2K reach'), findsOneWidget);
    expect(find.textContaining('94 clicks'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });

  testWidgets('a draft says Not started rather than zeroes', (tester) async {
    // "0 reach • 0 clicks" reads as a campaign doing badly, not one that has
    // never run.
    await pump(tester, campaign({'status': 'draft'}));
    expect(find.text('Not started'), findsOneWidget);
    expect(find.textContaining('0 reach'), findsNothing);
    expect(find.text('Draft'), findsOneWidget);
  });

  testWidgets('each waiting state says what it is waiting for', (tester) async {
    for (final (status, expected) in const [
      ('pending_review', 'Awaiting review'),
      ('approved_unpaid', 'Awaiting payment'),
      ('payment_expired', 'Payment window closed'),
      ('rejected', 'Not approved'),
    ]) {
      await pump(tester, campaign({'status': status}));
      expect(find.text(expected), findsOneWidget, reason: 'for $status');
    }
  });

  testWidgets('the row opens the campaign', (tester) async {
    var taps = 0;
    await pump(tester, campaign({}), onTap: () => taps++);
    await tester.tap(find.byType(CampaignRow));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('no inline actions — they live on the details screen',
      (tester) async {
    await pump(tester, campaign({'status': 'active'}));
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    expect(find.byIcon(Icons.edit_outlined), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('a campaign with no cover still renders', (tester) async {
    await pump(tester, campaign({}));
    expect(tester.takeException(), isNull);
    expect(find.byIcon(Icons.campaign_outlined), findsOneWidget);
  });

  testWidgets('a very long headline does not overflow', (tester) async {
    await pump(tester, campaign({
      'headline': 'An Extremely Long Campaign Headline That Would Wrap Twice',
      'status': 'active',
    }));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a campaign with no daily budget shows its total', (tester) async {
    // Older rows predate budget_mode and carry no per-day figure.
    final c = AdCampaign.fromJson({
      'id': 'old',
      'name': 'Legacy',
      'objective': 'awareness',
      'budget_amount': 500.0,
      'spent': 0,
      'currency': 'GHS',
      'status': 'active',
      'createdAt': '2026-05-01T10:00:00Z',
      'updatedAt': '2026-05-01T10:00:00Z',
    });
    await pump(tester, c);
    expect(find.textContaining('GHS 500'), findsOneWidget);
    expect(find.textContaining('/day'), findsNothing);
  });
}
