import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jperg_app/core/purchase/photo_price_badge.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/media_grid.dart';

/// How much of a thumbnail the amount is allowed to cover.
///
/// The badge is a label on a photo, and it was reading as a banner across it:
/// on a three-across grid "GHS 20" took up over half the tile's width, which
/// is the photo's space, not the price's.
///
/// A ratio rather than a font size, because the tile is what it has to sit on
/// and the tile changes with the screen. Measured on the narrowest phone the
/// app supports, where a tile is smallest and the badge is worst.
double _lastTileWidth = 0;

void main() {
  const designWidth = 390.0;

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(designWidth * 3, 844 * 3);
    view.devicePixelRatio = 3;
  });

  Future<double> ratioOn(WidgetTester t, {required bool compact}) async {
    late double tileWidth;

    await t.pumpWidget(ScreenUtilInit(
      designSize: const Size(designWidth, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: [AppThemeExtension.dark]),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: MediaGrid(
              shrinkWrap: true,
              itemCount: 3,
              itemBuilder: (context, i) => LayoutBuilder(
                builder: (context, constraints) {
                  tileWidth = constraints.maxWidth;
                  return Stack(
                    children: [
                      Positioned(
                        left: 6,
                        bottom: 6,
                        child: PhotoPriceBadge(price: 20, compact: compact),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    ));
    await t.pump();

    _lastTileWidth = tileWidth;
    final badge = t.getSize(find.byType(PhotoPriceBadge).first);
    return badge.width / tileWidth;
  }

  Future<({double height, double tile})> sizeOn(
    WidgetTester t, {
    required bool compact,
  }) async {
    await ratioOn(t, compact: compact);
    return (
      height: t.getSize(find.byType(PhotoPriceBadge).first).height,
      tile: _lastTileWidth,
    );
  }

  testWidgets('the amount takes half a grid tile at most', (t) async {
    final ratio = await ratioOn(t, compact: true);
    expect(ratio, lessThan(0.5),
        reason: 'it was covering 70% of the photo it labels');
  });

  testWidgets('and no more than a tenth of its height', (t) async {
    final size = await sizeOn(t, compact: true);
    expect(size.height / size.tile, lessThan(0.13),
        reason: 'a fifth of the tile was a band across the photo');
  });

  testWidgets('and stays large enough to read', (t) async {
    final ratio = await ratioOn(t, compact: true);
    expect(ratio, greaterThan(0.3),
        reason: 'a price nobody can read is not cheaper than one nobody wants');
  });

  testWidgets('the full size is the one no tile uses', (t) async {
    // Kept for the day something has room for it — the Buy pill in the viewer
    // draws its own, so nothing on a thumbnail should reach for this.
    expect(await ratioOn(t, compact: false),
        greaterThan(await ratioOn(t, compact: true)));
  });
}
