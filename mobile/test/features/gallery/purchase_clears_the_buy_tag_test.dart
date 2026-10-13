import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/purchase/paid_gallery_route.dart';
import 'package:jperg_app/core/purchase/photo_selection.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/core/widgets/image_aspect.dart';
import 'package:jperg_app/features/gallery/data/purchased_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/pages/found_photo_viewer_page.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_buy_pill.dart';
import 'package:jperg_app/features/home/presentation/pages/home_page.dart';
import 'package:jperg_app/features/user_profile/presentation/pages/user_profile_page.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// What happens to a photo once it has been paid for.
///
/// The report: "after payment is made the user comes back to the picture with
/// the buy tag again". Both halves of it are pinned here.
///
/// **The tag.** Every priced surface used to read `Photo.isPurchased`, which
/// is a flag fixed when the list was fetched — before the payment — and false
/// on all but two endpoints besides. So the viewer came back offering to sell
/// a photo that had just been bought. Ownership is [PurchasedPhotos]' answer
/// now, which checkout feeds the moment the payment completes.
///
/// **The destination.** A finished purchase does not belong on the photo it
/// started from; it belongs on the photos it bought. See [openPaidGallery].
class _EmptyStore implements PurchasedPhotoStore {
  @override
  Future<List<String>> purchasedIds() async => const [];
}

Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
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
  late PurchasedPhotos purchased;

  setUp(() {
    ImageAspectCache.clear();
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(390 * 3, 844 * 3);
    view.devicePixelRatio = 3;

    purchased = PurchasedPhotos(_EmptyStore());
    GetIt.I.registerSingleton<PurchasedPhotos>(purchased);
  });

  tearDown(() {
    GetIt.I.reset();
    HomePage.tabRequest.value = null;
    UserProfilePage.tabRequest.value = null;
  });

  group('the buy tag', () {
    testWidgets('is there while the photo is unowned', (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
      await t.pump();

      expect(find.byType(FoundBuyPill), findsOneWidget);
      expect(find.textContaining('GHS 20'), findsWidgets);
    });

    testWidgets('goes the moment the purchase lands, with the viewer still up',
        (t) async {
      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
      await t.pump();
      expect(find.byType(FoundBuyPill), findsOneWidget);

      // What checkout does when the payment completes. The photo on screen
      // still says `isPurchased: false` — it was fetched before the payment —
      // so this is the only thing that can correct it.
      purchased.add(['pic-1']);
      await t.pump();

      expect(find.byType(FoundBuyPill), findsNothing);
      expect(find.textContaining('GHS 20'), findsNothing);
    });

    testWidgets('is never drawn on a photo already owned', (t) async {
      purchased.add(['pic-1']);

      await t.pumpWidget(host(FoundPhotoViewerPage(photos: [photo()])));
      await t.pump();

      expect(find.byType(FoundBuyPill), findsNothing);
    });
  });

  group('the selection', () {
    test('drops a photo once it is bought, and says so', () {
      final selection = PhotoSelection(photos: [photo()]);
      addTearDown(selection.dispose);

      selection.toggle('pic-1');
      expect(selection.paidCount, 1);
      expect(selection.total, 20);

      var notified = 0;
      selection.addListener(() => notified++);

      purchased.add(['pic-1']);

      // Nothing left to charge for, and the bar above was told — otherwise it
      // would still be offering "Get 1 photo · GHS 20.00".
      expect(selection.paidCount, 0);
      expect(selection.total, 0);
      expect(selection.hasPurchase, isFalse);
      expect(notified, greaterThan(0));
    });
  });

  group('where a finished purchase lands', () {
    testWidgets('on the gallery of paid photos, not back on the picture',
        (t) async {
      await t.pumpWidget(MaterialApp(
        initialRoute: '/viewer',
        routes: {
          HomePage.routeName: (_) => const Text('home'),
          '/viewer': (context) => TextButton(
                onPressed: () => openPaidGallery(context),
                child: const Text('pay'),
              ),
        },
      ));

      await t.tap(find.text('pay'));
      await t.pumpAndSettle();

      expect(HomePage.tabRequest.value, HomePage.profileTab);
      expect(UserProfilePage.tabRequest.value, UserProfilePage.purchasedTab);
      // No Home was live, so one was opened rather than popped back to.
      expect(find.text('home'), findsOneWidget);
      expect(find.text('pay'), findsNothing);
    });
  });
}
