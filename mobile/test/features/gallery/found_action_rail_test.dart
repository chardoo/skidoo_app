import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:jperg_app/core/theme/app_theme_extension.dart';
import 'package:jperg_app/features/gallery/data/saved_photos.dart';
import 'package:jperg_app/features/gallery/presentation/found/widgets/found_action_rail.dart';
import 'package:jperg_app/models/photos/Photo.dart';

/// The viewer's rail is the app's reactions surface, and every screen that
/// shows reactions has to offer the external share. The rail was the one that
/// didn't: it had bookmark and send (in-app DM), but no hand-off to the OS
/// share sheet, so a photo opened from the Found tab or an event could not be
/// shared out the way the same photo could from the feed.
Widget host(Widget child) => ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (_, __) => MaterialApp(
        theme: ThemeData.dark()
            .copyWith(extensions: const [AppThemeExtension.dark]),
        home: Scaffold(body: child),
      ),
    );

Photo photo({bool commentsEnabled = true}) => Photo.fromMap({
      'id': 'pic-1',
      'url': 'https://cdn.example.com/pic-1.jpg',
      'comments_enabled': commentsEnabled,
      'likeCount': 206,
      'commentCount': 10,
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

  testWidgets('offers the share action', (t) async {
    await t.pumpWidget(host(FoundActionRail(photo: photo())));

    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
    expect(find.bySemanticsLabel('Share photo'), findsOneWidget);
  });

  testWidgets('save, share and download are three separate actions', (t) async {
    // Bookmark and download were once one button, so Save wrote a file to the
    // phone and no photo could actually be bookmarked. They stay apart because
    // they do genuinely different things.
    await t.pumpWidget(host(FoundActionRail(photo: photo())));

    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
    expect(find.byIcon(Icons.download_outlined), findsOneWidget);
  });

  testWidgets('send and share are one button, not two', (t) async {
    // The opposite call from the one above: these two named the same
    // intention, and the whole difference between them rested on a paper
    // plane sitting next to a share arrow. The destination is chosen in
    // ShareTargetSheet instead, in words — so the rail carries the plane
    // alone and the OS share box appears nowhere on it.
    await t.pumpWidget(host(FoundActionRail(photo: photo())));

    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
    expect(find.byIcon(Icons.ios_share_rounded), findsNothing);
  });

  testWidgets('share survives the owner switching engagement off', (t) async {
    // `comments_enabled` silences like and comment. Sharing is not engagement
    // — it is the viewer passing the photo on — so it stays.
    await t.pumpWidget(
        host(FoundActionRail(photo: photo(commentsEnabled: false))));

    expect(find.byIcon(Icons.favorite_border_rounded), findsNothing);
    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    expect(find.byIcon(Icons.near_me_outlined), findsOneWidget);
  });
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
