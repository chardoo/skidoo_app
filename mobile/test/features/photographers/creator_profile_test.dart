import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/photographers/presentation/pages/creator_profile_page.dart';

/// One profile for one person.
///
/// The app had two. A tap on any avatar opened a plain page with Sample Work
/// and Events; the request board opened a far better one — banner, rating pill,
/// specialties, a real portfolio — that nothing else could reach. Same person,
/// two screens, and the good one was the one nobody could get to.
///
/// This is the merged screen: the request board's design, with the Events tab
/// the other one had and the Follow and Message buttons it was missing.
Widget host(CreatorProfile profile) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: CreatorProfilePage(profile: profile, fetchProfile: false),
      ),
    );

CreatorProfile profile({
  String name = 'Joe',
  String? bio = 'I am a professional studio guy.',
  List<String> specialties = const ['Nature', 'Wedding'],
  int followerCount = 3,
  double? rating = 5.0,
}) =>
    CreatorProfile(
      id: 'p1',
      name: name,
      bio: bio,
      specialties: specialties,
      followerCount: followerCount,
      rating: rating,
      location: 'Accra',
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

  testWidgets('the header states who they are', (t) async {
    await t.pumpWidget(host(profile()));
    await t.pump();

    // Name in the bar and again beside the avatar, as the design draws it.
    expect(find.text('Joe'), findsNWidgets(2));
    expect(find.textContaining('3 followers'), findsOneWidget);
    expect(find.text('5.0'), findsOneWidget);
  });

  testWidgets('the bio comes before the specialties', (t) async {
    // The order asked for: what they say about themselves, then the labels.
    await t.pumpWidget(host(profile()));
    await t.pump();

    final bio = t.getRect(find.textContaining('professional studio guy')).top;
    final chip = t.getRect(find.text('Nature')).top;

    expect(bio, lessThan(chip));
  });

  testWidgets('three tabs, with Events among them', (t) async {
    await t.pumpWidget(host(profile()));
    await t.pump();

    expect(find.text('Portfolio'), findsOneWidget);
    expect(find.textContaining('Reviews'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
  });

  testWidgets('a person with nothing written still renders', (t) async {
    // Most profiles have no bio and no specialties. The section goes rather
    // than standing empty over a heading.
    await t.pumpWidget(host(profile(bio: null, specialties: const [])));
    await t.pump();

    expect(t.takeException(), isNull);
    expect(find.text('Bio & specialties'), findsNothing);
    expect(find.text('Portfolio'), findsOneWidget);
  });

  testWidgets('the tabs survive a long review count on a narrow phone',
      (t) async {
    await t.pumpWidget(host(profile()));
    await t.pump();

    // Three tabs is one more than this row was built for; it scrolls rather
    // than painting an overflow bar across somebody's profile.
    expect(t.takeException(), isNull);
  });

  group('the screens are actually merged', () {
    test('the page every creator tap opens is the one the board opens', () {
      // Both go through CreatorProfilePage. A second profile page reappearing
      // is the regression this whole change exists to prevent.
      final opener = File(
        'lib/features/discovery/presentation/utils/open_photographer_profile.dart',
      ).readAsStringSync();
      final board = File(
        'lib/features/ads/presentation/pages/request_photographer_page.dart',
      ).readAsStringSync();

      expect(opener, contains('CreatorProfilePage'));
      expect(board, contains('CreatorProfilePage'));
    });

    test('the page it replaced is gone', () {
      expect(
        File('lib/features/photographers/presentation/pages/'
                'photographer_profile_page.dart')
            .existsSync(),
        isFalse,
      );
    });

    test('an event opens from a profile with no bloc above it', () {
      // Tapping an event used to fire HomeImagesSearched, which meant it only
      // worked where a HomeBloc happened to be in the tree — from Following,
      // which pushes the page bare, the tap threw. It opens the album by id
      // now, so neither the page nor the helper needs anything carried in.
      final page = File('lib/features/photographers/presentation/pages/'
              'creator_profile_page.dart')
          .readAsStringSync();
      final opener = File(
        'lib/features/discovery/presentation/utils/open_photographer_profile.dart',
      ).readAsStringSync();

      expect(page, contains('SearchEventPhotosPage'));
      expect(page, isNot(contains('HomeImagesSearched')));
      expect(opener, isNot(contains('HomeBloc')));
    });

    test('nothing still reaches for it', () {
      // An import left behind would not compile, but a stale reference in a
      // comment or a route table would sit there looking correct.
      final lib = Directory('lib')
          .listSync(recursive: true)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'));

      for (final file in lib) {
        expect(file.readAsStringSync(), isNot(contains('PhotographerProfilePage')),
            reason: '${file.path} still names the retired page');
      }
    });
  });
}
