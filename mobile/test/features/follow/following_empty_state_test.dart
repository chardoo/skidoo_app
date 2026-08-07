import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/follow/data/follow_repository.dart';
import 'package:jperg_app/features/follow/presentation/widgets/following_empty_state.dart';

const _suggestions = [
  SuggestedPhotographer(
    id: 'p1',
    name: 'Cle Williams',
    contact: '',
    email: 'cle@example.com',
    followerCount: 1200,
    category: 'Events & Nature',
  ),
  SuggestedPhotographer(
    id: 'p2',
    name: 'Jordan Smith',
    contact: '',
    email: 'jordan@example.com',
    followerCount: 92,
  ),
];

Widget host(AppThemeExtension ext,
        {List<SuggestedPhotographer>? data, double topPadding = 0}) =>
    ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData(
          brightness: ext == AppThemeExtension.light
              ? Brightness.light
              : Brightness.dark,
          extensions: [ext],
        ),
        home: Scaffold(
          backgroundColor: ext.homeBackground,
          body: FollowingEmptyState(
            topPadding: topPadding,
            loadSuggestions: () async => data ?? _suggestions,
          ),
        ),
      ),
    );

Color colorOfText(WidgetTester t, String text) =>
    t.widget<Text>(find.text(text)).style!.color!;

void main() {
  testWidgets('shows the message and the way out of it', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));
    await t.pumpAndSettle();

    expect(find.text('Follow creators to see their works here'), findsOneWidget);
    expect(find.text('SUGGESTED CREATORS'), findsOneWidget);
    expect(find.text('Cle Williams'), findsOneWidget);
    expect(find.text('Jordan Smith'), findsOneWidget);
    // Every creator carries its own way to follow them.
    expect(find.text('Follow'), findsNWidgets(2));
  });

  testWidgets('a category reads beside the follower count, and is optional',
      (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));
    await t.pumpAndSettle();

    expect(find.text('Events & Nature · 1.2K followers'), findsOneWidget);
    // p2 has no category on record — the row is the count alone, with no
    // orphaned separator.
    expect(find.text('92 followers'), findsOneWidget);
  });

  testWidgets('dark theme colours come from the dark palette', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark));
    await t.pumpAndSettle();

    expect(colorOfText(t, 'Follow creators to see their works here'),
        AppThemeExtension.dark.greetingColor);
    expect(colorOfText(t, 'SUGGESTED CREATORS'),
        AppThemeExtension.dark.searchHintColor);
    expect(colorOfText(t, 'Cle Williams'),
        AppThemeExtension.dark.greetingColor);
  });

  testWidgets('light theme colours come from the light palette', (t) async {
    await t.pumpWidget(host(AppThemeExtension.light));
    await t.pumpAndSettle();

    expect(colorOfText(t, 'Follow creators to see their works here'),
        AppThemeExtension.light.greetingColor);
    expect(colorOfText(t, 'SUGGESTED CREATORS'),
        AppThemeExtension.light.searchHintColor);
    expect(colorOfText(t, 'Cle Williams'),
        AppThemeExtension.light.greetingColor);
  });

  testWidgets('the empty-state disc is a themed slot, not a fixed grey',
      (t) async {
    for (final ext in [AppThemeExtension.dark, AppThemeExtension.light]) {
      await t.pumpWidget(host(ext));
      await t.pumpAndSettle();

      final disc = t.widget<Container>(find
          .ancestor(
            of: find.byIcon(Icons.people_alt_rounded),
            matching: find.byType(Container),
          )
          .first);
      expect((disc.decoration as BoxDecoration).color, ext.searchFieldFill,
          reason: 'a hardcoded fill punches a hole in one of the two themes');
    }
  });

  testWidgets('no suggestions still leaves the message standing', (t) async {
    await t.pumpWidget(host(AppThemeExtension.dark, data: const []));
    await t.pumpAndSettle();

    expect(find.text('Follow creators to see their works here'), findsOneWidget);
    expect(find.text('No suggestions available yet.'), findsOneWidget);
  });

  // The endpoint omits anyone the user already follows, so an empty list is
  // ambiguous on its own — with a follow on record it means they've reached
  // the end of the suggestions, not that something is missing.
  testWidgets('an empty list reads as "followed everyone", not as a fault, '
      'once the user follows someone', (t) async {
    FollowRepository.seedFollowed(['someone-else']);
    addTearDown(FollowRepository.debugClearFollowed);

    await t.pumpWidget(host(AppThemeExtension.dark, data: const []));
    await t.pumpAndSettle();

    expect(find.textContaining("You're following everyone"), findsOneWidget);
    expect(find.text('No suggestions available yet.'), findsNothing);
  });

  testWidgets('starts below the floating header rather than under it',
      (t) async {
    // The Following tab passes the same top padding to every page it shows,
    // and that used to be 0 — right for a full-bleed photo, which is meant to
    // run edge-to-edge under the header, wrong for this one, whose icon and
    // headline landed behind the status bar and the tab labels.
    await t.pumpWidget(host(AppThemeExtension.dark));
    await t.pumpAndSettle();
    final withNone =
        t.getRect(find.text('Follow creators to see their works here')).top;

    await t.pumpWidget(host(AppThemeExtension.dark, topPadding: 120));
    await t.pumpAndSettle();
    final withHeader =
        t.getRect(find.text('Follow creators to see their works here')).top;

    expect(withHeader - withNone, moreOrLessEquals(120, epsilon: 1));
  });
}
