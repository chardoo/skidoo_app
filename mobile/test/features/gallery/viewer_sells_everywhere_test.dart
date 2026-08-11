import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_buy_pill.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_selection_panel.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// A priced photo can be bought from wherever this screen was opened.
///
/// The viewer used to sell only when the caller handed it a selection, which
/// two of its nine entry points did. From the other seven — the Found feed, the
/// discovery grid, a profile's liked and bookmarked photos, search, the request
/// page, a shared `/p/{id}` link — the price was visible and there was no way
/// to act on it.
///
/// The grids those entry points belong to stay plain. The amount lives on this
/// screen and on the Found and QR flows, and nowhere else.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: child,
      ),
    );

Photo photo({String id = 'pic-1', double price = 20}) => Photo.fromMap({
      'id': id,
      'url': 'https://cdn/$id.jpg',
      'price': price,
      'width': 1600,
      'height': 900,
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

void main() {
  setUp(() {
    ImageAspectCache.clear();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  group('opened without a selection', () {
    testWidgets('a priced photo still offers its price and a Buy', (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
      await t.pump();

      expect(find.byType(FoundBuyPill), findsOneWidget);
      expect(find.textContaining('GHS 20'), findsWidgets);
    });

    testWidgets('a free photo offers nothing to buy', (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo(price: 0)])));
      await t.pump();

      expect(find.byType(FoundBuyPill), findsNothing);
    });

    testWidgets('pressing Buy brings up what it will cost', (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
      await t.pump();

      // Nothing is selected until asked for — this is a browse, not a review.
      expect(find.text('Get 1 photo – GHS 20.00'), findsNothing);

      await t.tap(find.byType(FoundBuyPill));
      await t.pump();

      expect(find.text('1 photo selected'), findsOneWidget);
      expect(find.text('Get 1 photo – GHS 20.00'), findsOneWidget,
          reason: 'the price to pay, there and then, with no basket in between');
    });

    testWidgets('several photos add up', (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(
        photos: [photo(id: 'a'), photo(id: 'b'), photo(id: 'c')],
      )));
      await t.pump();

      await t.tap(find.byType(FoundBuyPill));
      await t.pump();
      // Swipe to the next photo and buy that one too.
      await t.drag(find.byType(PageView), const Offset(-400, 0));
      await t.pumpAndSettle();
      await t.tap(find.byType(FoundBuyPill));
      await t.pump();

      expect(find.text('2 photos selected'), findsOneWidget);
      expect(find.text('Get 2 photos – GHS 40.00'), findsOneWidget);
    });

    testWidgets('Clear empties it', (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
      await t.pump();
      await t.tap(find.byType(FoundBuyPill));
      await t.pump();

      await t.tap(find.text('Clear'));
      await t.pump();

      expect(find.text('1 photo selected'), findsNothing);
    });
  });

  group('opened from an album', () {
    testWidgets('it uses the album selection rather than making its own',
        (t) async {
      final photos = [photo(id: 'a'), photo(id: 'b')];
      final album = PhotoSelection(photos: photos);
      album.toggle('a');

      await t.pumpWidget(host(FoundPhotoViewerPage(
        photos: photos,
        selection: album,
      )));
      await t.pump();

      // The album's chosen photo is already in the total here.
      expect(find.text('1 photo selected'), findsOneWidget);

      await t.tap(find.byType(FoundBuyPill));
      await t.pump();

      // And a photo taken out here comes out of the album's selection too.
      expect(album.isSelected('a'), isFalse);
    });
  });

  testWidgets('the panel stays out of the way until something is chosen',
      (t) async {
    await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
    await t.pump();

    expect(find.byType(FoundSelectionPanel), findsOneWidget);
    expect(find.text('Clear'), findsNothing,
        reason: 'mounted, but drawing nothing until there is a selection');
  });
}
