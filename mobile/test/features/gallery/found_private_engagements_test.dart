import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/components/media/media_reaction_rail.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_photo_meta_bar.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// A private photo's engagements sit along the bottom, not down the right.
///
/// The reason is in [FoundPhotoActions.engagementsAtBottom]: a private photo
/// cannot be liked or discussed — both are public-only — so its vertical rail
/// held a single glyph, which is a column only in name. Everything it does
/// have joins the download in the bar, and the right edge goes back to being
/// photograph.
///
/// A public photo is untouched by all of this and keeps the rail it has always
/// had, which is the other half of what these pin.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: child)),
      ),
    );

Photo photo({
  bool isPublic = false,
  double price = 0,
  bool isPurchased = false,
}) =>
    Photo.fromMap({
      'id': 'pic-1',
      'url': 'https://cdn.example.com/pic-1.jpg',
      'price': price,
      'isPurchased': isPurchased,
      'public': isPublic,
      'comments_enabled': true,
      'likeCount': 12,
      'commentCount': 3,
      'event': const {'id': 'evt-1', 'eventName': 'Praise Reloaded 2026'},
    });

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

  testWidgets('a private photo carries its actions in the bottom bar',
      (t) async {
    await t.pumpWidget(host(
      FoundPhotoMetaBar(photo: photo(), purchaseGated: true),
    ));

    expect(find.byType(MediaReactionRail), findsOneWidget);
  });

  testWidgets('and lays them along the bottom, not down the side', (t) async {
    await t.pumpWidget(host(
      FoundPhotoMetaBar(photo: photo(), purchaseGated: true),
    ));

    final rail = t.widget<MediaReactionRail>(find.byType(MediaReactionRail));
    expect(rail.axis, Axis.horizontal);
  });

  testWidgets('a public photo puts nothing in the bar but the download',
      (t) async {
    // Its engagements belong to the rail, which this widget does not draw.
    await t.pumpWidget(host(
      FoundPhotoMetaBar(
        photo: photo(isPublic: true, price: 20, isPurchased: true),
        purchaseGated: true,
      ),
    ));

    expect(find.byType(MediaReactionRail), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsOneWidget);
  });

  testWidgets('an unbought photo gets no actions anywhere', (t) async {
    // Nothing is on offer at all, and the placement rule must not conjure a
    // row for it.
    await t.pumpWidget(host(
      FoundPhotoMetaBar(photo: photo(price: 20), purchaseGated: true),
    ));

    expect(find.byType(MediaReactionRail), findsNothing);
    expect(find.byIcon(Icons.download_rounded), findsNothing);
  });

  testWidgets('the photographer still gets the room they had', (t) async {
    // The actions share the line with the name. A long event title must still
    // ellipsize rather than overflow the row.
    await t.pumpWidget(host(
      FoundPhotoMetaBar(photo: photo(), purchaseGated: true),
    ));

    expect(t.takeException(), isNull);
    expect(find.text('Praise Reloaded 2026'), findsOneWidget);
  });
}

class _EmptyStore implements SavedPhotoStore {
  @override
  Future<List<String>> savedIds() async => const [];
  @override
  Future<void> save(String pictureId) async {}
  @override
  Future<void> unsave(String pictureId) async {}
}
