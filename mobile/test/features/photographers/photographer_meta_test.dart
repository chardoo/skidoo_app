import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/photographers/presentation/widgets/photographer_meta.dart';

/// Where a photographer is, how many follow them, what they are rated.
///
/// The same three facts sit under every photographer's name in the request
/// flow. They were written out separately in four files, and the review
/// composer — the one that took a pre-joined string — was only ever handed the
/// location, so it showed no followers and no rating at all. One widget now,
/// so a fifth screen cannot quietly show two of the three.
Widget host(Widget Function(AppThemeExtension ext) build) => ScreenUtilInit(
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

void main() {
  group('the row variant', () {
    testWidgets('leads with the rating, then location and followers',
        (tester) async {
      await tester.pumpWidget(host((ext) => PhotographerMeta(
            ext: ext, location: 'Paris', followerCount: 850, rating: 4.5,
          )));
      expect(tester.takeException(), isNull);
      expect(find.text('4.5'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.textContaining('Paris'), findsOneWidget);
      expect(find.textContaining('850 followers'), findsOneWidget);
    });

    testWidgets('an unrated photographer still shows a rating, at 0.0',
        (tester) async {
      // Hiding it left a gap that read as a field that had failed to load —
      // and every photographer is unrated until the first review lands, so
      // that gap was the normal case, not the edge one.
      await tester.pumpWidget(host((ext) => PhotographerMeta(
            ext: ext, location: 'Paris', followerCount: 850,
          )));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('0.0'), findsOneWidget);
      expect(find.textContaining('850 followers'), findsOneWidget);
    });

    testWidgets('no location leaves no dangling separator', (tester) async {
      await tester.pumpWidget(host((ext) => PhotographerMeta(
            ext: ext, followerCount: 4, rating: 4.9,
          )));
      expect(find.text('4 followers'), findsOneWidget);
    });

    testWidgets('counts are abbreviated, not spelled out', (tester) async {
      await tester.pumpWidget(host((ext) => PhotographerMeta(
            ext: ext, location: 'Accra', followerCount: 1200,
          )));
      expect(find.textContaining('1.2K followers'), findsOneWidget);
    });
  });

  group('the header variant', () {
    testWidgets('pins the location and accents the follower count',
        (tester) async {
      await tester.pumpWidget(host((ext) => PhotographerMeta(
            ext: ext,
            location: 'Accra, Ghana',
            followerCount: 1200,
            variant: PhotographerMetaVariant.header,
          )));
      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.place_outlined), findsOneWidget);

      // "1.2K followers" is the accent colour; the location beside it is not.
      final ext = AppThemeExtension.light;
      final rich = tester.widget<Text>(find.byType(Text).first);
      final spans = <InlineSpan>[];
      rich.textSpan!.visitChildren((s) {
        spans.add(s);
        return true;
      });
      final accented = spans.whereType<TextSpan>().where(
            (s) => s.style?.color == ext.accentGold,
          );
      expect(accented, isNotEmpty);
      expect(accented.first.text, contains('followers'));
    });

    testWidgets('no pin when there is no location', (tester) async {
      await tester.pumpWidget(host((ext) => PhotographerMeta(
            ext: ext,
            followerCount: 12,
            variant: PhotographerMetaVariant.header,
          )));
      expect(find.byIcon(Icons.place_outlined), findsNothing);
      expect(tester.takeException(), isNull);
    });
  });

  group('the rating pill', () {
    testWidgets('draws the score', (tester) async {
      await tester.pumpWidget(host((ext) => RatingPill(ext: ext, rating: 4.7)));
      expect(find.text('4.7'), findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
    });

    testWidgets('shows 0.0 when unrated rather than vanishing',
        (tester) async {
      await tester.pumpWidget(host((ext) => RatingPill(ext: ext, rating: null)));
      expect(find.byIcon(Icons.star_rounded), findsOneWidget);
      expect(find.text('0.0'), findsOneWidget);
    });
  });

  testWidgets('a screen reader hears one sentence, not three fragments',
      (tester) async {
    const meta = PhotographerMeta(
      ext: AppThemeExtension.light,
      location: 'Nairobi',
      followerCount: 620,
      rating: 4.8,
    );
    expect(meta.semanticsLabel, 'rated 4.8, Nairobi, 620 followers');
    expect(
      const PhotographerMeta(
        ext: AppThemeExtension.light, location: 'Lagos', followerCount: 3,
      ).semanticsLabel,
      // Not "rated 0.0" — that would be read out as a bad score.
      'not yet rated, Lagos, 3 followers',
    );
  });
}
