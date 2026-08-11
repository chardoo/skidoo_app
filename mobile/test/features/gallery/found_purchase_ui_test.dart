import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_tile.dart';
import 'package:jperg_app/core/purchase/photo_purchase_bar.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_review_prompt.dart';
import 'package:jperg_app/features/gallery/presentation/found/models/found_album.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_photo_grid.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What the album screen actually puts in front of someone.
///
/// The wording on the button is the only warning that pressing it charges for
/// every photo still ticked, so the count and the total are worth asserting
/// rather than eyeballing.
Photo _photo(
  String id, {
  double price = 0,
  bool purchased = false,
  String review = 'pending',
}) =>
    Photo(
      id,
      'Praise Reloaded 2026',
      'img_$id',
      'https://example.com/$id.jpg',
      'photographer-1',
      price,
      '',
      null,
      false,
      eventId: 'event-1',
      isPurchased: purchased,
      reviewStatus: review,
    );

Widget _wrap(Widget child) => ScreenUtilInit(
      designSize: const Size(412, 917),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

void main() {
  group('PhotoPurchaseBar — review screen', () {
    testWidgets('states the count and the total on the button', (tester) async {
      final selection = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
        _photo('c', price: 20),
      ]);

      await tester.pumpWidget(_wrap(PhotoPurchaseBar(
        selection: selection,
        onCheckout: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Get 3 photos – GHS 60.00'), findsOneWidget);
    });

    testWidgets('says how many free photos ride along', (tester) async {
      final selection = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('f1'),
        _photo('f2'),
      ]);

      await tester.pumpWidget(_wrap(PhotoPurchaseBar(
        selection: selection,
        onCheckout: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('2 free photos saved automatically'), findsOneWidget);
    });

    testWidgets('drops the total when a photo is marked not me',
        (tester) async {
      final selection = PhotoSelection(reviewMode: true, photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      await tester.pumpWidget(_wrap(PhotoPurchaseBar(
        selection: selection,
        onCheckout: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.text('Get 2 photos – GHS 40.00'), findsOneWidget);

      selection.toggle('a');
      await tester.pumpAndSettle();

      expect(find.text('Get 1 photo – GHS 20.00'), findsOneWidget);
    });

    testWidgets('disappears when every match is rejected', (tester) async {
      final selection = PhotoSelection(reviewMode: true, photos: [_photo('a', price: 20)]);

      await tester.pumpWidget(_wrap(PhotoPurchaseBar(
        selection: selection,
        onCheckout: () {},
      )));
      await tester.pumpAndSettle();
      expect(find.textContaining('Get 1 photo'), findsOneWidget);

      selection.toggle('a');
      await tester.pumpAndSettle();

      // No button rather than "Get 0 photos – GHS 0".
      expect(find.textContaining('Get'), findsNothing);
    });
  });

  group('FoundPhotoTile', () {
    testWidgets('shows the price on a photo that has to be bought',
        (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: FoundPhotoTile(photo: _photo('a', price: 20), onTap: () {}),
      )));
      await tester.pumpAndSettle();

      expect(find.text('GHS 20'), findsOneWidget);
    });

    testWidgets('shows no price on a photo already owned', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: FoundPhotoTile(
          photo: _photo('a', price: 20, purchased: true),
          onTap: () {},
        ),
      )));
      await tester.pumpAndSettle();

      // Repeating the amount on a photo they have paid for reads as a second
      // charge.
      expect(find.text('GHS 20'), findsNothing);
    });

    testWidgets('labels a deselected tile "Not me" while reviewing',
        (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: FoundPhotoTile(
          photo: _photo('a', price: 20),
          onTap: () {},
          selectable: true,
          selected: false,
          reviewing: true,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Not me'), findsOneWidget);
      // Still priced — a dimmed badge, not a missing one, or it would read as
      // free.
      expect(find.text('GHS 20'), findsOneWidget);
    });

    testWidgets('an unchosen tile on the browsing grid is not "Not me"',
        (tester) async {
      // The browsing grid opens with nothing selected. Before this was gated,
      // every tile in the album rendered dimmed and rejected the moment it
      // opened — the whole grid read as "none of these are you".
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: FoundPhotoTile(
          photo: _photo('a', price: 20),
          onTap: () {},
          selectable: true,
          selected: false,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Not me'), findsNothing);
      expect(find.text('GHS 20'), findsOneWidget);
    });

    testWidgets('a confirmed photo is never offered "Not me"', (tester) async {
      // They have already said this is them. Re-asking on every visit invites
      // them to undo an answer nobody asked them to revisit.
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: FoundPhotoTile(
          photo: _photo('a', price: 20, review: 'confirmed'),
          onTap: () {},
          selectable: true,
          selected: false,
          // The grid computes this as reviewMode && isPendingReview, so a
          // confirmed photo arrives here false even mid-review.
          reviewing: false,
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('Not me'), findsNothing);
    });

    testWidgets('tapping a selectable tile toggles rather than opens',
        (tester) async {
      var opened = false;
      var toggled = false;

      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: FoundPhotoTile(
          photo: _photo('a', price: 20),
          onTap: () => opened = true,
          selectable: true,
          onToggle: () => toggled = true,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FoundPhotoTile));
      await tester.pumpAndSettle();

      expect(toggled, isTrue);
      expect(opened, isFalse,
          reason: 'the caption promises tap means deselect');
    });
  });

  group('PhotoPurchaseBar — browsing an album', () {
    testWidgets('shows nothing until a photo is chosen', (tester) async {
      final selection = PhotoSelection(photos: [
        _photo('a', price: 20),
        _photo('b', price: 20),
      ]);

      await tester.pumpWidget(_wrap(PhotoPurchaseBar(
        selection: selection,
        onCheckout: () {},
      )));
      await tester.pumpAndSettle();

      // The album opens with nothing selected, so proposing to charge for
      // anything would be inventing an intent the person has not expressed.
      expect(find.textContaining('Get'), findsNothing);

      selection.toggle('a');
      await tester.pumpAndSettle();

      expect(find.text('Get 1 photo – GHS 20.00'), findsOneWidget);
    });

    testWidgets('never claims free photos are saved automatically',
        (tester) async {
      final selection = PhotoSelection(photos: [
        _photo('a', price: 20),
        _photo('f1'),
        _photo('f2'),
      ]);
      selection.toggle('a');
      selection.toggle('f1');

      await tester.pumpWidget(_wrap(PhotoPurchaseBar(
        selection: selection,
        onCheckout: () {},
      )));
      await tester.pumpAndSettle();

      // That line belongs to the review screen. Here the person picked what
      // they wanted, and nothing is being saved behind their back.
      expect(find.textContaining('saved automatically'), findsNothing);
      expect(find.text('Get 1 photo – GHS 20.00'), findsOneWidget);
    });
  });

  group('FoundReviewPrompt', () {
    testWidgets('asks the question with both answers available',
        (tester) async {
      await tester.pumpWidget(_wrap(FoundReviewPrompt(
        onYes: () {},
        onNo: () {},
      )));
      await tester.pumpAndSettle();

      expect(find.text('Is this your photo?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('No'), findsOneWidget);
    });

    testWidgets('reports which answer was given', (tester) async {
      String? answered;

      await tester.pumpWidget(_wrap(FoundReviewPrompt(
        onYes: () => answered = 'yes',
        onNo: () => answered = 'no',
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('No'));
      expect(answered, 'no');

      await tester.tap(find.text('Yes'));
      expect(answered, 'yes');
    });

    testWidgets('goes inert while an answer is in flight', (tester) async {
      var taps = 0;

      await tester.pumpWidget(_wrap(FoundReviewPrompt(
        busy: true,
        onYes: () => taps++,
        onNo: () => taps++,
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Yes'));
      await tester.tap(find.text('No'));

      // Double-answering would send a second verdict for a photo that has
      // already left the queue.
      expect(taps, 0);
    });
  });

  group('SearchPhotoTile — any grid that sells photos', () {
    testWidgets('shows the price on a priced photo', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: SearchPhotoTile(photo: _photo('a', price: 20), onTap: () {}),
      )));
      await tester.pumpAndSettle();

      expect(find.text('GHS 20'), findsOneWidget);
    });

    testWidgets('shows nothing on a free photo', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: SearchPhotoTile(photo: _photo('a'), onTap: () {}),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('GHS'), findsNothing);
    });

    testWidgets('shows nothing on a photo already owned', (tester) async {
      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: SearchPhotoTile(
          photo: _photo('a', price: 20, purchased: true),
          onTap: () {},
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.textContaining('GHS'), findsNothing);
    });

    testWidgets('a priced tile toggles on tap and opens on long press',
        (tester) async {
      var opened = false;
      var toggled = false;

      await tester.pumpWidget(_wrap(SizedBox(
        width: 120,
        height: 120,
        child: SearchPhotoTile(
          photo: _photo('a', price: 20),
          onTap: () => opened = true,
          selectable: true,
          onToggle: () => toggled = true,
        ),
      )));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SearchPhotoTile));
      expect(toggled, isTrue);
      expect(opened, isFalse);

      await tester.longPress(find.byType(SearchPhotoTile));
      expect(opened, isTrue);
    });
  });

  group('FoundAlbum counts', () {
    Map<String, dynamic> json({int photoCount = 7, int? mineCount}) => {
          'event': {'id': 'evt', 'eventName': 'Praise Reloaded 2026'},
          'photos': const <Map<String, dynamic>>[],
          'photoCount': photoCount,
          if (mineCount != null) 'mineCount': mineCount,
        };

    test('keeps the viewer\'s share apart from the row count', () {
      // The album carries the event's public photos too, so the two differ —
      // and only mineCount may be spoken as "N photos of you found!".
      final album = FoundAlbum.fromJson(json(photoCount: 7, mineCount: 4));

      expect(album.photoCount, 7);
      expect(album.mineCount, 4);
    });

    test('an older server that sends no mineCount is read as all-mine', () {
      // Before this rule every row was the viewer's own, so the row count was
      // the honest answer. Defaulting to 0 would have that build announce
      // "0 photos of you found!" against a full grid.
      final album = FoundAlbum.fromJson(json(photoCount: 7));

      expect(album.mineCount, 7);
    });
  });
}
