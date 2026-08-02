import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skidoo_app/core/theme/app_theme_extension.dart';
import 'package:skidoo_app/core/widgets/media_grid.dart';
import 'package:skidoo_app/features/search/presentation/widgets/search_photo_grid.dart';
import 'package:skidoo_app/models/photos/Photo.dart';

/// Media grids are uniform: every tile the same square, whatever shape the
/// photo is.
///
/// They used to be masonry — each tile at its own aspect ratio — which left
/// ragged columns, a short last column, and no two photos comparable at a
/// glance. These pin the replacement, because the ingredients for the old
/// behaviour are all still around: the models still carry `width`/`height` and
/// `PhotoAspectBox` still exists for the places that legitimately want a
/// photo's own shape.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(
          extensions: const [AppThemeExtension.dark],
        ),
        home: Scaffold(body: child),
      ),
    );

/// Deliberately mixed shapes — a panorama, a tower, a square and a couple of
/// legacy records with no dimensions at all.
List<Photo> mixedShapes() {
  const shapes = <List<int>?>[
    [4000, 1000], // 4:1 panorama
    [1000, 4000], // 1:4 tower
    [2000, 2000], // square
    null, // legacy, no dimensions
    [3000, 2000],
    [2000, 3000],
    null,
    [1600, 900],
    [900, 1600],
  ];
  return [
    for (var i = 0; i < shapes.length; i++)
      Photo.fromMap({
        'id': 'p$i',
        'url': 'https://cdn.example.com/p$i.jpg',
        if (shapes[i] != null) 'width': shapes[i]![0],
        if (shapes[i] != null) 'height': shapes[i]![1],
        'event': const {'id': 'e1', 'eventName': 'Praise Reloaded'},
      }),
  ];
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  testWidgets('every tile is the same square, whatever the photo\'s shape',
      (t) async {
    await t.pumpWidget(host(CustomScrollView(
      slivers: [
        SearchPhotoGridSliver(photos: mixedShapes(), onPhotoTap: (_) {}),
      ],
    )));

    final tiles = find.byType(SearchPhotoTile);
    expect(tiles, findsWidgets);

    final first = t.getSize(tiles.first);
    expect(first.width, moreOrLessEquals(first.height, epsilon: 0.5),
        reason: 'tiles must be square');

    for (var i = 1; i < tiles.evaluate().length; i++) {
      expect(t.getSize(tiles.at(i)), first,
          reason: 'tile $i differs from the first — the grid is not uniform');
    }
  });

  testWidgets('a phone gets three columns', (t) async {
    await t.pumpWidget(host(CustomScrollView(
      slivers: [
        SearchPhotoGridSliver(photos: mixedShapes(), onPhotoTap: (_) {}),
      ],
    )));

    final tiles = find.byType(SearchPhotoTile);
    final topRow = <double>{
      for (var i = 0; i < tiles.evaluate().length; i++)
        if (t.getTopLeft(tiles.at(i)).dy == t.getTopLeft(tiles.first).dy)
          t.getTopLeft(tiles.at(i)).dx,
    };
    expect(topRow.length, 3);
  });

  group('clearing the floating nav bar', () {
    /// The shell runs `extendBody: true`, so the body is laid out behind the
    /// bar and Flutter reports the bar's height as bottom padding. A grid that
    /// ignores it leaves its last row under the bar once you reach the end.
    Widget shell({required bool scrolls}) => ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, __) => MaterialApp(
            theme: ThemeData.dark()
                .copyWith(extensions: const [AppThemeExtension.dark]),
            home: MediaQuery(
              data: const MediaQueryData(
                padding: EdgeInsets.only(bottom: 92),
              ),
              child: Scaffold(
                body: scrolls
                    ? MediaGrid(
                        itemCount: 12,
                        itemBuilder: (_, i) => ColoredBox(
                          color: Colors.grey,
                          child: Text('$i'),
                        ),
                      )
                    : CustomScrollView(slivers: [
                        SliverToBoxAdapter(
                          child: MediaGrid(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 12,
                            itemBuilder: (_, i) => ColoredBox(
                              color: Colors.grey,
                              child: Text('$i'),
                            ),
                          ),
                        ),
                      ]),
              ),
            ),
          ),
        );

    testWidgets('a scrolling grid runs out past the bar', (t) async {
      await t.pumpWidget(shell(scrolls: true));

      final grid = t.widget<GridView>(find.byType(GridView));
      expect(grid.padding?.resolve(TextDirection.ltr).bottom, 92);
    });

    testWidgets('a nested grid leaves the clearance to its scroll view',
        (t) async {
      // Adding it here would open a 92 dp hole in the middle of the page.
      await t.pumpWidget(shell(scrolls: false));

      final grid = t.widget<GridView>(find.byType(GridView));
      expect(grid.padding?.resolve(TextDirection.ltr).bottom, 0);
    });
  });

  group('the shared metrics are the single source of truth', () {
    test('thumbnails: three across on a phone, more on wider screens', () {
      const d = MediaGridDensity.thumbnails;
      expect(d.columnsFor(360), 3);
      expect(d.columnsFor(390), 3);
      expect(d.columnsFor(768), 6);
      expect(d.columnsFor(200), 2, reason: 'clamped at the bottom');
      expect(d.columnsFor(4000), 6, reason: 'clamped at the top');
      expect(d.aspectRatio, 1, reason: 'thumbnails are square');
    });

    test('cards: two across on a phone, and taller than wide', () {
      const d = MediaGridDensity.cards;
      expect(d.columnsFor(390), 2);
      expect(d.aspectRatio, lessThan(1),
          reason: 'a card leaves room for text under the image');
    });

    test('a density fixes the shape of every cell it lays out', () {
      // What stops the two families drifting apart again: the delegate comes
      // from the density, not from the call site.
      for (final d in MediaGridDensity.values) {
        final delegate = d.delegate(390);
        expect(delegate.crossAxisCount, d.columnsFor(390));
        expect(delegate.childAspectRatio, d.aspectRatio);
      }
    });
  });
}
