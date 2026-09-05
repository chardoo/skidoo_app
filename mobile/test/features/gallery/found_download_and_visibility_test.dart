import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_photo_actions.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_meta_bar.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_visibility_badge.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Two changes to the full-screen Found viewer.
///
/// **The bottom bar.** It used to end in a "View album" button. That went, and
/// the download came down off the vertical rail to take its place beside the
/// photographer's name — the one action that takes the file off the platform,
/// sitting next to whose work it is. Sharing stayed on the rail with the other
/// engagements.
///
/// **The top-left marker.** "Public" and "Private" are the same length, start
/// in the same place and differed by a colour many people cannot tell apart, so
/// the pill was read by its shape and its shape never changed. An open eye and
/// a struck-through one differ at a glance.
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
}) =>
    Photo.fromMap({
      'id': 'pic-1',
      'url': 'https://cdn.example.com/pic-1.jpg',
      'price': price,
      'isPurchased': isPurchased,
      'public': isPublic,
      'comments_enabled': true,
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

void main() {
  group('what earns a download', () {
    test('a priced photo has to have been bought', () {
      expect(
        FoundPhotoActions.forFoundPhoto(photo(price: 20)).download,
        isFalse,
      );
      expect(
        FoundPhotoActions.forFoundPhoto(photo(price: 20, isPurchased: true))
            .download,
        isTrue,
      );
    });

    test('a free private photo is already the viewer\'s', () {
      // Nothing left to transact. A private photo is reachable only by the
      // people recognition found in it, so one on this screen is a photo of the
      // viewer that nobody else can see — and free means there is no price
      // either. Asking for a save first was a step that granted nothing, on a
      // screen that does not offer the bookmark to complete it.
      expect(FoundPhotoActions.forFoundPhoto(photo()).download, isTrue);
    });

    test('a free photo that was claimed is downloadable, public or not', () {
      // `isPurchased` is a PaidImage row, and adding a *free* photo to the
      // gallery writes one at a price of zero. The rule used to ask
      // `price > 0`, which is true only of paid photos — so a free photo the
      // viewer had explicitly claimed read the same as one they had never
      // touched. This is the case the Eastern Germany photos were in.
      expect(
        FoundPhotoActions.forFoundPhoto(
          photo(isPublic: true, isPurchased: true),
        ).download,
        isTrue,
      );
    });

    test('a free public photo nobody has claimed is not downloadable', () {
      // The one free case still refused, and the reason the private test above
      // is about privacy rather than about price. This photo is on show to
      // everyone; taking the file is what a claim is for.
      expect(
        FoundPhotoActions.forFoundPhoto(photo(isPublic: true)).download,
        isFalse,
      );
      expect(
        FoundPhotoActions.forFoundPhoto(photo(isPublic: true), saved: true)
            .download,
        isTrue,
      );
    });

    test('saving does not unlock a photo that was never bought', () {
      // An unbought priced photo offers nothing at all — a bookmark must not
      // be a way round the price.
      final actions =
          FoundPhotoActions.forFoundPhoto(photo(price: 20), saved: true);

      expect(actions.download, isFalse);
      expect(actions.any, isFalse);
    });

    test('screens showing someone else\'s work never offer it', () {
      // Discovery, search, a profile grid, a shared link. Nobody has bought
      // anything there, so a download would hand out a photographer's photo.
      expect(
        const FoundPhotoActions.unrestricted(commentsEnabled: true).download,
        isFalse,
      );
    });
  });

  group('where each action is drawn', () {
    // The photo's visibility decides, and only its visibility. A public photo
    // keeps the vertical rail it has always had; a private one has almost
    // nothing to put in a rail — no heart, no thread, both public-only — so
    // what it does have goes along the bottom and the right edge is left as
    // photograph.

    test('a public photo keeps every engagement on the rail', () {
      final bought = FoundPhotoActions.forFoundPhoto(
          photo(price: 20, isPurchased: true, isPublic: true));

      expect(bought.share, isTrue);
      expect(bought.anyInRail, isTrue);
      expect(bought.engagementsAtBottom, isFalse);
      // The bar is still the download alone, as it was.
      expect(bought.download, isTrue);
    });

    test('a private photo moves its engagements to the bar', () {
      final private =
          FoundPhotoActions.forFoundPhoto(photo(price: 20, isPurchased: true));

      expect(private.share, isTrue, reason: 'it still has something to offer');
      expect(private.anyInRail, isFalse, reason: 'nothing down the right edge');
      expect(private.anyInBar, isTrue);
      expect(private.engagementsAtBottom, isTrue);
    });

    test('a private photo with a download puts both in the bar', () {
      final free = FoundPhotoActions.forFoundPhoto(photo(), saved: true);

      expect(free.download, isTrue);
      expect(free.share, isTrue);
      expect(free.anyInBar, isTrue);
      expect(free.anyInRail, isFalse);
    });

    test('a photo with nothing on offer draws neither', () {
      // Unbought and priced. The rule about where things go must not conjure a
      // bottom row for a photo that has no actions at all.
      final locked = FoundPhotoActions.forFoundPhoto(photo(price: 20));

      expect(locked.any, isFalse);
      expect(locked.anyInRail, isFalse);
      expect(locked.anyInBar, isFalse);
    });

    test('a private photo that still has reactions keeps its rail', () {
      // Discovery, search, a profile grid, a shared link. Nothing there is
      // gated, so even a private photo carries the full set — heart, thread,
      // bookmark, share, each with a count. Four counted actions beside the
      // photographer's name is not a bar, it is an overflowing row, and the
      // reason for moving them does not apply: the rail is not nearly empty.
      const onSomebodysWork = FoundPhotoActions.unrestricted(
          commentsEnabled: true, isPublic: false);

      expect(onSomebodysWork.like, isTrue);
      expect(onSomebodysWork.engagementsAtBottom, isFalse);
      expect(onSomebodysWork.anyInRail, isTrue);
    });
  });

  group('the bottom bar', () {
    testWidgets('no longer offers View album', (t) async {
      await t.pumpWidget(host(FoundPhotoMetaBar(photo: photo())));

      expect(find.text('View album'), findsNothing);
    });

    testWidgets('still names the photographer', (t) async {
      // The identity block is the half of the bar that did not change.
      await t.pumpWidget(host(FoundPhotoMetaBar(photo: photo())));

      expect(find.text('Praise Reloaded 2026'), findsOneWidget);
    });
  });

  group('the visibility marker', () {
    testWidgets('a public photo gets an open eye', (t) async {
      await t.pumpWidget(host(const FoundVisibilityBadge(isPublic: true)));

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);
      expect(find.text('Public'), findsNothing);
    });

    testWidgets('a private photo gets a closed one', (t) async {
      await t.pumpWidget(host(const FoundVisibilityBadge(isPublic: false)));

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);
      expect(find.text('Private'), findsNothing);
    });

    testWidgets('the word survives for screen readers', (t) async {
      // A bare icon announces itself as nothing, and "eye" is not what should
      // be read out here.
      await t.pumpWidget(host(const FoundVisibilityBadge(isPublic: false)));

      expect(find.bySemanticsLabel('Private photo'), findsOneWidget);
    });
  });
}
