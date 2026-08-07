import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/repositories/ads_repository.dart';
import 'package:jperg_app/features/ads/models/ad_campaign.dart';
import 'package:jperg_app/features/ads/presentation/pages/campaign_details_page.dart';

/// The four cards form one column.
///
/// A Column centres its children by default, and a Container with no width
/// takes its child's — so each card came out as wide as its own longest line
/// and sat centred. Four cards, four widths, ragged down both edges. Nothing
/// in the analyzer or the model tests can see that.
/// Answers from memory. The real one would leave an HTTP timeout running past
/// the end of the test.
class _StubRepo extends AdsRepository {
  _StubRepo(this.campaign);

  final AdCampaign campaign;

  @override
  Future<AdCampaign> getCampaign(String id) async => campaign;
}

void main() {
  Widget host(Widget child) => ScreenUtilInit(
        designSize: const Size(390, 844),
        builder: (_, __) => MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AppThemeExtension.light],
          ),
          home: child,
        ),
      );

  testWidgets('every card is the same width, whatever it contains',
      (tester) async {
    final campaign = AdCampaign.fromJson({
      'id': 'c1',
      'name': 'Book Your Perfect Photoshoot',
      'headline': 'Book Your Perfect Photoshoot',
      'objective': 'services',
      'format': 'image',
      'budget_amount': 700.0,
      'daily_budget': 50.0,
      'duration_days': 14,
      'spent': 0.0,
      'currency': 'GHS',
      'status': 'pending_review',
      'cta_text': 'Book Now',
      // Deliberately lopsided: a one-word card next to a card with four long
      // lines is exactly what made the ragged edges visible.
      'locations': ['Accra', 'Kumasi'],
      'interests': ['Weddings', 'Portraits', 'Events'],
      'age_min': 25,
      'age_max': 55,
      'placements': ['event_feed', 'explore'],
      'createdAt': '2026-08-01T10:00:00Z',
      'updatedAt': '2026-08-01T10:00:00Z',
    });

    await tester.pumpWidget(host(CampaignDetailsPage(
      campaign: campaign,
      repository: _StubRepo(campaign),
    )));
    await tester.pump();

    // The list builds only what fits, and the cards sit below the banner.
    await tester.scrollUntilVisible(
      find.text('4. Budget & Schedule'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    for (final title in const [
      '1. Campaign Type',
      '2. Creative',
      '3. Audience',
      '4. Budget & Schedule',
    ]) {
      expect(find.text(title), findsOneWidget, reason: '$title should render');
    }

    double widthOf(String title) {
      final card = find.ancestor(
        of: find.text(title),
        matching: find.byType(Container),
      );
      return tester.getSize(card.first).width;
    }

    final widths = [
      widthOf('1. Campaign Type'),
      widthOf('2. Creative'),
      widthOf('3. Audience'),
      widthOf('4. Budget & Schedule'),
    ];
    expect(widths.toSet().length, 1,
        reason: 'the cards must share one width, got $widths');

    // And that width is the page minus its gutters, not the content's.
    final screen = tester.getSize(find.byType(MaterialApp)).width;
    expect(widths.first, greaterThan(screen * 0.85),
        reason: 'a card should span the column, not shrink to its text');
  });
}
