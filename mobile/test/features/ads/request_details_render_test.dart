import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/features/ads/data/models/feed_request_model.dart';
import 'package:skidoo_app/features/ads/presentation/pages/request_photographer_page.dart';

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
