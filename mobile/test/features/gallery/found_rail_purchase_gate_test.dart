import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_quick_actions.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What the Found viewer's rail offers depends on the photo once it is reached
/// from **Found you**: an unbought priced photo offers nothing at all, like and
/// comment are for public photos, and the download button appears only once the
/// photo has actually been bought. Everywhere else the rail is unchanged, and
/// that includes the bookmark, which Found you does not carry.
///
/// [bookmark] and [download] are deliberately checked as separate glyphs. They
/// were one button — the bookmark ran the download — so tapping Save wrote a
/// file to the phone and nothing was ever bookmarked. This file asserted that
/// behaviour too, with `const download = Icons.bookmark_border_rounded`.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

Photo photo({
  double price = 0,
  bool isPurchased = false,
  bool isPublic = false,
  bool commentsEnabled = true,
}) =>
    Photo.fromMap({
      'id': 'pic-1',
      'url': 'https://cdn.example.com/pic-1.jpg',
      'price': price,
      'public': isPublic,
      'isPurchased': isPurchased,
      'comments_enabled': commentsEnabled,
      'likeCount': 206,
      'commentCount': 10,
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

const like = Icons.favorite_border_rounded;
const comment = Icons.mode_comment_outlined;
const commentOff = Icons.comments_disabled_rounded;
const bookmark = Icons.bookmark_border_rounded;
/// The bar's download glyph. Deliberately a different icon from the rail's
/// old one, so a test cannot pass by finding the button in the wrong place.
const download = Icons.download_rounded;
const share = Icons.near_me_outlined;

/// The glyphs on the rail, in the order the rail lists them.
Set<IconData> railOf(WidgetTester t) => {
      // No download: it is not a rail action any more. [barHasDownload] asks
      // about it, and asking here as well would let a rail regression hide.
      for (final icon in [
        like,
        comment,
        commentOff,
        bookmark,
        share,
      ])
        if (t.any(find.byIcon(icon))) icon,
    };

Future<Set<IconData>> pumpRail(WidgetTester t, Photo p,
    {bool gated = true}) async {
  await t.pumpWidget(host(FoundActionRail(photo: p, purchaseGated: gated)));
  return railOf(t);
}

/// Whether the bar along the bottom of the photo offers the download.
///
/// The download moved off the rail and into that bar, beside the
/// photographer's name — see [FoundPhotoQuickActions]. Every question about
/// *whether* it is offered is still the same question, so it is asked here in
/// the same shape rather than being dropped.
Future<bool> barHasDownload(WidgetTester t, Photo p,
    {bool gated = true}) async {
  await t.pumpWidget(
      host(FoundPhotoQuickActions(photo: p, purchaseGated: gated)));
  await t.pump();
  return t.any(find.byIcon(download));
}

/// The rail's glyphs top to bottom. [railOf] answers *which* actions are on
/// offer; this answers where they sit, which is a separate question and the
/// only one an ordering assertion can be written against.
List<IconData> railOrder(WidgetTester t) {
  final icons = t
      .widgetList<Icon>(find.byType(Icon))
      .where((i) => i.icon != null)
      .toList();
  final positions = {
    for (final i in icons) i.icon!: t.getCenter(find.byIcon(i.icon!).first).dy,
  };
  final ordered = positions.keys.toList()
    ..sort((a, b) => positions[a]!.compareTo(positions[b]!));
  return ordered;
}

/// Answers "nothing is saved" without a network, a token or a signed-in user.
class _EmptyStore implements SavedPhotoStore {
  @override
  Future<List<String>> savedIds() async => const [];
  @override
  Future<void> save(String pictureId) async {}
  @override
  Future<void> unsave(String pictureId) async {}
}

/// The photo under test is already bookmarked.
class _SavedStore implements SavedPhotoStore {
  @override
  Future<List<String>> savedIds() async => const ['pic-1'];
  @override
  Future<void> save(String pictureId) async {}
  @override
  Future<void> unsave(String pictureId) async {}
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    GetIt.I.registerSingleton<SavedPhotos>(SavedPhotos(_EmptyStore()));
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();

    GetIt.I.reset();
  });

  group('a priced photo the viewer has not bought', () {
    testWidgets('offers nothing at all, private', (t) async {
      expect(await pumpRail(t, photo(price: 20)), isEmpty);
    });

    testWidgets('offers nothing at all, public either', (t) async {
      // Public is not the same question as bought. A photo of you that the
      // photographer has published is still one you have not paid for, and
      // there is nothing here to like, pass on or keep. Not even a bookmark:
      // the only thing to do with this photo is buy it.
      expect(await pumpRail(t, photo(price: 20, isPublic: true)), isEmpty);
    });
  });

  group('a paid photo the viewer has bought', () {
    testWidgets('private: download and share, but no comment', (t) async {
      // Private has no audience, so there is no thread to open — buying the
      // photo does not create one. Share is one glyph now: where the photo
      // goes is asked in ShareTargetSheet, not by a second button.
      final rail = await pumpRail(t, photo(price: 20, isPurchased: true));

      expect(rail, {share});
    });

    testWidgets('public: comment and like as well', (t) async {
      final rail = await pumpRail(
        t,
        photo(price: 20, isPurchased: true, isPublic: true),
      );

      expect(rail, {like, comment, share});
    });

    testWidgets('the download is not on the rail at all', (t) async {
      // It lives in the bar along the bottom now. Everything left on the rail
      // is something done with the photo on the platform; the download is the
      // one action that takes the file off it.
      final p = photo(price: 20, isPurchased: true, isPublic: true);

      expect(await pumpRail(t, p), isNot(contains(download)));
      expect(await barHasDownload(t, p), isTrue);
    });

    testWidgets('the download is what buying it unlocked', (t) async {
      // The same photo before and after: download is the one thing payment
      // adds, and it is never on offer before.
      expect(await barHasDownload(t, photo(price: 20, isPublic: true)),
          isFalse);
      expect(
        await barHasDownload(
            t, photo(price: 20, isPublic: true, isPurchased: true)),
        isTrue,
      );
    });
  });

  group('a free photo', () {
    testWidgets('is not downloadable until it is saved', (t) async {
      // Free to look at and free to pass on. Keeping it is a deliberate act
      // either way — paid for with money on a priced photo, with the bookmark
      // on a free one — so an unsaved free photo has no download.
      expect(await barHasDownload(t, photo()), isFalse);
      expect(await barHasDownload(t, photo(isPublic: true)), isFalse);
    });

    testWidgets('the rail is unchanged by any of it', (t) async {
      // The reactions are the reactions. Only the download reads the save.
      expect(await pumpRail(t, photo()), {share});
      expect(await pumpRail(t, photo(isPublic: true)), {like, comment, share});
    });

    testWidgets('needs no purchase to be reactable', (t) async {
      // `isPurchased` only goes true once a save has landed. Gating a free
      // photo on it would leave it with an empty rail and no way to fill it,
      // because the Buy pill is only drawn for a priced photo.
      expect(await pumpRail(t, photo(isPublic: true, isPurchased: false)),
          isNotEmpty);
    });
  });

  group('the owner switch', () {
    testWidgets('closes the thread and leaves the heart', (t) async {
      // It used to take the like with it, on the reading that the switch meant
      // "no feedback of any kind". It means "no discussion": somebody who
      // liked this yesterday must still be able to like it today.
      //
      // The comment glyph stays too, drawn off — a rail with none at all reads
      // as one that never had comments.
      final rail = await pumpRail(
        t,
        photo(
          price: 20,
          isPurchased: true,
          isPublic: true,
          commentsEnabled: false,
        ),
      );

      expect(rail, {like, commentOff, share});
    });

    testWidgets('says so on the ungated screens too', (t) async {
      final rail =
          await pumpRail(t, photo(commentsEnabled: false), gated: false);

      expect(rail, {like, commentOff, bookmark, share});
    });

    testWidgets('a private photo shows no comment glyph, crossed or not',
        (t) async {
      // Private has no audience by rule rather than by the owner's decision.
      // Marking every private photo "comments disabled" would be noise about
      // a thread that was never on offer.
      final rail = await pumpRail(t, photo(price: 20, isPurchased: true));

      expect(rail, isNot(contains(commentOff)));
      expect(rail, {share});
    });

    testWidgets('an unbought photo shows nothing, switch or no switch',
        (t) async {
      expect(
        await pumpRail(
            t, photo(price: 20, isPublic: true, commentsEnabled: false)),
        isEmpty,
      );
    });
  });

  group('the bookmark is an ungated-screen action', () {
    testWidgets('ungated callers keep everything but the download', (t) async {
      // Discovery, search, a profile grid, a shared link: the photo is
      // someone's work rather than a photo of you. Like, comment, bookmark and
      // share all apply; downloading it does not, because nobody has bought
      // anything here.
      final rail = await pumpRail(t, photo(price: 20), gated: false);

      expect(rail, {like, comment, bookmark, share});
    });

    testWidgets('and never appears in Found you, paid or free', (t) async {
      // Found you asks whether to buy the photo, not whether to keep a
      // reference to it.
      for (final p in [
        photo(),
        photo(isPublic: true),
        photo(price: 20),
        photo(price: 20, isPurchased: true),
        photo(price: 20, isPurchased: true, isPublic: true),
      ]) {
        expect(await pumpRail(t, p), isNot(contains(bookmark)));
      }
    });

    testWidgets('fills once the photo is saved', (t) async {
      // The state the glyph never had while it was really a download button:
      // nothing was stored, so nothing could come back filled, and there was
      // no way to un-save.
      GetIt.I.unregister<SavedPhotos>();
      GetIt.I.registerSingleton<SavedPhotos>(SavedPhotos(_SavedStore()));

      await pumpRail(t, photo(isPublic: true), gated: false);
      await t.pumpAndSettle();

      expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
      expect(find.byIcon(bookmark), findsNothing);
    });
  });

  group('the download', () {
    testWidgets('appears nowhere but a bought photo in Found you', (t) async {
      // The whole rule in one place. Every combination that is not "Found you,
      // priced, paid for" must not offer to write the file to the phone —
      // everywhere else the photo belongs to the photographer who took it.
      for (final gated in [true, false]) {
        for (final p in [
          photo(),
          photo(isPublic: true),
          photo(isPurchased: true),
          photo(isPublic: true, isPurchased: true),
          photo(price: 20),
          photo(price: 20, isPublic: true),
        ]) {
          expect(
            await pumpRail(t, p, gated: gated),
            isNot(contains(download)),
            reason: 'gated=$gated price=${p.price} '
                'purchased=${p.isPurchased} public=${p.isPublic}',
          );
        }
      }
    });

    testWidgets('appears on a bought photo in Found you, and only there',
        (t) async {
      final bought = photo(price: 20, isPurchased: true);

      expect(await barHasDownload(t, bought, gated: true), isTrue);
      // Same photo, opened from a screen that shows someone's work. Nobody has
      // bought anything there, so the bar has nothing to offer and draws
      // nothing at all.
      expect(await barHasDownload(t, bought, gated: false), isFalse);
    });
  });
}
