import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What the Found viewer's rail offers depends on the photo once it is reached
/// from **Found you**: an unbought priced photo offers only the bookmark, like
/// and comment are for public photos, and the download button is what a paid
/// photo gets that a free one doesn't. Everywhere else the rail is unchanged.
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
const download = Icons.download_outlined;
const share = Icons.ios_share_rounded;
const send = Icons.near_me_outlined;

/// The glyphs on the rail, in the order the rail lists them.
Set<IconData> railOf(WidgetTester t) => {
      for (final icon in [
        like,
        comment,
        commentOff,
        bookmark,
        download,
        share,
        send
      ])
        if (t.any(find.byIcon(icon))) icon,
    };

Future<Set<IconData>> pumpRail(WidgetTester t, Photo p,
    {bool gated = true}) async {
  await t.pumpWidget(host(FoundActionRail(photo: p, purchaseGated: gated)));
  return railOf(t);
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
    testWidgets('offers the bookmark and nothing else, private', (t) async {
      // A bookmark is a reference to a photo already on screen — it hands the
      // viewer nothing they did not have, so it is not something to be bought.
      // It is also the one thing worth having on a photo you have not decided
      // about yet: keep it where you can find it again.
      expect(await pumpRail(t, photo(price: 20)), {bookmark});
    });

    testWidgets('offers the bookmark and nothing else, public either',
        (t) async {
      // Public is not the same question as bought. A photo of you that the
      // photographer has published is still one you have not paid for, and
      // there is nothing here to like, pass on or keep.
      expect(
          await pumpRail(t, photo(price: 20, isPublic: true)), {bookmark});
    });

    testWidgets('and never the download', (t) async {
      final rail = await pumpRail(t, photo(price: 20, isPublic: true));

      expect(rail, isNot(contains(download)));
    });
  });

  group('a paid photo the viewer has bought', () {
    testWidgets('private: bookmark, download, share, send; no engagement',
        (t) async {
      final rail = await pumpRail(t, photo(price: 20, isPurchased: true));

      expect(rail, {bookmark, download, share, send});
    });

    testWidgets('public: engagement as well', (t) async {
      final rail = await pumpRail(
        t,
        photo(price: 20, isPurchased: true, isPublic: true),
      );

      expect(rail, {like, comment, bookmark, download, share, send});
    });
  });

  group('a free photo', () {
    testWidgets('is never downloadable, public or not', (t) async {
      // Free to look at and free to pass on, but not free to keep — the
      // download button is the paid photo's extra. The bookmark is not: it
      // costs nothing to offer and rides along on every photo.
      expect(await pumpRail(t, photo()), {bookmark, share, send});
      expect(await pumpRail(t, photo(isPublic: true)),
          {like, comment, bookmark, share, send});
    });

    testWidgets('can still be bookmarked', (t) async {
      // The bookmark used to be the download button wearing its glyph, so it
      // inherited the paid gate and a free photo could not be saved at all.
      expect(await pumpRail(t, photo()), contains(bookmark));
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
    testWidgets('takes the like and leaves the comment, drawn off', (t) async {
      // Not the same as hiding it. The owner closed the thread, and a rail
      // with no comment glyph at all reads as one that never had comments.
      final rail = await pumpRail(
        t,
        photo(
          price: 20,
          isPurchased: true,
          isPublic: true,
          commentsEnabled: false,
        ),
      );

      expect(rail, {commentOff, bookmark, download, share, send});
    });

    testWidgets('says so on the ungated screens too', (t) async {
      final rail =
          await pumpRail(t, photo(commentsEnabled: false), gated: false);

      expect(rail, {commentOff, bookmark, download, share, send});
    });

    testWidgets('a private photo shows no comment glyph, crossed or not',
        (t) async {
      // Private has no audience by rule rather than by the owner's decision.
      // Marking every private photo "comments disabled" would be noise about
      // a thread that was never on offer.
      final rail = await pumpRail(t, photo(price: 20, isPurchased: true));

      expect(rail, isNot(contains(commentOff)));
      expect(rail, {bookmark, download, share, send});
    });

    testWidgets('an unbought photo shows only the bookmark, switch or no switch',
        (t) async {
      expect(
        await pumpRail(
            t, photo(price: 20, isPublic: true, commentsEnabled: false)),
        {bookmark},
      );
    });
  });

  testWidgets('ungated callers are untouched by any of it', (t) async {
    // Discovery, search, a profile grid, a shared link: the photo is someone's
    // work rather than a photo of you, there is nothing to have bought, and
    // the rail is what it always was.
    final rail = await pumpRail(t, photo(price: 20), gated: false);

    expect(rail, {like, comment, bookmark, download, share, send});
  });

  testWidgets('the bookmark fills once the photo is saved', (t) async {
    // The state the glyph never had while it was really a download button:
    // nothing was stored, so nothing could come back filled, and there was no
    // way to un-save.
    GetIt.I.unregister<SavedPhotos>();
    GetIt.I.registerSingleton<SavedPhotos>(SavedPhotos(_SavedStore()));

    await pumpRail(t, photo(isPublic: true));
    await t.pumpAndSettle();

    expect(find.byIcon(Icons.bookmark_rounded), findsOneWidget);
    expect(find.byIcon(bookmark), findsNothing);
  });
}
