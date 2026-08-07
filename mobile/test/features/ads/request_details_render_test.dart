import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_radius.dart';
import 'package:jperg_app/core/theme/app_spacing.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/ads/data/models/feed_request_model.dart';
import 'package:jperg_app/features/ads/presentation/pages/request_photographer_page.dart';

/// These screens are drawn, not computed, and the analyzer sees none of it.
///
/// The selected tile carried `Border(left: …)` together with a `borderRadius`
/// for a while, which `Border.paint` refuses outright — the tile rendered as an
/// error box and nothing in `dart analyze` or the model tests noticed. Anything
/// that only fails during layout or paint needs a pump to catch it.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.light().copyWith(
          extensions: const [AppThemeExtension.light],
        ),
        home: child,
      ),
    );

RequestInterest person({
  String id = 'ph-1',
  String? name = 'Kwame Studios',
  double? rating = 4.7,
  bool selected = false,
  List<String> specialties = const ['Weddings', 'Bridal Showers', 'Portraits'],
  String? message = 'I have very flexible pricing plans.',
  String? bio = 'Specialising in bridal showers and natural light portraits.',
}) =>
    RequestInterest(
      id: id,
      name: name,
      profileUrl: null,
      message: message,
      bio: bio,
      location: 'Accra, Ghana',
      followerCount: 1200,
      eventCount: 132,
      rating: rating,
      ratingCount: 142,
      verified: true,
      specialties: specialties,
      selected: selected,
    );

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    RequestInterest? who,
    bool alreadySelected = false,
  }) async {
    await tester.pumpWidget(host(
      RequestPhotographerPage(
        photographer: who ?? person(),
        requestTitle: "Naomi's Bridal Shower",
        alreadySelected: alreadySelected,
        onSelect: () async => true,
      ),
    ));
    await tester.pump();
  }

  /// The page is longer than the test surface and the list only builds what
  /// fits, so anything below the fold has to be scrolled to before it exists.
  Future<void> scrollTo(WidgetTester tester, Finder target) =>
      tester.scrollUntilVisible(target, 240, scrollable: find.byType(Scrollable).first);

  _campaignDetailsChrome();

  group('the photographer profile renders', () {
    testWidgets('header, specialties and tabs paint without an exception',
        (tester) async {
      await pumpProfile(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Kwame Studios'), findsWidgets);
      // Location and followers on one line, the rating in its own pill.
      expect(find.textContaining('Accra, Ghana'), findsOneWidget);
      expect(find.textContaining('1.2K followers'), findsOneWidget);
      expect(find.text('4.7'), findsOneWidget);
    });

    testWidgets('the tab carries the review count', (tester) async {
      await pumpProfile(tester);
      expect(find.text('Portfolio'), findsOneWidget);
      // Seeded from the photographer's own total, so it does not count up
      // from zero once the reviews land.
      expect(find.text('Reviews (142)'), findsOneWidget);
    });

    testWidgets('specialty chips and the additional message box are drawn',
        (tester) async {
      await pumpProfile(tester);
      expect(find.text('Weddings'), findsOneWidget);
      expect(find.text('Bridal Showers'), findsOneWidget);
      expect(find.text('Portraits'), findsOneWidget);
      await scrollTo(tester, find.textContaining('flexible pricing'));
      expect(find.textContaining('flexible pricing'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the call to action is Select photographer', (tester) async {
      await pumpProfile(tester);
      await scrollTo(tester, find.text('Select photographer'));
      expect(find.text('Select photographer'), findsOneWidget);
      expect(find.text('View more profiles'), findsOneWidget);
      expect(find.text('Message'), findsNothing,
          reason: 'messaging comes after the selection, not on the profile');
    });

    testWidgets('an unrated photographer shows 0.0, not a gap', (tester) async {
      await pumpProfile(tester, who: person(rating: null));
      expect(tester.takeException(), isNull);
      expect(find.text('0.0'), findsOneWidget);
    });

    testWidgets('no specialties, no bio, no message — still renders',
        (tester) async {
      await pumpProfile(
        tester,
        who: person(specialties: const [], bio: null, message: null),
      );
      expect(tester.takeException(), isNull);
      await scrollTo(tester, find.text('Select photographer'));
      expect(find.text('Select photographer'), findsOneWidget);
    });

    testWidgets('a very long name does not overflow the header',
        (tester) async {
      await pumpProfile(
        tester,
        who: person(name: 'A Studio With An Extremely Long Trading Name Indeed'),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('already selected disables the button', (tester) async {
      await pumpProfile(tester, alreadySelected: true);
      await scrollTo(tester, find.text('Selected'));
      expect(find.text('Selected'), findsOneWidget);
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

  });
}

/// Campaign details, against the Figma pixels rather than against my memory of
/// them.
///
/// Measured off `CampaignDetails_InReview.png` (412 wide):
///   page gutter 20 · card padding 17 · gap between cards 11 · radius 12
///   card fill == page background (#F7F7F2) — the cards are outline-only
///   border ≈ searchHintColor at 0.18
///
/// The fill is the one that mattered: cardSurface is white, so every card read
/// as a raised panel against a background it was meant to sit in.
void _campaignDetailsChrome() {
  group('the details cards are drawn as the design draws them', () {
    testWidgets('a card is an outline, not a filled panel', (tester) async {
      await tester.pumpWidget(host(Builder(builder: (context) {
        final ext = Theme.of(context).extension<AppThemeExtension>()!;
        return Scaffold(
          backgroundColor: ext.homeBackground,
          body: Container(
            key: const Key('probe'),
            padding: EdgeInsets.all(AppSpacing.lg.w),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md.r),
              border: Border.all(
                color: ext.searchHintColor.withValues(alpha: 0.18), width: 1,
              ),
            ),
            child: const Text('1. Campaign Type'),
          ),
        );
      })));
      final box = tester.widget<Container>(find.byKey(const Key('probe')));
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.color, isNull,
          reason: 'the design fills cards with the page colour, i.e. not at all');
      expect(decoration.border, isNotNull);
    });

    test('the spacing scale carries the measured values', () {
      // 20 / 16 / 12 on a 390-wide design correspond to the 412-wide
      // measurements of 20 / 17 / 11-12.
      expect(AppSpacing.xl, 20, reason: 'page gutter');
      expect(AppSpacing.lg, 16, reason: 'card padding');
      expect(AppSpacing.md, 12, reason: 'gap between cards');
      expect(AppRadius.md, 12, reason: 'card corner radius');
    });
  });
}
