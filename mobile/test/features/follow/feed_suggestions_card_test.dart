import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/feed_suggestions_card.dart';

/// The card of suggested creators dealt between posts in the Following feed.
///
/// It used to be a page of its own in a vertical [PageView], so it was
/// stretched to the whole viewport whatever it held — five rows and then half
/// a screen of nothing. What matters now is that it is only as tall as its
/// contents, so the post after it starts right below.
const _suggestions = [
  SuggestedPhotographer(
    id: 'p1',
    name: 'Hussein Amadu',
    contact: '',
    email: 'h@example.com',
    followerCount: 4,
  ),
  SuggestedPhotographer(
    id: 'p2',
    name: 'Omg photos',
    contact: '',
    email: 'o@example.com',
    followerCount: 4,
  ),
  SuggestedPhotographer(
    id: 'p3',
    name: 'Michael Acheampong',
    contact: '',
    email: 'm@example.com',
    followerCount: 4,
  ),
];

/// The card as the feed places it — an item in a scrolling list, with the
/// viewport it must *not* fill.
Widget host({List<SuggestedPhotographer>? data}) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
          body: ListView(
            children: [
              FeedSuggestionsCard(suggestions: data ?? _suggestions),
              const SizedBox(key: ValueKey('next_post'), height: 400),
            ],
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  testWidgets('does not fill the screen', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    final card = t.getSize(find.byType(FeedSuggestionsCard));
    final screen = t.getSize(find.byType(Scaffold));

    expect(card.height, lessThan(screen.height * 0.75),
        reason: 'the card is an item in the feed, not a screen of its own');
  });

  testWidgets('is only as tall as its rows', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();
    final three = t.getSize(find.byType(FeedSuggestionsCard)).height;

    await t.pumpWidget(host(data: _suggestions.take(1).toList()));
    await t.pumpAndSettle();
    final one = t.getSize(find.byType(FeedSuggestionsCard)).height;

    // A fixed-height card would measure the same either way — that was the
    // old behaviour, and the empty half of the screen came with it.
    expect(one, lessThan(three));
  });

  testWidgets('the next post starts just below it', (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    final card = t.getRect(find.byType(FeedSuggestionsCard));
    final next = t.getRect(find.byKey(const ValueKey('next_post')));

    expect(next.top - card.bottom, lessThan(8),
        reason: 'no dead space between the card and the post after it');
  });

  testWidgets('still offers every creator with a way to follow them',
      (t) async {
    await t.pumpWidget(host());
    await t.pumpAndSettle();

    expect(find.text('Creators you might like'), findsOneWidget);
    expect(find.text('SUGGESTED CREATORS'), findsOneWidget);
    for (final s in _suggestions) {
      expect(find.text(s.name), findsOneWidget);
    }
    expect(find.text('Follow'), findsNWidgets(_suggestions.length));
  });
}
