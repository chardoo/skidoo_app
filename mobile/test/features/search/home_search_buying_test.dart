import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/search/presentation/widgets/search_photo_grid.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// Nothing in the home search flow is priced or sold from a grid.
///
/// Not "You may like", not an event's album, not the results. The amount lives
/// in the Found tab, the QR scan flow, and the full-screen photo view — which
/// is where a photo found through search gets bought.
///
/// The mechanism is one rule in the shared tile: a price is drawn only where
/// the grid was given something to sell into. No selection, no amount. That
/// makes the two failures this flow actually had — a grid pricing photos it
/// could not sell, and a grid selling photos it did not price — impossible to
/// build rather than merely absent today.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: CustomScrollView(slivers: [child]),
        ),
      ),
    );

Photo priced(String id) => Photo.fromMap({
      'id': id,
      'url': 'https://cdn/$id.jpg',
      'price': 13.38,
      'event': const {'id': 'evt-1', 'eventName': 'Amalitech'},
    });

void main() {
  testWidgets('a search grid shows no amount and cannot be bought from',
      (t) async {
    var opened = -1;

    await t.pumpWidget(host(SearchPhotoGridSliver(
      photos: [priced('a'), priced('b')],
      onPhotoTap: (index) => opened = index,
    )));
    await t.pump();

    expect(find.textContaining('GHS'), findsNothing,
        reason: 'priced photos, but not a screen that sells them');

    await t.tap(find.byType(SearchPhotoTile).first);
    await t.pump();

    expect(opened, 0,
        reason: 'a tap opens the photo — the big view is where it is bought');
  });

  testWidgets('the price only follows a grid that was given something to sell',
      (t) async {
    // The mechanism, stated once: the Found tab and the scanned album are the
    // grids that pass a selection, and they are the grids that show a price.
    final selection = PhotoSelection(photos: [priced('a')]);

    await t.pumpWidget(host(SearchPhotoGridSliver(
      photos: [priced('a')],
      selection: selection,
      onPhotoTap: (_) {},
    )));
    await t.pump();

    expect(find.text('GHS 13.38'), findsOneWidget);
  });

  testWidgets('a photo already owned is never priced, in either grid',
      (t) async {
    final owned = Photo.fromMap({
      'id': 'a',
      'url': 'https://cdn/a.jpg',
      'price': 13.38,
      'isPurchased': true,
      'event': const {'id': 'evt-1', 'eventName': 'Amalitech'},
    });

    await t.pumpWidget(host(SearchPhotoGridSliver(
      photos: [owned],
      selection: PhotoSelection(photos: [owned]),
      onPhotoTap: (_) {},
    )));
    await t.pump();

    expect(find.textContaining('GHS'), findsNothing,
        reason: 'repeating the amount on a photo they own reads as a second charge');
  });
}
